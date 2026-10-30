import Foundation
import SwiftData

@MainActor
final class CheckInService {
    private let context: ModelContext
    private let dayKeyDefaults: UserDefaults

    init(context: ModelContext, dayKeyDefaults: UserDefaults = AppGroup.defaults) {
        self.context = context
        self.dayKeyDefaults = dayKeyDefaults
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
        Self.normalizeDayKeys(context: context, defaults: dayKeyDefaults)
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
        context.saveOrReport()
    }

    /// The mood and note saved for a day, so the note sheet opens on what is
    /// already there instead of an empty field that would replace it.
    func detail(on date: Date = .now) -> (mood: Int?, note: String?) {
        guard let entry = find(day: DateHelpers.startOfDay(date)) else { return (nil, nil) }
        return (entry.mood, entry.note)
    }

    /// Save the note sheet's edit exactly as written: a cleared note clears,
    /// and the day's sober or slip answer is left alone. `checkIn` keeps a
    /// nil note and marks the day sober, which is right for a tap and wrong
    /// for an edit.
    func saveDetail(on date: Date = .now, mood: Int?, note: String?) {
        let day = DateHelpers.startOfDay(date)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (trimmed?.isEmpty ?? true) ? nil : trimmed
        if let existing = find(day: day) {
            existing.mood = mood
            existing.note = text
            existing.wasLogged = true
        } else {
            guard mood != nil || text != nil else { return }
            context.insert(DailyCheckIn(day: day, wasSober: true, mood: mood, note: text, wasLogged: true))
        }
        context.saveOrReport()
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
        // Rows keyed in another zone would read as missing days and be filled
        // a second time, so they move onto this zone's midnights first.
        Self.normalizeDayKeys(context: context, defaults: dayKeyDefaults)
        let cal = Calendar.current
        let first = DateHelpers.startOfDay(start)
        let last = DateHelpers.startOfDay(end)
        guard first <= last else { return }

        // Keyed by start of day, the same key `DailyCheckIn.init` writes, so
        // an insert can never land on an occupied day and replace it.
        let existing = Set(fetch(from: first, to: last).map { cal.startOfDay(for: $0.day) })
        var didInsert = false
        for day in Self.calendarDays(from: first, through: last, calendar: cal) where !existing.contains(day) {
            // Assumed, not tended: the user never said anything about
            // these days, the calendar just needs to agree with the
            // counter.
            context.insert(DailyCheckIn(day: day, wasSober: true, wasLogged: false))
            didInsert = true
        }
        if didInsert { context.saveOrReport() }
    }

