import Foundation

/// Which plan the one-tap onboarding trial buys. The `default` offering's
/// `onboarding_plan` metadata switches it without a release: `monthly` (or
/// missing) is the live button since 1.3.4, `yearly` is the button before it,
/// `split` deals each install one arm, 50/50, kept for good. The paywall keeps
/// its own yearly default either way.
///
/// Since 1.3.4 the trial rate per download held outside the US and fell in the
/// US, while US downloads also collapsed for store reasons, so the button is
/// tested head to head instead of reverted (Jack, 2026-11-17). The arm rides to
/// RevenueCat as the `onboarding_plan` attribute once the pitch has been seen.
/// Readout: `~/ios/growth/sober-onboarding-plan-test.md`.
enum OnboardingPlan {
    enum Config: String, Sendable {
        case monthly
        case yearly
        case split
    }

    static let metadataKey = "onboarding_plan"
    static let attributeKey = "onboarding_plan"

    private enum Key {
        static let arm = "onboardingPlan.arm"
        static let seen = "onboardingPlan.seen"
    }

    static func config(from metadata: [String: Any]?) -> Config {
        guard let raw = metadata?[metadataKey] as? String else { return .monthly }
        return Config(rawValue: raw) ?? .monthly
    }

    /// The plan the button leads with. Deals a `split` install its arm on the
    /// first call and keeps it; `monthly` or `yearly` overrides a kept arm.
    static func kind(_ config: Config, _ defaults: UserDefaults = .standard,
                     coin: () -> Bool = { Bool.random() }) -> SoberPackageKind {
        #if DEBUG
        if let pinned = launchOverride { return pinned }
        #endif
        switch config {
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .split:
            if let kept = defaults.string(forKey: Key.arm) { return kept == "yearly" ? .yearly : .monthly }
            let dealt: SoberPackageKind = coin() ? .yearly : .monthly
            defaults.set(dealt == .yearly ? "yearly" : "monthly", forKey: Key.arm)
            return dealt
        }
    }

    /// The pitch was on screen leading with `kind`.
    static func markSeen(_ kind: SoberPackageKind, _ defaults: UserDefaults = .standard) {
        defaults.set(kind == .yearly ? "yearly" : "monthly", forKey: Key.seen)
    }

    /// `monthly` or `yearly` once the pitch was seen while the test was on.
    static func seenArm(_ defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: Key.seen)
    }

    #if DEBUG
    /// `-onboardingPlan.arm monthly|yearly` pins the arm for captures.
    private static var launchOverride: SoberPackageKind? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-onboardingPlan.arm"), index + 1 < args.count else { return nil }
        return args[index + 1] == "yearly" ? .yearly : .monthly
    }
    #endif
}
