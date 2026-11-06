import Foundation
import SwiftData
import Testing
@testable import Sober

/// Repro for the 2026-11-06 state machine audit. Each test states the behaviour
/// the app promises, so a failure is evidence the invalid state is reachable.
/// `control` must pass: it shows the harness itself is sound.
@Suite("State machine audit repro", .serialized)
@MainActor
struct StateMachineAuditRepro {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
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

    // MARK: - Undo reads past a later slip or reset

    @Test func s1_slipWithALaterSlipIsNotUndoable() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(1), context: context)
        SlipRecorder.record(on: today, context: context)

        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(1), context: context) == false)
        SlipRecorder.undo(on: DateHelpers.daysAgo(1), context: context)
        #expect(sobriety.currentDayCount() == 1)
    }

    @Test func s2_undoDoesNotRunThroughAnOlderSlipEnteredLater() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(50), context: context)
        SlipRecorder.undo(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() <= 50)
    }

    @Test func s3_deliberateResetCannotBeUndoneThroughAnEarlierSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(1), context: context)
        sobriety.reset()
        garden.resetForNewJourney()
        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(1), context: context) == false)
    }

    // MARK: - Undo does not restore everything the slip changed

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
        SlipRecorder.undo(on: today, context: context)
        SlipRecorder.undo(on: DateHelpers.daysAgo(1), context: context)
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
        SlipRecorder.record(on: today, context: context)
        let after = GardenService.stage(forDays: garden.treeDays(streakDays: sobriety.currentDayCount()))
        #expect(after <= before)
    }

    @Test func g5_undoKeepsAGoalSetAfterTheSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        let goal = DateHelpers.startOfDay(Date.now.addingTimeInterval(30 * 86_400))
        sobriety.setGoal(goal)
        SlipRecorder.undo(on: today, context: context)
        #expect(sobriety.activeJourney()?.goalDate == goal)
    }

    // MARK: - Journey history

    @Test func j1_olderSlipStopsTheRunItFallsIn() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(50), context: context)
        #expect(sobriety.longestStreakDays() == 51)
    }

    @Test func j2_slipAfterASameDayResetScoresTheRunAfterTheReset() {
        sobriety.startJourney(at: DateHelpers.daysAgo(99))
        sobriety.reset()
        garden.resetForNewJourney()
        let outcome = SlipRecorder.record(on: today, context: context)
        #expect(outcome.previousStreakDays == 1)
        #expect(outcome.carryoverDays == 0)
    }

    @Test func j3_movingTheStartLaterRemovesTheDaysItNoLongerCovers() {
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        checkIns.fillJourney(start: DateHelpers.daysAgo(100), through: DateHelpers.daysAgo(1))
        sobriety.updateStartDate(DateHelpers.daysAgo(5))
        checkIns.fillJourney(start: DateHelpers.daysAgo(5), through: DateHelpers.daysAgo(1))
        #expect(checkIns.lifetimeSoberDayCount() == 5)
    }

    @Test func j4_movingTheStartEarlierCannotCrossALoggedSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        sobriety.updateStartDate(DateHelpers.daysAgo(30))
        #expect(sobriety.currentDayCount() <= 10)
    }

    @Test func c1_aCheckInCannotOverwriteALoggedSlip() {
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: today, context: context)
        checkIns.checkIn()
        #expect(checkIns.loggedSlip())
    }

    // MARK: - Trial reminder

    @Test func t1_reminderIsScheduledOncePermissionArrivesLater() async throws {
        let scheduler = FakeTrialScheduler()
        let previous = TrialLifecycle.notificationScheduler
        TrialLifecycle.notificationScheduler = scheduler
        defer {
            TrialLifecycle.clear()
            TrialLifecycle.notificationScheduler = previous
        }
        TrialLifecycle.clear()
        let end = Date.now.addingTimeInterval(7 * 86_400)

        scheduler.authorized = false
        TrialLifecycle.sync(isTrialing: true, endsAt: end)
        try await Task.sleep(for: .milliseconds(200))
        #expect(scheduler.scheduled == 0)

        scheduler.authorized = true
        TrialLifecycle.sync(isTrialing: true, endsAt: end)
        try await Task.sleep(for: .milliseconds(200))
        #expect(scheduler.scheduled == 1)
    }
}

@MainActor
private final class FakeTrialScheduler: TrialNotificationScheduling {
    var authorized = false
    var scheduled = 0

    func ensureAuthorized() async -> Bool { authorized }
    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async { scheduled += 1 }
    func cancelTrialEndingReminder() {}
}
