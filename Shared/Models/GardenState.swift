import Foundation
import SwiftData

@Model
final class GardenState {
    var id: UUID
    var vitality: Double                    // 0..1, decays daily, water to restore
    var lastWateredAt: Date?
    var unlockedItemIDs: [String]           // items earned through milestone days
    var placedItemIDs: [String]             // items currently displayed (Pro-gated slots)
    var activeBonsaiStyleID: String         // "traditional", "cascade", "windswept"
    var gardenThemeID: String               // "zen", "forest", "seasonal"
    var lastUnlockNotifiedAtDays: Int       // last day-count milestone we showed a celebration for

    init(
        id: UUID = UUID(),
        vitality: Double = 1.0,
        lastWateredAt: Date? = nil,
        unlockedItemIDs: [String] = ["moss"],
        placedItemIDs: [String] = [],
        activeBonsaiStyleID: String = "traditional-bonsai",
        gardenThemeID: String = "zen",
        lastUnlockNotifiedAtDays: Int = 0
    ) {
        self.id = id
        self.vitality = vitality
        self.lastWateredAt = lastWateredAt
        self.unlockedItemIDs = unlockedItemIDs
        self.placedItemIDs = placedItemIDs
        self.activeBonsaiStyleID = activeBonsaiStyleID
        self.gardenThemeID = gardenThemeID
        self.lastUnlockNotifiedAtDays = lastUnlockNotifiedAtDays
    }
}
