import Foundation
import Testing
@testable import Sober

@Suite("A burst of note edits saves once")
@MainActor
struct DebouncedActionTests {
    @Test func tenKeystrokesRunTheSaveOnce() async throws {
        let debounce = DebouncedAction(delay: .milliseconds(60))
        var saves = 0
        for _ in 0..<10 { debounce.schedule { saves += 1 } }
        #expect(saves == 0)
        try await Task.sleep(for: .milliseconds(250))
        #expect(saves == 1)
    }

    @Test func flushRunsAWaitingSaveNowAndOnlyOnce() async throws {
        let debounce = DebouncedAction(delay: .milliseconds(60))
        var saves = 0
        debounce.schedule { saves += 1 }
        debounce.flush()
        #expect(saves == 1)
        try await Task.sleep(for: .milliseconds(250))
        #expect(saves == 1)
        debounce.flush()
        #expect(saves == 1)
    }
}
