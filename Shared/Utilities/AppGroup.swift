import Foundation

enum AppGroup {
    static let identifier = "group.com.jackwallner.sober"

    /// Set when onboarding completes; HomeView consumes it to present the
    /// paywall once on first arrival — the day-0 moment where the large
    /// majority of trial starts happen.
    static let postOnboardingPaywallKey = "postOnboardingPaywallPending"

    /// Unix timestamp of the last passive trial nudge (e.g. on the Health tab).
    /// Gates a cooldown so the nudge surfaces on an escalating schedule.
    static let lastTrialNudgeKey = "lastTrialNudgeAt"

    /// How many passive trial nudges have been shown — indexes the escalating
    /// interval schedule (frequent at first, backing off so it never spams).
    static let trialNudgeCountKey = "trialNudgeCount"

    /// Persisted reach count for a locked Bloom+ feature (journal tap, etc.).
    static func bloomActionCountKey(for intent: String) -> String {
        "bloomActionCount_\(intent)"
    }

    /// Set once the pre-1.3.1 check-in rows have been marked as tended.
    /// `wasLogged` shipped with a default of false, so without this every day
    /// an earlier build recorded came back reading as "the app assumed this".
    static let legacyCheckInsMarkedLoggedKey = "legacyCheckInsMarkedLogged"

    static let journalTabVisitCountKey = "journalTabVisitCount"
    static let checkInCompletedCountKey = "checkInCompletedCount"
    static let growthCelebrationCountKey = "growthCelebrationCount"
    static let cravingRodeOutCountKey = "cravingRodeOutCount"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
