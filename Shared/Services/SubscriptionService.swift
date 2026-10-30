import Foundation
import Observation
import os
#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCat)
/// The purchase boundary is injectable so entitlement flows can run without StoreKit.
@MainActor
protocol RevenueCatClient: AnyObject {
    var cachedCustomerInfo: CustomerInfo? { get }
    func customerInfo(fetchPolicy: CacheFetchPolicy) async throws -> CustomerInfo
    func paywallOffering(forceRefresh: Bool) async throws -> RevenueCat.Offering?
    func purchase(package: Package) async throws -> PurchaseResultData
    func restorePurchases() async throws -> CustomerInfo
    func introEligibility(productIdentifiers: [String]) async -> [String: IntroEligibilityStatus]
    func setSubscriberAttributes(_ attributes: [String: String])
    func recordImpression(_ params: CustomPaywallImpressionParams)
}

extension Purchases: RevenueCatClient {
    func paywallOffering(forceRefresh: Bool) async throws -> RevenueCat.Offering? {
        let offerings: Offerings
        if forceRefresh, let refreshed = try await syncAttributesAndOfferingsIfNeeded() {
            offerings = refreshed
        } else {
            offerings = try await self.offerings()
        }
        return offerings.offering(identifier: "default") ?? offerings.current
    }

    func introEligibility(productIdentifiers: [String]) async -> [String: IntroEligibilityStatus] {
        await checkTrialOrIntroDiscountEligibility(productIdentifiers: productIdentifiers).mapValues(\.status)
    }

    func setSubscriberAttributes(_ attributes: [String: String]) {
        attribution.setAttributes(attributes)
    }

    func recordImpression(_ params: CustomPaywallImpressionParams) {
        trackCustomPaywallImpression(params)
    }
}

enum RevenueCatEnvironment {
    static func key(production: String, isDebug: Bool, isSimulator: Bool, testKey: String?) -> String? {
        if isDebug { return testKey?.hasPrefix("test_") == true ? testKey : nil }
        return !isSimulator && production.hasPrefix("appl_") ? production : nil
    }

    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
#endif

enum PurchaseState: Equatable {
    case purchased
    case cancelled
    case pending
}

enum OnboardingTrialResolution: Equatable {
    case eligible
    case ineligible
    case unavailable
    case failed
}

/// RevenueCat wrapper. `apiKey` is the production public SDK key from the
/// RevenueCat dashboard (App Store app). The "pro" entitlement gates Pro
/// features and must map to the three IAP products in the "default" offering.
@MainActor
@Observable
final class SubscriptionService: NSObject {
    static let shared = SubscriptionService()

    static let apiKey = "appl_eTgmJWtWPGZuOHUGMvSEpOOemxA"

    // The real entitlement identifier in the RevenueCat dashboard (the three
    // IAP products are attached to it). NOT "pro" — that mismatch is what left
    // completed purchases locked. The check below also falls back to "any active
    // entitlement" so a future dashboard rename can't silently re-break unlock.
    nonisolated static let proEntitlement = "Sober Tracker - Alcohol Free Pro"

    private static let trialEndsKey = "bloomTrialEndsAt"
    private static let trialClaimedKey = "bloomTrialClaimed"

    private let logger = Logger(subsystem: "com.jackwallner.sober", category: "Subscriptions")

    private(set) var hasResolvedEntitlements = false
    private var entitlementActive: Bool = false
    private var localOverride: Bool = false
    private var trialRevision: Int = 0
    private let clientOverride: (any RevenueCatClient)?
    private var client: any RevenueCatClient { clientOverride ?? Purchases.shared }
    private var lastCustomerInfoDate: Date?
    private(set) var entitlementCheckFailed = false
    var isCheckingEntitlements: Bool { storeIsLive && !hasResolvedEntitlements && !isProSubscriber && !entitlementCheckFailed }
    private(set) var isConfigured: Bool = false

