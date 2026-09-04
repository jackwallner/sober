import SwiftData
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps the daily-reminder notification — MainTabView
    /// switches to Home so the check-in button is right there.
    static let soberOpenCheckIn = Notification.Name("com.jackwallner.sober.openCheckIn")
    /// Posted when the user taps the trial-ending reminder. Lands on Bloom+ so
    /// they can see what they'd keep before deciding.
    static let soberOpenBloomPlus = Notification.Name("com.jackwallner.sober.openBloomPlus")
}

/// Routes notification taps. Without a delegate, tapping the daily reminder
/// just foregrounds the app on whatever tab was last open. Stateless, so the
/// unchecked-Sendable shared instance is safe.
final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationTapRouter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        switch info[NotificationService.deepLinkKey] as? String {
        case NotificationService.deepLinkCheckIn:
            await MainActor.run {
                NotificationCenter.default.post(name: .soberOpenCheckIn, object: nil)
            }
        case NotificationService.deepLinkBloomPlus:
            await MainActor.run {
                NotificationCenter.default.post(name: .soberOpenBloomPlus, object: nil)
            }
        default:
            return
        }
    }
}

@main
struct SoberApp: App {
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
        #if DEBUG
        Self.loadPreviewStoreIfRequested()
        #endif
        WatchConnectivityService.shared.activate()
        ReviewPromptTracker.recordAppLaunch()
        ConversionDiagnostics.recordAppOpen()
        #if DEBUG
        if RevenueCatProbe.isEnabled {
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            SubscriptionService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationTapRouter.shared
    }

    #if DEBUG
    /// `-previewStore [-previewTrialDays N]` loads a local offering so the real
    /// paywall renders on a headless simulator. Without it the simulator has no
    /// RevenueCat packages at all (see `PaywallPreviewStore`) and every
    /// store-derived string falls back to the dev placeholder, which is how a
    /// hardcoded "7 days free" survived in the yearly card for three releases.
    private static func loadPreviewStoreIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-previewStore") else { return }
        var days = 7
        if let index = args.firstIndex(of: "-previewTrialDays"),
           index + 1 < args.count,
           let parsed = Int(args[index + 1]) {
            days = parsed
        }
        SubscriptionService.shared.loadPreviewStore(
            trialDays: days,
            introEligible: !args.contains("-previewTrialUsed")
        )
    }
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = PaywallScreenshotMode.current {
                PaywallScreenshotHarness(mode: mode)
                    .environment(subscriptions)
            } else {
                RootView()
                    .environment(subscriptions)
            }
            #else
            RootView()
                .environment(subscriptions)
            #endif
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
        .preferredColorScheme(.light)
        .task { WidgetSnapshotPump.push(context: context) }
        #if DEBUG
        .task { seedDemoIfRequested() }
        #endif
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await SubscriptionService.shared.refreshFromServer() }
            case .background:
                // Sync on the way out, not on the way in: the funnel events that
                // matter (trial step seen, CTA tapped, free version chosen) all
                // happen after launch, so a foreground-only push would always be
                // one session stale, and for a user who never comes back it
                // would never arrive at all.
                #if canImport(RevenueCat)
                Task { await SubscriptionService.shared.syncConversionAttributes() }
                #endif
            default:
                break
            }
        }
    }

    #if DEBUG
    /// Launch-argument seeding for screenshots and to bypass UI-automation
    /// blockers (the onboarding wheel picker wedges the AX bridge). DEBUG only,
    /// never compiled into Release — no path to end users.
    ///   -seedDemo   : skip onboarding with a sober journey (24 days by default)
    ///   -seedDays N : override the journey length — App Store frames use 127 so
    ///                 the counter, calendar, health timeline, and money/calories
    ///                 saved all derive from one number and can't contradict
    ///                 each other the way the hand-captured 1.1.4 frames did
    ///   -demoPro    : flip the local Pro override on
    private func seedDemoIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoPro") {
            SubscriptionService.shared.setLocalOverride(isPro: true)
        }
        guard args.contains("-seedDemo"),
              !(settingsRows.first?.hasCompletedOnboarding ?? false) else { return }

        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = 2000
        settings.caloriesPerDay = 600
        settings.madeCommitment = true
        settings.hasCompletedOnboarding = true

        var days = 24
        if let index = args.firstIndex(of: "-seedDays"),
           index + 1 < args.count,
           let parsed = Int(args[index + 1]), parsed > 0 {
            days = parsed
        }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        _ = SobrietyService(context: context).startJourney(at: start)
        _ = GardenService(context: context).current()
        CheckInService(context: context).fillJourney(start: start, through: .now)
        seedJournal(start: start)
        try? context.save()
        WidgetSnapshotPump.push(context: context)
    }

    /// Journal renders an empty state until entries exist, which makes for a
    /// dead App Store frame. Seed a few so the tab shows the feature working.
    private func seedJournal(start: Date) {
        let entries: [(daysAgo: Int, text: String, feeling: String)] = [
            (1, "Went to Dan's birthday and stayed with soda water the whole night. Nobody cared. I drove myself home and woke up clear.", "good"),
            (6, "Rough day at work and the old reflex showed up around 6pm. Went for a walk instead. It passed in about twenty minutes.", "neutral"),
            (13, "Slept a full eight hours for the first time in years. That alone is worth it.", "excellent"),
        ]
        for entry in entries {
            let date = Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: .now) ?? .now
            guard date >= start else { continue }
            context.insert(
                JournalEntry(createdAt: date, kind: .daily, text: entry.text, feeling: entry.feeling)
            )
        }
    }
    #endif
}

