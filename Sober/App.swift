import SwiftData
import SwiftUI
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps the daily-reminder notification — MainTabView
    /// switches to Home so the check-in button is right there.
    static let soberOpenCheckIn = Notification.Name("com.jackwallner.sober.openCheckIn")
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
        guard info[NotificationService.deepLinkKey] as? String == NotificationService.deepLinkCheckIn else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .soberOpenCheckIn, object: nil)
        }
    }
}

@main
struct SoberApp: App {
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
        WatchConnectivityService.shared.activate()
        ReviewPromptTracker.recordAppLaunch()
        UNUserNotificationCenter.current().delegate = NotificationTapRouter.shared
    }

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
            if phase == .active {
                Task { await SubscriptionService.shared.refreshFromServer() }
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
    @State private var tab = 0
    @State private var showTrialOffer = false
    @State private var showTrialPaywall = false
    @State private var pendingPaywallAfterTrialDismiss = false
    @State private var trialOfferFocus: BloomFeature?
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String?

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
        .onChange(of: showTrialOffer) { _, _ in syncPresentationFlag() }
        .onChange(of: showTrialPaywall) { _, _ in syncPresentationFlag() }
        .onReceive(NotificationCenter.default.publisher(for: .soberOpenCheckIn)) { _ in
            tab = 0
        }
        .onChange(of: tab) { _, newTab in
            if newTab == 4, !subscriptions.isProSubscriber {
                subscriptions.trackPaywallImpression(id: "sober_bloom_tab", oncePerSession: true)
            }
        }
        .sheet(isPresented: $showTrialOffer, onDismiss: {
            trialPurchaseInFlight = false
            trialPurchaseError = nil
            if pendingPaywallAfterTrialDismiss {
                pendingPaywallAfterTrialDismiss = false
                showTrialPaywall = true
            }
        }) {
            TrialOfferSheet(
                focus: trialOfferFocus,
                offerLabel: trialOfferLabelText,
                priceLabel: trialOfferPriceText,
                directPurchase: hasDirectTrialPackage,
                isPurchasing: trialPurchaseInFlight,
                errorMessage: trialPurchaseError,
                onStartTrial: startDirectTrialPurchase,
                onSeeAllPlans: {
                    pendingPaywallAfterTrialDismiss = true
                    showTrialOffer = false
                },
                onDismiss: { showTrialOffer = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(trialPurchaseInFlight)
        }
        .sheet(isPresented: $showTrialPaywall, onDismiss: {
            trialOfferFocus = nil
        }) {
            PaywallView(focus: trialOfferFocus, impressionId: "sober_trial_sheet")
        }
    }

    private func syncPresentationFlag() {
        trialCoordinator.isPresentingSheet = showTrialOffer || showTrialPaywall
    }

    #if canImport(RevenueCat)
    private var hasDirectTrialPackage: Bool { subscriptions.directTrialPackage != nil }
    private var trialOfferLabelText: String? { subscriptions.directTrialPackage?.soberIntroOfferLabel }
    private var trialOfferPriceText: String? { subscriptions.directTrialPackage?.soberPriceLabel }

    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        guard !subscriptions.isProSubscriber else { return }
        // A review prompt on screen wins; drop the pitch rather than stacking
        // two sheet presentations from different view layers.
        guard !ReviewPromptCoordinator.shared.isPresentingSheet else { return }
        let focus = request.intent.focusFeature

        switch request.policy {
        case .initial, .explicitUpgrade:
            presentTrialOffer(focus: focus)
        case .subsequentLocked:
            let count = TrialSubsequentPitchGate.recordAction(for: request.intent)
            if count >= TrialSubsequentPitchGate.lockedFeatureThreshold,
               subscriptions.hasTrialOfferAvailable,
               TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent) {
                TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
                presentTrialOffer(focus: focus)
            } else {
                trialOfferFocus = focus
                showTrialPaywall = true
            }
        case .subsequentPassive:
            guard subscriptions.hasTrialOfferAvailable,
                  TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent)
            else {
                trialOfferFocus = focus
                showTrialPaywall = true
                return
            }
            TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
            presentTrialOffer(focus: focus)
        }
    }

    private func presentTrialOffer(focus: BloomFeature?) {
        guard !subscriptions.isProSubscriber, subscriptions.hasTrialOfferAvailable else {
            trialOfferFocus = focus
            showTrialPaywall = true
            return
        }
        trialOfferFocus = focus
        showTrialOffer = true
    }

    private func startDirectTrialPurchase() {
        guard let package = subscriptions.directTrialPackage else {
            pendingPaywallAfterTrialDismiss = true
            showTrialOffer = false
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    showTrialOffer = false
                case .pending:
                    showTrialOffer = false
                case .cancelled:
                    trialPurchaseError = "Trial start cancelled. Tap again to continue."
                }
            } catch {
                trialPurchaseError = "Couldn't start your trial. Please try again."
            }
        }
    }
    #else
    private var hasDirectTrialPackage: Bool { false }
    private var trialOfferLabelText: String? { nil }
    private var trialOfferPriceText: String? { nil }

    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        trialOfferFocus = request.intent.focusFeature
        showTrialPaywall = true
    }

    private func presentTrialOffer(focus: BloomFeature?) {
        trialOfferFocus = focus
        showTrialPaywall = true
    }

    private func startDirectTrialPurchase() {}
    #endif
}
