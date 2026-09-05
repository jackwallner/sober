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

    /// End the active journey and begin a new one at `start` (clamped to now).
    /// Used when a slip resets the counter: a past-dated slip starts the fresh
    /// journey the day after the slip, so the recovered streak is counted.
    ///
    /// `endingPreviousOn` is the day the run that just ended actually stopped,
    /// which for a back-dated slip is not today. Closing it at `.now` instead
    /// left the old journey covering the same dates as the fresh one, and
    /// `longestStreakDays()` measured the old run straight through the slip it
    /// was supposed to stop at: entering a slip from ten days ago *raised* the
    /// user's best streak. Journeys must not overlap.
    @discardableResult
    func resetJourney(
        startingAt start: Date,
        endingPreviousOn end: Date = .now,
        reason: String? = "slip"
    ) -> SobrietyJourney {
        if let current = activeJourney() {
            // A run can't end before it began, or in the future.
            current.endDate = max(current.startDate, min(end, .now))
            current.resetReason = reason
        }
        let new = SobrietyJourney(startDate: min(start, .now))
        context.insert(new)
        try? context.save()
        return new
    }

    /// Reverse the split a slip on `day` made: delete the run the slip started
    /// and reopen the one it closed. Returns the restored current day count, or
    /// nil when no such split is on record.
    ///
    /// Nil is the important half. Timeline offered "Change to sober" on a slip
    /// long before anything could reverse one, so the row went green while Home
    /// kept the counter the slip had reset. A caller that can't move the counter
    /// must not present the correction as done.
    ///
    /// Only the most recent slip is reversible: the run it started is the active
    /// one, so reopening is a local edit to two rows. Undoing an older slip would
    /// mean re-deriving every run after it, which is a rewrite of the user's
    /// history rather than an undo.
    @discardableResult
    func reopenJourney(endedOn day: Date) -> Int? {
        guard let (closed, active) = reversibleSplit(endedOn: day) else { return nil }
        context.delete(active)
        closed.endDate = nil
        closed.resetReason = nil
        try? context.save()
        return SobrietyService.daysSinceStart(closed.startDate)
    }

    /// Whether `reopenJourney(endedOn:)` would find something to reverse, so a
    /// view can decide whether to offer the correction at all.
    func canReopenJourney(endedOn day: Date) -> Bool {
        reversibleSplit(endedOn: day) != nil
    }

    /// The (run the slip closed, run the slip started) pair, when the slip on
    /// `day` is the one the live counter is sitting on.
    ///
    /// The adjacency check is what keeps this an undo. Matching on the end date
    /// alone would happily "reverse" a slip from three slips ago: it would
    /// reopen a run that a later slip has already closed and delete the current
    /// one, leaving overlapping runs and a counter reading past slips the user
    /// never took back. A back-dated slip starts the fresh run the next day; one
    /// logged today starts it the same day, because the start clamps to now.
    private func reversibleSplit(endedOn day: Date) -> (closed: SobrietyJourney, active: SobrietyJourney)? {
        guard let active = activeJourney() else { return nil }
        let target = DateHelpers.startOfDay(day)
        let activeStart = DateHelpers.startOfDay(active.startDate)
        let gap = DateHelpers.daysBetween(target, activeStart)
        guard gap == 0 || gap == 1 else { return nil }

        let descriptor = FetchDescriptor<SobrietyJourney>()
        let journeys = (try? context.fetch(descriptor)) ?? []
        let closed = journeys
            .filter { j in
                guard let end = j.endDate, j !== active else { return false }
                return DateHelpers.startOfDay(end) == target
            }
            .max(by: { $0.startDate < $1.startDate })
        guard let closed else { return nil }
        return (closed, active)
    }

    /// Whole days since the active journey's start. Returns 0 if none.
    func currentDayCount(asOf date: Date = .now) -> Int {
        guard let journey = activeJourney() else { return 0 }
        return SobrietyService.daysSinceStart(journey.startDate, asOf: date)
    }

    /// Whole days accrued as of `date` by whichever journey covered that date.
    ///
    /// Unlike `currentDayCount(asOf:)` this keeps answering correctly once a
    /// later reset has ended the journey in question, which is what a
    /// back-dated slip needs: the streak that was running on the day of the
    /// event, not the one running when the user got around to entering it.
    /// Journeys are scanned oldest-first so a date sitting on the boundary
    /// between a journey that ended and the one that replaced it resolves to
    /// the run that was actually going on that day.
    func dayCount(asOf date: Date) -> Int {
        let day = DateHelpers.startOfDay(date)
        let descriptor = FetchDescriptor<SobrietyJourney>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        let journeys = (try? context.fetch(descriptor)) ?? []
        let covering = journeys.first { j in
            guard day >= DateHelpers.startOfDay(j.startDate) else { return false }
            guard let end = j.endDate else { return true }
            return day <= DateHelpers.startOfDay(end)
        }
        guard let journey = covering else { return 0 }
        return SobrietyService.daysSinceStart(journey.startDate, asOf: date)
    }

    /// Hours since the active journey's start.
    func currentHours(asOf date: Date = .now) -> Double {
        guard let journey = activeJourney() else { return 0 }
        return max(0, DateHelpers.hoursBetween(journey.startDate, date))
    }

    /// 1-based: the start day itself is "Day 1" (matches how every other
    /// sobriety counter reads, and keeps the streak counter aligned with the
    /// count of sober check-ins, which also includes the start day). Callers
    /// distinguish "no journey" via the guards above, which return 0.
    nonisolated static func daysSinceStart(_ start: Date, asOf date: Date = .now) -> Int {
        max(0, DateHelpers.daysBetween(start, date)) + 1
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
