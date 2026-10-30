import Testing
import Foundation
import SwiftData
import RevenueCat
@testable import Sober

/// The 2026-10-30 overnight bug hunt (`~/ios/growth/2026-10-30-overnight/reports/sober.md`).
/// Each suite pins one finding the report proved with a scratch probe.

// MARK: - F01: a DST change at midnight made the backfill overwrite logged days

struct MidnightDSTCase: Sendable, CustomTestStringConvertible {
    let zone: String
    let year: Int
    let month: Int
    let day: Int
    var testDescription: String { zone }
}

@Suite("Backfill walks real days across a skipped midnight")
struct MidnightDSTBackfillTests {
    static let cases = [
        MidnightDSTCase(zone: "America/Santiago", year: 2026, month: 9, day: 6),
        MidnightDSTCase(zone: "America/Havana", year: 2026, month: 3, day: 8),
        MidnightDSTCase(zone: "Africa/Cairo", year: 2026, month: 4, day: 24),
    ]

    @Test(arguments: cases)
    func everyDayIsItsOwnStartOfDay(_ c: MidnightDSTCase) throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try #require(TimeZone(identifier: c.zone))
        let change = try #require(cal.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12)))
        // The case is only worth anything if that midnight really is skipped.
        #expect(cal.component(.hour, from: cal.startOfDay(for: change)) == 1)

        let first = cal.startOfDay(for: try #require(cal.date(byAdding: .day, value: -7, to: change)))
        let last = cal.startOfDay(for: try #require(cal.date(byAdding: .day, value: 7, to: change)))
        let days = CheckInService.calendarDays(from: first, through: last, calendar: cal)

        #expect(days.count == 15, "the walk stopped short (yesterday was never filled)")
        #expect(days.last == last)
        #expect(days.allSatisfy { cal.startOfDay(for: $0) == $0 },
                "a step landed off a start of day, so it missed the stored row and replaced it")
        #expect(Set(days.map { cal.component(.day, from: $0) }).count == 15)
    }

    @MainActor
    @Test func fillingNeverTouchesALoggedDay() throws {
        let container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let defaults = try #require(UserDefaults(suiteName: "dst-\(UUID().uuidString)"))
        let svc = CheckInService(context: container.mainContext, dayKeyDefaults: defaults)
        svc.checkIn(for: DateHelpers.daysAgo(3), mood: 4, note: "good day")
        svc.checkIn(for: DateHelpers.daysAgo(2), wasSober: false, note: "slipped at the party")

        svc.fillJourney(start: DateHelpers.daysAgo(11), through: DateHelpers.daysAgo(1))

        let rows = svc.fetch(from: DateHelpers.daysAgo(11), to: DateHelpers.daysAgo(1))
        #expect(rows.count == 11)
        let good = rows.first { $0.day == DateHelpers.daysAgo(3) }
        #expect(good?.wasLogged == true)
        #expect(good?.mood == 4)
        #expect(good?.note == "good day")
        let slip = rows.first { $0.day == DateHelpers.daysAgo(2) }
        #expect(slip?.wasSober == false)
        #expect(slip?.note == "slipped at the party")
        #expect(rows.contains { $0.day == DateHelpers.daysAgo(1) }, "yesterday was never filled")
    }
}

// MARK: - F02: crossing a time zone duplicated every check-in row

