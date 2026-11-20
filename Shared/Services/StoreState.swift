import Foundation
import Observation
import SwiftData

/// The store every screen reads, and what happened when it was opened. While
/// the real file cannot be opened, `status` is `.unavailable` and the app shows
/// `StoreUnavailableView` instead of the empty stand-in.
@MainActor
@Observable
final class StoreState {
    static let shared = StoreState()

    /// Whether the device is unlocked. The app sets this before the store is
    /// first opened; extensions keep the default, so they never count a launch.
    nonisolated(unsafe) static var protectedDataAvailable: () -> Bool = { false }

    private(set) var container: ModelContainer
    private(set) var status: LocalStoreStatus
    /// Set when a launch set the file aside or put a copy back; the root view
    /// shows it once.
    var notice: LocalStoreStatus?

    private init() {
        let result = DataService.openStore()
        container = result.container
        status = result.status
        if result.status == .movedAside || result.status == .recovered { notice = result.status }
    }

    /// Tries the real file again. Returns true once it is open.
    @discardableResult
    func retry() -> Bool {
        guard status == .unavailable else { return true }
        let result = DataService.openStore(countsAsLaunch: false)
        guard result.status != .unavailable else { return false }
        container = result.container
        status = result.status
        if result.status == .movedAside || result.status == .recovered { notice = result.status }
        return true
    }
}
