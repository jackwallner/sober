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
        Achievement(id: "first-step", title: String(localized: "First Step"), description: String(localized: "Begin your journey to sobriety."), kind: .timeMilestone, dayThreshold: 0, icon: "leaf.fill"),
        Achievement(id: "strong-foundation", title: String(localized: "Strong Foundation"), description: String(localized: "Complete your first week."), kind: .timeMilestone, dayThreshold: 7, icon: "shield.lefthalf.filled"),
        Achievement(id: "rising-star", title: String(localized: "Rising Star"), description: String(localized: "One month milestone reached."), kind: .timeMilestone, dayThreshold: 30, icon: "star.fill"),
        Achievement(id: "quarter-master", title: String(localized: "Quarter Master"), description: String(localized: "Three months strong."), kind: .timeMilestone, dayThreshold: 90, icon: "medal.fill"),
        Achievement(id: "half-year-hero", title: String(localized: "Half-Year Hero"), description: String(localized: "Six months of sobriety."), kind: .timeMilestone, dayThreshold: 180, icon: "trophy.fill"),
        Achievement(id: "year-one", title: String(localized: "Year One"), description: String(localized: "A full year. Incredible."), kind: .timeMilestone, dayThreshold: 365, icon: "crown.fill"),

        // Streak / check-in achievements
        Achievement(id: "perfect-week", title: String(localized: "Perfect Week"), description: String(localized: "Daily check-ins for 7 days straight."), kind: .streak, dayThreshold: 7, icon: "flame.fill"),
        Achievement(id: "consistency-champion", title: String(localized: "Consistency Champion"), description: String(localized: "30 consecutive check-ins."), kind: .streak, dayThreshold: 30, icon: "flame.fill"),
        Achievement(id: "diamond-discipline", title: String(localized: "Diamond Discipline"), description: String(localized: "100 consecutive check-ins."), kind: .streak, dayThreshold: 100, icon: "diamond.fill"),
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
