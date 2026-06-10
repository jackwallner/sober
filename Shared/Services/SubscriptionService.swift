import Foundation
import Observation
import os
#if canImport(RevenueCat)
import RevenueCat
#endif

enum PurchaseState {
    case purchased
    case cancelled
    case pending
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

    /// Per-product intro-offer eligibility from RevenueCat.
    private(set) var introEligibility: [String: Bool] = [:]

    /// True once RevenueCat has returned intro-offer eligibility. Until then the
    /// paywall must not promise a free trial it can't confirm (Apple 3.1.2).
    private(set) var introEligibilityResolved: Bool = false
    #endif

    private var paywallImpressionsThisSession: Set<String> = []

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

    private override init() {
        super.init()
    }

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
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
    }

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
        guard isConfigured else { return }
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
        guard isConfigured else { return }
        isLoadingProducts = true
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
                lastError = nil
            }
            await refreshIntroEligibility()
        } catch {
            logger.error("Product fetch failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't load subscription options. Check your connection and try again."
        }
        #endif
    }

    #if canImport(RevenueCat)
    private func refreshIntroEligibility() async {
        let identifiers = packages
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            introEligibilityResolved = true
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
        introEligibilityResolved = true
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.packageHasFreeTrialIntro() else { return false }
        // Until eligibility is confirmed, default to NOT eligible so the CTA and
        // disclosure never momentarily promise a free trial to a returning user
        // who has already consumed it (Apple 3.1.2). Flips to the real answer
        // once refreshIntroEligibility resolves.
        guard introEligibilityResolved else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? false
    }

    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard isConfigured else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        guard isConfigured else { throw PurchaseError.notConfigured }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        }
        if result.customerInfo.hasSoberProEntitlement {
            return .purchased
        }
        return .pending
    }

    func restorePurchases() async {
        guard isConfigured else { return }
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

    private func apply(customerInfo: CustomerInfo) {
        let active = customerInfo.hasSoberProEntitlement
        let activeKeys = customerInfo.entitlements.active.keys.sorted().joined(separator: ", ")
        // Logged so a dashboard mismatch (products not attached to the "pro"
        // entitlement, or an entitlement named "Bloom+"/different casing) is
        // visible in Console instead of silently leaving a paid user locked.
        logger.info("Applied customerInfo — active entitlements: [\(activeKeys, privacy: .public)] -> isPro \(active, privacy: .public)")
        entitlementActive = active
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

    /// Grant a one-time complimentary trial (surfaced at emotional milestones).
    /// No-op if one has already been claimed.
    func startComplimentaryTrial(days: Int) {
        guard !hasClaimedTrial else { return }
        let end = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        AppGroup.defaults.set(end.timeIntervalSince1970, forKey: Self.trialEndsKey)
        AppGroup.defaults.set(true, forKey: Self.trialClaimedKey)
        trialRevision += 1
    }

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
