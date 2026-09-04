import Testing
import Foundation
@testable import Sober

@Suite("Craving insights")
struct CravingInsightsTests {
    /// Fixed calendar and zone: hour-of-day and weekday readings are the whole
    /// point of this file, so they must not depend on where the test runs.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    private func date(_ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour)) ?? .distantPast
    }

    private func craving(
        day: Int = 2,
        hour: Int = 20,
        seconds: Int = 180,
        outcome: CravingOutcome = .rodeItOut,
        intensity: Int = 3,
        trigger: String? = nil
    ) -> CravingFacts {
        CravingFacts(
            startedAt: date(day, hour: hour),
            secondsElapsed: seconds,
            outcome: outcome,
            intensity: intensity,
            trigger: trigger
        )
    }

    // MARK: - Ride-out rate

    @Test func rateStaysSilentBelowItsSampleFloor() {
        #expect(CravingInsights.rideOutRate([craving(), craving()]) == nil)
    }

    /// Someone who closed the screen did not necessarily drink. Counting that
    /// against them would make the one number they see about themselves
    /// quietly pessimistic.
    @Test func unresolvedSessionsAreExcludedRatherThanCountedAsFailures() {
        let facts = [
            craving(outcome: .rodeItOut),
            craving(outcome: .rodeItOut),
            craving(outcome: .gaveIn),
            craving(outcome: .unresolved),
            craving(outcome: .unresolved),
        ]
        let rate = CravingInsights.rideOutRate(facts)
        #expect(rate?.rode == 2)
        #expect(rate?.resolved == 3)
    }

    // MARK: - Session length

    @Test func lengthUsesTheMedianSoOneLongSessionCannotSkewIt() {
        let facts = [
            craving(seconds: 120),
            craving(seconds: 150),
            craving(seconds: 180),
            craving(seconds: 3000),
        ]
        #expect(CravingInsights.medianRideOutSeconds(facts) == 165)
    }

    @Test func lengthIgnoresSessionsTheUserDidNotRideOut() {
        let facts = [
            craving(seconds: 240),
            craving(seconds: 240),
            craving(seconds: 240),
            craving(seconds: 5, outcome: .gaveIn),
        ]
        #expect(CravingInsights.medianRideOutSeconds(facts) == 240)
    }

    // MARK: - Timing

    @Test func peakWindowFindsTheHeaviestThreeHours() {
        let facts = [
            craving(hour: 20), craving(hour: 21), craving(hour: 21), craving(hour: 22),
            craving(hour: 9),
        ]
        let window = CravingInsights.peakWindow(facts, calendar: calendar)
        #expect(window?.startHour == 20)
        #expect(window?.count == 4)
    }

    @Test func timingStaysSilentBelowItsSampleFloor() {
        #expect(CravingInsights.peakWindow([craving(), craving(), craving()], calendar: calendar) == nil)
        #expect(CravingInsights.hardestWeekday([craving()], calendar: calendar) == nil)
    }

    @Test func hardestWeekdayCountsTheRightDay() {
        // 2026-03-06 is a Friday, which is weekday 6 in a Gregorian calendar.
        let facts = [
            craving(day: 6), craving(day: 6), craving(day: 6),
            craving(day: 4),
        ]
        let day = CravingInsights.hardestWeekday(facts, calendar: calendar)
        #expect(day?.weekday == 6)
        #expect(day?.count == 3)
    }

    // MARK: - Triggers

    @Test func triggerNeedsBothEnoughTagsAndARepeat() {
        let onesie = [
            craving(trigger: "Stress"),
            craving(trigger: "Boredom"),
            craving(trigger: "Tired"),
        ]
        #expect(CravingInsights.topTrigger(onesie) == nil)

        let repeated = onesie + [craving(trigger: "Stress")]
        let top = CravingInsights.topTrigger(repeated)
        #expect(top?.name == "Stress")
        #expect(top?.count == 2)
    }

    @Test func untaggedSessionsDoNotCountTowardTheTriggerFloor() {
        #expect(CravingInsights.topTrigger([craving(), craving(), craving(trigger: "Stress")]) == nil)
    }

    // MARK: - Week over week

    @Test func weeklyChangeSplitsTheTwoWindows() {
        let now = date(20, hour: 12)
        let facts = [
            craving(day: 18), craving(day: 19),
            craving(day: 10), craving(day: 11), craving(day: 12),
        ]
        let change = CravingInsights.weeklyChange(facts, asOf: now, calendar: calendar)
        #expect(change?.thisWeek == 2)
        #expect(change?.lastWeek == 3)
    }

    @Test func weeklyChangeStaysSilentOnThinData() {
        let now = date(20, hour: 12)
        #expect(CravingInsights.weeklyChange([craving(day: 19)], asOf: now, calendar: calendar) == nil)
    }

    // MARK: - Mood

    private func checkIn(_ day: Int, sober: Bool = true, mood: Int?) -> CheckInFacts {
        CheckInFacts(day: date(day, hour: 0), wasSober: sober, wasLogged: true, mood: mood)
    }

    @Test func moodDipNeedsTwoSlipsAndMoodsOnBothSides() {
        let oneSlip = [
            checkIn(8, mood: 2), checkIn(9, mood: 2), checkIn(10, sober: false, mood: 1),
            checkIn(1, mood: 5), checkIn(2, mood: 5), checkIn(3, mood: 5),
        ]
        #expect(CravingInsights.moodDipBeforeSlips(oneSlip, calendar: calendar) == nil)
    }

    @Test func moodDipIsReportedOnlyWhenItIsBigEnoughToMeanAnything() {
        let facts = [
            checkIn(8, mood: 2), checkIn(9, mood: 2), checkIn(10, sober: false, mood: 1),
            checkIn(18, mood: 2), checkIn(19, mood: 1), checkIn(20, sober: false, mood: 1),
            checkIn(1, mood: 5), checkIn(2, mood: 4), checkIn(3, mood: 5),
        ]
        let dip = CravingInsights.moodDipBeforeSlips(facts, calendar: calendar)
        #expect(dip != nil)
        #expect((dip ?? 0) >= 0.5)
    }

    @Test func aFlatMoodRecordProducesNoDip() {
        let facts = [
            checkIn(8, mood: 4), checkIn(9, mood: 4), checkIn(10, sober: false, mood: 4),
            checkIn(18, mood: 4), checkIn(19, mood: 4), checkIn(20, sober: false, mood: 4),
            checkIn(1, mood: 4), checkIn(2, mood: 4), checkIn(3, mood: 4),
        ]
        #expect(CravingInsights.moodDipBeforeSlips(facts, calendar: calendar) == nil)
    }

    // MARK: - Presentation

    @Test func anEmptyRecordProducesNoClaims() {
        #expect(CravingInsights.insights(cravings: [], checkIns: [], calendar: calendar).isEmpty)
    }

    @Test func nextUnlockCountsDownAndThenStopsAsking() {
        #expect(CravingInsights.nextUnlock([]) != nil)
        // The last one before the floor reads as a word, not a numeral.
        #expect(CravingInsights.nextUnlock(Array(repeating: craving(), count: 3))?.hasPrefix("One more") == true)
        #expect(CravingInsights.nextUnlock(Array(repeating: craving(), count: 4)) == nil)
    }

    @Test func coachLineIsSilentUntilThereIsSomethingTrueToSay() {
        #expect(CravingInsights.coachLine([craving()]) == nil)
        #expect(CravingInsights.coachLine(Array(repeating: craving(seconds: 240), count: 3)) != nil)
    }

    @Test func durationRoundsToWordsNotDecimals() {
        #expect(CravingInsights.spokenDuration(45) == "about a minute")
        #expect(CravingInsights.spokenDuration(200) == "about 3 minutes")
    }
}
