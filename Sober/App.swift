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
    ///   -seedDemo : skip onboarding with a ~3.5-week sober journey
    ///   -demoPro  : flip the local Pro override on
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

        let start = Calendar.current.date(byAdding: .day, value: -24, to: .now) ?? .now
        _ = SobrietyService(context: context).startJourney(at: start)
        _ = GardenService(context: context).current()
        CheckInService(context: context).fillJourney(start: start, through: .now)
        try? context.save()
        WidgetSnapshotPump.push(context: context)
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

    #if canImport(RevenueCat)
    private var hasDirectTrialPackage: Bool { subscriptions.directTrialPackage != nil }
    private var trialOfferLabelText: String? { subscriptions.directTrialPackage?.soberIntroOfferLabel }
    private var trialOfferPriceText: String? { subscriptions.directTrialPackage?.soberPriceLabel }

    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        guard !subscriptions.isProSubscriber else { return }
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
