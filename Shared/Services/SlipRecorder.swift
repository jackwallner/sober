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
        let previousStreak = sobriety.currentDayCount()

        CheckInService(context: context).checkIn(for: day, wasSober: false, mood: mood, note: note)

        let dayAfter = Calendar.current.date(
            byAdding: .day, value: 1, to: DateHelpers.startOfDay(day)
        ) ?? day
        sobriety.resetJourney(startingAt: dayAfter)

        let carryover = GardenService(context: context).recordSlip(previousStreakDays: previousStreak)
        WidgetSnapshotPump.push(context: context)

        return Outcome(previousStreakDays: previousStreak, carryoverDays: carryover)
    }
}
