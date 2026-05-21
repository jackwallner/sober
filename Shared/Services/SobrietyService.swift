import Foundation
import SwiftData

@MainActor
final class SobrietyService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func activeJourney() -> SobrietyJourney? {
        let descriptor = FetchDescriptor<SobrietyJourney>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func startJourney(at startDate: Date = .now) -> SobrietyJourney {
        // End any open journey first
        if let current = activeJourney() {
            current.endDate = .now
        }
        let new = SobrietyJourney(startDate: startDate)
        context.insert(new)
        try? context.save()
        return new
    }

    /// Move the active journey's start to a new timestamp (e.g. the user
    /// correcting their start date/time). Clamped to not run into the future.
    func updateStartDate(_ date: Date) {
        guard let journey = activeJourney() else { return }
        journey.startDate = min(date, .now)
        try? context.save()
    }

    func reset(reason: String? = nil) {
        if let current = activeJourney() {
            current.endDate = .now
            current.resetReason = reason
        }
        let new = SobrietyJourney(startDate: .now)
        context.insert(new)
        try? context.save()
    }

    /// Whole days since the active journey's start. Returns 0 if none.
    func currentDayCount(asOf date: Date = .now) -> Int {
        guard let journey = activeJourney() else { return 0 }
        return SobrietyService.daysSinceStart(journey.startDate, asOf: date)
    }

    /// Hours since the active journey's start.
    func currentHours(asOf date: Date = .now) -> Double {
        guard let journey = activeJourney() else { return 0 }
        return max(0, DateHelpers.hoursBetween(journey.startDate, date))
    }

    nonisolated static func daysSinceStart(_ start: Date, asOf date: Date = .now) -> Int {
        max(0, DateHelpers.daysBetween(start, date))
    }

    /// Best (longest) streak across all journeys recorded so far, in days.
    func longestStreakDays() -> Int {
        let descriptor = FetchDescriptor<SobrietyJourney>()
        let journeys = (try? context.fetch(descriptor)) ?? []
        let now = Date.now
        return journeys.map { j -> Int in
            let end = j.endDate ?? now
            return SobrietyService.daysSinceStart(j.startDate, asOf: end)
        }.max() ?? 0
    }
}