    /// The start of every calendar day from `first` through `last`.
    ///
    /// Each day is found from its own noon. Adding a day to a start of day
    /// broke where clocks skip midnight for daylight saving (Chile, Cuba,
    /// Egypt, Lebanon, the Azores): that day starts at 01:00, the walk stayed
    /// on 01:00 for good, missed every stored midnight, and its inserts
    /// replaced the days the user had logged.
    nonisolated static func calendarDays(from first: Date, through last: Date, calendar cal: Calendar) -> [Date] {
        let start = cal.startOfDay(for: first)
        let end = cal.startOfDay(for: last)
        guard start <= end,
              let anchor = cal.date(byAdding: .hour, value: 12, to: start) else { return [] }
        var days: [Date] = []
        var offset = 0
        while let noon = cal.date(byAdding: .day, value: offset, to: anchor) {
            let day = cal.startOfDay(for: noon)
            guard day <= end else { break }
            days.append(day)
            offset += 1
        }
        return days
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
        Self.normalizeDayKeys(context: context, defaults: dayKeyDefaults)
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
            fetch(from: from, to: today).map { (cal.startOfDay(for: $0.day), $0) },
            uniquingKeysWith: { a, _ in a }
        )
        for day in Self.calendarDays(from: from, through: today, calendar: cal) {
            if let row = existing[day] {
                // The user answered "still sober" for this whole span, so an
                // assumed day inside it is now tended.
                if row.wasSober { row.wasLogged = true }
            } else {
                context.insert(DailyCheckIn(day: day, wasSober: true, wasLogged: true))
            }
        }
        context.saveOrReport()
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
        context.saveOrReport()
    }

    // MARK: - Day keys across time zones

    /// Re-key every row onto the current zone's midnights when the zone has
    /// changed since the rows were written, merging rows that turn out to be
    /// the same calendar day.
    ///
    /// `day` stores the instant of local midnight, and the same calendar day
    /// has a different midnight in every zone. After a trip, `fillJourney`
    /// found none of the old rows at this zone's midnights and wrote every
    /// day again, doubling lifetime days and money kept, and `find(day:)`
    /// lost today's check-in. Keeping one zone's midnights on disk lets every
    /// reader go on comparing instants.
    ///
    /// The zone the rows are keyed in is remembered, which makes the move
    /// exact. Rows that are not on its midnights (duplicates written by builds
    /// before this repair, which recorded no zone) have their calendar day
    /// recovered from the instant itself: a midnight pins its zone's offset to
    /// within a whole day, and only one candidate falls inside the range of
    /// real offsets except at the date line. Nothing the user wrote is
    /// dropped: a tap, a slip, a mood and every note survive a merge.
    static func normalizeDayKeys(
        context: ModelContext,
        zone: TimeZone = .current,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        let keyedZone = defaults.string(forKey: AppGroup.checkInDayKeyZoneKey)
            .flatMap(TimeZone.init(identifier:))
        if keyedZone?.identifier == zone.identifier { return }

        guard let rows = try? context.fetch(FetchDescriptor<DailyCheckIn>()) else { return }
        var groups: [Date: [DailyCheckIn]] = [:]
        for row in rows {
            let target = startOfCalendarDay(containing: row.day, keyedIn: keyedZone, in: zone)
            groups[target, default: []].append(row)
        }

        var changed = false
        for (target, members) in groups {
            let survivor = members.first { $0.day == target }
                ?? members.first { $0.wasLogged }
                ?? members[0]
            if members.count > 1 {
                merge(members, into: survivor)
                for row in members where row !== survivor { context.delete(row) }
                changed = true
            }
            if survivor.day != target {
                survivor.day = target
                changed = true
            }
        }
        if changed {
            do {
                try context.save()
            } catch {
                // Left unmarked, so the next launch tries again.
                context.rollback()
                return
            }
        }
        defaults.set(zone.identifier, forKey: AppGroup.checkInDayKeyZoneKey)
    }

    /// This zone's start of the calendar day a stored row stands for.
    nonisolated static func startOfCalendarDay(
        containing stored: Date,
        keyedIn keyedZone: TimeZone?,
        in zone: TimeZone
    ) -> Date {
        let comps = calendarDay(of: stored, keyedIn: keyedZone, reference: zone)
        var target = Calendar(identifier: .gregorian)
        target.timeZone = zone
        // Noon, then back to the day's start: a zone whose clocks skip
        // midnight for daylight saving still has a start of day.
        var noon = comps
        noon.hour = 12
        guard let midday = target.date(from: noon) else { return stored }
        return target.startOfDay(for: midday)
    }

    nonisolated private static func calendarDay(
        of stored: Date,
        keyedIn keyedZone: TimeZone?,
        reference zone: TimeZone
    ) -> DateComponents {
        if let keyedZone {
            var keyed = Calendar(identifier: .gregorian)
            keyed.timeZone = keyedZone
            if keyed.startOfDay(for: stored) == stored {
                return keyed.dateComponents([.year, .month, .day], from: stored)
            }
        }
        // `stored` is the start of a day somewhere, so that zone's offset is
        // -stored modulo a day (an hour off where midnight was skipped, which
        // still lands inside the same date). Real offsets run -12h to +14h.
        let day = 86_400
        let seconds = Int(stored.timeIntervalSince1970.rounded())
        let remainder = ((-seconds % day) + day) % day
        let preferred = (keyedZone ?? zone).secondsFromGMT(for: stored)
        let offset = [remainder, remainder - day]
            .filter { $0 >= -12 * 3600 && $0 <= 14 * 3600 }
            .min { abs($0 - preferred) < abs($1 - preferred) } ?? preferred
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? zone
        return utc.dateComponents(
            [.year, .month, .day],
            from: stored.addingTimeInterval(TimeInterval(offset))
        )
    }

    /// Fold duplicates of one calendar day into `survivor`. A tap on any copy
    /// makes the day tended, a logged slip outranks an assumed sober day, and
    /// distinct notes are kept side by side rather than one winning.
    private static func merge(_ rows: [DailyCheckIn], into survivor: DailyCheckIn) {
        let logged = rows.filter(\.wasLogged)
        let decisive = logged.isEmpty ? rows : logged
        let ordered = [survivor] + rows.filter { $0 !== survivor }
        let preferred = ordered.filter(\.wasLogged) + ordered.filter { !$0.wasLogged }
        var notes: [String] = []
        for note in preferred.compactMap(\.note) where !note.isEmpty && !notes.contains(note) {
            notes.append(note)
        }
        survivor.wasLogged = !logged.isEmpty
        survivor.wasSober = decisive.allSatisfy(\.wasSober)
        survivor.mood = preferred.compactMap(\.mood).first
        survivor.note = notes.isEmpty ? nil : notes.joined(separator: "\n\n")
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
