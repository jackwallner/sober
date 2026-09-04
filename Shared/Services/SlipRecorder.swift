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

        let dayAfter = Calendar.current.date(
            byAdding: .day, value: 1, to: DateHelpers.startOfDay(day)
        ) ?? day
        sobriety.resetJourney(startingAt: dayAfter)

        let carryover = garden.recordSlip(previousStreakDays: previousStreak)
        WidgetSnapshotPump.push(context: context)

        return Outcome(previousStreakDays: previousStreak, carryoverDays: carryover)
    }
}
