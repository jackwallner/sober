import Foundation
import SwiftData
import UserNotifications

@MainActor
protocol ReminderCenter {
    func isAuthorized() async -> Bool
    func add(_ request: UNNotificationRequest)
    func removePending(identifiers: [String])
}

@MainActor
private struct LiveReminderCenter: ReminderCenter {
    func isAuthorized() async -> Bool {
        await NotificationService.isAuthorized()
    }

    func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func removePending(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Keeps the daily reminder, milestone-eve and lapse nudges in step with the
/// store.
///
/// Every reminder's copy is fixed when it is queued, so anything that moves
/// the counter (a slip, an undo, a Reset, a start date edit) or logs today has
/// to requeue them. Only Home's refresh used to, so a slip followed by closing
/// the app left "You're 100 days in" waiting for the next morning. The opt-in
/// is the source of truth: permission granted later in iOS Settings starts the
/// reminders on the next sync, without needing one already pending.
@MainActor
enum ReminderSync {
    static let liveCenter: any ReminderCenter = LiveReminderCenter()
    /// A fake center for one store, so a test's reminders can't be crossed
    /// with another test's running at the same time.
    static var overrides: [ObjectIdentifier: any ReminderCenter] = [:]
    private static var generations: [ObjectIdentifier: Int] = [:]

    struct Plan: Equatable {
        var enabled: Bool
        var hour: Int
        var committed: Bool
        var streakDays: Int
        var checkedInToday: Bool
    }

    static var allIdentifiers: [String] {
        NotificationService.dailyReminderIdentifiers
            + [NotificationService.milestoneEveID, NotificationService.lapseNudgeID]
    }

    static func center(for context: ModelContext) -> any ReminderCenter {
        overrides[ObjectIdentifier(context.container)] ?? liveCenter
    }

    static func plan(context: ModelContext, now: Date = .now) -> Plan {
        // A store opened without the settings model has no opt-in to read.
        let settings = context.holds(UserSettings.self)
            ? (try? context.fetch(FetchDescriptor<UserSettings>()).first)
            : nil
        return Plan(
            enabled: settings?.dailyReminderEnabled ?? false,
            hour: settings?.dailyReminderHour ?? 9,
            committed: settings?.madeCommitment ?? true,
            streakDays: SobrietyService(context: context).currentDayCount(asOf: now),
            checkedInToday: CheckInService(context: context).hasCheckedIn(on: now)
        )
    }

    /// Requeue everything from the store's current state. Does nothing
    /// without permission, so it never prompts and never cancels.
    @discardableResult
    static func sync(context: ModelContext, now: Date = .now) -> Task<Void, Never> {
        // The context doesn't keep its container alive, and reading a context
        // whose container is gone traps, so the task holds the container.
        let container = context.container
        let center = center(for: context)
        return Task {
            if await center.isAuthorized() {
                await apply(plan(context: context, now: now), context: context, now: now)
            }
            withExtendedLifetime(container) {}
        }
    }

    /// A later call supersedes an earlier one still waiting on permission, so
    /// two quick syncs can't land old copy over new. Off cancels the
    /// milestone and lapse nudges too: they ride on the same opt-in.
    static func apply(_ plan: Plan, context: ModelContext, now: Date = .now) async {
        let center = center(for: context)
        let key = ObjectIdentifier(context.container)
        let mine = (generations[key] ?? 0) + 1
        generations[key] = mine
        guard plan.enabled else {
            center.removePending(identifiers: allIdentifiers)
            return
        }
        guard await center.isAuthorized(), generations[key] == mine else { return }
        center.removePending(identifiers: allIdentifiers)
        for request in requests(for: plan, now: now) {
            center.add(request)
        }
    }

    static func requests(for plan: Plan, now: Date = .now) -> [UNNotificationRequest] {
        var requests = NotificationService.dailyReminderRequests(
            hour: plan.hour,
            committed: plan.committed,
            streakDays: plan.streakDays,
            checkedInToday: plan.checkedInToday,
            now: now
        )
        if let next = AchievementCatalog.nextTimeMilestone(after: plan.streakDays),
           let eve = NotificationService.milestoneEveRequest(
               currentDays: plan.streakDays,
               milestoneDays: next.dayThreshold,
               milestoneTitle: next.title,
               hour: plan.hour,
               now: now
           ) {
            requests.append(eve)
        }
        requests.append(NotificationService.lapseNudgeRequest(streakDays: plan.streakDays))
        return requests
    }
}
