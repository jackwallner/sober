import Foundation
import UserNotifications

enum NotificationService {
    static let dailyReminderID = "sober.daily-reminder"
    /// One-shot "you're about to hit a milestone" nudge, fired the evening before.
    static let milestoneEveID = "sober.milestone-eve"
    /// Rolling "we haven't seen you" nudge. Rescheduled on every open, so it
    /// only ever fires for someone who actually stopped coming back.
    static let lapseNudgeID = "sober.lapse-nudge"
    /// Fires before a Bloom+ free trial converts, so nobody is surprised by a charge.
    static let trialEndingID = "sober.trial-ending"

    /// userInfo marker so the app can route a reminder tap straight to Home.
    static let deepLinkKey = "deepLink"
    static let deepLinkCheckIn = "checkIn"
    static let deepLinkBloomPlus = "bloomPlus"

    /// How many days ahead of a trial's conversion the reminder fires.
    static let trialReminderLeadDays = 2
    /// Days of silence before the return nudge fires.
    static let lapseNudgeDays = 3

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Authorization state, without prompting.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isDenied() async -> Bool {
        await authorizationStatus() == .denied
    }

    /// True when a notification we schedule will actually be delivered.
    ///
    /// `UNUserNotificationCenter.add` succeeds whether or not the app has
    /// permission — it just never displays — so for a long time every reminder
    /// in this app was scheduled and silently dropped: nothing ever called
    /// `requestAuthorization`, which is the only thing that raises the system
    /// prompt. The daily reminder, the milestone nudge, the lapse nudge and the
    /// trial-ending warning were all affected.
    ///
    /// This deliberately does NOT prompt. Scheduling happens on app open and on
    /// every check-in, and a permission sheet thrown at someone who just opened
    /// the app is the reliable way to get it declined forever.
    static func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Ask for permission, at a moment the user has just asked for something
    /// that needs it: turning reminders on, or starting a trial they'll want
    /// warning about. Returns false if they decline or already declined.
    @discardableResult
    static func ensureAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        default:
            return true
        }
    }

    static func scheduleDailyReminder(hour: Int, committed: Bool = true, streakDays: Int = 0) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        await cancelDailyReminder()

        // Copy stays supportive — even the "committed" variants avoid guilt
        // language. People early in recovery delete apps that scold. When we
        // know the streak, lead with it so the reminder feels personal; the
        // schedule is refreshed on every check-in/app-open so it stays current.
        let content = UNMutableNotificationContent()
        if streakDays > 1 {
            content.title = "Day \(streakDays + 1) is waiting"
            content.body = committed
                ? "You're \(streakDays) days in. Log today and water your bonsai."
                : "\(streakDays) days and growing. If today's a sober one, log it."
        } else {
            content.title = committed ? "Showing up today" : "Daily check-in"
            content.body = committed
                ? "Log today and water your garden. You've got this."
                : "If today's a sober one, log it and water your garden."
        }
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkCheckIn]

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Re-schedule the daily reminder with fresh streak copy, but only if one
    /// is already pending — never resurrects a reminder the user turned off.
    static func refreshDailyReminder(hour: Int, committed: Bool, streakDays: Int) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard pending.contains(where: { $0.identifier == dailyReminderID }) else { return }
        await scheduleDailyReminder(hour: hour, committed: committed, streakDays: streakDays)
    }

    static func cancelDailyReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyReminderID]
        )
    }

    // MARK: - Retention nudges

    /// Anticipation beats reminding: the night before a milestone lands is the
    /// moment someone decides tomorrow counts. One-shot, rescheduled whenever
    /// the day count moves.
    static func scheduleMilestoneEve(
        currentDays: Int,
        milestoneDays: Int,
        milestoneTitle: String,
        hour: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        cancelMilestoneEve()

        guard let fireDate = milestoneEveFireDate(
            currentDays: currentDays,
            milestoneDays: milestoneDays,
            hour: hour,
            now: now,
            calendar: calendar
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tomorrow is day \(milestoneDays)"
        content.body = "One more sober day and \(milestoneTitle) is yours. Your bonsai is ready for it."
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkCheckIn]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: milestoneEveID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// When the milestone-eve nudge should fire, or nil when there's nothing to
    /// anticipate (milestone already passed, or the slot is in the past today).
    /// Separated out so the date math is testable without the notification center.
    static func milestoneEveFireDate(
        currentDays: Int,
        milestoneDays: Int,
        hour: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        let daysUntil = milestoneDays - currentDays
        guard daysUntil >= 1 else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .day, value: daysUntil - 1, to: startOfToday),
              let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        else { return nil }
        return fireDate > now ? fireDate : nil
    }

    static func cancelMilestoneEve() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [milestoneEveID]
        )
    }

    /// Rolling return nudge. Every app open pushes it back, so it only reaches
    /// people who have actually drifted. Framed as a door left open, never as a
    /// scolding. Someone who slipped is exactly who we don't want to shame.
    static func scheduleLapseNudge(streakDays: Int, now: Date = .now) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        cancelLapseNudge()

        let content = UNMutableNotificationContent()
        if streakDays > 0 {
            content.title = "Your garden is still here"
            content.body = "\(streakDays) days is still \(streakDays) days. Pick up wherever you are, no catching up required."
        } else {
            content.title = "Your garden is still here"
            content.body = "Whenever you're ready, day one is waiting. No streak to rebuild first."
        }
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkCheckIn]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(lapseNudgeDays) * 86_400,
            repeats: false
        )
        let request = UNNotificationRequest(identifier: lapseNudgeID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelLapseNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [lapseNudgeID]
        )
    }

    /// Cancels every nudge that rides on the daily-reminder opt-in. Called when
    /// the user turns reminders off so nothing keeps arriving behind their back.
    static func cancelRetentionNudges() {
        cancelMilestoneEve()
        cancelLapseNudge()
    }

    // MARK: - Trial

    /// Heads-up before a free trial converts. Leads with what they've grown, not
    /// with the charge, but states the date plainly, because a surprise bill is
    /// how you earn a one-star review.
    static func scheduleTrialEndingReminder(
        endsAt: Date,
        summary: String?,
        now: Date = .now
    ) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        cancelTrialEndingReminder()

        guard let fireDate = trialReminderFireDate(endsAt: endsAt, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your Bloom+ trial ends soon"
        if let summary, !summary.isEmpty {
            content.body = "\(summary) Keep the full garden, or cancel any time before it renews."
        } else {
            content.body = "Keep your full garden, journal, and savings, or cancel any time before it renews."
        }
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkBloomPlus]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, fireDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: trialEndingID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Two days before conversion, or the midpoint for trials too short for that.
    /// Nil when the trial ends too soon for a reminder to be anything but noise.
    static func trialReminderFireDate(endsAt: Date, now: Date = .now) -> Date? {
        let remaining = endsAt.timeIntervalSince(now)
        guard remaining > 3600 else { return nil }
        let lead = TimeInterval(trialReminderLeadDays) * 86_400
        let fire = remaining > lead
            ? endsAt.addingTimeInterval(-lead)
            : now.addingTimeInterval(remaining / 2)
        return fire > now ? fire : nil
    }

    static func cancelTrialEndingReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [trialEndingID]
        )
    }
}
