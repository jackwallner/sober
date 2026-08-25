import Foundation
import Observation
import os
#if canImport(RevenueCat)
import RevenueCat
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

    private var entitlementActive: Bool = false
    private var localOverride: Bool = false
    private var trialRevision: Int = 0
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

    override init() {
        super.init()
    }

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
        #if targetEnvironment(simulator)
        // StoreKit Testing supplies local products on simulator. Never configure
        // the production RevenueCat project here or agent runs pollute customer
        // counts and make the real install funnel impossible to interpret.
        return
        #else
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        Task {
            await refresh(fetchPolicy: .fetchCurrent)
            await fetchProducts()
        }
        #endif
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
        do {
            let info = try await Purchases.shared.customerInfo(fetchPolicy: fetchPolicy)
            apply(customerInfo: info)
        } catch {
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
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.soberPaywallOffering
            packages = offering?.soberSortedPackages ?? []
            if packages.isEmpty {
                // The network call succeeded but the paywall offering is missing
                // or carries no packages — a RevenueCat dashboard gap (offering
                // not published, or no products attached to "default"/current),
                // NOT a connectivity problem. Surface an honest message and log
                // it so the dead-end is visible in TestFlight/review instead of
                // masquerading as an offline error the user can never clear.
                logger.error("Offerings loaded but the paywall offering has no packages. Check the RevenueCat \"default\" offering and product attachment.")
                lastError = "Plans are temporarily unavailable. Please try again in a moment."
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
            lastError = "Couldn't load subscription options. Check your connection and try again."
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
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues(\.status)
        introEligibilityResolved = true
        let statuses = result
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.status.description)" }
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
        let counts = ConversionDiagnostics.counts
        guard !counts.isEmpty else { return }
        var attributes: [String: String] = [:]
        for (event, count) in counts {
            attributes["funnel_\(event.rawValue)"] = String(count)
        }
        Purchases.shared.attribution.setAttributes(attributes)
    }

    func trackPaywallImpression(id: String, package: Package? = nil, oncePerSession: Bool = false) {
        guard storeIsLive else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
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
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let result = try await Purchases.shared.purchase(package: package)
        return processPurchaseResult(
            customerInfo: result.customerInfo,
            userCancelled: result.userCancelled
        )
    }

    func restorePurchases() async {
        guard storeIsLive else { return }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            if !entitlementActive {
                lastError = "No active Bloom+ purchase was found for this Apple ID."
            }
        } catch {
            logger.error("Restore failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private func apply(customerInfo: CustomerInfo, now: Date = .now) {
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
        if customerInfo.hasSoberProEntitlement { return .purchased }
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
    nonisolated static let autoRenewDisclosure = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions."

    #if canImport(RevenueCat)
    /// The plan the one-tap onboarding trial actually buys: yearly when it
    /// carries a free-trial intro offer this Apple ID is still eligible for,
    /// monthly as the fallback.
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

    /// Yearly first, everywhere. The onboarding CTA briefly preferred monthly on
    /// the theory that the smaller recurring figure starts more trials, which
    /// held when monthly was $2.99 against a $19.99 yearly (15% of the ask). The
    /// August ladder is $9.99 against $29.99, so monthly is now a third of the
    /// yearly price and Apple's sheet reads "$9.99 every month" where it used to
    /// read "$2.99". Every trial start on record but one was yearly (13 of 14
    /// through 2026-08-15), and the category sells 68% annual, so onboarding and
    /// the paywall now lead with the same plan.
    nonisolated static func preferredTrialKind(from kinds: [SoberPackageKind]) -> SoberPackageKind? {
        if kinds.contains(.yearly) { return .yearly }
        if kinds.contains(.monthly) { return .monthly }
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
        if isEligibleForIntroOffer(package), let trial = package.soberIntroOfferLabel {
            return "\(trial.capitalized), then \(package.soberPriceLabel)."
        }
        return "\(package.soberPriceLabel)."
    }

    /// Auto-renew terms and the cancel path. Stays caption-sized: Apple wants it
    /// present and legible, not competing with the price.
    var directTrialRenewalDisclosure: String? {
        directTrialPriceHeadline == nil ? nil : Self.autoRenewDisclosure
    }


    /// Parsed trial length for hero and plan-stack footnotes.
    var trialOfferDayCount: Int? {
        guard let label = trialOfferHeadlineLabel else { return nil }
        let digits = String(label.drop { !$0.isNumber }.prefix { $0.isNumber })
        return Int(digits)
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
        let label = days == 1 ? "1-day" : "\(days)-day"
        switch (trialKinds.contains(.monthly), trialKinds.contains(.yearly)) {
        case (true, true):
            return "\(label.capitalized) free trial on Monthly and Yearly."
        case (true, false):
            return "\(label.capitalized) free trial on Monthly."
        case (false, true):
            return "\(label.capitalized) free trial on Yearly."
        default:
            return nil
        }
    }
    #endif

    /// Debug-only escape hatch so the paywall and gated views can be exercised
    /// without a live RevenueCat key.
    func setLocalOverride(isPro: Bool) {
        localOverride = isPro
    }
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
        Task { @MainActor in
            SubscriptionService.shared.apply(customerInfo: customerInfo)
        }
    }
}

enum PurchaseError: Error {
    case notConfigured
}
#endif
