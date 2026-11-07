import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Sober

#if canImport(RevenueCat)
import RevenueCat
#endif

// Regression tests for the bugs the 2026-11-06 state machine review confirmed
// (project-docs/audits/state-machines-2026-11-06-review.md). Each name carries
// the claim id. Where the audit's repro test was sound it is kept as written.

@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
        for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UserSettings.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

// MARK: - Reminders (N1, N2, N3, and the check-in reminder the audit missed)

@MainActor
private final class FakeReminderCenter: ReminderCenter {
    var authorized = true
    var pending: [UNNotificationRequest] = []
    var removals = 0

    func isAuthorized() async -> Bool { authorized }
    func add(_ request: UNNotificationRequest) {
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }
    func removePending(identifiers: [String]) {
        removals += 1
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func request(_ id: String) -> UNNotificationRequest? {
        pending.first { $0.identifier == id }
    }

    var dailyRequests: [UNNotificationRequest] {
        pending.filter { $0.identifier.hasPrefix("\(NotificationService.dailyReminderID).") }
    }
}

@Suite("Reminders follow the store", .serialized)
@MainActor
struct ReminderSyncRegressionTests {
    private let container: ModelContainer
    private let center = FakeReminderCenter()

    init() throws {
        container = try makeContainer()
        ReminderSync.overrides[ObjectIdentifier(container)] = center
        let settings = SettingsService(context: container.mainContext).current()
        settings.dailyReminderEnabled = true
        settings.dailyReminderHour = 9
        settings.hasCompletedOnboarding = true
        try container.mainContext.save()
    }

    private var context: ModelContext { container.mainContext }
    private var tomorrowID: String { "\(NotificationService.dailyReminderID).1" }

    private func settle(until done: () -> Bool) async throws {
        for _ in 0..<80 where !done() {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    /// N1: a slip used to leave every queued reminder on the old streak.
    @Test func n1_aSlipRequeuesTheRemindersAtTheNewStreak() async throws {
        defer { ReminderSync.overrides[ObjectIdentifier(container)] = nil }
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(27))
        await ReminderSync.sync(context: context).value
        // Control: before the slip, tomorrow is day 29 and day 30's eve is queued.
        #expect(center.request(tomorrowID)?.content.title.contains("29") == true)
        #expect(center.request(NotificationService.milestoneEveID)?.content.title.contains("30") == true)
        let removalsBefore = center.removals

        SlipRecorder.record(on: .now, context: context)
        try await settle { center.removals > removalsBefore && center.request(tomorrowID) != nil }

        #expect(center.request(tomorrowID)?.content.title.contains("Day 2 ") == true)
        // The next milestone after day 1 is day 7.
        #expect(center.request(NotificationService.milestoneEveID)?.content.title.contains("7") == true)
        #expect(center.request(NotificationService.lapseNudgeID)?.content.body.contains("28") == false)
        // A slip logged today is today's entry, so today's reminder is gone.
        #expect(center.request("\(NotificationService.dailyReminderID).0") == nil)
    }

    @Test func n1_undoingASlipRequeuesTheRestoredStreak() async throws {
        defer { ReminderSync.overrides[ObjectIdentifier(container)] = nil }
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: .now, context: context)
        try await settle { center.request(tomorrowID)?.content.title.contains("Day 2") == true }
        #expect(center.request(tomorrowID)?.content.title.contains("Day 2") == true)

        #expect(SlipRecorder.undo(on: .now, context: context))
        try await settle { center.request(tomorrowID)?.content.title.contains("42") == true }
        #expect(center.request(tomorrowID)?.content.title.contains("42") == true)
    }

    /// N2: permission granted in iOS Settings after the toggle was turned on.
    /// The old refresh only re-copied a reminder already pending, and there
    /// never was one.
    @Test func n2_permissionGrantedLaterStartsTheDailyReminder() async throws {
        defer { ReminderSync.overrides[ObjectIdentifier(container)] = nil }
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(10))
        center.authorized = false
        await ReminderSync.sync(context: context).value
        #expect(center.pending.isEmpty)

        center.authorized = true
        await ReminderSync.sync(context: context).value
        #expect(center.dailyRequests.count >= NotificationService.dailyReminderWindowDays - 1)
    }

    @Test func turningRemindersOffCancelsEverything() async throws {
        defer { ReminderSync.overrides[ObjectIdentifier(container)] = nil }
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(10))
        await ReminderSync.sync(context: context).value
        #expect(!center.pending.isEmpty)
        SettingsService(context: context).current().dailyReminderEnabled = false
        await ReminderSync.apply(ReminderSync.plan(context: context), context: context)
        #expect(center.pending.isEmpty)
    }
}

