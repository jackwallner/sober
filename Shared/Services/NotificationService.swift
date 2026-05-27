import Foundation
import UserNotifications

enum NotificationService {
    static let dailyReminderID = "sober.daily-reminder"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int, committed: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        await cancelDailyReminder()

        // Both variants stay supportive — even the "committed" copy avoids
        // guilt language. People early in recovery delete apps that scold.
        let content = UNMutableNotificationContent()
        content.title = committed ? "Showing up today" : "Daily check-in"
        content.body = committed
            ? "Log today and water your garden — you've got this."
            : "If today's a sober one, log it and water your garden."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelDailyReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyReminderID]
        )
    }
}
