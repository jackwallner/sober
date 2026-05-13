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

    init(
        id: UUID = UUID(),
        costPerDayCents: Int = 2000,        // $20/day default per reference screenshot
        currencyCode: String = "USD",
        caloriesPerDay: Int = 600,
        dailyReminderEnabled: Bool = true,
        dailyReminderHour: Int = 9,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.costPerDayCents = costPerDayCents
        self.currencyCode = currencyCode
        self.caloriesPerDay = caloriesPerDay
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    var costPerDay: Decimal {
        Decimal(costPerDayCents) / 100
    }
}
