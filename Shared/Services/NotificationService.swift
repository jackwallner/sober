import Foundation
import UserNotifications

enum NotificationService {
    static let dailyReminderID = "sober.daily-reminder"
    /// userInfo marker so the app can route a reminder tap straight to Home.
    static let deepLinkKey = "deepLink"
    static let deepLinkCheckIn = "checkIn"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int, committed: Bool = true, streakDays: Int = 0) async {
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
}
