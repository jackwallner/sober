import SwiftUI

@main
struct SoberWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @State private var snapshot: WidgetSnapshot = WidgetSnapshotStore.load()

    var body: some View {
        VStack(spacing: 6) {
            Text("\(snapshot.currentStreakDays)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.brandGradient)
            Text(snapshot.currentStreakDays == 1 ? "day sober" : "days sober")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let start = snapshot.sobrietyStartDate {
                Text("since \(DateHelpers.mediumDate(start))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { snapshot = WidgetSnapshotStore.load() }
    }
}