    private(set) var isLoadingProducts: Bool = false
    private(set) var lastError: String?
    private(set) var purchaseInFlight: Bool = false

    #if canImport(RevenueCat)
    private(set) var packages: [Package] = []

    /// Per-product intro-offer eligibility from RevenueCat. Preserve the full
    /// status so onboarding can distinguish a confirmed ineligible account from
    /// a temporary unknown result instead of silently skipping the trial.
    private(set) var introEligibility: [String: IntroEligibilityStatus] = [:]

    /// True once RevenueCat has returned intro-offer eligibility. Until then the
    /// paywall must not promise a free trial it can't confirm (Apple 3.1.2).
    private(set) var introEligibilityResolved: Bool = false
    #endif

    private var paywallImpressionsThisSession: Set<String> = []

    /// The `default` offering's `trial_note` switch. See `TrialNote`.
    private(set) var trialNoteConfig: TrialNote.Config = .none
    /// The trial note's promise: ask what to fix once its trial stops renewing.
    private(set) var whatToFixDue = false
    private var productFetchTask: Task<Void, Never>?

    /// Single gate the whole app reads. True for a real entitlement, a dev
    /// override, or an active complimentary trial.
    var isProSubscriber: Bool {
        _ = trialRevision  // observation dependency so trial grants re-render
        return entitlementActive || localOverride || isTrialActive
    }

    /// Whether a complimentary trial has ever been granted (so we only offer
    /// it once).
    var hasClaimedTrial: Bool {
        AppGroup.defaults.bool(forKey: Self.trialClaimedKey)
    }

