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
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "leaf.fill") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            HealthView()
                .tabItem { Label("Health", systemImage: "heart.fill") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
