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

    private func find(day: Date) -> DailyCheckIn? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.day == day }
        )
        return try? context.fetch(descriptor).first
    }
}
