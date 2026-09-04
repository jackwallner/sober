import Foundation
import SwiftData

@Model
final class DailyCheckIn {
    @Attribute(.unique) var day: Date  // start-of-day
    var wasSober: Bool
    var mood: Int?       // 1..5 optional
    var note: String?
    /// True when the user actually tapped for this day, false when the app
    /// filled it in on their behalf.
    ///
    /// Without this the two are indistinguishable, and because `fillJourney`
    /// backfills every past day, "when did you last check in?" could never
    /// answer anything but "yesterday". Defaults to false so the SwiftData
    /// migration is lightweight; callers that represent a real tap pass true.
    var wasLogged: Bool = false

    init(
        day: Date,
        wasSober: Bool = true,
        mood: Int? = nil,
        note: String? = nil,
        wasLogged: Bool = false
    ) {
        self.day = DateHelpers.startOfDay(day)
        self.wasSober = wasSober
        self.mood = mood
        self.note = note
        self.wasLogged = wasLogged
    }
}