@Suite("Daily reminder copy")
struct DailyReminderCopyTests {
    private let calendar = Calendar.current
    private var morning: Date {
        calendar.date(bySettingHour: 7, minute: 0, second: 0, of: DateHelpers.startOfDay())!
    }

    /// N3: one repeating request repeated the copy from the last app open.
    @Test func n3_eachQueuedDayCarriesItsOwnCount() {
        let requests = NotificationService.dailyReminderRequests(
            hour: 9, committed: true, streakDays: 30, checkedInToday: false, now: morning
        )
        #expect(requests.count == NotificationService.dailyReminderWindowDays)
        #expect(requests.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == false })
        #expect(requests[0].content.title.contains("30"))
        #expect(requests[1].content.title.contains("31"))
        #expect(requests[6].content.title.contains("36"))
        #expect(Set(requests.map(\.content.title)).count == requests.count)
    }

    /// Missed by the audit: the reminder still fired after today's check-in.
    @Test func checkedInTodayDropsTodaysReminder() {
        let requests = NotificationService.dailyReminderRequests(
            hour: 9, committed: true, streakDays: 30, checkedInToday: true, now: morning
        )
        #expect(!requests.contains { $0.identifier.hasSuffix(".0") })
        #expect(requests.first?.content.title.contains("31") == true)
    }

    /// Missed by the audit: the title ran one day ahead of its own body.
    @Test func titleAndBodyNameTheSameDay() {
        let content = NotificationService.dailyReminderContent(dayCount: 30, committed: true)
        #expect(content.title.contains("30"))
        #expect(!content.title.contains("31"))
        #expect(content.body.contains("30"))
    }

    @Test func aPassedHourLeavesTodayOut() {
        let evening = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: DateHelpers.startOfDay())!
        let requests = NotificationService.dailyReminderRequests(
            hour: 9, committed: true, streakDays: 5, checkedInToday: false, now: evening
        )
        #expect(requests.first?.identifier.hasSuffix(".1") == true)
    }
}

// MARK: - Slips, undo and history (S1, J1, C1, J3, J4, G1 to G5, Z1)

@Suite("Slip history regressions", .serialized)
@MainActor
struct SlipHistoryRegressionTests {
    private let container: ModelContainer

    init() throws {
        container = try makeContainer()
    }

    private var context: ModelContext { container.mainContext }
    private var sobriety: SobrietyService { SobrietyService(context: context) }
    private var garden: GardenService { GardenService(context: context) }
    private var checkIns: CheckInService { CheckInService(context: context) }
    private var today: Date { DateHelpers.startOfDay() }

