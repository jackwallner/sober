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
    @State private var snapshot: WidgetSnapshot = WidgetSnapshotStore.load()

    /// The stored streak is frozen at the last iPhone app launch. Derive the
    /// live count from the start date (1-based, matching
    /// `SobrietyService.daysSinceStart`) so the watch advances with the
    /// calendar even when the phone app hasn't been opened.
    private var days: Int {
        guard let start = snapshot.sobrietyStartDate else { return snapshot.currentStreakDays }
        return max(0, DateHelpers.daysBetween(start, .now)) + 1
    }

    private var stageTitle: String {
        let title = GardenService.stage(forDays: days).title
        let completed = GardenService.cycleProgress(forDays: days).completed
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
        .onReceive(NotificationCenter.default.publisher(for: .soberWatchSnapshotUpdated)) { _ in
            snapshot = WidgetSnapshotStore.load()
        }
    }

    private var stageIcon: String {
        switch GardenService.stage(forDays: days).rawValue {
        case 0: return "circle"
        case 1, 2: return "leaf.fill"
        case 3, 4: return "tree.fill"
        case 5, 6: return "crown.fill"
        case 7, 8: return "star.fill"
        default: return "leaf.fill"
        }
    }
}
