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
        let current = activeJourney()
        current?.endDate = .now
        let new = SobrietyJourney(startDate: startDate, goalDate: Self.carriedGoal(from: current))
        context.insert(new)
        context.saveOrReport()
        return new
    }

    /// Move the active journey's start to a new timestamp (e.g. the user
    /// correcting their start date/time). Clamped to not run into the future,
    /// and not back past a logged slip (`earliestStartDate`). Runs must not
    /// overlap, so a closed run the new start reaches into is trimmed to it.
    ///
    /// Moving the start later drops the days the app assumed sober for the
    /// old range. Kept, they went on counting in lifetime days, money and
    /// calories ("Day 5" over "100 days sober"), and they sit before the first
    /// run, where Timeline can't select them. Days the user tapped, or gave a
    /// mood or note, stay.
    func updateStartDate(_ date: Date) {
        guard let journey = activeJourney() else { return }
        let oldStart = DateHelpers.startOfDay(journey.startDate)
        var newStart = min(date, .now)
        if let earliest = earliestStartDate() { newStart = max(newStart, earliest) }
        journey.startDate = newStart
        trimClosedJourneys(after: newStart, keeping: journey)
        let newStartDay = DateHelpers.startOfDay(newStart)
        if newStartDay > oldStart {
            let descriptor = FetchDescriptor<DailyCheckIn>(
                predicate: #Predicate {
                    $0.day >= oldStart && $0.day < newStartDay && !$0.wasLogged && $0.wasSober
                }
            )
            for row in (try? context.fetch(descriptor)) ?? [] where row.mood == nil && row.note == nil {
                context.delete(row)
            }
        }
        context.saveOrReport()
    }

    /// The earliest start the active run can be moved back to: the day after
    /// the latest logged slip. Nil when no slip came before. Never later than
    /// the current start, so the picker can always show it, and never later
    /// than `now`: a zone change west can re-key the start past the present,
    /// and Settings builds `earliest...now`, which traps if reversed.
    ///
    /// Only slips set the floor. A Reset (or the closed run older onboarding
    /// builds left behind) is not a day the user drank, and it has no undo, so
    /// moving the start back past it is how a Reset gets corrected. Such a run
    /// is trimmed instead (`trimClosedJourneys`).
    func earliestStartDate(now: Date = .now) -> Date? {
        guard let active = activeJourney() else { return nil }
        let journeys = (try? context.fetch(FetchDescriptor<SobrietyJourney>())) ?? []
        var bounds: [Date] = journeys.compactMap { j in
            guard j !== active, let end = j.endDate, j.resetReason == Self.slipReason else { return nil }
            return Self.dayAfter(end)
        }
        if let lastSlip = CheckInService(context: context).lastSlipDate() {
            bounds.append(Self.dayAfter(lastSlip))
        }
        guard let bound = bounds.max() else { return nil }
        return min(bound, active.startDate, now)
    }

    /// End every closed run still going at `start` there, so a start moved
    /// back past a Reset leaves no overlapping runs. A run that began after
    /// `start` is kept, ending where it began.
    private func trimClosedJourneys(after start: Date, keeping active: SobrietyJourney) {
        let journeys = (try? context.fetch(FetchDescriptor<SobrietyJourney>())) ?? []
        for j in journeys where j !== active {
            guard let end = j.endDate, end > start else { continue }
            j.endDate = max(j.startDate, start)
        }
    }

    private static func dayAfter(_ date: Date) -> Date {
        let day = DateHelpers.startOfDay(date)
        return Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
    }

    /// Set or clear the goal on the active journey. Stored as a start of day so
    /// "29 days to go" never flips at an odd hour.
    func setGoal(_ date: Date?) {
        guard let journey = activeJourney() else { return }
        journey.goalDate = date.map { DateHelpers.startOfDay($0) }
        context.saveOrReport()
    }

    /// A slip or a restart keeps a goal that is still ahead: the date the user
    /// is working toward did not move because the counter did. A goal already
    /// behind them is done, so it is not carried into the next run.
    nonisolated static func carriedGoal(from journey: SobrietyJourney?, now: Date = .now) -> Date? {
        guard let goal = journey?.goalDate, goal > DateHelpers.startOfDay(now) else { return nil }
        return goal
    }

    func reset(reason: String? = nil) {
        let current = activeJourney()
        current?.endDate = .now
        current?.resetReason = reason
        let new = SobrietyJourney(startDate: .now, goalDate: Self.carriedGoal(from: current))
        context.insert(new)
        context.saveOrReport()
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
        reason: String? = SobrietyService.slipReason
    ) -> SobrietyJourney {
        let current = activeJourney()
        if let current {
            // A run can't end before it began, or in the future.
            current.endDate = max(current.startDate, min(end, .now))
            current.resetReason = reason
        }
        let new = SobrietyJourney(startDate: min(start, .now), goalDate: Self.carriedGoal(from: current))
        context.insert(new)
        context.saveOrReport()
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
        // A goal set or cleared after the slip lived on the run being deleted.
        // Left alone, the reopened run quietly brought back the old one.
        if active.goalDate != Self.carriedGoal(from: closed) {
            closed.goalDate = active.goalDate
        }
        context.delete(active)
        closed.endDate = nil
        closed.resetReason = nil
        context.saveOrReport()
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
    ///
    /// The closed run must also be the one directly before the active run, and
    /// closed by a slip. Matching any run that ended on `day` let a slip
    /// yesterday be undone straight through a slip today, or through an older
    /// slip entered later, reopening a run that overlaps the ones after it.
    ///
    /// Only a run between the slip and the active run can block it: one that
    /// began at or after the slip's run ended and ended by the active run's
    /// start. A later slip and a Reset after the slip are such runs. Two kinds
    /// of closed run sit beside the slip's run without coming after it: the
    /// run older onboarding builds left behind, which starts anywhere inside
    /// the user's run when setup was redone on a later launch and ends
    /// wherever setup ran, and a Reset or leftover run the user moved the
    /// start back past, which `trimClosedJourneys` leaves empty on its own
    /// start. Taken as "the run before", either one refused the undo of the
    /// slip that really closed the run before the active one.
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

    // SCRATCH: shim so the new tests and TimelineView compile.
    static func effectiveEnd(of run: SobrietyJourney, among runs: [SobrietyJourney]) -> Date? { run.endDate }

    static let slipReason = "slip"

    /// Stop the closed run that a back-dated slip on `day` falls inside, and
    /// keep the rest of that run as its own closed run after the slip.
    ///
    /// Without this an older slip entered after a newer one left the run it
    /// fell in spanning it, so the longest streak counted straight through a
    /// day the user had just logged as a slip, right after the alert promised
    /// it "reflects the corrected dates". Returns the run made for the days
    /// after the slip, or nil when no closed run spans `day`.
    @discardableResult
    func splitClosedJourney(at day: Date) -> SobrietyJourney? {
        let slipDay = DateHelpers.startOfDay(day)
        guard let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: slipDay) else { return nil }
        let journeys = (try? context.fetch(FetchDescriptor<SobrietyJourney>())) ?? []
        let spanning = journeys.filter { j in
            guard let end = j.endDate else { return false }
            return DateHelpers.startOfDay(j.startDate) <= slipDay
                && dayAfter <= DateHelpers.startOfDay(end)
        }
        // The run older onboarding builds left behind can span the day too.
        // Taking whichever the fetch returned first could split it and leave
        // the user's run counting straight through this slip. Theirs is the
        // one a slip closed, else the one that ended last: the leftover ended
        // when setup ran, before any Reset.
        let covering = spanning.first { $0.resetReason == Self.slipReason }
            ?? spanning.max { ($0.endDate ?? .distantPast) < ($1.endDate ?? .distantPast) }
        guard let covering, let oldEnd = covering.endDate else { return nil }
        let rest = SobrietyJourney(
            startDate: dayAfter,
            endDate: oldEnd,
            resetReason: covering.resetReason,
            goalDate: covering.goalDate
        )
        covering.endDate = max(covering.startDate, slipDay)
        covering.resetReason = Self.slipReason
        context.insert(rest)
        context.saveOrReport()
        return rest
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
