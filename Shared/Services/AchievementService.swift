import Foundation
import SwiftData

/// Writes `UnlockedAchievement` rows when a threshold is hit so earned badges
/// survive relapse resets — the trophy case is "ever earned," not "currently
/// holding."
@MainActor
final class AchievementService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Unlock any time milestones the active streak now satisfies, plus any
    /// streak achievements satisfied by the longest run of consecutive sober
    /// check-ins on record. Idempotent — re-running is cheap and inserts no
    /// duplicates because `achievementID` is unique.
    func processUnlocks(currentDays: Int) {
        let longestStreak = longestSoberStreak()
        let already = Set(unlocked().map(\.achievementID))
        for a in AchievementCatalog.all {
            guard !already.contains(a.id) else { continue }
            let earned: Bool
            switch a.kind {
            case .timeMilestone: earned = currentDays >= a.dayThreshold
            case .streak: earned = longestStreak >= a.dayThreshold
            case .challenge: earned = false
            }
            if earned {
                context.insert(UnlockedAchievement(achievementID: a.id))
            }
        }
        if !already.contains(JanuaryChallenge.achievementID), januaryChallengeComplete() {
            context.insert(UnlockedAchievement(achievementID: JanuaryChallenge.achievementID))
        }
        context.saveOrReport()
    }

    /// All 31 January days on record as dry.
    private func januaryChallengeComplete(now: Date = JanuaryChallenge.clock()) -> Bool {
        let days = JanuaryChallenge.days()
        guard let first = days.first, let last = days.last, now >= last else { return false }
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.day >= first && $0.day <= last }
        )
        let facts = ((try? context.fetch(descriptor)) ?? []).map {
            CheckInFacts(day: $0.day, wasSober: $0.wasSober, wasLogged: $0.wasLogged, mood: $0.mood)
        }
        return JanuaryChallenge.snapshot(now: now, facts: facts).isComplete
    }

    func unlocked() -> [UnlockedAchievement] {
        (try? context.fetch(FetchDescriptor<UnlockedAchievement>())) ?? []
    }

    private func longestSoberStreak() -> Int {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            sortBy: [SortDescriptor(\.day)]
        )
        let sortedDays = (try? context.fetch(descriptor))?
            // Check-in badges need check-ins: a day the app assumed is sober,
            // but nobody checked in on it.
            .filter { $0.wasSober && $0.wasLogged }
            .map { DateHelpers.startOfDay($0.day) } ?? []
        guard !sortedDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<sortedDays.count {
            let gap = Calendar.current.dateComponents([.day], from: sortedDays[i - 1], to: sortedDays[i]).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else if gap > 1 {
                current = 1
            }
        }
        return longest
    }
}
