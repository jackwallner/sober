import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
enum WidgetSnapshotPump {
    static func push(context: ModelContext) {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        let active = sobriety.activeJourney()
        let days = sobriety.currentDayCount()
        let gs = garden.current()
        let snap = WidgetSnapshot(
            sobrietyStartDate: active?.startDate,
            currentStreakDays: days,
            longestStreakDays: sobriety.longestStreakDays(),
            bonsaiStage: GardenService.stage(forDays: days).rawValue,
            bonsaiStyleID: gs.activeBonsaiStyleID,
            gardenVitality: gs.vitality,
            placedItemIDs: gs.placedItemIDs,
            unlockedItemIDs: gs.unlockedItemIDs,
            generatedAt: .now
        )
        WidgetSnapshotStore.save(snap)
        #if os(iOS)
        // Mirror to the paired watch — App Group containers aren't shared across
        // devices, so the watch only sees data via this transport.
        if let data = try? JSONEncoder().encode(snap) {
            WatchConnectivityService.shared.send(snapshot: data)
        }
        #endif
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