    var trialEndsAt: Date? {
        let ts = AppGroup.defaults.double(forKey: Self.trialEndsKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    var isTrialActive: Bool {
        guard let end = trialEndsAt else { return false }
        return end > .now
    }

    var trialDaysRemaining: Int {
        guard let end = trialEndsAt, end > .now else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 0)
    }

    init(client: (any RevenueCatClient)? = nil) {
        clientOverride = client
        super.init()
        isConfigured = client != nil
    }

    func configure() {
        configureIfNeeded()
        guard storeIsLive else { return }
        if let cached = client.cachedCustomerInfo { apply(customerInfo: cached) }
        Task {
            await refresh(fetchPolicy: .fetchCurrent)
            await fetchProducts()
        }
    }

    private func configureIfNeeded() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
        #if DEBUG
        let testKey = RevenueCatProbe.isEnabled ? RevenueCatProbe.testStoreKey : nil
        #else
        let testKey: String? = nil
        #endif
        guard let key = RevenueCatEnvironment.key(
            production: Self.apiKey,
            isDebug: RevenueCatEnvironment.isDebug,
            isSimulator: RevenueCatEnvironment.isSimulator,
            testKey: testKey
        ) else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: key)
                .with(appUserID: RevenueCatProbe.appUserID)
                .build()
        )
        #else
        Purchases.configure(withAPIKey: key)
        #endif
        Purchases.shared.delegate = self
        isConfigured = true
        #endif
    }

    #if canImport(RevenueCat)
    /// True only when a real `Purchases` session exists. Every call that
    /// touches `Purchases.shared` must gate on this rather than `isConfigured`:
    /// the preview store sets `isConfigured` so the paywall renders, but there
    /// is no configured SDK behind it and the accessor traps.
    var storeIsLive: Bool {
        #if DEBUG
        return isConfigured && !isPreviewStore
        #else
        return isConfigured
        #endif
    }
    #endif

    #if DEBUG && canImport(RevenueCat)
    /// True when the paywall is running against locally-built packages instead
    /// of a live RevenueCat offering, so purchase paths know to no-op rather
    /// than call into an unconfigured `Purchases`.
    private(set) var isPreviewStore: Bool = false

    /// Load a local offering so the real paywall renders on a headless
    /// simulator. See `PaywallPreviewStore` for why this exists: `configure()`
    /// intentionally refuses to run on simulator, which otherwise makes every
    /// store-derived string on the paywall impossible to inspect before ship.
    func loadPreviewStore(trialDays: Int, introEligible: Bool = true) {
        let loaded = PaywallPreviewStore.packages(trialDays: trialDays).sorted {
            let lhs = $0.soberPackageKind.rawValue
            let rhs = $1.soberPackageKind.rawValue
            if lhs != rhs { return lhs < rhs }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
        packages = loaded
        introEligibility = Dictionary(
            uniqueKeysWithValues: PaywallPreviewStore.eligibleIdentifiers(in: loaded).map {
                ($0, introEligible ? IntroEligibilityStatus.eligible : .ineligible)
            }
        )
        introEligibilityResolved = true
        isLoadingProducts = false
        lastError = nil
        isPreviewStore = true
        isConfigured = true
        logger.info("Preview store loaded with a \(trialDays)-day trial")
    }
    #endif

    func refresh() async {
        await refresh(fetchPolicy: .default)
    }

    /// Force a server-side entitlement re-check that bypasses the on-device
    /// cache. Called on every foreground so renewals/restores/late grants flip
    /// the app to Pro promptly. RevenueCat-type-free signature so callers (e.g.
    /// `App.swift`) don't need to import RevenueCat.
    func refreshFromServer() async {
        #if canImport(RevenueCat)
        await refresh(fetchPolicy: .fetchCurrent)
        #endif
    }

    func refresh(fetchPolicy: CacheFetchPolicy = .default) async {
        #if canImport(RevenueCat)
        guard storeIsLive else { return }
        entitlementCheckFailed = false
        do {
            let info = try await client.customerInfo(fetchPolicy: fetchPolicy)
            apply(customerInfo: info)
        } catch {
            entitlementCheckFailed = true
            // Leave previous state on network errors.
        }
        #endif
    }

    func fetchProducts() async {
        #if canImport(RevenueCat)
        guard storeIsLive else { return }
        if let productFetchTask {
            await productFetchTask.value
            return
        }
        let task = Task { @MainActor in
            await performProductFetch()
        }
        productFetchTask = task
        await task.value
        productFetchTask = nil
        #endif
    }

    #if canImport(RevenueCat)
    private func performProductFetch() async {
        isLoadingProducts = true
        introEligibilityResolved = false
        defer { isLoadingProducts = false }
        do {
            let offering = try await client.paywallOffering(forceRefresh: false)
            packages = offering?.soberSortedPackages ?? []
            trialNoteConfig = TrialNote.config(from: offering?.metadata)
            if packages.isEmpty {
                // The network call succeeded but the paywall offering is missing
                // or carries no packages — a RevenueCat dashboard gap (offering
                // not published, or no products attached to "default"/current),
                // NOT a connectivity problem. Surface an honest message and log
                // it so the dead-end is visible in TestFlight/review instead of
                // masquerading as an offline error the user can never clear.
                logger.error("Offerings loaded but the paywall offering has no packages. Check the RevenueCat \"default\" offering and product attachment.")
                lastError = String(localized: "Plans are temporarily unavailable. Please try again in a moment.")
            } else {
                let kinds = packages.map { String(describing: $0.soberPackageKind) }.joined(separator: ",")
                logger.info("Loaded \(self.packages.count) packages [\(kinds, privacy: .public)]")
                lastError = nil
            }
            await refreshIntroEligibility()
        } catch {
            packages = []
            introEligibility = [:]
            introEligibilityResolved = false
            logger.error("Product fetch failed: \(String(describing: error), privacy: .public)")
            lastError = String(localized: "Couldn't load subscription options. Check your connection and try again.")
        }
    }
    #endif

    #if canImport(RevenueCat)
    private func refreshIntroEligibility() async {
        let identifiers = packages
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            introEligibilityResolved = true
            logger.info("No fetched package contains an introductory offer")
            return
        }
        let result = await client.introEligibility(productIdentifiers: identifiers)
        introEligibility = result
        introEligibilityResolved = true
        let statuses = result
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.description)" }
            .joined(separator: ",")
        logger.info("Intro eligibility resolved [\(statuses, privacy: .public)]")
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.packageHasFreeTrialIntro() else { return false }
        // Until eligibility is confirmed, default to NOT eligible so the CTA and
        // disclosure never momentarily promise a free trial to a returning user
        // who has already consumed it (Apple 3.1.2). Flips to the real answer
        // once refreshIntroEligibility resolves.
        guard introEligibilityResolved else { return false }
        return introEligibility[package.storeProduct.productIdentifier] == .eligible
    }

    /// Mirror the on-device conversion counters onto the RevenueCat customer as
    /// subscriber attributes (`funnel_*`).
    ///
    /// Deliberately NOT sent as extra custom paywall impressions: `paywall_
    /// encounter_v3` treats every impression id as a paywall encounter, so
    /// pushing funnel steps through that channel would drive the encounter rate
    /// to 100% and destroy the one server-side number that currently works.
    /// Attributes stay off the charts and are readable per customer.
    func syncConversionAttributes() {
        guard storeIsLive else { return }
        var attributes: [String: String] = [:]
        for (event, count) in ConversionDiagnostics.counts {
            attributes["funnel_\(event.rawValue)"] = String(count)
        }
        // The fleet-wide paywall keys, alongside the onboarding event counters
        // rather than replacing them: the events say where someone dropped out
        // of onboarding, these say how often and how early they were pitched.
        attributes.merge(ConversionDiagnostics.subscriberAttributes) { _, fleet in fleet }
        if let arm = TrialNote.seenArm() { attributes[TrialNote.attributeKey] = arm }
        guard !attributes.isEmpty else { return }
        client.setSubscriberAttributes(attributes)
    }

    func trackPaywallImpression(id: String, package: Package? = nil, oncePerSession: Bool = false) {
        guard storeIsLive else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        ConversionDiagnostics.recordPitchView(impressionID: id)
        syncConversionAttributes()
        client.recordImpression(
            CustomPaywallImpressionParams(
                paywallId: id,
                offeringId: package?.presentedOfferingContext.offeringIdentifier
            )
        )
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        #if DEBUG
        // Rendering harness: `Purchases` was never configured, so a real
        // purchase would trap. Grant locally instead so the post-purchase
        // states stay inspectable too.
        if isPreviewStore {
            setLocalOverride(isPro: true)
            return .purchased
        }
        #endif
        guard storeIsLive else { throw PurchaseError.notConfigured }
        if !hasResolvedEntitlements { await refresh() }
        if isProSubscriber { return .purchased }
        guard hasResolvedEntitlements else { throw PurchaseError.notConfigured }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let startedTrial = isEligibleForIntroOffer(package)
        let result: PurchaseResultData
        do {
            result = try await client.purchase(package: package)
        } catch where Self.isDeferredPayment(error) {
            // Ask to Buy and bank approval arrive as an error, not as a
            // pending result, so they read as a failed purchase and invited a
            // second request. The entitlement lands later through the delegate.
            return .pending
        }
        let state = processPurchaseResult(
            customerInfo: result.customerInfo,
            userCancelled: result.userCancelled
        )
        if state == .purchased {
            ConversionDiagnostics.recordConversion(
                plan: package.storeProduct.productIdentifier,
                startedTrial: startedTrial,
                offeringID: package.presentedOfferingContext.offeringIdentifier
            )
            syncConversionAttributes()
        }
        return state
    }

    nonisolated static func isDeferredPayment(_ error: Error) -> Bool {
        (error as? RevenueCat.ErrorCode) == .paymentPendingError
    }

    func restorePurchases() async {
        guard storeIsLive else { return }
        lastError = nil
        do {
            let info = try await client.restorePurchases()
            apply(customerInfo: info)
            if !entitlementActive {
                lastError = String(localized: "No active Bloom+ purchase was found for this Apple ID.")
            }
        } catch {
            logger.error("Restore failed: \(String(describing: error), privacy: .public)")
            lastError = String(localized: "Couldn't restore purchases. Try again.")
        }
    }

    private func apply(customerInfo: CustomerInfo, now: Date = .now) {
        guard lastCustomerInfoDate.map({ customerInfo.requestDate >= $0 }) ?? true else { return }
        lastCustomerInfoDate = customerInfo.requestDate
        hasResolvedEntitlements = true
        let active = customerInfo.hasSoberProEntitlement
        let activeKeys = customerInfo.entitlements.active.keys.sorted().joined(separator: ", ")
        // Logged so a dashboard mismatch (products not attached to the "pro"
        // entitlement, or an entitlement named "Bloom+"/different casing) is
        // visible in Console instead of silently leaving a paid user locked.
        logger.info("Applied customerInfo — active entitlements: [\(activeKeys, privacy: .public)] -> isPro \(active, privacy: .public)")
        entitlementActive = active

        // Detect the trial here rather than at the purchase call site: this runs
        // on every refresh and delegate push, so a trial started in onboarding,
        // on another device, or restored later is still tracked.
        let entitlement = customerInfo.entitlements[Self.proEntitlement]
            ?? customerInfo.entitlements.active.values.first
        TrialLifecycle.sync(
            isTrialing: entitlement?.isActive == true && entitlement?.periodType == .trial,
            endsAt: entitlement?.expirationDate,
            now: now
        )
        whatToFixDue = TrialNote.whatToFixDue(
            // Running or already ended: someone who cancels and next opens the
            // app after the week is still owed the ask.
            inTrial: entitlement?.periodType == .trial,
            // A billing retry is Apple still trying, not a choice to leave.
            willRenew: entitlement.map { $0.willRenew || $0.billingIssueDetectedAt != nil } ?? true
        )
    }

    func whatToFixShown() {
        TrialNote.markAsked()
        whatToFixDue = false
    }

    /// Applies the same CustomerInfo returned by RevenueCat after a purchase.
    /// Kept as one handler so tests can exercise the purchase-to-trial path with
    /// a constructed sandbox CustomerInfo without configuring the production SDK.
    @discardableResult
    func processPurchaseResult(
        customerInfo: CustomerInfo,
        userCancelled: Bool,
        now: Date = .now
    ) -> PurchaseState {
        apply(customerInfo: customerInfo, now: now)
        if userCancelled { return .cancelled }
        if entitlementActive { return .purchased }
        return .pending
    }
    #endif

    /// True when at least one fetched package carries an intro offer the current
    /// Apple ID is still eligible for. Drives trial-led copy *outside* the
    /// paywall (Apple 3.1.2: never promise a free trial to a user who already
    /// consumed theirs).
    var hasTrialOfferAvailable: Bool {
        #if canImport(RevenueCat)
        return packages.contains { isEligibleForIntroOffer($0) }
        #else
        return false
        #endif
    }

    /// Auto-renew terms and the cancel path. Stays caption-sized wherever it is
    /// shown: Apple wants it present and legible, not competing with the price.
    ///
    /// Outside the RevenueCat guard because onboarding reserves this string's
    /// height on every step, including the ones that never touch the store.
    nonisolated static var autoRenewDisclosure: String {
        String(localized: "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions.")
    }

    #if canImport(RevenueCat)
    /// The plan the one-tap onboarding trial actually buys: monthly when it
    /// carries a free-trial intro offer this Apple ID is still eligible for,
    /// yearly as the fallback.
    var directTrialPackage: Package? {
        let trialPackages = packages.filter { isEligibleForIntroOffer($0) }
        return Self.preferredTrialPackage(from: trialPackages)
    }

    /// What the one-tap onboarding CTA actually buys, trial or not.
    ///
    /// `directTrialPackage` is nil for an Apple ID that has already used its
    /// intro offer, which used to mean onboarding had nothing to sell and fell
    /// through to a paywall sheet on Home. Same preference order, minus the
    /// eligibility filter, so a returning user still gets an offer in place.
    var directOfferPackage: Package? {
        directTrialPackage ?? Self.preferredTrialPackage(from: packages)
    }

    static func preferredTrialPackage(from trialPackages: [Package]) -> Package? {
        guard let preferredKind = preferredTrialKind(from: trialPackages.map(\.soberPackageKind)) else {
            return nil
        }
        return trialPackages.first { $0.soberPackageKind == preferredKind }
    }

    /// Monthly first for the one-tap onboarding trial (2026-10-16). The yearly
    /// CTA sent Apple's sheet to "$29.99 every year": on the 1.3.3 page 3 of 4
    /// users who tapped it cancelled there, and fleet-wide the onboarding pages
    /// that sell a monthly trial convert best (Mahj, 129 of 130 trials monthly,
    /// 43% of viewers). The paywall keeps its own yearly default; this only
    /// picks what the onboarding button buys.
    nonisolated static func preferredTrialKind(from kinds: [SoberPackageKind]) -> SoberPackageKind? {
        if kinds.contains(.monthly) { return .monthly }
        if kinds.contains(.yearly) { return .yearly }
        return kinds.first
    }

    func resolveOnboardingTrial() async -> OnboardingTrialResolution {
        if isProSubscriber { return .ineligible }

        if packages.isEmpty || !introEligibilityResolved || lastError != nil {
            await fetchProducts()
        }

        if isProSubscriber { return .ineligible }
        guard !packages.isEmpty else {
            logger.error("Onboarding trial unavailable: no packages loaded")
            return lastError == nil ? .unavailable : .failed
        }

        let trialPackages = packages.filter { $0.packageHasFreeTrialIntro() }
        guard !trialPackages.isEmpty else {
            logger.error("Onboarding trial unavailable: no package has a free-trial intro")
            return .unavailable
        }
        guard introEligibilityResolved else {
            logger.error("Onboarding trial failed: intro eligibility did not resolve")
            return .failed
        }
        if Self.preferredTrialPackage(from: trialPackages.filter { isEligibleForIntroOffer($0) }) != nil {
            return .eligible
        }

        let statuses = trialPackages.compactMap {
            introEligibility[$0.storeProduct.productIdentifier]
        }
        if statuses.contains(.unknown) {
            logger.error("Onboarding trial failed: RevenueCat returned unknown eligibility")
            return .failed
        }
        return .ineligible
    }

    var trialOfferHeadlineLabel: String? {
        directTrialPackage?.soberIntroOfferLabel
    }

    /// Full Apple-3.1.2 auto-renew disclosure for the direct-trial CTA: trial
    /// length, then the real price of the package the button purchases, then
    /// auto-renew and the cancel path. Nil until products load so the UI never
    /// shows a placeholder price. Falls back to a price-only variant when the
    /// intro offer isn't available to this Apple ID.
    ///
    /// The fallback runs the same `preferredTrialKind` selection over every
    /// loaded package rather than naming a plan literally, so it cannot drift
    /// out of step with the CTA and quote a plan the button does not buy (3.1.2,
    /// and a refund magnet).
    var directTrialCTADisclosureText: String? {
        guard let headline = directTrialPriceHeadline else { return nil }
        return "\(headline) \(Self.autoRenewDisclosure)"
    }

    /// The price half of the 3.1.2 disclosure, on its own so onboarding can give
    /// it real visual weight next to the CTA.
    ///
    /// It used to exist only as the opening clause of a single caption-sized,
    /// 75%-opacity paragraph that also carried the auto-renew boilerplate, sat
    /// third in the stack under two louder cards, and so was the least prominent
    /// thing on a screen whose whole job is to start a paid trial. "Clearly and
    /// conspicuously" is the standard, and a legalese blob does not meet it.
    var directTrialPriceHeadline: String? {
        guard let package = directOfferPackage else { return nil }
        if isEligibleForIntroOffer(package), let headline = package.soberTrialThenPriceSentence {
            return headline
        }
        let price = package.soberPriceLabel
        return String(localized: "\(price).")
    }

    /// Auto-renew terms and the cancel path. Stays caption-sized: Apple wants it
    /// present and legible, not competing with the price.
    var directTrialRenewalDisclosure: String? {
        directTrialPriceHeadline == nil ? nil : Self.autoRenewDisclosure
    }


    /// Parsed trial length for hero and plan-stack footnotes.
    var trialOfferDayCount: Int? {
        directTrialPackage?.soberIntroOfferDays
    }

    /// Footnote under the plan stack — makes it explicit which tiers include
    /// a free trial when Monthly and Yearly both carry intro offers.
    var subscriptionTrialFootnote: String? {
        let trialKinds = Set(
            packages.filter { isEligibleForIntroOffer($0) }.map(\.soberPackageKind)
        )
        guard trialKinds.contains(.monthly) || trialKinds.contains(.yearly) else { return nil }
        // No literal fallback: a footnote that names the wrong number is worse
        // than no footnote, and the plan cards already carry the real label.
        guard let days = trialOfferDayCount else { return nil }
        switch (trialKinds.contains(.monthly), trialKinds.contains(.yearly)) {
        case (true, true):
            return String(localized: "\(days)-day free trial on Monthly and Yearly.")
        case (true, false):
            return String(localized: "\(days)-day free trial on Monthly.")
        case (false, true):
            return String(localized: "\(days)-day free trial on Yearly.")
        default:
            return nil
        }
    }
    #endif

    /// Debug-only escape hatch so the paywall and gated views can be exercised
    /// without a live RevenueCat key.
    #if DEBUG
    func setLocalOverride(isPro: Bool) {
        localOverride = isPro
    }
    #endif
}

