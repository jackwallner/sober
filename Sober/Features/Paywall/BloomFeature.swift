import SwiftUI

/// Bloom+ capabilities — single source of truth for trial-sheet and paywall copy.
enum BloomFeature: CaseIterable {
    case gardenSpecies
    case healthTimeline
    case journal
    case savingsTracking

    var icon: String {
        switch self {
        case .gardenSpecies: "leaf.fill"
        case .healthTimeline: "heart.text.square.fill"
        case .journal: "book.closed.fill"
        case .savingsTracking: "dollarsign.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .gardenSpecies: "All 6 bonsai species"
        case .healthTimeline: "Full health timeline"
        case .journal: "Daily journal"
        case .savingsTracking: "Money & calorie tracking"
        }
    }

    var detail: String {
        switch self {
        case .gardenSpecies: "Switch your tree as your streak grows."
        case .healthTimeline: "13 recovery milestones with sources."
        case .journal: "Prompts and reflections on hard days."
        case .savingsTracking: "Every dollar and calorie you avoid, tracked."
        }
    }

    var pitchHeadline: String {
        switch self {
        case .gardenSpecies: "Grow every species."
        case .healthTimeline: "See what's coming back."
        case .journal: "Write through the urges."
        case .savingsTracking: "Watch your savings add up."
        }
    }

    var pitchSubheadline: String {
        switch self {
        case .gardenSpecies: "Unlock every bonsai species and switch whenever you like, plus the rest of Bloom+."
        case .healthTimeline: "Unlock the full 13-milestone recovery timeline, plus the rest of Bloom+."
        case .journal: "Daily journal prompts when you need them most, plus the rest of Bloom+."
        case .savingsTracking: "Track every dollar and calorie you avoid, plus the rest of Bloom+."
        }
    }
}

@MainActor
final class TrialOfferCoordinator: ObservableObject {
    static let shared = TrialOfferCoordinator()

    enum Intent {
        case postOnboarding
        case journal
        case healthTimeline
        case gardenSpecies
        case progressSheet
        case settings
        case growthCelebration

        var focusFeature: BloomFeature? {
            switch self {
            case .journal: .journal
            case .healthTimeline: .healthTimeline
            case .gardenSpecies: .gardenSpecies
            case .progressSheet: .savingsTracking
            case .postOnboarding, .settings, .growthCelebration: nil
            }
        }
    }

    @Published var pendingIntent: Intent?

    private init() {}

    func request(_ intent: Intent) { pendingIntent = intent }
    func clear() { pendingIntent = nil }
}

/// Cooldown gate for *passive* trial nudges — the ones the app surfaces on its
/// own (landing on Home, Timeline, or Health) rather than in response to a tap.
/// The interval *escalates*: the small trial popup shows roughly daily at first
/// — the cadence that drives high trial-start rates — then backs off so it never
/// becomes spam (and stays clear of App Store "persistent paywall" concerns).
enum TrialNudgeGate {
    /// Hours to wait before the next nudge, indexed by how many have shown.
    private static let scheduleHours: [Double] = [20, 28, 44, 96, 168]

    private static var shownCount: Int {
        AppGroup.defaults.integer(forKey: AppGroup.trialNudgeCountKey)
    }

    static func canShow() -> Bool {
        let last = AppGroup.defaults.double(forKey: AppGroup.lastTrialNudgeKey)
        guard last > 0 else { return true }
        let idx = min(max(shownCount, 1), scheduleHours.count) - 1
        let gap = scheduleHours[idx] * 3600
        return Date().timeIntervalSince1970 - last >= gap
    }

    static func markShown() {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: AppGroup.lastTrialNudgeKey)
        AppGroup.defaults.set(shownCount + 1, forKey: AppGroup.trialNudgeCountKey)
    }
}

/// Passive, cooldown-gated trial nudge shared by the Home, Timeline, and Health
/// tabs. Safe to call from every tab's `.task` — the gate handles frequency, so
/// whichever tab a returning free user lands on surfaces the small trial sheet
/// once the interval has elapsed. No-op for subscribers or trial-ineligible users.
@MainActor
func presentPassiveTrialNudge(
    _ subscriptions: SubscriptionService,
    intent: TrialOfferCoordinator.Intent,
    delay: Double = 4
) async {
    guard !subscriptions.isProSubscriber,
          !subscriptions.hasClaimedTrial,
          subscriptions.hasTrialOfferAvailable,
          TrialOfferCoordinator.shared.pendingIntent == nil,
          TrialNudgeGate.canShow()
    else { return }
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard !Task.isCancelled,
          !subscriptions.isProSubscriber,
          TrialOfferCoordinator.shared.pendingIntent == nil
    else { return }
    TrialNudgeGate.markShown()
    TrialOfferCoordinator.shared.request(intent)
}
