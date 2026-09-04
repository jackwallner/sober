import Testing
import Foundation
import SwiftData
@testable import Sober

/// The build 83 to 87 audit (`reg93.md`) found four bugs that share one root:
/// `wasLogged` and carryover were added without being taught to every path
/// that already existed. These pin the repaired behaviour.

@Suite("Upgrading from a build without wasLogged")
@MainActor
struct LegacyCheckInMigrationTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        AppGroup.defaults.removeObject(forKey: AppGroup.legacyCheckInsMarkedLoggedKey)
    }

    private func service() -> CheckInService {
        CheckInService(context: container.mainContext)
    }

    /// The regression: `wasLogged` defaults to false, so an upgrading user's
    /// whole tended history came back reading as days the app had assumed.
    @Test func rowsWrittenBeforeTheFieldExistedReadAsTended() {
        let svc = service()
        // A pre-upgrade row: no `wasLogged`, so it lands on the default.
        container.mainContext.insert(DailyCheckIn(day: DateHelpers.daysAgo(1), wasSober: true))
        container.mainContext.insert(DailyCheckIn(day: .now, wasSober: true))
        try? container.mainContext.save()
        #expect(svc.hasCheckedIn() == false)

        CheckInService.migrateLegacyCheckInsIfNeeded(context: container.mainContext)
        #expect(svc.hasCheckedIn() == true)
        let migrated = svc.facts(from: DateHelpers.daysAgo(1), to: .now)
        #expect(migrated.filter(\.wasLogged).count == migrated.count)
    }

    /// It runs once. A second pass after this build has filled in assumed days
    /// would promote exactly the rows the field exists to keep separate.
    @Test func itNeverRunsTwice() {
        let svc = service()
        CheckInService.migrateLegacyCheckInsIfNeeded(context: container.mainContext)

        svc.fillJourney(start: DateHelpers.daysAgo(3), through: DateHelpers.daysAgo(1))
        CheckInService.migrateLegacyCheckInsIfNeeded(context: container.mainContext)
        #expect(svc.facts(from: DateHelpers.daysAgo(3), to: DateHelpers.daysAgo(1))
            .allSatisfy { $0.wasLogged == false })
    }
}

@Suite("Still sober covers the days it claims")
@MainActor
struct StillSoberBackfillTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func service() -> CheckInService {
        CheckInService(context: container.mainContext)
    }

    /// The exact Home sequence: `fillJourney` runs on appear and writes assumed
    /// rows through yesterday, *then* the user taps "Still sober". Anchoring on
    /// the last row rather than the last tap made the action cover today alone
    /// while the week strip kept showing the span as untended.
    @Test func itPromotesTheAssumedDaysHomeAlreadyFilledIn() {
        let svc = service()
        svc.checkIn(for: DateHelpers.daysAgo(4))
        svc.fillJourney(start: DateHelpers.daysAgo(4), through: DateHelpers.daysAgo(1))
        #expect(svc.facts(from: DateHelpers.daysAgo(3), to: DateHelpers.daysAgo(1))
            .allSatisfy { $0.wasLogged == false })

        svc.backfillSoberDays()

        let span = svc.facts(from: DateHelpers.daysAgo(4), to: .now)
        #expect(span.count == 5)
        #expect(span.allSatisfy { $0.wasLogged && $0.wasSober })
        #expect(svc.daysSinceLastCheckIn() == 0)
    }

    /// Confirming a stretch of days never overwrites something the user told
    /// the app happened.
    @Test func aLoggedSlipInsideTheSpanSurvives() {
        let svc = service()
        svc.checkIn(for: DateHelpers.daysAgo(5))
        svc.checkIn(for: DateHelpers.daysAgo(3), wasSober: false)
        svc.fillJourney(start: DateHelpers.daysAgo(5), through: DateHelpers.daysAgo(1))

        svc.backfillSoberDays()

        let slip = svc.facts(from: DateHelpers.daysAgo(3), to: DateHelpers.daysAgo(3)).first
        #expect(slip?.wasSober == false)
        #expect(slip?.wasLogged == true)
        // Days before the slip stay as the app filled them: the confirmation
        // only reaches back to the last thing the user actually said.
        #expect(svc.facts(from: DateHelpers.daysAgo(4), to: DateHelpers.daysAgo(4)).first?.wasLogged == false)
    }

    @Test func itIsIdempotent() {
        let svc = service()
        svc.checkIn(for: DateHelpers.daysAgo(2))
        svc.backfillSoberDays()
        svc.backfillSoberDays()
        #expect(svc.facts(from: DateHelpers.daysAgo(2), to: .now).count == 3)
    }
}

