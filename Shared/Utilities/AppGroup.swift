import Foundation

enum AppGroup {
    static let identifier = "group.com.jackwallner.sober"

    /// Set when onboarding completes; HomeView consumes it to present the
    /// paywall once on first arrival — the day-0 moment where the large
    /// majority of trial starts happen.
    static let postOnboardingPaywallKey = "postOnboardingPaywallPending"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
