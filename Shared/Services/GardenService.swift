import Foundation
import SwiftData

enum GardenStage: Int, CaseIterable {
    case seed = 0
    case sprout = 1
    case sapling = 2
    case youngTree = 3
    case fullTree = 4
    case ancient = 5

    var title: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .sapling: return "Sapling"
        case .youngTree: return "Young Tree"
        case .fullTree: return "Full Tree"
        case .ancient: return "Ancient Guardian"
        }
    }

    /// Day threshold at which this stage is reached.
    var dayThreshold: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 1
        case .sapling: return 7
        case .youngTree: return 30
        case .fullTree: return 90
        case .ancient: return 365
        }
    }
}

@MainActor
final class GardenService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func current() -> GardenState {
        let descriptor = FetchDescriptor<GardenState>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let fresh = GardenState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    func water(at date: Date = .now) {
        let state = current()
        state.lastWateredAt = date
        state.vitality = min(1.0, state.vitality + 0.25)
        try? context.save()
    }

    /// Pure helper — maps day count to growth stage.
    nonisolated static func stage(forDays days: Int) -> GardenStage {
        let stages = GardenStage.allCases.sorted { $0.dayThreshold < $1.dayThreshold }
        return stages.last(where: { days >= $0.dayThreshold }) ?? .seed
    }

    /// Vitality decays if the user misses check-ins. 1 free day, then -0.15/day.
    nonisolated static func decayedVitality(
        from base: Double,
        lastCheckIn: Date?,
        now: Date = .now
    ) -> Double {
        guard let last = lastCheckIn else { return base }
        let gap = DateHelpers.daysBetween(last, now)
        guard gap > 1 else { return base }
        let penalty = Double(gap - 1) * 0.15
        return max(0, base - penalty)
    }
}
