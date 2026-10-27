import SwiftUI

/// Bloom+ capabilities — single source of truth for trial-sheet and paywall copy.
///
/// The line between free and Bloom+ is drawn by *tense*, not by feature count.
/// Free owns the past: the counter, the calendar, today's tree, and the money
/// kept so far. Bloom+ owns the future: the year-ahead projection, the tree
/// you're growing toward, the journal you'll write in, the milestones still to
/// come. Selling a bigger version of a complete free app is what put trial
/// starts at 3%; selling the half the free app can't show is the bet.
///
/// `patterns` leads, and the declaration order here is the paywall's priority
/// order (`visibleBenefits` keeps the first N). Everything below it can be
/// computed from a start date, which is why the old list read as a bigger
/// version of the free app; patterns is the only one that cannot exist without
/// the user's own record, and it is the only one a competitor cannot copy off
/// a screenshot.
///
/// `goalProjection` and `urgePlaybook` follow it (added 1.3.3) because they are
/// the two things a user on day zero wants right now: what the date they just
/// picked is worth, and a plan for the first hard evening. Everything after
/// them only pays off once the user has been here a while.
enum BloomFeature: CaseIterable {
    case patterns
    case goalProjection
    case urgePlaybook
    case healthTimeline
    case savingsTracking
    case journal
    case gardenSpecies

    var icon: String {
        switch self {
        case .patterns: "chart.bar.xaxis"
        case .goalProjection: "flag.checkered"
        case .urgePlaybook: "list.bullet.clipboard"
        case .gardenSpecies: "leaf.fill"
        case .healthTimeline: "heart.text.square.fill"
        case .journal: "book.closed.fill"
        case .savingsTracking: "chart.line.uptrend.xyaxis"
        }
    }

    var title: String {
        switch self {
        case .patterns: String(localized: "Your craving patterns")
        case .goalProjection: String(localized: "Your goal, projected")
        case .urgePlaybook: String(localized: "Craving playbook")
        case .gardenSpecies: String(localized: "All 6 bonsai species")
        case .healthTimeline: String(localized: "Full health timeline")
        case .journal: String(localized: "Daily journal")
        case .savingsTracking: String(localized: "Your year ahead")
        }
    }

    var detail: String {
        switch self {
        case .patterns: String(localized: "When they hit, what sets them off, how long yours last.")
        case .goalProjection: String(localized: "Money, calories, and milestones by the date you picked.")
        case .urgePlaybook: String(localized: "A plan for each trigger: what to do and what to say.")
        case .gardenSpecies: String(localized: "Switch your tree as your streak grows.")
        case .healthTimeline: String(localized: "13 recovery milestones with sources.")
        case .journal: String(localized: "Prompts and reflections on hard days.")
        case .savingsTracking: String(localized: "What you'll have kept by this time next year.")
        }
    }

    var pitchHeadline: String {
        switch self {
        case .patterns: String(localized: "Learn your own pattern.")
        case .goalProjection: String(localized: "See your goal day.")
        case .urgePlaybook: String(localized: "Have a plan ready.")
        case .gardenSpecies: String(localized: "Grow every species.")
        case .healthTimeline: String(localized: "See what's coming back.")
        case .journal: String(localized: "Write through the urges.")
        case .savingsTracking: String(localized: "See where this goes.")
        }
    }

    var pitchSubheadline: String {
        switch self {
        case .patterns: String(localized: "See when your cravings hit, what sets them off, and how long yours actually last, plus the rest of Bloom+.")
        case .goalProjection: String(localized: "See what you'll have kept and which milestones you'll have passed by your goal date, plus the rest of Bloom+.")
        case .urgePlaybook: String(localized: "Six plans for the first hard moments: what to do, and what to say when you're offered a drink. Plus the rest of Bloom+.")
        case .gardenSpecies: String(localized: "Unlock every bonsai species and switch whenever you like, plus the rest of Bloom+.")
        case .healthTimeline: String(localized: "Unlock the full 13-milestone recovery timeline, plus the rest of Bloom+.")
        case .journal: String(localized: "Daily journal prompts when you need them most, plus the rest of Bloom+.")
        case .savingsTracking: String(localized: "Project your money, calories, and tree a year out, plus the rest of Bloom+.")
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
        case cravingRelief
        case patterns
        case goalProjection
        case urgePlaybook

        var focusFeature: BloomFeature? {
            switch self {
            case .journal: .journal
            case .healthTimeline: .healthTimeline
            case .gardenSpecies: .gardenSpecies
            case .progressSheet: .savingsTracking
            // Riding out an urge is the moment the patterns pitch is actually
            // about something the user just did, so it leads with that rather
            // than the generic page.
            case .cravingRelief, .patterns: .patterns
            case .goalProjection: .goalProjection
            case .urgePlaybook: .urgePlaybook
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
