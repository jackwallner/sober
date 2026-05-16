import Foundation
import SwiftData

// MARK: - Bonsai Growth Stages

enum BonsaiStage: Int, CaseIterable, Comparable, Sendable {
    case seed = 0
    case sprout = 1
    case seedling = 2
    case young = 3
    case adolescent = 4
    case mature = 5
    case refined = 6
    case ancient = 7
    case legendary = 8

    var title: String {
        switch self {
        case .seed: return "Seed"
        case .sprout: return "Sprout"
        case .seedling: return "Seedling"
        case .young: return "Young Bonsai"
        case .adolescent: return "Adolescent"
        case .mature: return "Mature"
        case .refined: return "Refined"
        case .ancient: return "Ancient"
        case .legendary: return "Legendary"
        }
    }

    var dayThreshold: Int {
        switch self {
        case .seed: return 0
        case .sprout: return 3
        case .seedling: return 7
        case .young: return 14
        case .adolescent: return 30
        case .mature: return 60
        case .refined: return 90
        case .ancient: return 180
        case .legendary: return 365
        }
    }

    static func < (lhs: BonsaiStage, rhs: BonsaiStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Service

@MainActor
final class GardenService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // ── Singleton Access ──

    @discardableResult
    func current() -> GardenState {
        let descriptor = FetchDescriptor<GardenState>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let fresh = GardenState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    // ── Vitality ──

    func water(at date: Date = .now) {
        let state = current()
        state.lastWateredAt = date
        state.vitality = min(1.0, state.vitality + 0.25)
        try? context.save()
    }

    /// Call daily to decay vitality if user skipped a check-in.
    func applyVitalityDecay(lastCheckIn: Date?, now: Date = .now) {
        let state = current()
        state.vitality = Self.decayedVitality(from: state.vitality, lastCheckIn: lastCheckIn, now: now)
        try? context.save()
    }

    nonisolated static func decayedVitality(
        from base: Double,
        lastCheckIn: Date?,
        now: Date = .now
    ) -> Double {
        guard let last = lastCheckIn else { return base }
        let gap = DateHelpers.daysBetween(last, now)
        guard gap > 1 else { return base }
        let penalty = Double(gap - 1) * 0.12
        return max(0.1, base - penalty) // floor at 0.1 so it never fully dies
    }

    // ── Stage ──

    nonisolated static func stage(forDays days: Int) -> BonsaiStage {
        let inCycle = cycleProgress(forDays: days).dayInCycle
        return BonsaiStage.allCases
            .sorted { $0.dayThreshold < $1.dayThreshold }
            .last(where: { inCycle >= $0.dayThreshold }) ?? .seed
    }

    // ── Cycle ──

    /// One bonsai grows over 365 days. At day 365 it completes; on day 366 a
    /// fresh sapling begins and the previous tree joins the grove.
    /// Returns (dayInCycle: 0…365, completed: number of trees already in grove).
    nonisolated static func cycleProgress(forDays days: Int) -> (dayInCycle: Int, completed: Int) {
        if days <= 0 { return (0, 0) }
        let q = (days - 1) / 365
        return (days - q * 365, q)
    }

    /// Detect newly-completed cycles and append the current style to the grove,
    /// once per crossed 365-boundary. Returns count of newly-appended trees.
    @discardableResult
    func processCycleCompletions(days: Int) -> Int {
        let state = current()
        let expected = Self.cycleProgress(forDays: days).completed
        let have = state.completedTreeStyles.count
        guard expected > have else { return 0 }
        for _ in have..<expected {
            state.completedTreeStyles.append(state.activeBonsaiStyleID)
        }
        try? context.save()
        return expected - have
    }

    // ── Unlocks ──

    /// Process new milestone unlocks since the last check.
    ///
    /// Returns every item that crossed its milestone since `lastUnlockNotifiedAtDays`,
    /// in ascending order by milestone day. The caller is expected to celebrate them
    /// in sequence. All newly earned items are also added to `unlockedItemIDs`.
    func processNewUnlocks(days: Int) -> [GardenItem] {
        let state = current()
        let previouslyNotified = state.lastUnlockNotifiedAtDays

        let newlyEarned = GardenItemCatalog.all
            .filter { $0.milestoneDays > previouslyNotified && $0.milestoneDays <= days }
            .sorted { $0.milestoneDays < $1.milestoneDays }

        for item in newlyEarned {
            if !state.unlockedItemIDs.contains(item.id) {
                state.unlockedItemIDs.append(item.id)
            }
        }
        state.lastUnlockNotifiedAtDays = max(state.lastUnlockNotifiedAtDays, days)
        try? context.save()
        return newlyEarned
    }

    /// Clear the unlock-celebration tracker so milestones replay on a new journey.
    /// Earned items in `unlockedItemIDs` are intentionally kept (the user worked
    /// for those once); placed items are cleared so the new garden starts fresh.
    func resetForNewJourney() {
        let state = current()
        state.lastUnlockNotifiedAtDays = 0
        state.placedItemIDs.removeAll()
        state.vitality = 1.0
        state.lastWateredAt = nil
        try? context.save()
    }

    /// All items the user has unlocked.
    func unlockedItems(days: Int) -> [GardenItem] {
        GardenItemCatalog.unlocked(atDays: days)
    }

    // ── Placement ──

    func canPlaceItem(_ item: GardenItem, isPro: Bool) -> Bool {
        GardenItemCatalog.canPlace(item, isPro: isPro, currentPlacedCount: current().placedItemIDs.count)
    }

    func placeItem(_ item: GardenItem) {
        let state = current()
        guard !state.placedItemIDs.contains(item.id) else { return }
        state.placedItemIDs.append(item.id)
        try? context.save()
    }

    func removeItem(_ item: GardenItem) {
        let state = current()
        state.placedItemIDs.removeAll { $0 == item.id }
        try? context.save()
    }

    func setBonsaiStyle(_ styleID: String) {
        let state = current()
        state.activeBonsaiStyleID = styleID
        if !state.placedItemIDs.contains(styleID) {
            state.placedItemIDs.append(styleID)
        }
        try? context.save()
    }

    func clearAllPlaced() {
        let state = current()
        state.placedItemIDs.removeAll()
        try? context.save()
    }
}
