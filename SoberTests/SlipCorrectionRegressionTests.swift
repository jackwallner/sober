import Testing
import Foundation
import SwiftData
@testable import Sober

/// The build 83 to 88 audit (`reg94.md`). Three of its findings share a root:
/// the slip path was written forwards only, so anything that had to reason
/// *backwards* from a slip — what the run before it was worth, how to take one
/// back, what the tree should look like on another device — read the wrong
/// numbers. These pin the repaired behaviour.

@Suite("A slip splits history without overlapping it")
@MainActor
struct SlipJourneyBoundaryTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func journeys() -> [SobrietyJourney] {
        let descriptor = FetchDescriptor<SobrietyJourney>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The regression: the run a back-dated slip ended was closed at `.now`,
    /// so it covered the same dates as the run that replaced it.
    @Test func theClosedRunStopsOnTheSlipDayNotToday() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(26))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)

        let all = journeys()
        #expect(all.count == 2)
        #expect(DateHelpers.startOfDay(all[0].endDate ?? .now) == DateHelpers.daysAgo(10))
        #expect(DateHelpers.startOfDay(all[1].startDate) == DateHelpers.daysAgo(9))
        // The closed run ends strictly before the fresh one begins.
        #expect((all[0].endDate ?? .now) < all[1].startDate)
    }

    /// The user-visible cost of the overlap: logging a slip from ten days ago
    /// *raised* the best streak, because the old run was measured through it.
    @Test func aBackdatedSlipDoesNotInflateTheLongestStreak() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(26))
        #expect(sobriety.longestStreakDays() == 27)

        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        // The run that was actually interrupted was worth 17 days, and the
        // recovered run is 10 days old. Neither is 27.
        #expect(sobriety.longestStreakDays() == 17)
        #expect(sobriety.currentDayCount() == 10)
    }

    /// Entering an older slip after a newer one must not wind the counter
    /// forward past a slip that has already happened.
    @Test func anOutOfOrderSlipDoesNotRewindTheCounter() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(26))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() == 10)

        SlipRecorder.record(on: DateHelpers.daysAgo(20), context: context)
        #expect(sobriety.currentDayCount() == 10)
    }

    /// Every recorded run still describes a distinct stretch of days.
    @Test func repeatedSlipsLeaveNoOverlap() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(30), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(20), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(5), context: context)

        let all = journeys()
        for (earlier, later) in zip(all, all.dropFirst()) {
            #expect((earlier.endDate ?? .now) < later.startDate)
        }
    }
}

@Suite("A slip can be taken back in full")
@MainActor
struct SlipUndoTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// The regression: Timeline's "Change to sober" flipped the calendar row
    /// and nothing else, so the day went green next to a counter still sitting
    /// at the reset the slip had caused.
    @Test func undoingTodaysSlipRestoresTheCounterAndTheTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(27))
        #expect(sobriety.currentDayCount() == 28)

        SlipRecorder.record(on: .now, context: context)
        #expect(sobriety.currentDayCount() == 1)
        #expect(garden.current().carryoverDays == 14)

        #expect(SlipRecorder.canUndo(on: .now, context: context))
        #expect(SlipRecorder.undo(on: .now, context: context))

        #expect(sobriety.currentDayCount() == 28)
        #expect(sobriety.longestStreakDays() == 28)
        #expect(garden.current().carryoverDays == 0)
        #expect(CheckInService(context: context).loggedSlip(on: .now) == false)
        // The tree is drawn at the full restored run again, not at 1 + 14.
        #expect(garden.treeDays(streakDays: sobriety.currentDayCount()) == 28)
    }

    @Test func undoingABackdatedSlipRestoresTheWholeRun() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(26))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() == 10)

        #expect(SlipRecorder.undo(on: DateHelpers.daysAgo(10), context: context))
        #expect(sobriety.currentDayCount() == 27)
        #expect(sobriety.longestStreakDays() == 27)
    }

    /// A second slip gives the tree back exactly what it had, not an estimate:
    /// halving throws away the odd day, so re-deriving would shrink the tree on
    /// an undo that is supposed to be lossless.
    @Test func theExactPreSlipCarryoverComesBack() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(20), context: context)
        let afterFirst = garden.current().carryoverDays
        #expect(afterFirst > 0)

        SlipRecorder.record(on: .now, context: context)
        #expect(garden.current().carryoverDays != afterFirst)

        #expect(SlipRecorder.undo(on: .now, context: context))
        #expect(garden.current().carryoverDays == afterFirst)
    }

    /// Only the slip the counter is currently sitting on can be reversed.
    /// Reopening an older one would resurrect a run a later slip already
    /// closed, which is a rewrite of the user's history, not an undo.
    @Test func anOlderSlipIsNotOfferedAsReversible() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(20), context: context)
        SlipRecorder.record(on: DateHelpers.daysAgo(5), context: context)

        #expect(SlipRecorder.canUndo(on: DateHelpers.daysAgo(20), context: context) == false)
        #expect(SlipRecorder.undo(on: DateHelpers.daysAgo(20), context: context) == false)
        // Refused means nothing moved, including the calendar row.
        #expect(sobriety.currentDayCount() == 5)
        #expect(CheckInService(context: context).loggedSlip(on: DateHelpers.daysAgo(20)))
    }

    @Test func aSoberDayHasNothingToUndo() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(10))
        CheckInService(context: context).checkIn(for: .now, wasSober: true)
        #expect(SlipRecorder.canUndo(on: .now, context: context) == false)
        #expect(SlipRecorder.undo(on: .now, context: context) == false)
    }
}