@Suite("Check-in days survive a time zone change")
@MainActor
struct TimeZoneDayKeyTests {
    private let container: ModelContainer
    private let defaults: UserDefaults

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        defaults = UserDefaults(suiteName: "tz-day-keys-\(UUID().uuidString)")!
    }

    private var context: ModelContext { container.mainContext }

    private func rows() -> [DailyCheckIn] {
        (try? context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.day)]))) ?? []
    }

    /// A fixed-offset zone more than twelve hours from this one, where
    /// nearest-midnight guessing alone would pick the wrong day.
    private var farZone: TimeZone {
        let here = TimeZone.current.secondsFromGMT()
        return TimeZone(secondsFromGMT: here >= 0 ? -10 * 3600 : 9 * 3600)!
    }

    /// Five hours from here, as on a flight from New York to London.
    private var nearZone: TimeZone {
        let here = TimeZone.current.secondsFromGMT()
        let shifted = here + 5 * 3600 <= 14 * 3600 ? here + 5 * 3600 : here - 5 * 3600
        return TimeZone(secondsFromGMT: shifted)!
    }

    /// Midnight in `zone` of the calendar date that is `daysAgo` days back here.
    private func midnight(daysAgo: Int, in zone: TimeZone) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: DateHelpers.daysAgo(daysAgo))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: comps)!
    }

    private func insert(daysAgo: Int, in zone: TimeZone, sober: Bool = true, logged: Bool = false, mood: Int? = nil, note: String? = nil) {
        let row = DailyCheckIn(day: .now, wasSober: sober, mood: mood, note: note, wasLogged: logged)
        // The initializer keys to this zone; overwrite with the other zone's midnight.
        row.day = midnight(daysAgo: daysAgo, in: zone)
        context.insert(row)
    }

    /// The report's probe: twenty days filled in one zone, today checked in,
    /// then Home's refresh runs in another zone.
    @Test func travellingDoesNotDuplicateHistory() throws {
        for d in 1...20 { insert(daysAgo: d, in: farZone) }
        insert(daysAgo: 0, in: farZone, logged: true)
        try context.save()
        defaults.set(farZone.identifier, forKey: AppGroup.checkInDayKeyZoneKey)

        let svc = CheckInService(context: context, dayKeyDefaults: defaults)
        svc.fillJourney(start: DateHelpers.daysAgo(20), through: DateHelpers.daysAgo(1))

        #expect(rows().count == 21, "21 calendar days became \(rows().count) rows")
        #expect(svc.lifetimeSoberDayCount() == 21)
        #expect(svc.hasCheckedIn(), "today's check-in, written in the other zone, was lost")
        #expect(rows().allSatisfy { DateHelpers.startOfDay($0.day) == $0.day })
        #expect(defaults.string(forKey: AppGroup.checkInDayKeyZoneKey) == TimeZone.current.identifier)
    }

    /// Users who already travelled on an older build have both copies on disk
    /// and no record of the zone. The repair merges them and keeps every word.
    @Test func duplicatesFromEarlierBuildsMergeWithoutLosingAnything() throws {
        for d in 1...10 { insert(daysAgo: d, in: .current) }
        for d in 1...10 where d != 3 && d != 5 { insert(daysAgo: d, in: nearZone) }
        insert(daysAgo: 3, in: nearZone, sober: false, logged: true, note: "rough day")
        insert(daysAgo: 5, in: nearZone, logged: true, mood: 4, note: "walked it off")
        let five = try #require(rows().first { $0.day == midnight(daysAgo: 5, in: .current) })
        five.wasLogged = true
        five.note = "first note"
        try context.save()
        #expect(rows().count == 20)

        CheckInService.normalizeDayKeys(context: context, defaults: defaults)

        let after = rows()
        #expect(after.count == 10)
        let slip = after.first { $0.day == DateHelpers.daysAgo(3) }
        #expect(slip?.wasSober == false)
        #expect(slip?.wasLogged == true)
        #expect(slip?.note == "rough day")
        let merged = after.first { $0.day == DateHelpers.daysAgo(5) }
        #expect(merged?.mood == 4)
        #expect(merged?.note?.contains("first note") == true)
        #expect(merged?.note?.contains("walked it off") == true)
        #expect(after.filter(\.wasLogged).count == 2)
    }

    @Test func aSecondPassChangesNothing() throws {
        for d in 1...5 { insert(daysAgo: d, in: .current) }
        try context.save()
        CheckInService.normalizeDayKeys(context: context, defaults: defaults)
        let first = rows().map(\.day)
        CheckInService.normalizeDayKeys(context: context, defaults: defaults)
        #expect(rows().map(\.day) == first)
        #expect(first.count == 5)
    }

    @Test func calendarDayIsRecoveredAcrossTheWidestTrips() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let london = TimeZone(identifier: "Europe/London")!
        func midnight(_ zone: TimeZone) -> Date {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = zone
            return cal.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        }
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: la, in: tokyo) == midnight(tokyo))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: nil, in: tokyo) == midnight(tokyo))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(tokyo), keyedIn: nil, in: la) == midnight(la))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(london), keyedIn: nil, in: la) == midnight(la))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: la, in: la) == midnight(la))
    }

    /// Santiago's Sept 6, 2026 starts at 01:00. A row keyed there must stay
    /// on that day when the zone is unknown (the first launch of this build).
    @Test func aSkippedMidnightKeepsItsDay() throws {
        let santiago = try #require(TimeZone(identifier: "America/Santiago"))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = santiago
        let noon = try #require(cal.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
        let start = cal.startOfDay(for: noon)
        #expect(CheckInService.startOfCalendarDay(containing: start, keyedIn: nil, in: santiago) == start)
    }
}

