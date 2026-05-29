import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

extension Notification.Name {
    /// Posted on the watch when a fresh snapshot arrives from the paired phone.
    static let soberWatchSnapshotUpdated = Notification.Name("com.jackwallner.sober.watchSnapshotUpdated")
}

/// Bridges the `WidgetSnapshot` from the iPhone to the watch.
///
/// App Group containers (UserDefaults suite + on-disk store) are sandboxed per
/// device, so on real hardware the watch process can't read the phone's App
/// Group — `WidgetSnapshotStore.load()` would always return `.empty` and the
/// watch app would show 0 days / Seed regardless of the real streak. The phone
/// pushes the latest snapshot via `updateApplicationContext` (latest-wins,
/// survives launches); the watch caches it into its own App Group defaults so
/// `WidgetSnapshotStore.load()` returns real data on the next cold launch too.
@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    nonisolated private static let snapshotContextKey = "snapshot"

    private override init() { super.init() }

    /// Activate the session. Call once at launch on both the phone and the watch.
    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    /// iPhone → watch: push the latest snapshot. No-op off iOS, before the
    /// session is active, or when no watch app is installed.
    func send(snapshot data: Data) {
        #if canImport(WatchConnectivity) && os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext([Self.snapshotContextKey: data])
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a newly paired watch keeps receiving snapshots.
        session.activate()
    }
    #endif

    #if os(watchOS)
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.snapshotContextKey] as? Data else { return }
        Task { @MainActor in
            guard let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return }
            WidgetSnapshotStore.save(snap)
            NotificationCenter.default.post(name: .soberWatchSnapshotUpdated, object: nil)
        }
    }
    #endif
}
#endif