struct MainTabView: View {
    @Environment(SubscriptionService.self) private var subscriptions
    @StateObject private var trialCoordinator = TrialOfferCoordinator.shared
    @StateObject private var reviewCoordinator = ReviewPromptCoordinator.shared
    #if DEBUG
    /// `-tab N` opens straight onto a tab. The Bloom+ paywall only lays out the
    /// way a user sees it when the tab bar is eating the bottom of the screen,
    /// and there is no other way to get there on a headless simulator.
    private static var launchTab: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-tab"),
              index + 1 < args.count,
              let parsed = Int(args[index + 1]) else { return 0 }
        return parsed
    }
    @State private var tab = MainTabView.launchTab
    #else
    @State private var tab = 0
    #endif
    @State private var showTrialPaywall = false
    @State private var trialOfferFocus: BloomFeature?
    @State private var deferredTrialPitch: TrialOfferCoordinator.PendingRequest?

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
            BloomPlusTabView()
                .tabItem {
                    Label(
                        subscriptions.isProSubscriber ? "Bloom+" : "Upgrade",
                        systemImage: subscriptions.isProSubscriber ? "sparkles" : "lock.fill"
                    )
                }
                .tag(4)
        }
        .onChange(of: trialCoordinator.pendingRequest) { _, request in
            guard let request else { return }
            trialCoordinator.clear()
            handleTrialPitch(request)
        }
        .onChange(of: showTrialPaywall) { _, _ in syncPresentationFlag() }
        .onChange(of: reviewCoordinator.isPresentingSheet) { _, presenting in
            guard !presenting, let pitch = deferredTrialPitch else { return }
            deferredTrialPitch = nil
            Task { @MainActor in
                // Let the review sheet finish dismissing before a second sheet
                // asks to present, or UIKit drops the new one on the floor.
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !ReviewPromptCoordinator.shared.isPresentingSheet,
                      !showTrialPaywall else { return }
                handleTrialPitch(pitch)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .soberOpenCheckIn)) { _ in
            tab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .soberOpenBloomPlus)) { _ in
            tab = 4
        }
        .onChange(of: tab) { _, newTab in
            if newTab == 4, !subscriptions.isProSubscriber {
                subscriptions.trackPaywallImpression(id: "sober_bloom_tab", oncePerSession: true)
            }
        }
        .sheet(isPresented: $showTrialPaywall, onDismiss: {
            trialOfferFocus = nil
        }) {
            PaywallView(
                focus: trialOfferFocus,
                impressionId: paywallImpressionId(for: trialOfferFocus)
            )
        }
    }

    private func syncPresentationFlag() {
        trialCoordinator.isPresentingSheet = showTrialPaywall
    }

    #if canImport(RevenueCat)
    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        guard !subscriptions.isProSubscriber else { return }
        // A review prompt on screen wins, but hold the pitch instead of dropping
        // it: the coordinator's request is already cleared by the time we get
        // here, so returning threw the only trial offer that user was ever going
        // to see. Re-runs when the review sheet goes away.
        guard !ReviewPromptCoordinator.shared.isPresentingSheet else {
            deferredTrialPitch = request
            return
        }
        let focus = request.intent.focusFeature

        switch request.policy {
        case .initial, .explicitUpgrade:
            presentPaywall(focus: focus)
        case .subsequentLocked:
            let count = TrialSubsequentPitchGate.recordAction(for: request.intent)
            if count >= TrialSubsequentPitchGate.lockedFeatureThreshold,
               TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent) {
                TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
            }
            presentPaywall(focus: focus)
        case .subsequentPassive:
            guard TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent) else { return }
            TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
            presentPaywall(focus: focus)
        }
    }

    private func presentPaywall(focus: BloomFeature?) {
        trialOfferFocus = focus
        showTrialPaywall = true
    }
    #else
    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        trialOfferFocus = request.intent.focusFeature
        showTrialPaywall = true
    }
    #endif

    private func paywallImpressionId(for focus: BloomFeature?) -> String {
        switch focus {
        case .patterns: "sober_paywall_patterns"
        case .gardenSpecies: "sober_paywall_garden"
        case .healthTimeline: "sober_paywall_health"
        case .journal: "sober_paywall_journal"
        case .savingsTracking: "sober_paywall_savings"
        case nil: "sober_paywall_general"
        }
    }
}
