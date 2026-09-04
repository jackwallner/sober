import Foundation
import SwiftData

@MainActor
final class CheckInService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Record a day the user acted on. `logged` marks it as a real tap, which
    /// is what separates a tended day from one the app assumed on their behalf.
    func checkIn(
        for date: Date = .now,
        wasSober: Bool = true,
        mood: Int? = nil,
        note: String? = nil,
        logged: Bool = true
    ) {
        let day = DateHelpers.startOfDay(date)
        if let existing = find(day: day) {
            existing.wasSober = wasSober
            existing.mood = mood ?? existing.mood
            existing.note = note ?? existing.note
            // Only ever promotes. An auto-filled day the user later tends is
            // tended; a tended day is never demoted by a later backfill.
            existing.wasLogged = existing.wasLogged || logged
        } else {
            let entry = DailyCheckIn(day: day, wasSober: wasSober, mood: mood, note: note, wasLogged: logged)
            context.insert(entry)
        }
        try? context.save()
    }

    /// Whether the user has actually checked in on this day, as opposed to the
    /// app having filled it in. Drives Home's check-in control, so it has to
    /// mean the tap, not the row.
    func hasCheckedIn(on date: Date = .now) -> Bool {
        find(day: DateHelpers.startOfDay(date))?.wasLogged ?? false
    }

    /// Whether the day the user logged today was a slip. Home needs this
    /// because `hasCheckedIn` answers "did they log something", and logging a
    /// slip is very much logging something.
    func loggedSlip(on date: Date = .now) -> Bool {
        guard let entry = find(day: DateHelpers.startOfDay(date)) else { return false }
        return entry.wasLogged && !entry.wasSober
    }

    /// Facts about a date range, detached from SwiftData so views and tests
    /// can reason about a week without a ModelContext.
    func facts(from start: Date, to end: Date) -> [CheckInFacts] {
        fetch(from: start, to: end).map {
            CheckInFacts(day: $0.day, wasSober: $0.wasSober, wasLogged: $0.wasLogged, mood: $0.mood)
        }
    }

    func fetch(from start: Date, to end: Date) -> [DailyCheckIn] {
        let s = DateHelpers.startOfDay(start)
        let e = DateHelpers.startOfDay(end)
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.day >= s && $0.day <= e },
            sortBy: [SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Ensure every day in the active journey's range up to `through` has a sober
    /// check-in so the calendar always matches the journey-day counter on the
    /// Home spine. Callers pass `through: yesterday` so the current day is left
    /// for the user to actively check in (the Home check-in / slip controls key
    /// off today being unlogged). Fills gaps only — never overwrites an existing
    /// entry (e.g. an edited mood or a logged slip). Idempotent.
    ///
    /// Batches into a single fetch + single save: a long back-dated start could
    /// otherwise fire thousands of serial fetch round-trips on the main actor
    /// and stall the first Home render.
    func fillJourney(start: Date, through end: Date) {
        let cal = Calendar.current
        let first = DateHelpers.startOfDay(start)
        let last = DateHelpers.startOfDay(end)
        guard first <= last else { return }

        let existing = Set(fetch(from: first, to: last).map(\.day))
        var cursor = first
        var didInsert = false
        while cursor <= last {
            if !existing.contains(cursor) {
                // Assumed, not tended: the user never said anything about
                // these days, the calendar just needs to agree with the
                // counter.
                context.insert(DailyCheckIn(day: cursor, wasSober: true, wasLogged: false))
                didInsert = true
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if didInsert { try? context.save() }
    }

    /// Backfill check-ins as sober for every day from the last recorded check-in
    /// (or today if there is none) up through today. Idempotent.
    func backfillSoberDays(through end: Date = .now) {
        let today = DateHelpers.startOfDay(end)
        let cal = Calendar.current
        let from: Date = {
            if let last = lastCheckInDate() {
                return cal.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(last)) ?? today
            }
            return today
        }()
        var cursor = from
        while cursor <= today {
            if find(day: cursor) == nil {
                // The user answered "still sober" for this whole span, so
                // every day in it is tended rather than assumed.
                context.insert(DailyCheckIn(day: cursor, wasSober: true, wasLogged: true))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        try? context.save()
    }

    /// Every sober day ever logged, across all journeys. This is the number
    /// that makes a slip survivable: the streak restarts, this does not.
    func lifetimeSoberDayCount() -> Int {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.wasSober }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Number of full days since the user last actually checked in. Returns 0
    /// when they checked in today, and 0 when they never have.
    ///
    /// Counting rows rather than taps made this permanently return 1, because
    /// `fillJourney` backfills every day through yesterday on each launch.
    /// That silently killed Home's "welcome back" branch. The never-logged
    /// case returns 0 rather than the age of the journey so that upgrading
    /// users, whose existing rows all default to unlogged, are not greeted by
    /// a "you have been gone for 200 days" banner on first launch.
    func daysSinceLastCheckIn(asOf now: Date = .now) -> Int {
        guard let last = lastLoggedCheckInDate() else { return 0 }
        return max(0, DateHelpers.daysBetween(last, now))
    }

    func lastCheckInDate() -> Date? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        return try? context.fetch(descriptor).first?.day
    }

    func lastLoggedCheckInDate() -> Date? {
        var descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.wasLogged },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.day
    }

    private func find(day: Date) -> DailyCheckIn? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.day == day }
        )
        return try? context.fetch(descriptor).first
    }
}