// MARK: - F03: the trial recap said "ends tomorrow" on the trial's last day

@Suite("Trial days remaining are calendar days")
struct TrialDaysRemainingTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func at(_ day: Int, _ hour: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func theLastDayReadsToday() {
        #expect(TrialLifecycle.daysRemaining(until: at(9, 21), now: at(9, 9), calendar: cal) == 0)
    }

    @Test func theEveningBeforeReadsTomorrow() {
        #expect(TrialLifecycle.daysRemaining(until: at(9, 21), now: at(8, 21), calendar: cal) == 1)
        #expect(TrialLifecycle.daysRemaining(until: at(9, 9), now: at(8, 22), calendar: cal) == 1)
    }

    @Test func twoCalendarDaysOutReadsTwo() {
        #expect(TrialLifecycle.daysRemaining(until: at(9, 9), now: at(7, 23), calendar: cal) == 2)
    }

    @Test func anEndedTrialHasNoCount() {
        #expect(TrialLifecycle.daysRemaining(until: at(9, 9), now: at(9, 10), calendar: cal) == nil)
    }
}

// MARK: - F04: daily spend capped at 200 units of the local currency

struct SpendCase: Sendable, CustomTestStringConvertible {
    let code: String
    /// Rough local units per US dollar, autumn 2026.
    let perDollar: Double
    var testDescription: String { code }
}

@Suite("Daily spend controls fit the local currency")
struct SpendScaleTests {
    static let cases = [
        SpendCase(code: "VND", perDollar: 25_000),
        SpendCase(code: "INR", perDollar: 84),
        SpendCase(code: "RUB", perDollar: 90),
        SpendCase(code: "CLP", perDollar: 950),
        SpendCase(code: "UAH", perDollar: 41),
        SpendCase(code: "USD", perDollar: 1),
        SpendCase(code: "EUR", perDollar: 0.92),
    ]

    @Test(arguments: cases)
    func theRangeReachesARealDailySpend(_ c: SpendCase) {
        let scale = SpendScale(currencyCode: c.code)
        #expect(Double(scale.maxDaily) / c.perDollar >= 50)
        #expect(Double(scale.defaultDaily * 365) / c.perDollar >= 100)
        #expect(Double(scale.defaultDaily) / c.perDollar <= 60, "the default overstates the habit")
        #expect(scale.maxDaily % scale.step == 0)
    }

    @Test func anUnknownCurrencyKeepsTheDollarShape() {
        let scale = SpendScale(currencyCode: nil)
        #expect(scale.defaultDaily == 20)
        #expect(scale.step == 5)
        #expect(scale.maxDaily == 200)
    }
}

// MARK: - F05: "Add note" opened empty and replaced the saved note

