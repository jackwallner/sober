import Foundation

/// Tracks an in-flight Bloom+ free trial so the app can warn before it converts.
///
/// Trials were previously invisible to the app: someone started a 7-day trial
/// and heard nothing until the charge landed, which is both the worst moment to
/// discover a subscription and a reliable source of one-star reviews. This owns
/// the trial's end date, the pre-conversion reminder, and the in-app recap.
///
/// State lives in the App Group rather than SwiftData because the reminder has
/// to survive without a model container (RevenueCat can hand us an update from
/// any launch path, including before the store is ready).
@MainActor
enum TrialLifecycle {
    private static let defaults = AppGroup.defaults

    private static let endsAtKey = "trialLifecycle.endsAt"
    private static let recapSummaryKey = "trialLifecycle.recapSummary"
    private static let recapDismissedForKey = "trialLifecycle.recapDismissedForEnd"

    /// How many days out the in-app recap banner starts showing.
    static let recapLeadDays = 3

    /// End of the trial currently being tracked, if any.
    static var endsAt: Date? {
        let ts = defaults.double(forKey: endsAtKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func daysRemaining(now: Date = .now) -> Int? {
        guard let endsAt, endsAt > now else { return nil }
        let days = Calendar.current.dateComponents([.day], from: now, to: endsAt).day ?? 0
        return max(1, days)
    }

    /// Short "here's what you've grown" line reused by the reminder and recap.
    /// Written by the app when it has the numbers; absent copy falls back to a
    /// generic benefit list rather than fabricating a total.
    static var recapSummary: String? {
        get {
            let value = defaults.string(forKey: recapSummaryKey)
            return (value?.isEmpty ?? true) ? nil : value
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: recapSummaryKey)
            } else {
                defaults.removeObject(forKey: recapSummaryKey)
            }
        }
    }

    /// Reconciles tracked state with the store's view of the subscription.
    /// Idempotent: called on every entitlement refresh, only does work when the
    /// trial's end date actually changes, so foregrounding doesn't respam the
    /// notification center.
    static func sync(isTrialing: Bool, endsAt newEnd: Date?, now: Date = .now) {
        guard isTrialing, let newEnd, newEnd > now else {
            clear()
            return
        }
        // Same trial we already know about — leave the pending reminder alone.
        if let current = endsAt, abs(current.timeIntervalSince(newEnd)) < 60 { return }

        defaults.set(newEnd.timeIntervalSince1970, forKey: endsAtKey)
        defaults.removeObject(forKey: recapDismissedForKey)
        let summary = recapSummary
        Task {
            await NotificationService.scheduleTrialEndingReminder(
                endsAt: newEnd,
                summary: summary,
                now: now
            )
        }
    }

    /// Drops tracked state and the pending reminder — the trial converted, was
    /// cancelled, or the entitlement is gone.
    static func clear() {
        guard defaults.double(forKey: endsAtKey) > 0 else { return }
        defaults.removeObject(forKey: endsAtKey)
        defaults.removeObject(forKey: recapDismissedForKey)
        NotificationService.cancelTrialEndingReminder()
    }

    // MARK: - In-app recap

    /// Whether the Home banner should surface. Deliberately narrow: only in the
    /// final stretch, and only until the user acknowledges it once per trial.
    static func shouldShowRecap(now: Date = .now) -> Bool {
        guard let endsAt, endsAt > now else { return false }
        guard let remaining = daysRemaining(now: now), remaining <= recapLeadDays else { return false }
        return defaults.double(forKey: recapDismissedForKey) != endsAt.timeIntervalSince1970
    }

    static func dismissRecap() {
        guard let endsAt else { return }
        defaults.set(endsAt.timeIntervalSince1970, forKey: recapDismissedForKey)
    }
}
