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

    private var stageTitle: String {
        let titles = ["Seed", "Sprout", "Seedling", "Young", "Adolescent", "Mature", "Refined", "Ancient", "Legendary"]
        let idx = snapshot.bonsaiStage
        return titles.indices.contains(idx) ? titles[idx] : "Seed"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(snapshot.currentStreakDays)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brandGradient)
            Text(snapshot.currentStreakDays == 1 ? "day sober" : "days sober")
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

            // Placed items count
            if !snapshot.placedItemIDs.isEmpty {
                Text("\(snapshot.placedItemIDs.count) garden items")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { snapshot = WidgetSnapshotStore.load() }
        .onReceive(NotificationCenter.default.publisher(for: .soberWatchSnapshotUpdated)) { _ in
            snapshot = WidgetSnapshotStore.load()
        }
    }

    private var stageIcon: String {
        switch snapshot.bonsaiStage {
        case 0: return "circle"
        case 1, 2: return "leaf.fill"
        case 3, 4: return "tree.fill"
        case 5, 6: return "crown.fill"
        case 7, 8: return "star.fill"
        default: return "leaf.fill"
        }
    }
}
