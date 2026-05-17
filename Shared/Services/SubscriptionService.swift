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

    static let apiKey = "appl_eTgmJWtWPGZuOHUGMvSEpOOemxA"

    static let proEntitlement = "pro"

    private static let trialEndsKey = "bloomTrialEndsAt"
    private static let trialClaimedKey = "bloomTrialClaimed"

    private var entitlementActive: Bool = false
    private var localOverride: Bool = false
    private var trialRevision: Int = 0
    private(set) var isConfigured: Bool = false

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

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
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
            entitlementActive = info.entitlements[Self.proEntitlement]?.isActive == true
        } catch {
            // Leave previous state on network errors.
        }
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
