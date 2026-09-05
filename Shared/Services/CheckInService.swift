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

    /// Backfill check-ins as sober for every day from the last day the user
    /// actually tended (or today if there is none) up through today. Idempotent.
    ///
    /// Anchored on the last *logged* day, not the last row on disk: `fillJourney`
    /// has already written assumed rows through yesterday by the time Home can
    /// offer "Still sober", so anchoring on any row made the action cover today
    /// alone while the week strip and calendar kept showing the span it claimed
    /// to confirm as untended. Days already in the span are promoted rather than
    /// skipped, since the user has now spoken for them.
    ///
    /// A logged slip inside the span is left exactly as it is: confirming a
    /// stretch of days never overwrites something the user told the app happened.
    func backfillSoberDays(through end: Date = .now) {
        let today = DateHelpers.startOfDay(end)
        let cal = Calendar.current
        let from: Date = {
            if let last = lastLoggedCheckInDate() {
                return cal.date(byAdding: .day, value: 1, to: DateHelpers.startOfDay(last)) ?? today
            }
            return today
        }()
        guard from <= today else { return }

        // One fetch for the whole span rather than one per day: a user back
        // after a long absence would otherwise pay a fetch per missed day on
        // the main actor, in the tap handler.
        let existing = Dictionary(
            fetch(from: from, to: today).map { ($0.day, $0) },
            uniquingKeysWith: { a, _ in a }
        )
        var cursor = from
        while cursor <= today {
            if let row = existing[cursor] {
                // The user answered "still sober" for this whole span, so an
                // assumed day inside it is now tended.
                if row.wasSober { row.wasLogged = true }
            } else {
                context.insert(DailyCheckIn(day: cursor, wasSober: true, wasLogged: true))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        try? context.save()
    }

    /// One-time upgrade repair for rows written before `wasLogged` existed.
    ///
    /// The field shipped with a default of `false` so the SwiftData migration
    /// could stay lightweight, which meant an upgrading user's entire tended
    /// history came back reading as days the app had assumed: Home offered a
    /// second check-in for a day already logged, and the calendar faded a real
    /// record. Every pre-upgrade row came from a real tap or from a backfill
    /// that older builds treated as a check-in, so "tended" is the meaning
    /// those rows were written with.
    ///
    /// Must run before this build's first `fillJourney`, or the assumed rows
    /// that call creates would be swept up with the legacy ones. `SoberApp.init`
    /// is that point.
    static func migrateLegacyCheckInsIfNeeded(context: ModelContext) {
        let defaults = AppGroup.defaults
        guard !defaults.bool(forKey: AppGroup.legacyCheckInsMarkedLoggedKey) else { return }
        defaults.set(true, forKey: AppGroup.legacyCheckInsMarkedLoggedKey)

        let descriptor = FetchDescriptor<DailyCheckIn>(predicate: #Predicate { !$0.wasLogged })
        guard let legacy = try? context.fetch(descriptor), !legacy.isEmpty else { return }
        for row in legacy { row.wasLogged = true }
        try? context.save()
    }

    /// Every sober day on record, across all journeys. This is the number
    /// that makes a slip survivable: the streak restarts, this does not.
    ///
    /// Deliberately counts assumed days alongside tended ones - a day the user
    /// stayed sober through without opening the app still happened, and
    /// dropping it would shrink the money and calorie totals underneath. The
    /// copy that presents this number says "counted", never "logged", because
    /// `wasLogged` is the only thing that can claim the tap.
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

    /// The most recent day the user logged as a slip, if any. `SlipRecorder`
    /// needs it so a slip entered out of order can't restart the counter from a
    /// date that a later slip has already superseded.
    func lastSlipDate() -> Date? {
        var descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.wasLogged && !$0.wasSober },
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        descriptor.fetchLimit = 1
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
