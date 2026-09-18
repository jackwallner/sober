import Foundation
import SwiftData
import Testing
@testable import Sober

struct DataServiceQuarantineTests {
    @Test func unreadableStoreIsMovedAsideNotDeleted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appendingPathComponent("Sober.v2.store")
        let wal = URL(fileURLWithPath: store.path + "-wal")
        try Data("journey".utf8).write(to: store)
        try Data("wal".utf8).write(to: wal)

        let moved = DataService.quarantineStore(at: store)

        #expect(moved.count == 2)
        #expect(!FileManager.default.fileExists(atPath: store.path))
        #expect(!FileManager.default.fileExists(atPath: wal.path))
        let copy = try #require(moved.first { !$0.lastPathComponent.contains("-wal") })
        #expect(copy.lastPathComponent.hasPrefix("Sober.v2.store.corrupt-"))
        #expect(try Data(contentsOf: copy) == Data("journey".utf8))
    }

    @Test func missingStoreQuarantinesNothing() {
        let store = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Sober.v2.store")
        #expect(DataService.quarantineStore(at: store).isEmpty)
    }
}

@MainActor
@Suite(.serialized)
struct SaveFailureReporterTests {
    @Test func cravingSaveReportsNothingWhenStoreIsFine() throws {
        let schema = Schema([CravingEpisode.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        SaveFailureReporter.shared.message = nil
        CravingService(context: container.mainContext).record(
            startedAt: .now.addingTimeInterval(-120), secondsElapsed: 120, outcome: .rodeItOut, intensity: 3
        )
        #expect(SaveFailureReporter.shared.message == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<CravingEpisode>()) == 1)
    }

    @Test func reportedFailureProducesPlainMessage() {
        SaveFailureReporter.shared.message = nil
        SaveFailureReporter.shared.report(CocoaError(.fileWriteOutOfSpace))
        let message = SaveFailureReporter.shared.message ?? ""
        #expect(message.contains("could not be saved"))
        #expect(!message.contains("—"))
        SaveFailureReporter.shared.message = nil
    }
}
