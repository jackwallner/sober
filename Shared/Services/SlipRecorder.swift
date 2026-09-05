import Foundation
import SwiftData

/// The one path a slip takes through the app.
///
/// Home and Timeline both used to hand-roll this sequence, which is how they
/// ended up disagreeing about what a slip does to the garden. Everything that
/// records a slip goes through here so the promise the UI makes ("your tree
/// keeps most of its growth, your history is kept") is enforced in one place.
@MainActor
enum SlipRecorder {
    struct Outcome {
        /// The streak the user was on when they slipped, so the UI can name it.
        let previousStreakDays: Int
        /// Days of growth the new tree inherited.
        let carryoverDays: Int
    }

    /// The streak the user was on at the end of `day`, which for a back-dated
    /// slip is not the streak they are on now.
    ///
    /// Reading the live counter meant a slip entered from ten days ago was
    /// scored against today's run: the confirmation named a streak that had
    /// not happened yet on the date being logged, and the garden inherited
    /// growth from days that came after the event. The as-of count keeps the
    /// result tied to when the slip happened rather than to when it was typed in.
    static func streakDays(endingOn day: Date, context: ModelContext) -> Int {
        max(0, SobrietyService(context: context).dayCount(asOf: day))
    }

    /// Log a slip on `day`, restart the counter the day after, and let the
    /// garden bank half the tree.
    ///
    /// A past-dated slip starts the fresh journey the following day so the
    /// days since then are counted rather than thrown away. `SobrietyService`
    /// clamps a future start back to now, so a slip logged today yields day 1.
    @discardableResult
    static func record(
        on day: Date,
        mood: Int? = nil,
        note: String? = nil,
        context: ModelContext
    ) -> Outcome {
        let sobriety = SobrietyService(context: context)
        let checkIns = CheckInService(context: context)
        let garden = GardenService(context: context)

        // Re-submitting a slip for a day that already has one is an edit, not a
        // second event. The counter reset is idempotent, but the garden's 50%
        // rule is not: applying it again halved the inherited growth a second
        // time, so a double tap quietly shrank the tree the flow had just
        // promised would keep it.
        if checkIns.loggedSlip(on: day) {
            checkIns.checkIn(for: day, wasSober: false, mood: mood, note: note)
            WidgetSnapshotPump.push(context: context)
            return Outcome(
                previousStreakDays: streakDays(endingOn: day, context: context),
                carryoverDays: garden.current().carryoverDays
            )
        }

        let previousStreak = streakDays(endingOn: day, context: context)

        checkIns.checkIn(for: day, wasSober: false, mood: mood, note: note)

        // The fresh run begins the day after the *latest* slip on record, not
        // necessarily the day after this one. Entering an older slip after a
        // newer one would otherwise wind the counter forward past a slip that
        // has already happened.
        let latestSlip = checkIns.lastSlipDate() ?? day
        let restartFrom = max(DateHelpers.startOfDay(day), DateHelpers.startOfDay(latestSlip))
        let dayAfter = Calendar.current.date(
            byAdding: .day, value: 1, to: restartFrom
        ) ?? day
        // An out-of-order slip leaves the current run beginning exactly where it
        // already began, so closing it and opening an identical one would only
        // litter the record with a zero-length stub.
        let alreadyRestarted = sobriety.activeJourney().map {
            DateHelpers.startOfDay($0.startDate) >= DateHelpers.startOfDay(dayAfter)
        } ?? false
        if !alreadyRestarted {
            // The run that just ended stopped on the slip day, not today: closing
            // it at `.now` left it overlapping the fresh run whenever the slip
            // was back-dated, so a slip from ten days ago *raised* the longest
            // streak.
            sobriety.resetJourney(startingAt: dayAfter, endingPreviousOn: day)
        }

        let carryover = garden.recordSlip(previousStreakDays: previousStreak)
        WidgetSnapshotPump.push(context: context)

        return Outcome(previousStreakDays: previousStreak, carryoverDays: carryover)
    }

    /// Whether a slip on `day` can still be taken back in full: the check-in
    /// flipped, the run it ended reopened, and the garden's growth returned.
    ///
    /// Views ask before offering the correction. Timeline used to offer
    /// "Change to sober" unconditionally while only rewriting the calendar row,
    /// so the day went green next to a counter still sitting at the reset the
    /// slip caused. An affordance that can't finish the job shouldn't be there.
    static func canUndo(on day: Date, context: ModelContext) -> Bool {
        CheckInService(context: context).loggedSlip(on: day)
            && SobrietyService(context: context).canReopenJourney(endedOn: day)
    }

    /// Take back a slip on `day`, reversing every part of `record`.
    ///
    /// Returns false and changes nothing when the slip can't be fully reversed,
    /// so a caller never shows a half-applied correction. Mis-tapping "I
    /// slipped" is one of the worst things this app can let happen to someone,
    /// and until now it was permanent.
    @discardableResult
    static func undo(on day: Date, mood: Int? = nil, note: String? = nil, context: ModelContext) -> Bool {
        let checkIns = CheckInService(context: context)
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)

        guard checkIns.loggedSlip(on: day) else { return false }
        // Reopen first: if the counter can't be put back, the calendar row must
        // stay as it is rather than disagree with it.
        guard let restoredStreak = sobriety.reopenJourney(endedOn: day) else { return false }

        checkIns.checkIn(for: day, wasSober: true, mood: mood, note: note)
        garden.undoSlip(restoredStreakDays: restoredStreak)
        WidgetSnapshotPump.push(context: context)
        return true
    }
}
