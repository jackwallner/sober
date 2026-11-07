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
    /// What the garden was just before the slip that started this run, so
    /// undoing that slip restores it exactly (`GardenSlipRecord`). Each run
    /// holds its own, so undoing two slips in turn walks back through both.
    /// Optional with a default, a lightweight migration: runs written before
    /// it was added read as `.legacy`.
    var gardenBeforeSlip: Data? = nil

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
