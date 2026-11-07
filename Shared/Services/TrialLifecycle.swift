import Foundation

@MainActor
protocol TrialNotificationScheduling {
    func ensureAuthorized() async -> Bool
    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async
    func cancelTrialEndingReminder()
}

@MainActor
private struct LiveTrialNotificationScheduler: TrialNotificationScheduling {
    func ensureAuthorized() async -> Bool {
        await NotificationService.ensureAuthorized()
    }

    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async {
        await NotificationService.scheduleTrialEndingReminder(
            endsAt: endsAt,
            summary: summary,
            now: now
        )
    }

    func cancelTrialEndingReminder() {
        NotificationService.cancelTrialEndingReminder()
    }
}

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
    static var notificationScheduler: any TrialNotificationScheduling = LiveTrialNotificationScheduler()

    private static let endsAtKey = "trialLifecycle.endsAt"
    private static let recapSummaryKey = "trialLifecycle.recapSummary"
    private static let recapDismissedForKey = "trialLifecycle.recapDismissedForEnd"
    private static let scheduledEndKey = "trialLifecycle.scheduledEnd"
    private static let scheduledSummaryKey = "trialLifecycle.scheduledSummary"
    private static var generation = 0

    /// How many days out the in-app recap banner starts showing.
    static let recapLeadDays = 3

    /// End of the trial currently being tracked, if any.
    static var endsAt: Date? {
        let ts = defaults.double(forKey: endsAtKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func daysRemaining(now: Date = .now) -> Int? {
        guard let endsAt else { return nil }
        return daysRemaining(until: endsAt, now: now)
    }

    /// Calendar days until the trial's last day: 0 on that day, 1 the day
    /// before. Counting whole 24-hour blocks and rounding "less than a day"
    /// up to 1 told someone "ends tomorrow" hours before the charge.
    nonisolated static func daysRemaining(until endsAt: Date, now: Date, calendar: Calendar = .current) -> Int? {
        guard endsAt > now else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: endsAt)
        ).day ?? 0
        return max(0, days)
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
    /// reminder on record doesn't match the trial, so foregrounding doesn't
    /// respam the notification center.
    ///
    /// A trial whose renewal is off is no longer tracked: its reminder says
    /// "cancel any time before it renews", which reads as a failed cancel to
    /// someone who already cancelled.
    ///
    /// "Known trial" and "reminder scheduled" are separate. Keying both off the
    /// end date meant a trial first seen while notifications were denied never
    /// got its reminder once they were allowed, and a reminder kept the
    /// numbers from the day the trial started.
    static func sync(isTrialing: Bool, endsAt newEnd: Date?, willRenew: Bool = true, now: Date = .now) {
        guard isTrialing, willRenew, let newEnd, newEnd > now else {
            clear()
            return
        }
        let summary = recapSummary
        if let current = endsAt, abs(current.timeIntervalSince(newEnd)) < 60 {
            // Same trial we already know about: leave a matching reminder alone.
            let scheduledEnd = defaults.double(forKey: scheduledEndKey)
            if abs(scheduledEnd - newEnd.timeIntervalSince1970) < 60,
               defaults.string(forKey: scheduledSummaryKey) == (summary ?? "") {
                return
            }
        } else {
            defaults.set(newEnd.timeIntervalSince1970, forKey: endsAtKey)
            defaults.removeObject(forKey: recapDismissedForKey)
            defaults.removeObject(forKey: scheduledEndKey)
            defaults.removeObject(forKey: scheduledSummaryKey)
        }
        let scheduler = notificationScheduler
        generation += 1
        let mine = generation
        Task {
            // The paywall's trial timeline promises "we'll remind you before
            // your trial ends". This is the moment that promise is made good:
            // the user has just started a trial, so asking now is expected.
            // Once they've answered, this no longer prompts.
            guard await scheduler.ensureAuthorized(), mine == generation else { return }
            await scheduler.scheduleTrialEndingReminder(
                endsAt: newEnd,
                summary: summary,
                now: now
            )
            guard mine == generation else { return }
            defaults.set(newEnd.timeIntervalSince1970, forKey: scheduledEndKey)
            defaults.set(summary ?? "", forKey: scheduledSummaryKey)
        }
    }

    /// Re-run `sync` for the trial already on record, after the recap's
    /// numbers change or permission may have been granted.
    static func resync(now: Date = .now) {
        guard let endsAt else { return }
        sync(isTrialing: true, endsAt: endsAt, now: now)
    }

    /// Drops tracked state and the pending reminder: the trial converted, was
    /// cancelled, or the entitlement is gone.
    static func clear() {
        guard defaults.double(forKey: endsAtKey) > 0 else { return }
        defaults.removeObject(forKey: endsAtKey)
        defaults.removeObject(forKey: recapDismissedForKey)
        defaults.removeObject(forKey: scheduledEndKey)
        defaults.removeObject(forKey: scheduledSummaryKey)
        generation += 1
        notificationScheduler.cancelTrialEndingReminder()
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
