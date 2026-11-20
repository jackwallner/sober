import Foundation
import SwiftData
import os

@MainActor
enum DataService {
    nonisolated(unsafe) static let schema = Schema([
        SobrietyJourney.self,
        DailyCheckIn.self,
        JournalEntry.self,
        UnlockedAchievement.self,
        UnlockedHealthBenefit.self,
        GardenState.self,
        UserSettings.self,
        CravingEpisode.self,
    ])

    /// The open store. Read through `StoreState` so a Try Again that reaches
    /// the real file reaches every screen too.
    static var sharedModelContainer: ModelContainer { StoreState.shared.container }

    /// Opens the store. The sobriety date and every check-in exist nowhere
    /// else, so a failed open never trades them for an empty file.
    nonisolated static func openStore(countsAsLaunch: Bool = true) -> (container: ModelContainer, status: LocalStoreStatus) {
        storeOpener(url: containerURL).run(countsAsLaunch: countsAsLaunch)
    }

    nonisolated static func storeOpener(url: URL, defaults: UserDefaults = .standard) -> LocalStoreOpener {
        LocalStoreOpener(
            url: url,
            open: { try makeContainer(url: $0) },
            hasUserData: hasUserData(in:),
            makeStandIn: {
                let inMemory = ModelConfiguration("Sober", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [inMemory])
            },
            protectedDataAvailable: { StoreState.protectedDataAvailable() },
            defaults: defaults,
            failureCountKey: "storeOpenFailedLaunches",
            logger: Logger(subsystem: "com.jackwallner.sober", category: "DataService")
        )
    }

    nonisolated static func makeContainer(url: URL) throws -> ModelContainer {
        let config = ModelConfiguration("Sober", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    nonisolated static func hasUserData(in container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        let journeys = (try? context.fetchCount(FetchDescriptor<SobrietyJourney>())) ?? 0
        let checkIns = (try? context.fetchCount(FetchDescriptor<DailyCheckIn>())) ?? 0
        let journal = (try? context.fetchCount(FetchDescriptor<JournalEntry>())) ?? 0
        return journeys + checkIns + journal > 0
    }

    private static let logger = Logger(subsystem: "com.jackwallner.sober", category: "DataService")

    /// Bumped to v2 when the Garden schema was reshaped (species → items).
    /// Old `Sober.store` is left dormant on disk so a future migration could
    /// recover salvageable fields (e.g. SobrietyJourney start date) if needed.
    nonisolated static var containerURL: URL {
        AppGroup.containerURL.appendingPathComponent("Sober.v2.store")
    }
}
