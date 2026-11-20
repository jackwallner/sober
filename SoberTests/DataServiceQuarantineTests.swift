import Foundation
import SwiftData
import Testing
@testable import Sober

/// A failed open must never trade the sobriety date for an empty file.
/// These run the real opener on real SwiftData files in a scratch folder,
/// with the open itself made to fail the way a locked phone, a full disk or a
/// corrupt file would.
@Suite(.serialized)
struct LocalStoreOpenerTests {
    private final class Calls: @unchecked Sendable { var count = 0 }

    private func scratchStore() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("store-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Sober.v2.store")
    }

    /// Writes a store holding one journey and closes it.
    private func writeJourney(at url: URL) throws {
        let container = try DataService.makeContainer(url: url)
        let context = ModelContext(container)
        context.insert(SobrietyJourney(startDate: Date(timeIntervalSince1970: 1_700_000_000)))
        try context.save()
    }

    private func opener(
        _ url: URL,
        unlocked: Bool = false,
        failFirst: Int = 0,
        error: Error = CocoaError(.fileReadNoPermission),
        calls: Calls = Calls()
    ) -> LocalStoreOpener {
        var opener = DataService.storeOpener(url: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        opener.retryDelay = 0
        opener.protectedDataAvailable = { unlocked }
        opener.open = { target in
            calls.count += 1
            if calls.count <= failFirst { throw error }
            return try DataService.makeContainer(url: target)
        }
        return opener
    }

    private func setAside(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.contains(".unopenable-") || $0.contains(".corrupt-") }
    }

    @Test func aTransientFailureIsRetriedAndNothingMoves() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        let result = opener(url, unlocked: true, failFirst: 2).run()
        #expect(result.status == .opened)
        #expect(DataService.hasUserData(in: result.container))
        #expect(try setAside(in: url.deletingLastPathComponent()).isEmpty)
    }

    @Test func aLockedPhoneNeverMovesTheFileAndNeverShowsAnEmptyStore() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        let failing = opener(url, unlocked: false, failFirst: .max)
        for _ in 0..<5 {
            let result = failing.run()
            #expect(result.status == .unavailable)
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try setAside(in: url.deletingLastPathComponent()).isEmpty)
    }

    @Test func anUnlockedFailureMovesTheFileOnlyAfterThreeLaunches() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        var failing = DataService.storeOpener(url: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        failing.retryDelay = 0
        failing.protectedDataAvailable = { true }
        failing.open = { _ in throw CocoaError(.fileWriteOutOfSpace) }
        #expect(failing.run().status == .unavailable)
        #expect(failing.run().status == .unavailable)
        #expect(FileManager.default.fileExists(atPath: url.path))
        // Try Again inside a launch never adds up.
        for _ in 0..<5 { #expect(failing.run(countsAsLaunch: false).status == .unavailable) }
        #expect(try setAside(in: url.deletingLastPathComponent()).isEmpty)

        let third = failing.run()
        #expect(third.status == .unavailable)
        #expect(try setAside(in: url.deletingLastPathComponent()).count >= 1, "the third launch sets the file aside")
    }

    @Test func aProvenCorruptFileIsSetAsideAtOnceAndKept() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        let corrupt = NSError(domain: NSCocoaErrorDomain, code: 259, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: "NSSQLiteErrorDomain", code: 11)
        ])
        let result = opener(url, unlocked: false, failFirst: 3, error: corrupt).run()
        #expect(result.status == .movedAside)
        #expect(!DataService.hasUserData(in: result.container))
        #expect(try setAside(in: url.deletingLastPathComponent()).contains { $0.hasPrefix("Sober.v2.store.unopenable-") })
    }

    @Test func busyAndFullErrorsAreNotCorruption() {
        #expect(!LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 5)))
        #expect(!LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 13)))
        #expect(!LocalStoreOpener.isCorrupt(CocoaError(.fileReadNoPermission)))
        #expect(LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 26)))
        #expect(LocalStoreOpener.isCorrupt(NSError(domain: "NSSQLiteErrorDomain", code: 11 | (1 << 8))))
    }

    /// Earlier builds moved the store aside on any failure and opened an empty
    /// one. That copy is put back the first time the open store is empty.
    @Test func anEmptyStoreGetsTheSetAsideCopyBackOnce() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        let folder = url.deletingLastPathComponent()
        let suffix = ".corrupt-\(UUID().uuidString)"
        for extra in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + extra)
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            try FileManager.default.moveItem(at: file, to: URL(fileURLWithPath: file.path + suffix))
        }
        // The old build's fresh, empty store.
        _ = try DataService.makeContainer(url: url)

        let result = opener(url).run()
        #expect(result.status == .recovered)
        #expect(DataService.hasUserData(in: result.container))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(!names.contains { $0.contains(".corrupt-") }, "a copy that was put back is not offered again")
        #expect(names.contains { $0.hasPrefix("Sober.v2.store.restored-") })
    }

    @Test func aStoreWithDataIsNeverReplacedByACopy() throws {
        let url = try scratchStore()
        try writeJourney(at: url)
        let stale = try scratchStore()
        try writeJourney(at: stale)
        try FileManager.default.copyItem(at: stale, to: URL(fileURLWithPath: url.path + ".corrupt-OLD"))

        let result = opener(url).run()
        #expect(result.status == .opened)
        #expect(FileManager.default.fileExists(atPath: url.path + ".corrupt-OLD"))
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
