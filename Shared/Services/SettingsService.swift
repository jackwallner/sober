import Foundation
import SwiftData

@MainActor
final class SettingsService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func current() -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let fresh = UserSettings()
        context.insert(fresh)
        context.saveOrReport()
        return fresh
    }

    /// Money is formatted in the stored currency code, but builds before
    /// 2026-10-30 never wrote it: every upgrading install still holds the
    /// "USD" default whatever currency the person entered their spend in.
    /// Once, on the first launch of a build that reads the code, a "USD" row
    /// that finished onboarding takes the device currency it was entered in.
    /// A code other than "USD" was written by onboarding and is left alone.
    static func settleCurrencyIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = AppGroup.defaults,
        deviceCode: String = SpendScale.currentCode
    ) {
        guard !defaults.bool(forKey: AppGroup.currencySettledKey) else { return }
        defaults.set(true, forKey: AppGroup.currencySettledKey)
        guard context.holds(UserSettings.self),
              let row = try? context.fetch(FetchDescriptor<UserSettings>()).first,
              row.hasCompletedOnboarding, row.currencyCode == "USD", deviceCode != "USD" else { return }
        row.currencyCode = deviceCode
        context.saveOrReport()
    }

    func save() { context.saveOrReport() }
}
