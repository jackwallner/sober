import Foundation

extension Notification.Name {
    /// Posted after a satisfaction moment on Home — host may present the enjoyment funnel after a short delay.
    static let soberPositiveMomentForReview = Notification.Name("com.jackwallner.sober.positiveMomentForReview")
}

/// How the user last resolved the in-app review / feedback prompt.
enum ReviewPromptOutcome: String, Sendable {
    case openedWriteReview
    case submittedFeedback
}

/// Persists launch counts, positive moments, and review-prompt eligibility in the app group.
@MainActor
enum ReviewPromptTracker {
    private static let defaults = AppGroup.defaults

    private static let launchCountKey = "reviewPrompt.appLaunchCount"
    private static let firstOpenKey = "reviewPrompt.firstAppOpenDate"
    private static let lastShownKey = "reviewPrompt.lastShownDate"
    private static let outcomeKey = "reviewPrompt.outcome"
    private static let positiveMomentCountKey = "reviewPrompt.positiveMomentCount"
    private static let pendingPositiveMomentKey = "reviewPrompt.pendingPositiveMoment"
    private static let pendingMilestoneMomentKey = "reviewPrompt.pendingMilestoneMoment"

    /// Minimum cold starts before passive prompts are considered.
    #if DEBUG
    static let minimumLaunchCount = 2
    #else
    static let minimumLaunchCount = 3
    #endif
    static let minimumDaysSinceFirstOpen = 3
    /// Minimum cumulative positive moments before the passive enjoyment funnel surfaces.
    static let minimumPositiveMoments = 2
    static let cooldownDays = 120
    /// Milestone peaks (a week reached, a tree completed) skip the tenure and
    /// frequency thresholds. Those gates exist to avoid asking a stranger; a
    /// user standing in a celebration screen is not a stranger. Still requires
    /// finished setup, a second launch, and the resolved/cooldown checks.
    static let minimumLaunchCountForMilestone = 2

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: launchCountKey), 0) }
        set { defaults.set(newValue, forKey: launchCountKey) }
    }

    static var firstAppOpenDate: Date? {
        get { defaults.object(forKey: firstOpenKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: firstOpenKey)
            } else {
                defaults.removeObject(forKey: firstOpenKey)
            }
        }
    }

    static var lastShownDate: Date? {
        get { defaults.object(forKey: lastShownKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: lastShownKey)
            } else {
                defaults.removeObject(forKey: lastShownKey)
            }
        }
    }

    static var outcome: ReviewPromptOutcome? {
        get {
            guard let raw = defaults.string(forKey: outcomeKey) else { return nil }
            return ReviewPromptOutcome(rawValue: raw)
        }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: outcomeKey)
            } else {
                defaults.removeObject(forKey: outcomeKey)
            }
        }
    }

    static var positiveMomentCount: Int {
        get { max(defaults.integer(forKey: positiveMomentCountKey), 0) }
        set { defaults.set(newValue, forKey: positiveMomentCountKey) }
    }

    static var hasPendingPositiveMoment: Bool {
        get { defaults.bool(forKey: pendingPositiveMomentKey) }
        set { defaults.set(newValue, forKey: pendingPositiveMomentKey) }
    }

    /// True when the pending moment is a milestone peak rather than a routine
    /// check-in, which relaxes the tenure gates for this one presentation.
    static var hasPendingMilestoneMoment: Bool {
        get { defaults.bool(forKey: pendingMilestoneMomentKey) }
        set { defaults.set(newValue, forKey: pendingMilestoneMomentKey) }
    }

    static func recordAppLaunch(now: Date = .now) {
        if firstAppOpenDate == nil {
            firstAppOpenDate = now
        }
        appLaunchCount += 1
    }

    /// - Parameter isMilestone: pass true for celebration peaks (a time
    ///   milestone reached, a growth stage unlocked) so the prompt can surface
    ///   at the emotional high instead of waiting out the passive thresholds.
    static func recordPositiveMoment(isMilestone: Bool = false) {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
        if isMilestone {
            hasPendingMilestoneMoment = true
        }
    }

    static func consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
        hasPendingMilestoneMoment = false
    }

    static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome == nil else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    static func canPresentEnjoymentPrompt(
        hasCompletedSetup: Bool,
        isMilestone: Bool = false,
        now: Date = .now
    ) -> Bool {
        guard !ScreenshotConfig.isEnabled else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        if isMilestone {
            return appLaunchCount >= minimumLaunchCountForMilestone
        }
        guard appLaunchCount >= minimumLaunchCount else { return false }
        guard positiveMomentCount >= minimumPositiveMoments else { return false }
        guard let first = firstAppOpenDate else { return false }
        let minInterval = TimeInterval(minimumDaysSinceFirstOpen) * 86_400
        guard now.timeIntervalSince(first) >= minInterval else { return false }
        return true
    }

    static func shouldShowAfterPositiveMoment(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canPresentEnjoymentPrompt(
            hasCompletedSetup: hasCompletedSetup,
            isMilestone: hasPendingMilestoneMoment,
            now: now
        )
    }

    static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    static func markFeedbackSubmitted() {
        outcome = .submittedFeedback
        markShown()
    }
}