@Suite("A slip is scored against the day it happened")
@MainActor
struct BackdatedSlipTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// The regression: the preview, the confirmation, and the carryover all
    /// read the live counter, so a slip entered from ten days ago was scored
    /// against a 27-day run that had not happened yet on that date.
    @Test func thePreviousStreakIsMeasuredAtTheSlipDate() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(26))
        #expect(SlipRecorder.streakDays(endingOn: .now, context: context) == 27)
        #expect(SlipRecorder.streakDays(endingOn: DateHelpers.daysAgo(10), context: context) == 17)

        let outcome = SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(outcome.previousStreakDays == 17)
        #expect(outcome.carryoverDays == 8)
    }

    /// The reset date and the streak the confirmation names have to describe
    /// the same timeline.
    @Test func theNewJourneyStartsTheDayAfterTheSlip() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(26))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() == 10)
    }

    /// Re-submitting a slip for a day that already has one is an edit. The
    /// counter reset is idempotent; the garden's 50% rule was not, so a double
    /// tap halved the inherited growth a second time.
    @Test func aSecondSlipOnTheSameDayDoesNotShrinkTheTreeAgain() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(26))
        let first = SlipRecorder.record(on: .now, context: context)
        #expect(first.carryoverDays == 13)

        let second = SlipRecorder.record(on: .now, note: "second thoughts", context: context)
        #expect(second.carryoverDays == 13)
        #expect(GardenService(context: context).current().carryoverDays == 13)
    }

    /// An edit still lands: the note goes on the existing row rather than
    /// being dropped along with the duplicate garden mutation.
    @Test func theEditItselfIsStillRecorded() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(10))
        SlipRecorder.record(on: .now, context: context)
        SlipRecorder.record(on: .now, mood: 2, note: "rough night", context: context)

        let rows = CheckInService(context: context).fetch(from: .now, to: .now)
        #expect(rows.count == 1)
        #expect(rows.first?.note == "rough night")
        #expect(rows.first?.mood == 2)
    }
}

@Suite("Patterns do not claim more than the sample supports")
struct PatternSampleFloorTests {
    private func craving(hour: Int, outcome: CravingOutcome = .rodeItOut) -> CravingFacts {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
        return CravingFacts(
            startedAt: date,
            secondsElapsed: 120,
            outcome: outcome,
            intensity: 3,
            trigger: nil
        )
    }

    /// The guard's second clause restated the one at the top of the function,
    /// so it could never fire: four urges inside one evening produced a
    /// confident "Hardest between" with nothing to compare against.
    @Test func aWindowHoldingEveryRecordIsNotAPattern() {
        let clustered = [craving(hour: 19), craving(hour: 20), craving(hour: 20), craving(hour: 21)]
        #expect(CravingInsights.peakWindow(clustered) == nil)
    }

    @Test func aRealPeakStillReads() {
        let spread = [
            craving(hour: 19), craving(hour: 20), craving(hour: 20),
            craving(hour: 8), craving(hour: 13),
        ]
        let window = CravingInsights.peakWindow(spread)
        #expect(window?.count == 3)
        #expect(window?.startHour == 18 || window?.startHour == 19 || window?.startHour == 20)
    }

    /// `nextUnlock` counted rows, so four abandoned sessions made the "more
    /// data" line disappear while every insight it explained stayed empty.
    @Test func abandonedSessionsDoNotSatisfyTheUnlock() {
        let unresolved = Array(repeating: craving(hour: 12, outcome: .unresolved), count: 4)
        // Timing readings only need a start time, so some cards do appear. The
        // ones that need an outcome do not, and the unlock line has to keep
        // explaining that rather than vanishing on a row count.
        let shown = CravingInsights.insights(cravings: unresolved, checkIns: [])
        #expect(shown.contains { $0.id == "rate" } == false)
        #expect(shown.contains { $0.id == "length" } == false)
        #expect(CravingInsights.nextUnlock(unresolved, showing: shown.count) != nil)
    }

    @Test func resolvedSessionsDoSatisfyIt() {
        let resolved = [
            craving(hour: 8), craving(hour: 13),
            craving(hour: 19, outcome: .gaveIn), craving(hour: 20),
        ]
        #expect(CravingInsights.nextUnlock(resolved) == nil)
    }
}