@Suite("The widget and the watch draw the tree the app promised")
struct SnapshotCarryoverTests {
    /// The regression: both consumers recompute the day count at render time so
    /// they roll over at midnight on their own, then derived the stage from the
    /// reset streak — drawing bare soil beside a Home screen showing the tree
    /// the slip had just promised was kept.
    @Test func theSnapshotRedoesTheGardensSum() {
        var snap = WidgetSnapshot.empty
        snap.carryoverDays = 14
        #expect(snap.treeDays(streakDays: 1) == 15)
        #expect(snap.treeDays(streakDays: 1) == GardenService.treeDays(streakDays: 1, carryover: 14))
        #expect(GardenService.stage(forDays: snap.treeDays(streakDays: 1)) == .young)
    }

    @Test func noCarryoverLeavesTheStreakAlone() {
        #expect(WidgetSnapshot.empty.treeDays(streakDays: 30) == 30)
    }

    /// The widget reads this store across an app update. A strictly-decoded
    /// snapshot would fail on the key the new build added and fall back to
    /// `.empty`, blanking the widget to 0 days until the app was next opened.
    @Test func aPayloadFromAnOlderBuildStillLoads() throws {
        let legacy = """
        {"currentStreakDays":12,"longestStreakDays":30,"bonsaiStage":3,\
        "bonsaiStyleID":"cascade","gardenVitality":0.8,"placedItemIDs":[],\
        "unlockedItemIDs":["moss"],"generatedAt":0}
        """
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(legacy.utf8))
        #expect(decoded.currentStreakDays == 12)
        #expect(decoded.bonsaiStyleID == "cascade")
        #expect(decoded.carryoverDays == 0)
    }

    @Test func aRoundTripKeepsTheCarryover() throws {
        var snap = WidgetSnapshot.empty
        snap.carryoverDays = 9
        snap.currentStreakDays = 3
        let decoded = try JSONDecoder().decode(
            WidgetSnapshot.self, from: try JSONEncoder().encode(snap)
        )
        #expect(decoded == snap)
        #expect(decoded.carryoverDays == 9)
    }
}

@Suite("Pattern totals divide by sessions the user answered for")
struct PatternDenominatorTests {
    private func craving(_ outcome: CravingOutcome) -> CravingFacts {
        CravingFacts(
            startedAt: Date(timeIntervalSince1970: 1_756_000_000),
            secondsElapsed: 120,
            outcome: outcome,
            intensity: 3,
            trigger: nil
        )
    }

    /// The regression: the headline counted abandoned sessions in its
    /// denominator, so the one number the screen says about the user read as
    /// failures they never had, and it disagreed with the rate card below it.
    @Test func abandonedSessionsAreNotFailures() {
        let facts = [
            craving(.rodeItOut), craving(.rodeItOut), craving(.gaveIn),
            craving(.unresolved), craving(.unresolved)
        ]
        #expect(CravingInsights.resolved(facts).count == 3)
        let rate = CravingInsights.rideOutRate(facts)
        #expect(rate?.rode == 2)
        #expect(rate?.resolved == 3)
    }

    @Test func timingStillCountsEverySessionTheUserStarted() {
        // An urge that started at 9pm started at 9pm however the screen closed,
        // so the timing floor is measured against the full log.
        let facts = Array(repeating: craving(.unresolved), count: 4)
        #expect(facts.count >= CravingInsights.minimumForTiming)
        #expect(CravingInsights.resolved(facts).isEmpty)
    }
}
