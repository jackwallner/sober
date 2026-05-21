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
            }
            if earned {
                context.insert(UnlockedAchievement(achievementID: a.id))
            }
        }
        try? context.save()
    }

    func unlocked() -> [UnlockedAchievement] {
        (try? context.fetch(FetchDescriptor<UnlockedAchievement>())) ?? []
    }

    private func longestSoberStreak() -> Int {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            sortBy: [SortDescriptor(\.day)]
        )
        let sortedDays = (try? context.fetch(descriptor))?
            .filter { $0.wasSober }
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
