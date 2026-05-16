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

    static let empty = WidgetSnapshot(
        sobrietyStartDate: nil,
        currentStreakDays: 0,
        longestStreakDays: 0,
        bonsaiStage: 0,
        bonsaiStyleID: "traditional",
        gardenVitality: 0,
        placedItemIDs: [],
        unlockedItemIDs: [],
        generatedAt: .distantPast
    )
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
