import SwiftData
import SwiftUI

@main
struct SoberApp: App {
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(subscriptions)
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [UserSettings]

    var body: some View {
        let onboarded = settingsRows.first?.hasCompletedOnboarding ?? false
        Group {
            if onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task { WidgetSnapshotPump.push(context: context) }
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView(goToGarden: { tab = 1 })
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)
            GardenView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(1)
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(2)
            HealthView()
                .tabItem { Label("Health", systemImage: "heart.fill") }
                .tag(3)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(4)
        }
    }
}
