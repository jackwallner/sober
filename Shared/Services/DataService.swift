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
            CravingEpisode.self,
        ])
        let url = containerURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // A failed migration or half-written file can leave the store unopenable.
        // It holds the sobriety date and every check-in, and exists nowhere else,
        // so move it aside instead of deleting it, then retry with a fresh store.
        logger.error("ModelContainer failed to open; quarantining the store and retrying")
        quarantineStore(at: url)
        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Last-resort in-memory fallback so the app still launches
        let inMemory = ModelConfiguration("Sober", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            logger.critical("ModelContainer failed even in-memory: \(String(describing: error), privacy: .public)")
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    private static let logger = Logger(subsystem: "com.jackwallner.sober", category: "DataService")

    /// Renames the store and its SQLite sidecars to `<name>.corrupt-<uuid>` so a
    /// fresh store can open at `url`. Returns the quarantined copies.
    @discardableResult
    nonisolated static func quarantineStore(at url: URL, fileManager: FileManager = .default) -> [URL] {
        let suffix = ".corrupt-\(UUID().uuidString)"
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
            url.appendingPathExtension("wal"),
            url.appendingPathExtension("shm")
        ]
        var moved: [URL] = []
        for file in candidates where fileManager.fileExists(atPath: file.path) {
            let destination = URL(fileURLWithPath: file.path + suffix)
            if (try? fileManager.moveItem(at: file, to: destination)) != nil {
                moved.append(destination)
            }
        }
        return moved
    }

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
