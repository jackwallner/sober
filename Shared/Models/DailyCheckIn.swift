import Foundation
import SwiftData

@Model
final class DailyCheckIn {
    @Attribute(.unique) var day: Date  // start-of-day
    var wasSober: Bool
    var mood: Int?       // 1..5 optional
    var note: String?

    init(day: Date, wasSober: Bool = true, mood: Int? = nil, note: String? = nil) {
        self.day = DateHelpers.startOfDay(day)
        self.wasSober = wasSober
        self.mood = mood
        self.note = note
    }
}
