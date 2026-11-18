import Foundation
import Testing
@testable import Sober

@Suite("Dry January challenge")
struct JanuaryChallengeTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        return cal
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func facts(_ days: ClosedRange<Int>, slips: Set<Int> = []) -> [CheckInFacts] {
        days.map {
            CheckInFacts(day: day(2027, 1, $0, hour: 0), wasSober: !slips.contains($0), wasLogged: false, mood: nil)
        }
    }

    @Test func monthIsThirtyOneLocalMidnights() {
        let days = JanuaryChallenge.days(calendar: calendar)
        #expect(days.count == 31)
        #expect(days.first == day(2027, 1, 1, hour: 0))
        #expect(days.last == day(2027, 1, 31, hour: 0))
    }

    @Test func upcomingCountsDownToJanuaryFirst() {
        let snapshot = JanuaryChallenge.snapshot(now: day(2026, 12, 18), facts: [], calendar: calendar)
        #expect(snapshot.phase == .upcoming(daysUntilStart: 14))
        #expect(snapshot.dryDays == 0)
        #expect(snapshot.days.allSatisfy { $0.mark == .ahead })
    }

    @Test func activeCountsDryDaysAndKeepsSlipsOut() {
        let snapshot = JanuaryChallenge.snapshot(
            now: day(2027, 1, 12), facts: facts(1...11, slips: [4]), calendar: calendar
        )
        #expect(snapshot.phase == .active)
        #expect(snapshot.dryDays == 10)
        #expect(snapshot.days[3].mark == .slip)
        #expect(snapshot.days[11].mark == .open)
        #expect(snapshot.days[11].isToday)
        #expect(snapshot.days[12].mark == .ahead)
        #expect(!snapshot.isComplete)
    }

    @Test func daysBeforeTheUsersFirstDayStayOpen() {
        let snapshot = JanuaryChallenge.snapshot(now: day(2027, 1, 20), facts: facts(10...19), calendar: calendar)
        #expect(snapshot.dryDays == 10)
        #expect(snapshot.days[0].mark == .open)
    }

    @Test func completeOnlyWithAllThirtyOneDry() {
        let full = JanuaryChallenge.snapshot(now: day(2027, 2, 1), facts: facts(1...31), calendar: calendar)
        #expect(full.phase == .finished)
        #expect(full.isComplete)
        let slipped = JanuaryChallenge.snapshot(now: day(2027, 2, 1), facts: facts(1...31, slips: [20]), calendar: calendar)
        #expect(!slipped.isComplete)
        #expect(slipped.dryDays == 30)
    }

    @Test func cardShowsFromTwoWeeksBeforeToAWeekAfter() {
        #expect(!JanuaryChallenge.showsCard(now: day(2026, 12, 17), calendar: calendar))
        #expect(JanuaryChallenge.showsCard(now: day(2026, 12, 18), calendar: calendar))
        #expect(JanuaryChallenge.showsCard(now: day(2027, 2, 7), calendar: calendar))
        #expect(!JanuaryChallenge.showsCard(now: day(2027, 2, 8), calendar: calendar))
        #expect(JanuaryChallenge.acceptsLink(now: day(2026, 11, 20), calendar: calendar))
        #expect(!JanuaryChallenge.acceptsLink(now: day(2027, 2, 8), calendar: calendar))
    }

    @Test func onlyTheChallengeLinkIsHandled() throws {
        #expect(JanuaryChallenge.handles(try #require(URL(string: "sober://dry-january"))))
        #expect(JanuaryChallenge.handles(try #require(URL(string: "SOBER://Dry-January"))))
        #expect(!JanuaryChallenge.handles(try #require(URL(string: "sober://garden"))))
        #expect(!JanuaryChallenge.handles(try #require(URL(string: "https://example.com/dry-january"))))
    }
}
