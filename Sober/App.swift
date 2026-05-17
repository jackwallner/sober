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
        let settings = settingsRows.first
        let onboarded = settings?.hasCompletedOnboarding ?? false
        Group {
            if onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(colorScheme(for: settings?.appearancePreference ?? .system))
        .task { WidgetSnapshotPump.push(context: context) }
    }

    private func colorScheme(for pref: AppearancePreference) -> ColorScheme? {
        switch pref {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct MainTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "leaf.fill") }
                .tag(0)
            TimelineView()
                .tabItem { Label("Timeline", systemImage: "calendar") }
                .tag(1)
            HealthView()
                .tabItem { Label("Health", systemImage: "heart.fill") }
                .tag(2)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(3)
        }
    }
}
