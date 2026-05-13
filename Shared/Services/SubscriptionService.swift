import Foundation
import Observation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat wrapper. Replace `apiKey` with the live key from the RevenueCat
/// dashboard before shipping. The "pro" entitlement gates Pro features.
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    // TODO: replace with the live key from the RevenueCat dashboard.
    static let apiKey = "appl_PLACEHOLDER_REPLACE_ME"

    static let proEntitlement = "pro"

    private(set) var isProSubscriber: Bool = false
    private(set) var isConfigured: Bool = false

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
        guard Self.apiKey.hasPrefix("appl_") && Self.apiKey != "appl_PLACEHOLDER_REPLACE_ME" else { return }
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true
        Task { await refresh() }
        #endif
    }

    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isProSubscriber = info.entitlements[Self.proEntitlement]?.isActive == true
        } catch {
            // Leave previous state on network errors.
        }
        #endif
    }

    /// Debug-only escape hatch so the paywall and gated views can be exercised
    /// without a live RevenueCat key.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
    }
}
