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

    /// One warm line describing what just happened to the tree, shown in the
    /// "New Growth" celebration when the bonsai advances to this stage.
    var growthMessage: String {
        switch self {
        case .seed:       return "A seed is planted. Every great tree starts here."
        case .sprout:     return "Your first sprout has broken the soil."
        case .seedling:   return "A seedling stands tall — roots are taking hold."
        case .young:      return "Your bonsai is filling out into a young tree."
        case .adolescent: return "Branches are reaching wider. The shape is emerging."
        case .mature:     return "Your bonsai has matured into a full, leafy canopy."
        case .refined:    return "Refined and dense — the work of real patience."
        case .ancient:    return "Ancient and weathered. This tree has seen a lot."
        case .legendary:  return "A legendary bonsai. A full year of growth made visible."
        }
    }

    static func < (lhs: BonsaiStage, rhs: BonsaiStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Growth Events

/// What just happened in the garden since the user last looked, worth a
/// full-screen celebration. `treeCompleted` outranks `newStage`: crossing a
/// 365-day boundary always also resets the stage, and "your tree joined the
/// grove" is the story that explains why the big tree became a sapling.
enum GardenGrowthEvent: Equatable, Sendable {
    case newStage(BonsaiStage)
    case treeCompleted(total: Int)
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

    /// Gently fade vitality for days elapsed since the garden was last watered.
    /// Recovery-first by design: floored at 0.3 so a returning user never finds
    /// a "dead" garden, and a single check-in (`water`) immediately perks it
    /// back up. Does nothing until the first-ever check-in sets `lastWateredAt`.
    func applyVitalityDecay(asOf date: Date = .now) {
        let state = current()
        guard let last = state.lastWateredAt else { return }
        let daysMissed = DateHelpers.daysBetween(last, date)
        guard daysMissed > 0 else { return }
        state.vitality = max(0.3, state.vitality - Double(daysMissed) * 0.1)
        try? context.save()
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
    /// Expected size is the journey-start baseline plus this journey's
    /// completed cycles, so trees grown before a relapse reset don't absorb
    /// the ones grown after it.
    @discardableResult
    func processCycleCompletions(days: Int) -> Int {
        let state = current()
        let expected = state.groveCountAtJourneyStart + Self.cycleProgress(forDays: days).completed
        let have = state.completedTreeStyles.count
        guard expected > have else { return 0 }
        for _ in have..<expected {
            state.completedTreeStyles.append(state.activeBonsaiStyleID)
        }
        try? context.save()
        return expected - have
    }

    // ── Growth ──

    /// Pure decision: what celebration (if any) does moving from
    /// `previousDays` to `currentDays` earn? A crossed 365-boundary wins —
    /// the tree completed and joined the grove — otherwise a stage advance
    /// within the current cycle. `previousDays == 0` (first-ever check, e.g.
    /// a back-dated onboarding) earns nothing, so a returning user isn't
    /// ambushed by celebrations for growth that happened off-screen.
    nonisolated static func growthEvent(previousDays: Int, currentDays: Int) -> GardenGrowthEvent? {
        guard previousDays > 0, currentDays > previousDays else { return nil }
        let prev = cycleProgress(forDays: previousDays)
        let cur = cycleProgress(forDays: currentDays)
        if cur.completed > prev.completed {
            return .treeCompleted(total: cur.completed)
        }
        let prevStage = stage(forDays: previousDays)
        let curStage = stage(forDays: currentDays)
        return curStage > prevStage ? .newStage(curStage) : nil
    }

    /// Detect what grew since the last time we checked — a stage advance, or
    /// a completed tree joining the grove — and return it for celebration.
    /// `lastUnlockNotifiedAtDays` is reused as the day-count watermark.
    func processGrowthEvents(days: Int) -> GardenGrowthEvent? {
        let state = current()
        let previous = state.lastUnlockNotifiedAtDays
        state.lastUnlockNotifiedAtDays = max(previous, days)
        try? context.save()
        return Self.growthEvent(previousDays: previous, currentDays: days)
    }

    /// Clear growth tracking so stage celebrations replay on a new journey, and
    /// reset the live tree to a fresh sapling. Completed trees in the grove are
    /// kept — they're a permanent record of cycles actually finished.
    func resetForNewJourney() {
        let state = current()
        state.lastUnlockNotifiedAtDays = 0
        state.groveCountAtJourneyStart = state.completedTreeStyles.count
        state.placedItemIDs.removeAll()
        state.vitality = 1.0
        state.lastWateredAt = nil
        try? context.save()
    }

    // ── Species ──

    func setBonsaiStyle(_ styleID: String) {
        let state = current()
        state.activeBonsaiStyleID = styleID
        try? context.save()
    }
}
