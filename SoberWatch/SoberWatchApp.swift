import SwiftUI

@main
struct SoberWatchApp: App {
    init() {
        WatchConnectivityService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshot: WidgetSnapshot = WidgetSnapshotStore.load()
    @State private var now = Date.now

    /// The stored streak is frozen at the last iPhone app launch. Derive the
    /// live count from the start date (1-based, matching
    /// `SobrietyService.daysSinceStart`) so the watch advances with the
    /// calendar even when the phone app hasn't been opened.
    private var days: Int {
        guard let start = snapshot.sobrietyStartDate else { return snapshot.currentStreakDays }
        return max(0, DateHelpers.daysBetween(start, now)) + 1
    }

    /// The stage badge describes the tree, so it follows the garden's day count
    /// (streak plus slip carryover) rather than the streak printed above it.
    /// Same rule as Home and the widget.
    private var treeDays: Int { snapshot.treeDays(streakDays: days) }

    private var stageTitle: String {
        let title = GardenService.stage(forDays: treeDays).title
        let completed = GardenService.cycleProgress(forDays: treeDays).completed
        return completed > 0 ? "Year \(completed + 1) · \(title)" : title
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(days)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 6)
                .foregroundStyle(Theme.brandGradient)
            Text(days == 1 ? "day sober" : "days sober")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let start = snapshot.sobrietyStartDate {
                Text("since \(DateHelpers.mediumDate(start))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Garden stage indicator
            HStack(spacing: 6) {
                Image(systemName: stageIcon)
                    .font(.caption2)
                Text(stageTitle)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .onAppear { snapshot = WidgetSnapshotStore.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
                snapshot = WidgetSnapshotStore.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .soberWatchSnapshotUpdated)) { _ in
            snapshot = WidgetSnapshotStore.load()
        }
    }

    private var stageIcon: String {
        switch GardenService.stage(forDays: treeDays).rawValue {
        case 0: return "circle"
        case 1, 2: return "leaf.fill"
        case 3, 4: return "tree.fill"
        case 5, 6: return "crown.fill"
        case 7, 8: return "star.fill"
        default: return "leaf.fill"
        }
    }
}
