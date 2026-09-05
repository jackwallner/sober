import Foundation

/// Lightweight snapshot pushed to the App Group so widgets and the watch app
/// can render without opening the SwiftData store.
struct WidgetSnapshot: Codable, Equatable {
    var sobrietyStartDate: Date?
    var currentStreakDays: Int
    var longestStreakDays: Int
    var bonsaiStage: Int             // 0..8
    var bonsaiStyleID: String        // "traditional", "cascade", "windswept"
    var gardenVitality: Double       // 0..1
    var placedItemIDs: [String]      // items in the garden scene
    var unlockedItemIDs: [String]    // items earned through milestones
    var generatedAt: Date
    /// Growth the live tree inherited from the last slip. The widget and the
    /// watch recompute the day count from `sobrietyStartDate` so they roll over
    /// at midnight on their own, so the stored `bonsaiStage` can't be the thing
    /// they draw — they need the carryover itself to redo the same sum the app
    /// does. Without it, Home showed the tree a slip had preserved while the
    /// widget beside it drew day-one bare soil for the same moment.
    var carryoverDays: Int = 0

    static let empty = WidgetSnapshot(
        sobrietyStartDate: nil,
        currentStreakDays: 0,
        longestStreakDays: 0,
        bonsaiStage: 0,
        bonsaiStyleID: "traditional",
        gardenVitality: 0,
        placedItemIDs: [],
        unlockedItemIDs: [],
        generatedAt: .distantPast,
        carryoverDays: 0
    )

    /// The day count the tree is drawn at, as opposed to the streak printed
    /// next to it. Same rule as `GardenService.treeDays`, applied to whatever
    /// day count the consumer computed for the moment it is rendering.
    func treeDays(streakDays: Int) -> Int {
        GardenService.treeDays(streakDays: streakDays, carryover: carryoverDays)
    }
}

/// Decoded field by field so a payload written by an older build still loads.
///
/// The synthesised decoder fails the whole snapshot on a missing key, and the
/// widget reads this store across an app update: on the first launch after one,
/// a strictly-decoded snapshot would fall back to `.empty` and show 0 days
/// until the user next opened the app.
extension WidgetSnapshot {
    private enum CodingKeys: String, CodingKey {
        case sobrietyStartDate, currentStreakDays, longestStreakDays, bonsaiStage
        case bonsaiStyleID, gardenVitality, placedItemIDs, unlockedItemIDs
        case generatedAt, carryoverDays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sobrietyStartDate = try c.decodeIfPresent(Date.self, forKey: .sobrietyStartDate)
        currentStreakDays = try c.decodeIfPresent(Int.self, forKey: .currentStreakDays) ?? 0
        longestStreakDays = try c.decodeIfPresent(Int.self, forKey: .longestStreakDays) ?? 0
        bonsaiStage = try c.decodeIfPresent(Int.self, forKey: .bonsaiStage) ?? 0
        bonsaiStyleID = try c.decodeIfPresent(String.self, forKey: .bonsaiStyleID) ?? "traditional"
        gardenVitality = try c.decodeIfPresent(Double.self, forKey: .gardenVitality) ?? 0
        placedItemIDs = try c.decodeIfPresent([String].self, forKey: .placedItemIDs) ?? []
        unlockedItemIDs = try c.decodeIfPresent([String].self, forKey: .unlockedItemIDs) ?? []
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .distantPast
        carryoverDays = try c.decodeIfPresent(Int.self, forKey: .carryoverDays) ?? 0
    }
}

enum WidgetSnapshotStore {
    private static let key = "sober.widget.snapshot.v1"

    static func load() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snap
    }

    static func save(_ snap: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
