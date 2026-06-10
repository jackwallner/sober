import Foundation
import SwiftData

@Model
final class GardenState {
    var id: UUID
    var vitality: Double                    // 0..1, decays daily, water to restore
    var lastWateredAt: Date?
    var unlockedItemIDs: [String]           // items earned through milestone days
    var placedItemIDs: [String]             // items currently displayed (Pro-gated slots)
    var activeBonsaiStyleID: String         // current growing tree's style — Pro can swap mid-cycle
    var gardenThemeID: String               // "zen", "forest", "seasonal"
    var lastUnlockNotifiedAtDays: Int       // last day-count milestone we showed a celebration for
    /// Grove of completed bonsai, one entry per 365-day cycle. Style locks at
    /// completion; persists across relapse resets (a permanent record of
    /// milestones actually reached).
    var completedTreeStyles: [String] = []
    /// Grove size when the current journey began. The grove outlives resets,
    /// but cycle counting restarts with each journey — without this baseline,
    /// a post-reset journey's completions would be swallowed until they
    /// exceeded the lifetime total.
    var groveCountAtJourneyStart: Int = 0

    init(
        id: UUID = UUID(),
        vitality: Double = 1.0,
        lastWateredAt: Date? = nil,
        unlockedItemIDs: [String] = ["moss"],
        placedItemIDs: [String] = [],
        activeBonsaiStyleID: String = "traditional-bonsai",
        gardenThemeID: String = "zen",
        lastUnlockNotifiedAtDays: Int = 0,
        completedTreeStyles: [String] = []
    ) {
        self.id = id
        self.vitality = vitality
        self.lastWateredAt = lastWateredAt
        self.unlockedItemIDs = unlockedItemIDs
        self.placedItemIDs = placedItemIDs
        self.activeBonsaiStyleID = activeBonsaiStyleID
        self.gardenThemeID = gardenThemeID
        self.lastUnlockNotifiedAtDays = lastUnlockNotifiedAtDays
        self.completedTreeStyles = completedTreeStyles
    }
}
