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

    func save() { context.saveOrReport() }
}
