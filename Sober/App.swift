import SwiftData
import SwiftUI

@main
struct SoberApp: App {
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
        WatchConnectivityService.shared.activate()
        ReviewPromptTracker.recordAppLaunch()
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
    @Environment(\.scenePhase) private var scenePhase
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
        .tint(Theme.brandPrimary)
        // The D1 "Slow morning" theme is a fixed warm-light brand: surfaces are
        // hardcoded cream/ink, so system dark mode only darkens the chrome
        // (lists, pickers, sheets, tab bar) and clashes. Lock to light.
        .preferredColorScheme(.light)
        .task { WidgetSnapshotPump.push(context: context) }
        // Re-check entitlements on every foreground (not just cold launch) so a
        // renewal, restore, or server-delayed grant flips the app to Pro
        // promptly — matches Vitals' willEnterForeground refresh.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SubscriptionService.shared.refreshFromServer() }
            }
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
