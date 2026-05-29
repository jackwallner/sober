import Foundation
import SwiftData

@MainActor
final class CheckInService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func checkIn(for date: Date = .now, wasSober: Bool = true, mood: Int? = nil, note: String? = nil) {
        let day = DateHelpers.startOfDay(date)
        if let existing = find(day: day) {
            existing.wasSober = wasSober
            existing.mood = mood ?? existing.mood
            existing.note = note ?? existing.note
        } else {
            let entry = DailyCheckIn(day: day, wasSober: wasSober, mood: mood, note: note)
            context.insert(entry)
        }
        try? context.save()
    }

    func hasCheckedIn(on date: Date = .now) -> Bool {
        find(day: DateHelpers.startOfDay(date)) != nil
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
                context.insert(DailyCheckIn(day: cursor, wasSober: true))
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
                context.insert(DailyCheckIn(day: cursor, wasSober: true))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        try? context.save()
    }

    /// Number of full days since the last check-in. Returns 0 if checked in today
    /// or if there has never been a check-in.
    func daysSinceLastCheckIn(asOf now: Date = .now) -> Int {
        guard let last = lastCheckInDate() else { return 0 }
        return max(0, DateHelpers.daysBetween(last, now))
    }

    func lastCheckInDate() -> Date? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        return try? context.fetch(descriptor).first?.day
    }

    private func find(day: Date) -> DailyCheckIn? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.day == day }
        )
        return try? context.fetch(descriptor).first
    }
}
