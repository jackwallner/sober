import Foundation
import SwiftData

@Model
final class SobrietyJourney {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var resetReason: String?
    /// The day the user is counting toward, stored as a start of day. Optional
    /// with a default, so adding it is a lightweight migration: rows written by
    /// 1.3.2 and earlier open with no goal rather than failing to load.
    var goalDate: Date? = nil

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        resetReason: String? = nil,
        goalDate: Date? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.resetReason = resetReason
        self.goalDate = goalDate
    }

    var isActive: Bool { endDate == nil }
}