#if canImport(RevenueCat)
extension CustomerInfo {
    /// Sober ships a single premium tier (Bloom+), so any active entitlement
    /// unlocks Pro. Intentionally permissive: matching only one literal
    /// identifier silently leaves a completed purchase locked whenever the
    /// RevenueCat dashboard entitlement is named differently (the actual one is
    /// "Sober Tracker - Alcohol Free Pro", not "pro") or the products aren't
    /// attached to it. Prefer the named entitlement, fall back to "any active
    /// entitlement" like Vitals.
    var hasSoberProEntitlement: Bool {
        entitlements[SubscriptionService.proEntitlement]?.isActive == true
            || !entitlements.active.isEmpty
    }
}

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        receive(customerInfo)
    }

    @discardableResult
    nonisolated func receive(_ customerInfo: CustomerInfo) -> Task<Void, Never> {
        Task { @MainActor in self.apply(customerInfo: customerInfo) }
    }
}

enum PurchaseError: Error {
    case notConfigured
}
#endif

#if DEBUG
/// Simulator-only proof path for the fleet-wide funnel attributes.
///
/// Under the normal rules the attributes cannot be verified on a simulator: the
/// production key must never be configured there, so RevenueCat is never
/// configured, so nothing is ever sent, so a physical device is the only
/// witness. This uses the project's Test Store key instead, which is a different
/// RevenueCat app inside the same project.
///
/// DEBUG only, and only with the launch argument, so it cannot reach a Release
/// build or an ordinary simulator run.
enum RevenueCatProbe {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobe")
    }

    static let testStoreKey = "test_YhWujUwGWMbMMFevFoWfiQqdpyJ"

    static var appUserID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_USER"] ?? "funnel-probe-sober"
    }

    /// The surface the probe reports, so a read-back can assert an exact value
    /// rather than "something arrived".
    static var impressionID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_SURFACE"] ?? "sober_bloom_tab"
    }

    /// Drives a Test Store purchase after the impression, so the `converted_*`
    /// half of the funnel record is exercised and not just the impression half.
    static var wantsPurchase: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobepurchase")
    }
}
#endif
