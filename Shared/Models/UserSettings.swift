import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var costPerDayCents: Int          // store as integer cents to avoid Decimal in SwiftData
    var currencyCode: String
    var caloriesPerDay: Int
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var hasCompletedOnboarding: Bool
    var appearancePreferenceRaw: String = AppearancePreference.system.rawValue

    init(
        id: UUID = UUID(),
        costPerDayCents: Int = 2000,        // $20/day default per reference screenshot
        currencyCode: String = "USD",
        caloriesPerDay: Int = 600,
        dailyReminderEnabled: Bool = true,
        dailyReminderHour: Int = 9,
        hasCompletedOnboarding: Bool = false,
        appearancePreference: AppearancePreference = .system
    ) {
        self.id = id
        self.costPerDayCents = costPerDayCents
        self.currencyCode = currencyCode
        self.caloriesPerDay = caloriesPerDay
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.appearancePreferenceRaw = appearancePreference.rawValue
    }

    var appearancePreference: AppearancePreference {
        get { AppearancePreference(rawValue: appearancePreferenceRaw) ?? .system }
        set { appearancePreferenceRaw = newValue.rawValue }
    }

    var costPerDay: Decimal {
        Decimal(costPerDayCents) / 100
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
