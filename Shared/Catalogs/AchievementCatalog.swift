import Foundation

enum AchievementKind: String, Codable {
    case timeMilestone
    case streak
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let kind: AchievementKind
    let dayThreshold: Int
    let icon: String   // SF Symbol
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        // Time milestones
        Achievement(id: "first-step", title: "First Step", description: "Begin your journey to sobriety.", kind: .timeMilestone, dayThreshold: 0, icon: "leaf.fill"),
        Achievement(id: "strong-foundation", title: "Strong Foundation", description: "Complete your first week.", kind: .timeMilestone, dayThreshold: 7, icon: "shield.lefthalf.filled"),
        Achievement(id: "rising-star", title: "Rising Star", description: "One month milestone reached.", kind: .timeMilestone, dayThreshold: 30, icon: "star.fill"),
        Achievement(id: "quarter-master", title: "Quarter Master", description: "Three months strong.", kind: .timeMilestone, dayThreshold: 90, icon: "medal.fill"),
        Achievement(id: "half-year-hero", title: "Half-Year Hero", description: "Six months of sobriety.", kind: .timeMilestone, dayThreshold: 180, icon: "trophy.fill"),
        Achievement(id: "year-one", title: "Year One", description: "A full year. Incredible.", kind: .timeMilestone, dayThreshold: 365, icon: "crown.fill"),

        // Streak / check-in achievements
        Achievement(id: "perfect-week", title: "Perfect Week", description: "Daily check-ins for 7 days straight.", kind: .streak, dayThreshold: 7, icon: "flame.fill"),
        Achievement(id: "consistency-champion", title: "Consistency Champion", description: "30 consecutive check-ins.", kind: .streak, dayThreshold: 30, icon: "flame.fill"),
        Achievement(id: "diamond-discipline", title: "Diamond Discipline", description: "100 consecutive check-ins.", kind: .streak, dayThreshold: 100, icon: "diamond.fill"),
    ]

    static func achievement(id: String) -> Achievement? {
        all.first { $0.id == id }
    }

    static func timeMilestones(unlockedAt days: Int) -> [Achievement] {
        all.filter { $0.kind == .timeMilestone && days >= $0.dayThreshold }
    }

    static func nextTimeMilestone(after days: Int) -> Achievement? {
        all.first { $0.kind == .timeMilestone && days < $0.dayThreshold }
    }
}
