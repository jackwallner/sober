import Foundation
import SwiftData

@Model
final class UnlockedAchievement {
    @Attribute(.unique) var achievementID: String
    var unlockedAt: Date

    init(achievementID: String, unlockedAt: Date = .now) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}
