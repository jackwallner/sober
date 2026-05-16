import Foundation
import SwiftData
import os

@MainActor
enum DataService {
    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SobrietyJourney.self,
            DailyCheckIn.self,
            JournalEntry.self,
            UnlockedAchievement.self,
            UnlockedHealthBenefit.self,
            GardenState.self,
            UserSettings.self,
        ])
        let url = containerURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Corrupt store — wipe and retry
        let storeFiles = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
        for file in storeFiles {
            try? FileManager.default.removeItem(at: file)
        }
        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Last-resort in-memory fallback so the app still launches
        let inMemory = ModelConfiguration("Sober", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            let logger = Logger(subsystem: "com.jackwallner.sober", category: "DataService")
            logger.critical("ModelContainer failed even in-memory: \(String(describing: error), privacy: .public)")
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "Sober",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    /// Bumped to v2 when the Garden schema was reshaped (species → items).
    /// Old `Sober.store` is left dormant on disk so a future migration could
    /// recover salvageable fields (e.g. SobrietyJourney start date) if needed.
    private static var containerURL: URL {
        AppGroup.containerURL.appendingPathComponent("Sober.v2.store")
    }
}
