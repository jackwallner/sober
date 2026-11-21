import Foundation
import SwiftData
import Testing
@testable import Sober

@Suite("Money follows the stored currency, not the device region")
@MainActor
struct StoredCurrencyTests {
    @Test func moneyIsFormattedInTheStoredCode() {
        let yen = Money.format(dollars: 4000, code: "JPY")
        let dollars = Money.format(dollars: 4000, code: "USD")
        #expect(yen.contains("¥") || yen.contains("JP¥"))
        #expect(!yen.contains("$"))
        #expect(dollars.contains("$"))
    }

    @Test func aBlankCodeFallsBackToTheDeviceCurrency() {
        #expect(Money.format(dollars: 20, code: "") == Money.format(dollars: 20, code: SpendScale.currentCode))
        #expect(Money.format(dollars: 20, code: nil) == Money.format(dollars: 20, code: SpendScale.currentCode))
    }

    /// The controls were sized from the live region, so 4000 yen a day sat on
    /// the dollar scale (max 200) after a move.
    @Test func theSpendControlsAreSizedFromTheStoredCode() {
        let settings = UserSettings(currencyCode: "JPY")
        #expect(SpendScale(settings: settings).unit == 200)
        #expect(SpendScale(settings: settings).maxDaily == 40_000)
    }

    @Test func aGoalProjectionKeepsTheCurrencyItWasEnteredIn() {
        let start = Date(timeIntervalSince1970: 1_756_000_000)
        let p = GoalProjection(
            start: start, goal: start.addingTimeInterval(86_400 * 29), now: start,
            costPerDayCents: 400_000, caloriesPerDay: 0, currencyCode: "JPY"
        )
        #expect(p.moneyText.contains("¥"))
        #expect(!p.moneyText.contains("$"))
    }

    /// A context does not keep its container alive, so the container is returned too.
    private func store(_ settings: UserSettings) throws -> (container: ModelContainer, context: ModelContext) {
        let container = try ModelContainer(for: UserSettings.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(settings)
        return (container, container.mainContext)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "StoredCurrencyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Builds before 2026-10-30 left the "USD" default whatever the person used.
    @Test func anUpgradingInstallTakesTheDeviceCurrencyItWasEnteredIn() throws {
        let (container, context) = try store(UserSettings(currencyCode: "USD", hasCompletedOnboarding: true))
        SettingsService.settleCurrencyIfNeeded(context: context, defaults: freshDefaults(), deviceCode: "EUR")
        withExtendedLifetime(container) {}
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.currencyCode == "EUR")
    }

    @Test func aCodeOnboardingWroteIsNeverOverwritten() throws {
        let (container, context) = try store(UserSettings(currencyCode: "JPY", hasCompletedOnboarding: true))
        SettingsService.settleCurrencyIfNeeded(context: context, defaults: freshDefaults(), deviceCode: "USD")
        withExtendedLifetime(container) {}
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.currencyCode == "JPY")
    }

    @Test func settlingHappensOnlyOnce() throws {
        let defaults = freshDefaults()
        let (container, context) = try store(UserSettings(currencyCode: "USD", hasCompletedOnboarding: true))
        SettingsService.settleCurrencyIfNeeded(context: context, defaults: defaults, deviceCode: "USD")
        try context.fetch(FetchDescriptor<UserSettings>()).first?.currencyCode = "USD"
        SettingsService.settleCurrencyIfNeeded(context: context, defaults: defaults, deviceCode: "EUR")
        withExtendedLifetime(container) {}
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.currencyCode == "USD")
    }

    @Test func aRowStillInOnboardingIsLeftForOnboardingToWrite() throws {
        let (container, context) = try store(UserSettings(currencyCode: "USD", hasCompletedOnboarding: false))
        SettingsService.settleCurrencyIfNeeded(context: context, defaults: freshDefaults(), deviceCode: "EUR")
        withExtendedLifetime(container) {}
        #expect(try context.fetch(FetchDescriptor<UserSettings>()).first?.currencyCode == "USD")
    }
}
