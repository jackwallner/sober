import Testing
import Foundation
import SwiftData
@testable import Sober

@Suite("Week strip")
struct TendedWeekTests {
    private let today = DateHelpers.startOfDay(Date(timeIntervalSince1970: 1_756_000_000))

    private func fact(_ daysAgo: Int, sober: Bool = true, logged: Bool, mood: Int? = nil) -> CheckInFacts {
        CheckInFacts(
            day: DateHelpers.daysAgo(daysAgo, from: today),
            wasSober: sober,
            wasLogged: logged,
            mood: mood
        )
    }

    @Test func alwaysSevenDaysOldestFirstEndingToday() {
        let week = TendedWeek.days(endingOn: today, facts: [])
        #expect(week.count == 7)
        #expect(week.first?.day == DateHelpers.daysAgo(6, from: today))
        #expect(week.last?.day == today)
    }

    @Test func aTapReadsDifferentlyFromAnAssumption() {
        let week = TendedWeek.days(endingOn: today, facts: [
            fact(0, logged: true),
            fact(1, logged: false),
            fact(2, sober: false, logged: true),
        ])
        #expect(week[6].mark == .tended)
        #expect(week[5].mark == .assumed)
        #expect(week[4].mark == .slip)
        #expect(week[3].mark == .blank)
        #expect(TendedWeek.tendedCount(week) == 1)
    }

    /// A slip is a slip whether or not the user tapped it in, so it must never
    /// be reported as an assumed sober day.
    @Test func aSlipIsNeverGreen() {
        let week = TendedWeek.days(endingOn: today, facts: [fact(0, sober: false, logged: false)])
        #expect(week[6].mark == .slip)
    }

    @Test func facturesOutsideTheWindowAreIgnored() {
        let week = TendedWeek.days(endingOn: today, facts: [fact(30, logged: true)])
        #expect(TendedWeek.tendedCount(week) == 0)
    }

    @Test func summaryNeverScolds() {
        let empty = TendedWeek.days(endingOn: today, facts: [])
        #expect(TendedWeek.summary(empty) == "Tend a day to start your week")
        let full = TendedWeek.days(endingOn: today, facts: (0..<7).map { fact($0, logged: true) })
        #expect(TendedWeek.summary(full) == "All 7 days tended")
    }

    @Test func moodSummaryNeedsAtLeastOneMood() {
        #expect(TendedWeek.moodSummary(TendedWeek.days(endingOn: today, facts: [fact(0, logged: true)])) == nil)
    }

    @Test func moodSummaryAveragesWhatWasRecorded() {
        let week = TendedWeek.days(endingOn: today, facts: [
            fact(0, logged: true, mood: 4),
            fact(1, logged: true, mood: 4),
            fact(2, logged: true, mood: 5),
        ])
        #expect(TendedWeek.moodSummary(week) == "mostly good")
    }

    @Test func outOfRangeMoodsAreDiscardedRatherThanSkewing() {
        let week = TendedWeek.days(endingOn: today, facts: [
            fact(0, logged: true, mood: 99),
            fact(1, logged: true, mood: 1),
        ])
        #expect(TendedWeek.moodSummary(week) == "mostly rough")
    }
}