    @Test func control_undoOfALoneSlipRestoresTheRun() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        #expect(sobriety.currentDayCount() == 1)
        #expect(SlipRecorder.undo(on: today, context: context))
        #expect(sobriety.currentDayCount() == 41)
    }

    // S1

    @Test func s1_slipWithALaterSlipIsNotUndoable() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(1), context: context)
        SlipRecorder.record(on: today, context: context)

        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(1), context: context) == false)
        SlipRecorder.undo(on: DateHelpers.daysAgo(1), context: context)
        #expect(sobriety.currentDayCount() == 1)
        // Today's slip, the latest, still can be.
        #expect(SlipRecorder.canUndo(on: today, context: context))
    }

    @Test func s1_undoDoesNotRunThroughAnOlderSlipEnteredLater() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(50), context: context)
        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(10), context: context))
        SlipRecorder.undo(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() <= 50)
    }

    @Test func s1_aResetAfterASlipCannotBeUndoneThroughIt() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(1), context: context)
        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(1), context: context))
        sobriety.reset()
        garden.resetForNewJourney()
        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(1), context: context) == false)
    }

    @Test func s1_aResetOnTheSlipDayCannotBeUndoneThroughIt() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        sobriety.reset()
        #expect(SlipRecorder.canUndo(on: today, context: context) == false)
    }

    // J1

    @Test func j1_olderSlipStopsTheRunItFallsIn() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(50), context: context)
        #expect(sobriety.longestStreakDays() == 51)
        #expect(sobriety.currentDayCount() == 10)
    }

    @Test func j1_bothSlipsUndoNewestFirst() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        let carryover = garden.current().carryoverDays
        SlipRecorder.record(on: DateHelpers.daysAgo(50), context: context)
        // An older slip leaves the live tree alone.
        #expect(garden.current().carryoverDays == carryover)

        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(50), context: context) == false)
        #expect(SlipRecorder.undo(on: DateHelpers.daysAgo(10), context: context))
        #expect(sobriety.currentDayCount() == 50)
        #expect(garden.current().carryoverDays == 0)
        #expect(SlipRecorder.undo(on: DateHelpers.daysAgo(50), context: context))
        #expect(sobriety.currentDayCount() == 101)
        #expect(garden.current().carryoverDays == 0)
    }

    // C1

    @Test func c1_aCheckInCannotOverwriteALoggedSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        checkIns.checkIn()
        #expect(checkIns.loggedSlip())
        // The slip's own undo still goes through.
        #expect(SlipRecorder.undo(on: today, context: context))
        #expect(!checkIns.loggedSlip())
    }

    // J3

    @Test func j3_movingTheStartLaterRemovesTheDaysItNoLongerCovers() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        checkIns.fillJourney(start: DateHelpers.daysAgo(100), through: DateHelpers.daysAgo(1))
        sobriety.updateStartDate(DateHelpers.daysAgo(5))
        checkIns.fillJourney(start: DateHelpers.daysAgo(5), through: DateHelpers.daysAgo(1))
        #expect(checkIns.lifetimeSoberDayCount() == 5)
    }

    @Test func j3_daysTheUserTendedSurviveTheMove() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        checkIns.fillJourney(start: DateHelpers.daysAgo(100), through: DateHelpers.daysAgo(1))
        checkIns.checkIn(for: DateHelpers.daysAgo(60))
        checkIns.saveDetail(on: DateHelpers.daysAgo(70), mood: 3, note: "kept")
        sobriety.updateStartDate(DateHelpers.daysAgo(5))
        #expect(checkIns.lifetimeSoberDayCount() == 5 + 2)
        #expect(checkIns.detail(on: DateHelpers.daysAgo(70)).note == "kept")
    }

    @Test func j3_aMisTapEarlierThenTheRightDateLeavesNoExtraDays() {
        sobriety.startJourney(at: DateHelpers.daysAgo(20))
        checkIns.fillJourney(start: DateHelpers.daysAgo(20), through: DateHelpers.daysAgo(1))
        sobriety.updateStartDate(DateHelpers.daysAgo(90))
        checkIns.fillJourney(start: DateHelpers.daysAgo(90), through: DateHelpers.daysAgo(1))
        sobriety.updateStartDate(DateHelpers.daysAgo(20))
        #expect(checkIns.lifetimeSoberDayCount() == 20)
    }

    // J4

    @Test func j4_movingTheStartEarlierCannotCrossALoggedSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        sobriety.updateStartDate(DateHelpers.daysAgo(30))
        #expect(sobriety.currentDayCount() <= 10)
        #expect(sobriety.earliestStartDate() == DateHelpers.daysAgo(9))
    }

    @Test func j4_aFirstRunHasNoLowerBound() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        #expect(sobriety.earliestStartDate() == nil)
        sobriety.updateStartDate(DateHelpers.daysAgo(400))
        #expect(sobriety.currentDayCount() == 401)
    }

    // G1 to G5

    @Test func g1_undoPastAYearDoesNotAddATree() {
        sobriety.startJourney(at: DateHelpers.daysAgo(399))
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.count == 1)

        SlipRecorder.record(on: today, context: context)
        SlipRecorder.undo(on: today, context: context)
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.count == 1)
    }

    @Test func g2_undoingTwoSlipsRestoresTheOriginalCarryover() {
        sobriety.startJourney(at: DateHelpers.daysAgo(60))
        SlipRecorder.record(on: DateHelpers.daysAgo(30), context: context)
        let original = garden.current().carryoverDays
        #expect(original > 0)

        SlipRecorder.record(on: DateHelpers.daysAgo(1), context: context)
        SlipRecorder.record(on: today, context: context)
        #expect(SlipRecorder.undo(on: today, context: context))
        #expect(SlipRecorder.undo(on: DateHelpers.daysAgo(1), context: context))
        #expect(garden.current().carryoverDays == original)
    }

    @Test func g3_undoRestoresVitalityAndWatering() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        garden.water()
        let state = garden.current()
        state.vitality = 0.4
        SlipRecorder.record(on: today, context: context)
        SlipRecorder.undo(on: today, context: context)
        #expect(abs(garden.current().vitality - 0.4) < 0.001)
        #expect(garden.current().lastWateredAt != nil)
    }

    @Test func g4_aSlipDoesNotGrowTheTree() {
        sobriety.startJourney(at: DateHelpers.daysAgo(399))
        let before = GardenService.stage(forDays: garden.treeDays(streakDays: sobriety.currentDayCount()))
        let outcome = SlipRecorder.record(on: today, context: context)
        let after = GardenService.stage(forDays: garden.treeDays(streakDays: sobriety.currentDayCount()))
        #expect(after <= before)
        // Half of the 35-day tree on screen, not of the 400-day streak.
        #expect(outcome.carryoverDays == 17)
    }

    @Test func g4_underAYearStillBanksHalf() {
        sobriety.startJourney(at: DateHelpers.daysAgo(39))
        #expect(SlipRecorder.record(on: today, context: context).carryoverDays == 20)
    }

    @Test func g5_undoKeepsAGoalSetAfterTheSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        let goal = DateHelpers.startOfDay(Date.now.addingTimeInterval(30 * 86_400))
        sobriety.setGoal(goal)
        SlipRecorder.undo(on: today, context: context)
        #expect(sobriety.activeJourney()?.goalDate == goal)
    }

    @Test func g5_undoKeepsTheGoalTheSlipCarried() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        let goal = DateHelpers.startOfDay(Date.now.addingTimeInterval(20 * 86_400))
        sobriety.setGoal(goal)
        SlipRecorder.record(on: today, context: context)
        SlipRecorder.undo(on: today, context: context)
        #expect(sobriety.activeJourney()?.goalDate == goal)
    }

    /// Upgrade: a slip logged by a build before per-run snapshots has none on
    /// its run. Its undo still restores the one-slot carryover and adds no tree.
    @Test func upgrade_undoOfASlipFromBeforeSnapshots() {
        sobriety.startJourney(at: DateHelpers.daysAgo(399))
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        let state = garden.current()
        state.carryoverDays = 12
        SlipRecorder.record(on: today, context: context)
        // What the older build left: no snapshot on the run.
        sobriety.activeJourney()?.gardenBeforeSlip = nil
        #expect(garden.current().carryoverBeforeSlip == 12)

        #expect(SlipRecorder.undo(on: today, context: context))
        #expect(garden.current().carryoverDays == 12)
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.count == 1)
    }

    @Test func gardenSlipRecordRoundTrips() {
        let snapshot = GardenSlipSnapshot(
            carryoverDays: 3, groveCountAtJourneyStart: 1, vitality: 0.5,
            lastWateredAt: Date(timeIntervalSince1970: 1_000), vitalityDecayDays: 2
        )
        #expect(GardenSlipRecord(stored: GardenSlipRecord.snapshot(snapshot).stored) == .snapshot(snapshot))
        #expect(GardenSlipRecord(stored: GardenSlipRecord.untouched.stored) == .untouched)
        #expect(GardenSlipRecord(stored: nil) == .legacy)
    }

    // Z1

    @Test func z1_runDaysMoveWithTheRowsOnAZoneChange() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let defaults = try #require(UserDefaults(suiteName: "z1-\(UUID().uuidString)"))
        defaults.set(newYork.identifier, forKey: AppGroup.checkInDayKeyZoneKey)
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = newYork
        var la = Calendar(identifier: .gregorian)
        la.timeZone = losAngeles

        let slipDay = ny.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let restart = ny.date(from: DateComponents(year: 2026, month: 3, day: 11))!
        let instant = ny.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15, minute: 20))!
        let closed = SobrietyJourney(startDate: instant, endDate: slipDay, resetReason: "slip")
        let active = SobrietyJourney(startDate: restart, goalDate: restart)
        context.insert(closed)
        context.insert(active)
        try context.save()

        CheckInService.normalizeDayKeys(context: context, zone: losAngeles, defaults: defaults)

        #expect(active.startDate == la.date(from: DateComponents(year: 2026, month: 3, day: 11)))
        #expect(active.goalDate == la.date(from: DateComponents(year: 2026, month: 3, day: 11)))
        #expect(closed.endDate == la.date(from: DateComponents(year: 2026, month: 3, day: 10)))
        // A run started at a moment, not a midnight, keeps that moment.
        #expect(closed.startDate == instant)
        #expect(defaults.string(forKey: AppGroup.checkInDayKeyZoneKey) == losAngeles.identifier)
    }
}

