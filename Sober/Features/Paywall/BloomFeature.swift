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