@Suite("Tended days vs filled days")
@MainActor
struct CheckInLoggingTests {
    /// Held for the life of the test: the context does not keep the container
    /// alive, so a helper that returns only the context hands back a store
    /// that has already gone away.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func service() -> CheckInService {
        CheckInService(context: container.mainContext)
    }

    @Test func backfilledDaysAreNotTended() throws {
        let svc = service()
        svc.fillJourney(start: DateHelpers.daysAgo(5), through: DateHelpers.daysAgo(1))
        let facts = svc.facts(from: DateHelpers.daysAgo(5), to: .now)
        #expect(facts.count == 5)
        #expect(facts.allSatisfy { !$0.wasLogged })
    }

    /// The bug this whole field exists for: `fillJourney` runs on every Home
    /// appearance, so counting rows meant the answer was always 1 and the
    /// "welcome back" branch could never fire.
    @Test func absenceIsMeasuredInTapsNotRows() throws {
        let svc = service()
        svc.checkIn(for: DateHelpers.daysAgo(4))
        svc.fillJourney(start: DateHelpers.daysAgo(10), through: DateHelpers.daysAgo(1))
        #expect(svc.daysSinceLastCheckIn() == 4)
    }

    /// Existing installs upgrade with every row defaulting to unlogged. They
    /// must not be greeted by "you have been gone for 200 days".
    @Test func aUserWhoHasNeverTappedIsNotTreatedAsAbsent() throws {
        let svc = service()
        svc.fillJourney(start: DateHelpers.daysAgo(200), through: DateHelpers.daysAgo(1))
        #expect(svc.daysSinceLastCheckIn() == 0)
    }

    @Test func todayIsOnlyCheckedInOnceTapped() throws {
        let svc = service()
        svc.fillJourney(start: DateHelpers.daysAgo(3), through: .now)
        #expect(svc.hasCheckedIn() == false)
        svc.checkIn()
        #expect(svc.hasCheckedIn() == true)
    }

    /// Tending a day the app had already filled promotes it; a later backfill
    /// must never demote a day the user actually tended.
    @Test func loggedStatusOnlyEverPromotes() throws {
        let svc = service()
        let day = DateHelpers.daysAgo(2)
        svc.fillJourney(start: day, through: day)
        svc.checkIn(for: day, mood: 4)
        svc.fillJourney(start: day, through: day)
        let fact = svc.facts(from: day, to: day).first
        #expect(fact?.wasLogged == true)
        #expect(fact?.mood == 4)
    }

    @Test func lifetimeCountIncludesFilledDaysButNotSlips() throws {
        let svc = service()
        svc.fillJourney(start: DateHelpers.daysAgo(4), through: DateHelpers.daysAgo(1))
        svc.checkIn(for: DateHelpers.daysAgo(2), wasSober: false)
        #expect(svc.lifetimeSoberDayCount() == 3)
    }
}

@Suite("Today's slip is not a check-in")
@MainActor
struct SlipDayDisplayTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func service() -> CheckInService {
        CheckInService(context: container.mainContext)
    }

    /// Home keyed its "Today is logged, your bonsai is watered" card off
    /// hasCheckedIn, which only means the user logged *something*. Logging a
    /// slip is something, so the app congratulated people on the day they told
    /// it they drank.
    @Test func aSlipLoggedTodayIsReportedAsASlip() {
        let svc = service()
        svc.checkIn(wasSober: false)
        #expect(svc.hasCheckedIn() == true)
        #expect(svc.loggedSlip() == true)
    }

    @Test func anOrdinaryCheckInIsNotASlip() {
        let svc = service()
        svc.checkIn()
        #expect(svc.loggedSlip() == false)
    }

    @Test func anAutoFilledDayIsNeitherLoggedNorASlip() {
        let svc = service()
        svc.fillJourney(start: DateHelpers.daysAgo(2), through: .now)
        #expect(svc.hasCheckedIn() == false)
        #expect(svc.loggedSlip() == false)
    }

    /// The Home card sits between a checkmark and a button; the full sentence
    /// clipped to "Tend a day to start..." there.
    @Test func compactSummaryStaysShortEnoughForTheHomeCard() {
        let week = TendedWeek.days(facts: [])
        #expect(TendedWeek.compactSummary(week) == "0/7 tended")
        #expect(TendedWeek.compactSummary(week).count < 15)
    }
}

@Suite("Week line copy")
struct WeekLineTests {
    private let today = DateHelpers.startOfDay(Date(timeIntervalSince1970: 1_756_000_000))

    /// A user who checks in with a mood and then logs a slip that same day
    /// leaves the week with zero tended days but a recorded mood, which read
    /// as "Tend a day to start your week - felt mostly good".
    @Test func theMoodClauseNeedsACountToHangOff() {
        let week = TendedWeek.days(endingOn: today, facts: [
            CheckInFacts(day: today, wasSober: false, wasLogged: true, mood: 4)
        ])
        #expect(TendedWeek.tendedCount(week) == 0)
        #expect(TendedWeek.moodSummary(week) == "mostly good")
        #expect(TendedWeek.summary(week) == "Tend a day to start your week")
    }
}
