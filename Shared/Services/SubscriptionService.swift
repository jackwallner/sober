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

/// RevenueCat wrapper. Replace `apiKey` with the live key from the RevenueCat
/// dashboard before shipping. The "pro" entitlement gates Pro features.
@MainActor
@Observable
final class SubscriptionService: NSObject {
    static let shared = SubscriptionService()

    static let apiKey = "appl_eTgmJWtWPGZuOHUGMvSEpOOemxA"

    static let proEntitlement = "pro"

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
            lastError = nil
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
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.packageHasFreeTrialIntro() else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? true
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
        if result.customerInfo.entitlements[Self.proEntitlement]?.isActive == true {
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
        entitlementActive = customerInfo.entitlements[Self.proEntitlement]?.isActive == true
    }
    #endif

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
