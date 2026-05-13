import Foundation
import SwiftData

@Model
final class SobrietyJourney {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var resetReason: String?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        resetReason: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.resetReason = resetReason
    }

    var isActive: Bool { endDate == nil }
}
