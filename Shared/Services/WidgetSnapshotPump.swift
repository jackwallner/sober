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
            gardenStage: GardenService.stage(forDays: days).rawValue,
            gardenVitality: gs.vitality,
            generatedAt: .now
        )
        WidgetSnapshotStore.save(snap)
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