// MARK: - Trial reminder (T1, T2, T3)

@MainActor
private final class FakeTrialScheduler: TrialNotificationScheduling {
    var authorized = true
    var scheduled: [String?] = []
    var cancelled = 0
    var prompts = 0

    func ensureAuthorized() async -> Bool {
        prompts += 1
        return authorized
    }
    func isAuthorized() async -> Bool { authorized }
    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async {
        scheduled.append(summary)
    }
    func cancelTrialEndingReminder() { cancelled += 1 }
}

@Suite("Trial reminder regressions", .serialized)
@MainActor
struct TrialReminderRegressionTests {
    private func withScheduler(_ body: (FakeTrialScheduler) async throws -> Void) async rethrows {
        let scheduler = FakeTrialScheduler()
        let previous = TrialLifecycle.notificationScheduler
        let previousSummary = TrialLifecycle.recapSummary
        TrialLifecycle.clear()
        TrialLifecycle.notificationScheduler = scheduler
        defer {
            TrialLifecycle.clear()
            TrialLifecycle.notificationScheduler = previous
            TrialLifecycle.recapSummary = previousSummary
        }
        try await body(scheduler)
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func t1_reminderIsScheduledOncePermissionArrivesLater() async throws {
        try await withScheduler { scheduler in
            let end = Date.now.addingTimeInterval(7 * 86_400)
            scheduler.authorized = false
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            #expect(scheduler.scheduled.isEmpty)

            scheduler.authorized = true
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            #expect(scheduler.scheduled.count == 1)

            // And only once.
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            #expect(scheduler.scheduled.count == 1)
            // Only the first sight of the trial may raise the system prompt.
            #expect(scheduler.prompts == 1)
        }
    }

    @Test func t2_aCancelledTrialDropsItsRenewalReminder() async throws {
        try await withScheduler { scheduler in
            let end = Date.now.addingTimeInterval(7 * 86_400)
            TrialLifecycle.sync(isTrialing: true, endsAt: end, willRenew: true)
            try await settle()
            #expect(scheduler.scheduled.count == 1)

            TrialLifecycle.sync(isTrialing: true, endsAt: end, willRenew: false)
            #expect(scheduler.cancelled == 1)
            #expect(TrialLifecycle.endsAt == nil)
        }
    }

    @Test func t3_theReminderPicksUpNewRecapNumbers() async throws {
        try await withScheduler { scheduler in
            let end = Date.now.addingTimeInterval(7 * 86_400)
            TrialLifecycle.recapSummary = "12 sober days so far."
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            #expect(scheduler.scheduled.last == "12 sober days so far.")

            TrialLifecycle.recapSummary = "17 sober days so far."
            TrialLifecycle.resync()
            try await settle()
            #expect(scheduler.scheduled.last == "17 sober days so far.")
            #expect(scheduler.scheduled.count == 2)
        }
    }

    /// Upgrade: a trial the old build tracked has an end date and no record of
    /// what it scheduled. It is rescheduled once, then left alone.
    @Test func upgrade_aTrialTrackedByTheOldBuildIsRescheduledOnce() async throws {
        try await withScheduler { scheduler in
            let end = Date.now.addingTimeInterval(7 * 86_400)
            AppGroup.defaults.set(end.timeIntervalSince1970, forKey: "trialLifecycle.endsAt")
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            TrialLifecycle.sync(isTrialing: true, endsAt: end)
            try await settle()
            #expect(scheduler.scheduled.count == 1)
        }
    }

    #if canImport(RevenueCat)
    @Test func t2_aCancelledTrialFromRevenueCatIsNotReminded() async throws {
        try await withScheduler { scheduler in
            let service = SubscriptionService()
            let now = Date.now
            let end = now.addingTimeInterval(7 * 86_400)
            service.processPurchaseResult(
                customerInfo: Self.trial(willRenew: true, expires: end, now: now),
                userCancelled: false,
                now: now
            )
            try await settle()
            #expect(scheduler.scheduled.count == 1)

            let later = now.addingTimeInterval(60)
            service.processPurchaseResult(
                customerInfo: Self.trial(willRenew: false, expires: end, now: later),
                userCancelled: false,
                now: later
            )
            #expect(scheduler.cancelled >= 1)
            #expect(TrialLifecycle.endsAt == nil)
        }
    }

    private static func trial(willRenew: Bool, expires: Date, now: Date) -> CustomerInfo {
        let entitlement = EntitlementInfo(
            identifier: SubscriptionService.proEntitlement,
            isActive: true,
            willRenew: willRenew,
            periodType: .trial,
            latestPurchaseDate: now,
            originalPurchaseDate: now,
            expirationDate: expires,
            store: .appStore,
            productIdentifier: "com.jackwallner.sober.pro.yearly",
            isSandbox: true,
            ownershipType: .purchased
        )
        return CustomerInfo(
            entitlements: EntitlementInfos(entitlements: [SubscriptionService.proEntitlement: entitlement]),
            requestDate: now,
            firstSeen: now,
            originalAppUserId: "state-machine-t2"
        )
    }
    #endif
}
