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

    enum Intent: String {
        case postOnboarding
        case journal
        case healthTimeline
        case gardenSpecies
        case progressSheet
        case settings
        case growthCelebration
        case checkInMilestone

        var focusFeature: BloomFeature? {
            switch self {
            case .journal: .journal
            case .healthTimeline: .healthTimeline
            case .gardenSpecies: .gardenSpecies
            case .progressSheet: .savingsTracking
            case .postOnboarding, .settings, .growthCelebration, .checkInMilestone: nil
            }
        }
    }

    enum PitchPolicy: Equatable {
        case initial
        case explicitUpgrade
        case subsequentLocked
        case subsequentPassive
    }

    struct PendingRequest: Equatable {
        let intent: Intent
        let policy: PitchPolicy
    }

    @Published var pendingRequest: PendingRequest?

    /// True while MainTabView has the trial-offer or paywall sheet on screen.
    /// The review-prompt scheduler checks this (and vice versa) so the two
    /// sheet systems — owned by different view layers — never race to present.
    @Published var isPresentingSheet = false

    private init() {}

    func request(_ intent: Intent, policy: PitchPolicy = .subsequentLocked) {
        pendingRequest = PendingRequest(intent: intent, policy: policy)
    }

    func clear() { pendingRequest = nil }
}

@MainActor
enum TrialSubsequentPitchGate {
    static let lockedFeatureThreshold = 2
    static let passiveUsageThreshold = 2
    static let maxTrialPitchesPerIntentPerSession = 2

    private static var sessionTrialPitchCounts: [String: Int] = [:]

    static func actionCount(for intent: TrialOfferCoordinator.Intent) -> Int {
        AppGroup.defaults.integer(forKey: AppGroup.bloomActionCountKey(for: intent.rawValue))
    }

    @discardableResult
    static func recordAction(for intent: TrialOfferCoordinator.Intent) -> Int {
        let next = actionCount(for: intent) + 1
        AppGroup.defaults.set(next, forKey: AppGroup.bloomActionCountKey(for: intent.rawValue))
        return next
    }

    static func canPresentTrialPitch(for intent: TrialOfferCoordinator.Intent) -> Bool {
        sessionTrialPitchCounts[intent.rawValue, default: 0] < maxTrialPitchesPerIntentPerSession
    }

    static func markTrialPitchPresented(for intent: TrialOfferCoordinator.Intent) {
        sessionTrialPitchCounts[intent.rawValue, default: 0] += 1
        TrialNudgeGate.markShown()
    }

    @discardableResult
    static func incrementPersistedCount(key: String) -> Int {
        let next = AppGroup.defaults.integer(forKey: key) + 1
        AppGroup.defaults.set(next, forKey: key)
        return next
    }
}

@MainActor
func requestSubsequentLockedFeaturePitch(_ intent: TrialOfferCoordinator.Intent) {
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentLocked)
}

enum TrialNudgeGate {
    private static let scheduleHours: [Double] = [48, 72, 120, 168, 336]

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

@MainActor
func presentPassiveTrialNudge(
    _ subscriptions: SubscriptionService,
    intent: TrialOfferCoordinator.Intent,
    delay: Double = 4
) async {
    guard !subscriptions.isProSubscriber,
          !subscriptions.hasClaimedTrial,
          subscriptions.hasTrialOfferAvailable,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow()
    else { return }
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard !Task.isCancelled,
          !subscriptions.isProSubscriber,
          TrialOfferCoordinator.shared.pendingRequest == nil
    else { return }
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentPassive)
}

@MainActor
func evaluateUsageBasedTrialPitch(
    _ subscriptions: SubscriptionService,
    intent: TrialOfferCoordinator.Intent,
    usageCount: Int,
    threshold: Int = TrialSubsequentPitchGate.passiveUsageThreshold,
    delay: Double = 1.5
) async {
    guard !subscriptions.isProSubscriber,
          !subscriptions.hasClaimedTrial,
          subscriptions.hasTrialOfferAvailable,
          usageCount >= threshold,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow(),
          TrialSubsequentPitchGate.canPresentTrialPitch(for: intent)
    else { return }
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard !Task.isCancelled,
          !subscriptions.isProSubscriber,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow(),
          TrialSubsequentPitchGate.canPresentTrialPitch(for: intent)
    else { return }
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentPassive)
}