@Suite("The day's note is edited, never replaced blind")
@MainActor
struct CheckInNoteEditTests {
    private let container: ModelContainer
    private let svc: CheckInService

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        svc = CheckInService(
            context: container.mainContext,
            dayKeyDefaults: UserDefaults(suiteName: "note-\(UUID().uuidString)")!
        )
    }

    @Test func theSheetOpensOnTheSavedNote() {
        svc.checkIn()
        svc.saveDetail(mood: 4, note: "Craving at lunch, walked it off")
        let saved = svc.detail()
        #expect(saved.mood == 4)
        #expect(saved.note == "Craving at lunch, walked it off")
    }

    @Test func anEditKeepsWhatTheUserLeftInTheField() {
        svc.checkIn()
        svc.saveDetail(mood: 4, note: "Craving at lunch, walked it off")
        let opened = svc.detail().note ?? ""
        svc.saveDetail(mood: 4, note: opened + "\nEvening was fine")
        #expect(svc.detail().note == "Craving at lunch, walked it off\nEvening was fine")
    }

    @Test func clearingTheFieldClearsTheNote() {
        svc.checkIn(note: "draft")
        svc.saveDetail(mood: nil, note: "   ")
        #expect(svc.detail().note == nil)
        #expect(svc.hasCheckedIn())
    }

    @Test func aNoteOnASlipDayLeavesTheSlip() {
        svc.checkIn(wasSober: false)
        svc.saveDetail(mood: 2, note: "Tomorrow is day one")
        #expect(svc.loggedSlip())
        #expect(svc.detail().note == "Tomorrow is day one")
    }
}

// MARK: - P2s fixed in the same pass

@Suite("Smaller overnight findings")
@MainActor
struct OvernightP2Tests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UnlockedAchievement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// F06: RevenueCat reports Ask to Buy as `paymentPendingError`.
    @Test func aDeferredPaymentIsPendingNotFailed() {
        #expect(SubscriptionService.isDeferredPayment(RevenueCat.ErrorCode.paymentPendingError))
        #expect(!SubscriptionService.isDeferredPayment(RevenueCat.ErrorCode.purchaseCancelledError))
        #expect(!SubscriptionService.isDeferredPayment(URLError(.notConnectedToInternet)))
    }

    /// F08: an older slip entered after a newer one leaves the live tree and
    /// the latest slip's undo snapshot alone.
    @Test func anOlderSlipLeavesTheLiveTree() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(26))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        let garden = GardenService(context: context)
        let carryover = garden.current().carryoverDays
        let snapshot = garden.current().carryoverBeforeSlip
        let grove = garden.current().groveCountAtJourneyStart

        SlipRecorder.record(on: DateHelpers.daysAgo(20), context: context)

        #expect(SobrietyService(context: context).currentDayCount() == 10)
        #expect(garden.current().carryoverDays == carryover)
        #expect(garden.current().carryoverBeforeSlip == snapshot)
        #expect(garden.current().groveCountAtJourneyStart == grove)
    }

    /// F09: Home appearing three times on one day costs one day's fade.
    @Test func vitalityFadesOncePerMissedDay() {
        let garden = GardenService(context: context)
        garden.water(at: DateHelpers.daysAgo(2))
        garden.current().vitality = 1.0
        garden.applyVitalityDecay()
        let once = garden.current().vitality
        garden.applyVitalityDecay()
        garden.applyVitalityDecay()
        #expect(garden.current().vitality == once)
        #expect(abs(once - 0.8) < 0.0001)
    }

    /// F10: streak badges say "check-ins", so assumed days don't earn them.
    @Test func checkInBadgesNeedCheckIns() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(120))
        CheckInService(context: context).fillJourney(start: DateHelpers.daysAgo(120), through: DateHelpers.daysAgo(1))
        let achievements = AchievementService(context: context)
        achievements.processUnlocks(currentDays: 121)
        let ids = Set(achievements.unlocked().map(\.achievementID))
        #expect(ids.contains("perfect-week") == false)
        #expect(ids.contains("consistency-champion") == false)
        #expect(ids.contains("diamond-discipline") == false)
        #expect(ids.contains("quarter-master"))
    }
}
