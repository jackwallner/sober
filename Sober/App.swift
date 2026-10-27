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

    // Completion handler form, answered on the main thread. The async form's
    // compiler-made thunk calls UIKit's handler from a background thread, and
    // UIKit asserts the main thread there, so a tap could abort the app (the
    // crash Baby build 66 and Recharge build 39 shipped).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let name: Notification.Name?
        switch info[NotificationService.deepLinkKey] as? String {
        case NotificationService.deepLinkCheckIn: name = .soberOpenCheckIn
        case NotificationService.deepLinkBloomPlus: name = .soberOpenBloomPlus
        default: name = nil
        }
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            if let name { NotificationCenter.default.post(name: name, object: nil) }
            done()
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
            if RevenueCatProbe.wantsPurchase {
                Task {
                    await SubscriptionService.shared.fetchProducts()
                    // Logged rather than asserted: when the Test Store sheet
                    // never appears, this separates "no packages came back"
                    // from "purchase threw".
                    NSLog("RCPROBE packages=%d", SubscriptionService.shared.packages.count)
                    guard let package = SubscriptionService.shared.packages.first else { return }
                    do {
                        let outcome = try await SubscriptionService.shared.purchase(package)
                        NSLog("RCPROBE purchase outcome=%@", String(describing: outcome))
                    } catch {
                        NSLog("RCPROBE purchase error=%@", String(describing: error))
                    }
                }
            }
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationTapRouter.shared
        // Before any view can run `fillJourney`, or this build's assumed rows
        // would be marked tended along with the legacy ones.
        CheckInService.migrateLegacyCheckInsIfNeeded(
            context: DataService.sharedModelContainer.mainContext
        )
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
    @State private var saveFailures = SaveFailureReporter.shared
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
        .alert(
            "Not saved",
            isPresented: Binding(
                get: { saveFailures.message != nil },
                set: { if !$0 { saveFailures.message = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveFailures.message = nil }
        } message: {
            Text(saveFailures.message ?? "")
        }
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
    ///   -seedGoal N : set a 30/90/365-day goal on the seeded journey
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
           let parsed = Int(args[index + 1]), parsed >= 0 {
            days = parsed
        }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let journey = SobrietyService(context: context).startJourney(at: start)
        // -seedGoal N: a goal N days from the start, as onboarding would set.
        if let index = args.firstIndex(of: "-seedGoal"),
           index + 1 < args.count,
           let goalDays = Int(args[index + 1]),
           let preset = GoalPreset(rawValue: goalDays) {
            journey.goalDate = preset.date(from: start)
        }
        // A user this far in has already seen each stage's celebration; left at
        // zero, the first Home appearance replays one over the screen.
        GardenService(context: context).current().lastUnlockNotifiedAtDays = days + 1
        CheckInService(context: context).fillJourney(start: start, through: .now)
        // Badges are otherwise earned when Home appears, so a capture that opens
        // on another tab showed none. The counter is 1-based (start day is Day 1).
        AchievementService(context: context).processUnlocks(currentDays: days + 1)
        seedJournal(start: start)
        try? context.save()
        WidgetSnapshotPump.push(context: context)
    }

    /// Journal renders an empty state until entries exist, which makes for a
    /// dead App Store frame. Seed a few so the tab shows the feature working.
    private func seedJournal(start: Date) {
        let entries: [(daysAgo: Int, text: String, feeling: String)] = [
            (1, String(localized: "Went to Dan's birthday and stayed with soda water the whole night. Nobody cared. I drove myself home and woke up clear."), "good"),
            (6, String(localized: "Rough day at work and the old reflex showed up around 6pm. Went for a walk instead. It passed in about twenty minutes."), "neutral"),
            (13, String(localized: "Slept a full eight hours for the first time in years. That alone is worth it."), "excellent"),
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

private struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?
}

struct MainTabView: View {
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var trialCoordinator = TrialOfferCoordinator.shared
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

    /// `-tourTab N` switches to tab N nine seconds after launch, so a Duo
    /// recording shows a real tab change before the screenshot.
    private func runTourTabIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-tourTab"),
              index + 1 < args.count,
              let target = Int(args[index + 1]) else { return }
        try? await Task.sleep(for: .seconds(9))
        tab = target
    }
    #else
    @State private var tab = 0
    #endif
    @State private var showTrialPaywall = false
    @State private var trialOfferFocus: BloomFeature?
    /// The container's width and fold, measured so the unfolded iPhone Duo can
    /// put the tabs and Timeline on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry()
    /// Set the first time the Duo unfolds and never cleared, so folding only
    /// moves frames and the Timeline pane keeps its selected day. Ordinary
    /// iPhones never build it.
    @State private var timelinePaneHasAppeared = false

    /// Unfolded, Timeline has its own pane beside the tabs, so it is never a tab.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tabs
                .environment(\.horizontalSizeClass, paneSizeClass)
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            if timelinePaneHasAppeared {
                TimelineView(isPane: true)
                    .clearsFloatingTabBar(split != nil, backdrop: Color(.systemGroupedBackground))
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(maxWidth: split?.secondaryWidth ?? .infinity, maxHeight: .infinity)
                    .padding(.leading, split?.secondaryX ?? 0)
                    .opacity(split == nil ? 0 : 1)
                    .allowsHitTesting(split != nil)
                    .accessibilityHidden(split == nil)
            }
        }
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .onChange(of: split != nil, initial: true) { _, isSplit in
            guard isSplit else { return }
            timelinePaneHasAppeared = true
            if tab == 1 { tab = 0 }
        }
        #if DEBUG
        .task { await runTourTabIfRequested() }
        #endif
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            HomeView()
                .leadingPaneTab(isSplit: split != nil)
                .tabItem { Label("Home", systemImage: "leaf.fill") }
                .tag(0)
            if split == nil {
                TimelineView()
                    .tabItem { Label("Timeline", systemImage: "calendar") }
                    .tag(1)
            }
            HealthView()
                .leadingPaneTab(isSplit: split != nil)
                .tabItem { Label("Health", systemImage: "heart.fill") }
                .tag(2)
            JournalView()
                .leadingPaneTab(isSplit: split != nil)
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(3)
            BloomPlusTabView()
                .leadingPaneTab(isSplit: split != nil)
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
        case .goalProjection: "sober_paywall_goal"
        case .urgePlaybook: "sober_paywall_playbook"
        case .gardenSpecies: "sober_paywall_garden"
        case .healthTimeline: "sober_paywall_health"
        case .journal: "sober_paywall_journal"
        case .savingsTracking: "sober_paywall_savings"
        case nil: "sober_paywall_general"
        }
    }
}

private extension View {
    /// A tab in the leading pane: phone bars, and nothing under the floating
    /// tab bar while split. Folded, both are the system default.
    func leadingPaneTab(isSplit: Bool) -> some View {
        horizontalBarsInPane(isSplit)
            .clearsFloatingTabBar(isSplit)
            .environment(\.isUnfoldedPane, isSplit)
    }
}
