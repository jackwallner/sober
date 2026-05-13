import Foundation
import SwiftData

@Model
final class GardenState {
    var id: UUID
    var vitality: Double             // 0..1
    var lastWateredAt: Date?
    var unlockedSpeciesIDs: [String]
    var activeSpeciesID: String

    init(
        id: UUID = UUID(),
        vitality: Double = 1.0,
        lastWateredAt: Date? = nil,
        unlockedSpeciesIDs: [String] = ["oak"],
        activeSpeciesID: String = "oak"
    ) {
        self.id = id
        self.vitality = vitality
        self.lastWateredAt = lastWateredAt
        self.unlockedSpeciesIDs = unlockedSpeciesIDs
        self.activeSpeciesID = activeSpeciesID
    }
}
