import Foundation

/// Lightweight snapshot pushed to the App Group so widgets and the watch app
/// can render without opening the SwiftData store.
struct WidgetSnapshot: Codable, Equatable {
    var sobrietyStartDate: Date?
    var currentStreakDays: Int
    var longestStreakDays: Int
    var gardenStage: Int       // 0..5
    var gardenVitality: Double // 0..1
    var generatedAt: Date

    static let empty = WidgetSnapshot(
        sobrietyStartDate: nil,
        currentStreakDays: 0,
        longestStreakDays: 0,
        gardenStage: 0,
        gardenVitality: 0,
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
