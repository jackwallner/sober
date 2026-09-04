import SwiftData
import StoreKit
import SwiftUI

/// Home: the garden IS the home. A full-bleed, explorable scene with the day
/// counter, check-in, and growth surfaced as overlays on top of it. Replaces
/// the old separate Today + Garden tabs.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var gardenStates: [GardenState]
    @Query private var settingsRows: [UserSettings]

    @State private var showResetAlert = false
    @State private var showSlipSheet = false
    @State private var showCraving = false
    @State private var bestStreak = 0
    @State private var lifetimeSoberDays = 0
    @State private var week: [TendedDay] = []
    @State private var todayWasSlip = false
    @State private var checkedInToday = false
    @State private var daysMissed = 0
    @State private var showSettings = false
    @State private var showCustomize = false
    @State private var showProgress = false
    @State private var growthEvent: GardenGrowthEvent?
    @State private var showGrowth = false
    @State private var showCheckInDetail = false
    @State private var showReviewPrompt = false
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
    @State private var showTrialRecap = false
    @State private var postOnboardingPaywallTask: Task<Void, Never>?
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @Environment(\.requestReview) private var requestReview

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
    private var hasCompletedOnboarding: Bool { settingsRows.first?.hasCompletedOnboarding ?? false }
    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = activeJourney else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var isPro: Bool { subscriptions.isProSubscriber }
    /// The day count the tree is drawn at. Equal to `days` until the user's
    /// first slip, after which it also carries the growth the previous tree
    /// handed down. The counter above the garden always shows the honest
    /// streak; only the tree inherits.
    private var treeDays: Int {
        GardenService.treeDays(streakDays: days, carryover: gardenState?.carryoverDays ?? 0)
    }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: treeDays).dayInCycle }
    private var stage: BonsaiStage { GardenService.stage(forDays: treeDays) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if !showGrowth {
                    VStack(spacing: Theme.Space.l) {
                        trialRecapBanner
                        counterHeader
                        gardenCard
                        checkInControl
                        cravingControl
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.top, Theme.Space.s)
                    .padding(.bottom, Theme.Space.m)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProgress = true } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .accessibilityLabel("Progress")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showCustomize = true } label: {
                            Label("Customize garden", systemImage: "paintbrush.pointed")
                        }
                        Button { showSettings = true } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Divider()
                        // A slip is an ordinary, non-destructive entry: it is
                        // logged, and the tree and the history survive it. The
                        // destructive item below is the other thing entirely,
                        // for someone who set the counter up wrong.
                        Button { showSlipSheet = true } label: {
                            Label("I slipped", systemImage: "arrow.uturn.backward")
                        }
                        Button(role: .destructive) { showResetAlert = true } label: {
                            Label("Reset counter", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
            .alert("Reset sobriety counter?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    SobrietyService(context: context).reset()
                    GardenService(context: context).resetForNewJourney()
                    refreshCheckInState()
                    WidgetSnapshotPump.push(context: context)
                }
            } message: {
                Text("Your day counter will restart at zero. Your history is kept.")
            }
            .onAppear {
                GardenService(context: context).applyVitalityDecay()
                if let j = activeJourney {
                    // Backfill only through yesterday so today stays unlogged and
                    // the active "Check in for today" control is reachable (auto-
                    // filling today would always render the "Today is logged"
                    // state before the user ever taps).
                    CheckInService(context: context).fillJourney(start: j.startDate, through: DateHelpers.daysAgo(1))
                }
                refreshCheckInState()
                checkForGrowth()
                WidgetSnapshotPump.push(context: context)
                refreshReminderCopy()
                scheduleRetentionNudges()
                refreshTrialRecap()
                presentPostOnboardingPaywallIfNeeded()
                #if DEBUG
                // The pool devices' accessibility bridge is unreliable, so the
                // sheets that can't be reached by `axe tap` get a launch
                // argument, same as -seedDemo. DEBUG only.
                if ProcessInfo.processInfo.arguments.contains("-showProgress") {
                    showProgress = true
                }
                #endif
            }
            .task { await presentPassiveTrialNudge(subscriptions, intent: .postOnboarding, delay: 6) }
            .overlay {
                if showGrowth, let event = growthEvent {
                    GrowthCelebrationView(
                        event: event,
                        style: GardenSceneView.styleEnum(for: gardenState?.activeBonsaiStyleID ?? GardenItemCatalog.freeSpeciesID),
                        dayInCycle: dayInCycle
                    ) {
                        withAnimation { showGrowth = false }
                        growthEvent = nil
                        WidgetSnapshotPump.push(context: context)
                        recordPositiveMomentForReview(isMilestone: true)
                        presentPostOnboardingPaywallIfNeeded()
                        scheduleTrialPitchAfterGrowthCelebration()
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .sheet(isPresented: $showCheckInDetail) {
                CheckInDetailSheet()
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showSlipSheet) {
                SlipSheet(currentStreakDays: days) {
                    refreshCheckInState()
                    checkedInToday = CheckInService(context: context).hasCheckedIn()
                }
            }
            .fullScreenCover(isPresented: $showCraving) {
                CravingModeView { outcome in
                    handleCravingFinished(outcome)
                }
            }
            .sheet(isPresented: $showCustomize) { GardenCustomizationView() }
            .sheet(isPresented: $showProgress) {
                ProgressSheet(days: days, gardenState: gardenState, isPro: isPro)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showReviewPrompt, onDismiss: {
                if pendingNativeReviewAfterDismiss {
                    pendingNativeReviewAfterDismiss = false
                    requestReview()
                }
            }) {
                ReviewPromptSheet(initialStep: reviewPromptInitialStep, onFinish: handleReviewPromptFinish)
            }
            .onReceive(NotificationCenter.default.publisher(for: .soberPositiveMomentForReview)) { _ in
                scheduleReviewPromptAfterPositiveMoment()
            }
            .onChange(of: showReviewPrompt) { _, presented in
                ReviewPromptCoordinator.shared.isPresentingSheet = presented
            }
            .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
                guard let presentation else { return }
                defer { reviewPromptCoordinator.clear() }
                guard !showGrowth else { return }
                showSettings = false
                switch presentation {
                case .enjoymentPrompt:
                    presentReviewPrompt(step: .enjoyment)
                case .feedbackOnly:
                    presentReviewPrompt(step: .feedback)
                }
            }
        }
    }

    // MARK: - Counter + garden

    /// Day counter on the cream chrome — ink/moss text on the app background,
    /// not white-on-garden. Sits above the garden card so the big numeral is
    /// always legible regardless of the scene's brightness.
    private var counterHeader: some View {
        VStack(spacing: 0) {
            Text("\(days)")
                .font(Theme.bigNumber(80))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.brandPrimary)
                .accessibilityLabel("\(days) \(days == 1 ? "day" : "days") sober")
            Text(days == 1 ? "Day Sober" : "Days Sober")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
            if let history = historyLine {
                Text(history)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The record behind the current run. Hidden on a first, unbroken journey,
    /// where "best 12, 12 days logged" only restates the number above it; it
    /// appears once there is history the counter alone does not show, which in
    /// practice is the moment after a slip, when it matters most.
    private var historyLine: String? {
        guard bestStreak > days || lifetimeSoberDays > days else { return nil }
        var parts: [String] = []
        if bestStreak > days { parts.append("Best \(bestStreak)") }
        if lifetimeSoberDays > days { parts.append("\(lifetimeSoberDays) days logged") }
        return parts.joined(separator: " · ")
    }

    /// The garden, framed as a card that claims all the vertical space between
    /// the counter and the CTA. The scene fits the bonsai to whatever height it
    /// gets (see `BonsaiView(fill:)`), so expanding the card grows the tree
    /// rather than opening a dead sky band. A content-driven floor keeps a
    /// sparse early garden generous while a rich one (placed items, a grove)
    /// pushes for even more room.
    private var gardenCard: some View {
        PannableGardenView(
            days: treeDays,
            vitality: gardenState?.vitality ?? 1.0,
            activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? GardenItemCatalog.freeSpeciesID,
            isPro: isPro,
            completedTreeStyles: gardenState?.completedTreeStyles ?? [],
            onSwapBonsai: { showCustomize = true }
        )
        .frame(maxWidth: .infinity, minHeight: gardenMinHeight, maxHeight: .infinity)
        .layoutPriority(1)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.ringTrack, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    /// How much "stuff" is in the garden — completed trees in the grove.
    /// Drives the card's minimum height so the real estate scales with content.
    private var gardenContentScore: Int {
        gardenState?.completedTreeStyles.count ?? 0
    }

    /// The craving control below the check-in row costs about 54pt including
    /// its gap. Home does not scroll, so that has to come out of somewhere;
    /// taking it off the garden's floor keeps the vertical budget exactly
    /// where it was on the smallest supported screen rather than pushing the
    /// CTA under the tab bar.
    private var gardenMinHeight: CGFloat {
        let stageBoost: CGFloat = stage == .seed ? 0 : 60
        return 246 + stageBoost + min(120, CGFloat(gardenContentScore) * 16)
    }

    /// Final-stretch heads-up while a Bloom+ trial is running. Leads with what
    /// the trial has been worth so the decision is about value, not about a
    /// charge appearing out of nowhere.
    @ViewBuilder
    private var trialRecapBanner: some View {
        if showTrialRecap, let remaining = TrialLifecycle.daysRemaining() {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining == 1 ? "Your Bloom+ trial ends tomorrow" : "Your Bloom+ trial ends in \(remaining) days")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(trialRecapDetail)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    TrialLifecycle.dismissRecap()
                    withAnimation { showTrialRecap = false }
                } label: {
                    Text("Got it")
                        .font(Theme.caption(weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.brandPrimary)
                .controlSize(.small)
            }
            .padding(12)
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.brandPrimary.opacity(0.28), lineWidth: 1)
            )
            .transition(.opacity)
        }
    }

    private var trialRecapDetail: String {
        if let summary = TrialLifecycle.recapSummary {
            return "\(summary) Cancel any time in Settings."
        }
        return "Keep your full garden, journal, and savings, or cancel any time in Settings."
    }

    @ViewBuilder
    private var checkInControl: some View {
        if !checkedInToday && daysMissed > 1 {
            VStack(spacing: 8) {
                Text("Welcome back. You haven't checked in for \(daysMissed) days. Still going strong?")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button {
                        let svc = CheckInService(context: context)
                        svc.backfillSoberDays()
                        GardenService(context: context).water()
                        refreshCheckInState()
                        WidgetSnapshotPump.push(context: context)
                        recordPositiveMomentForReview(isMilestone: isTimeMilestoneDay)
                        scheduleRetentionNudges()
                        recordCheckInForTrialPitch()
                    } label: {
                        Label("Still sober", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)

                    Button {
                        showSlipSheet = true
                    } label: {
                        Text("I slipped")
                            .fontWeight(.medium)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18).stroke(Theme.ringTrack, lineWidth: 1)
            )
        } else if todayWasSlip {
            // `checkedInToday` only means "the user logged something today",
            // and a slip is something. Falling through to the card below had
            // Home congratulating people with a green tick and a watered
            // bonsai on the day they told it they drank.
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today is logged as a slip")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your tree kept its growth. Day one starts now.")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.ringTrack, lineWidth: 1)
            )
        } else if checkedInToday {
            // After check-in, show what the action actually accomplished rather
            // than a static "done" pill, so the tap feels consequential.
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandPrimary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today is logged")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    // The tap's receipt. A day counter would have said the same
                    // thing whether or not the user ever opened the app, so the
                    // confirmation shows the one record that only exists
                    // because they did.
                    HStack(spacing: Theme.Space.s) {
                        WeekStripView(days: week)
                        Text(TendedWeek.compactSummary(week))
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button { showCheckInDetail = true } label: {
                    Text("Add note")
                        .font(Theme.caption(weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.brandPrimary)
                .controlSize(.small)
            }
            .padding(14)
            .background(Theme.checkInDoneFill, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.brandPrimary.opacity(0.28), lineWidth: 1)
            )
        } else {
            Button {
                CheckInService(context: context).checkIn()
                GardenService(context: context).water()
                refreshCheckInState()
                WidgetSnapshotPump.push(context: context)
                recordPositiveMomentForReview(isMilestone: isTimeMilestoneDay)
                scheduleRetentionNudges()
                recordCheckInForTrialPitch()
                showCheckInDetail = true
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                        Text("Check in for today")
                            .fontWeight(.semibold)
                    }
                    Text("Log today sober and water your bonsai")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AnyShapeStyle(Theme.brandPrimary), in: Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// The only control on Home that is for a bad moment rather than a good
    /// one, and the only reason to open this app when nothing has gone right.
    /// Free, ungated, and always present: the check-in above it can be done
    /// once a day, but an urge does not schedule itself.
    private var cravingControl: some View {
        Button { showCraving = true } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "wind")
                    .font(Theme.body(weight: .semibold))
                    .foregroundStyle(Theme.brandPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("I'm having a \(HabitVocabulary.urgeNoun)")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(CravingCoach.buttonSubtitle)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.cardSurface, in: Capsule())
            .overlay(Capsule().stroke(Theme.ringTrack, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - State

    private func refreshCheckInState() {
        let svc = CheckInService(context: context)
        checkedInToday = svc.hasCheckedIn()
        todayWasSlip = svc.loggedSlip()
        daysMissed = svc.daysSinceLastCheckIn()
        lifetimeSoberDays = svc.lifetimeSoberDayCount()
        bestStreak = SobrietyService(context: context).longestStreakDays()
        week = TendedWeek.days(
            facts: svc.facts(from: DateHelpers.daysAgo(TendedWeek.length - 1), to: .now)
        )
    }

    /// Riding out an urge is the single highest-intent moment this app has:
    /// the user just used it for something hard and it worked. The review and
    /// trial prompts both key off that, on the same gated schedule as every
    /// other positive moment so it can't turn into a shakedown.
    private func handleCravingFinished(_ outcome: CravingOutcome) {
        WidgetSnapshotPump.push(context: context)
        refreshCheckInState()
        guard outcome == .rodeItOut else { return }
        recordPositiveMomentForReview()
        guard !isPro else { return }
        let count = TrialSubsequentPitchGate.incrementPersistedCount(key: AppGroup.cravingRodeOutCountKey)
        Task {
            await evaluateUsageBasedTrialPitch(
                subscriptions,
                intent: .cravingRelief,
                usageCount: count,
                threshold: 2,
                delay: 3
            )
        }
    }

    private func checkForGrowth() {
        let svc = GardenService(context: context)
        svc.processCycleCompletions(days: days)
        var event = svc.processGrowthEvents(days: treeDays)
        AchievementService(context: context).processUnlocks(currentDays: days)
        guard event != nil else { return }
        if case .treeCompleted = event {
            // The event counts this journey's cycles; the grove also holds
            // trees from before any reset. Celebrate the lifetime total so
            // the message matches the garden's "N trees grown" badge.
            event = .treeCompleted(total: svc.current().completedTreeStyles.count)
        }
        growthEvent = event
        withAnimation { showGrowth = true }
    }

    /// One-shot paywall on the first Home arrival after onboarding — the day-0
    /// moment where most trial decisions happen. The flag survives until it's
    /// actually presented (a growth celebration on first launch defers it to
    /// its own dismissal), then clears for good.
    private func presentPostOnboardingPaywallIfNeeded() {
        guard AppGroup.defaults.bool(forKey: AppGroup.postOnboardingPaywallKey) else { return }
        guard !isPro else {
            AppGroup.defaults.set(false, forKey: AppGroup.postOnboardingPaywallKey)
            return
        }
        // The in-view latch only dedupes the delay task (onAppear fires again on
        // every tab switch). The persisted flag is what makes this one-shot, and
        // it is consumed below, at the moment the pitch is actually requested.
        guard !showGrowth, postOnboardingPaywallTask == nil else { return }
        postOnboardingPaywallTask = Task { @MainActor in
            defer { postOnboardingPaywallTask = nil }
            try? await Task.sleep(nanoseconds: 700_000_000)
            // Clearing the flag before this guard burned the day-0 paywall for
            // good whenever a growth celebration or review prompt landed inside
            // the delay window, which 1.2.5's lower review thresholds made a
            // regular event. Leaving it set retries on the next Home arrival.
            guard !showGrowth, !showReviewPrompt else { return }
            AppGroup.defaults.set(false, forKey: AppGroup.postOnboardingPaywallKey)
            // Start the passive-nudge cooldown here so the day-0 popup and the
            // Home/Timeline/Health passive nudges don't fire back-to-back.
            TrialNudgeGate.markShown()
            TrialOfferCoordinator.shared.request(.postOnboarding, policy: .initial)
        }
    }

    /// Keep the daily reminder's streak copy current. No-ops unless a reminder
    /// is already pending, so it never resurrects one the user disabled.
    private func refreshReminderCopy() {
        guard let s = settingsRows.first, s.dailyReminderEnabled else { return }
        let hour = s.dailyReminderHour
        let committed = s.madeCommitment
        let streak = days
        Task {
            await NotificationService.refreshDailyReminder(hour: hour, committed: committed, streakDays: streak)
        }
    }

    /// Milestone-eve and lapse nudges ride on the daily-reminder opt-in, so a
    /// user who turned reminders off never gets them. Rescheduled on every Home
    /// appearance and check-in: the lapse nudge is a rolling timer that only
    /// fires for someone who stopped returning.
    private func scheduleRetentionNudges() {
        guard let s = settingsRows.first, s.dailyReminderEnabled else { return }
        let hour = s.dailyReminderHour
        let current = days
        let next = AchievementCatalog.nextTimeMilestone(after: current)
        Task {
            await NotificationService.scheduleLapseNudge(streakDays: current)
            if let next {
                await NotificationService.scheduleMilestoneEve(
                    currentDays: current,
                    milestoneDays: next.dayThreshold,
                    milestoneTitle: next.title,
                    hour: hour
                )
            } else {
                NotificationService.cancelMilestoneEve()
            }
        }
    }

    /// Refresh the banner and keep the trial-reminder copy stocked with real
    /// numbers, so a notification scheduled later can name what they've built.
    private func refreshTrialRecap() {
        let cents = settingsRows.first?.costPerDayCents ?? 0
        var parts = ["\(days) sober \(days == 1 ? "day" : "days")"]
        if cents > 0 {
            let dollars = Double(days * cents) / 100
            let money = Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
            parts.append("\(money) saved")
        }
        TrialLifecycle.recapSummary = parts.joined(separator: " and ") + " so far."
        showTrialRecap = TrialLifecycle.shouldShowRecap()
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    /// Time milestones and growth celebrations are the app's emotional peaks.
    /// The review prompt relaxes its tenure gates for these, so ask there.
    private func recordPositiveMomentForReview(isMilestone: Bool = false) {
        ReviewPromptTracker.recordPositiveMoment(isMilestone: isMilestone)
        NotificationCenter.default.post(name: .soberPositiveMomentForReview, object: nil)
    }

    /// True on the exact day a time milestone lands (7, 30, 90, …).
    private var isTimeMilestoneDay: Bool {
        days > 0 && AchievementCatalog.all.contains {
            $0.kind == .timeMilestone && $0.dayThreshold == days
        }
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              !showGrowth,
              !showCheckInDetail,
              !showReviewPrompt
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !showGrowth,
                  !showCheckInDetail,
                  !showReviewPrompt,
                  // A trial pitch may have been scheduled from the same moment
                  // (e.g. a growth-celebration dismiss) and already be on
                  // screen from MainTabView's layer — never stack on top of it.
                  !TrialOfferCoordinator.shared.isPresentingSheet,
                  TrialOfferCoordinator.shared.pendingRequest == nil,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding)
            else { return }
            ReviewPromptTracker.consumePendingPositiveMoment()
            reviewPromptInitialStep = .enjoyment
            reviewPromptShownThisSession = true
            showReviewPrompt = true
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        showReviewPrompt = false
        if outcome == .enjoyedMaybeLater {
            pendingNativeReviewAfterDismiss = true
        }
    }

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptInitialStep = step
        reviewPromptShownThisSession = true
        showReviewPrompt = true
    }

    private func recordCheckInForTrialPitch() {
        guard !isPro else { return }
        let count = TrialSubsequentPitchGate.incrementPersistedCount(key: AppGroup.checkInCompletedCountKey)
        Task {
            await evaluateUsageBasedTrialPitch(
                subscriptions,
                intent: .checkInMilestone,
                usageCount: count,
                threshold: 3,
                delay: 2.5
            )
        }
    }

    private func scheduleTrialPitchAfterGrowthCelebration() {
        guard !isPro else { return }
        let count = TrialSubsequentPitchGate.incrementPersistedCount(key: AppGroup.growthCelebrationCountKey)
        Task {
            await evaluateUsageBasedTrialPitch(
                subscriptions,
                intent: .growthCelebration,
                usageCount: count,
                delay: 1.5
            )
        }
    }
}

/// Optional reflection after the one-tap check-in. The day is already logged
/// and the garden watered before this appears — capturing mood/note here is
/// purely additive, and "Skip" keeps the frictionless path intact.
private struct CheckInDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Int?
    @State private var note: String = ""

    private let symbols = ["cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"]
    private let moodLabels = ["Rough", "Low", "OK", "Good", "Great"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mood") {
                    HStack(spacing: Theme.Space.m) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                mood = (mood == value) ? nil : value
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: symbols[value - 1])
                                        .font(.title2)
                                        .foregroundStyle(mood == value ? Theme.brandPrimary : Theme.textTertiary)
                                    Text(moodLabels[value - 1])
                                        .font(Theme.caption(weight: .semibold))
                                        .foregroundStyle(mood == value ? Theme.brandPrimary : Theme.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Theme.Space.xs)
                }
                Section("Note") {
                    TextField("Anything you want to remember about today?", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Checked in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if mood != nil || !trimmed.isEmpty {
            CheckInService(context: context).checkIn(mood: mood, note: trimmed.isEmpty ? nil : trimmed)
        }
        dismiss()
    }
}

/// Pull-up sheet for the longer-horizon progress that used to live on Today:
/// next milestone, next health benefit, the unlock collection, money/calories
/// saved, and the achievement grid. Single discovery surface for everything
/// off the garden spine.
struct ProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var settingsRows: [UserSettings]
    @Query private var unlockedAchievements: [UnlockedAchievement]
    @Query private var checkIns: [DailyCheckIn]
    let days: Int
    let gardenState: GardenState?
    let isPro: Bool

    private var settings: UserSettings? { settingsRows.first }

    private var week: [TendedDay] {
        TendedWeek.days(facts: checkIns.map {
            CheckInFacts(day: $0.day, wasSober: $0.wasSober, wasLogged: $0.wasLogged, mood: $0.mood)
        })
    }

    private var weekLine: String {
        let summary = TendedWeek.summary(week)
        // The mood clause only makes sense hanging off a count. Appending it
        // to the zero-day prompt produced "Tend a day to start your week ·
        // felt mostly good", which a user who checked in and then logged a
        // slip could actually see.
        guard TendedWeek.tendedCount(week) > 0, let mood = TendedWeek.moodSummary(week) else {
            return summary
        }
        return "\(summary) · felt \(mood)"
    }

    /// Trial-led upsell only when a free trial is actually on the table for
    /// this Apple ID (3.1.2) — otherwise the nudge would promise a trial the
    /// paywall can't deliver.
    private var showTrialNudge: Bool {
        days >= 7 && !isPro && !subscriptions.hasClaimedTrial && subscriptions.hasTrialOfferAvailable
    }

    var body: some View {
        NavigationStack {
            List {
                if showTrialNudge {
                    Section { trialNudgeRow }
                }

                Section("Next up") {
                    nextMilestoneRow
                    nextBenefitRow
                }

                // Free, on purpose. The week strip and the mood read are the
                // payoff for checking in, and a payoff behind a paywall is not
                // a payoff, it is a hostage.
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        WeekStripView(days: week, dotSize: 14)
                        Text(weekLine)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, Theme.Space.xs)
                } header: {
                    Text("This week")
                } footer: {
                    Text("A filled dot is a day you checked in. A hollow one is a sober day the app filled in for you.")
                }

                Section {
                    if isPro {
                        NavigationLink { PatternsView() } label: {
                            progressRow(
                                icon: "chart.bar.xaxis",
                                title: "Your patterns",
                                detail: "When your \(HabitVocabulary.urgeNounPlural) hit and what sets them off"
                            )
                        }
                    } else {
                        patternsLockedRow
                    }
                }

                // Free, for everyone. What you have already kept is the single
                // strongest thing this app can say to a non-subscriber, and it
                // spent its whole life behind the wall where nobody could be
                // moved by it. Bloom+ sells the projection below, not this.
                if hasSpendData {
                    Section {
                        savedRow(label: "Money", streak: moneySaved, lifetime: lifetimeMoneySaved, sub: "$\((settings?.costPerDayCents ?? 0) / 100) / day", icon: "dollarsign.circle.fill")
                        savedRow(label: "Calories", streak: caloriesAvoided.formatted(), lifetime: lifetimeCaloriesAvoided.formatted(), sub: "\(settings?.caloriesPerDay ?? 0) / day", icon: "flame.fill")
                        savedRow(label: "Body fat", streak: poundsOfFat(caloriesAvoided), lifetime: poundsOfFat(lifetimeCaloriesAvoided), sub: "~3,500 cal per lb", icon: "scalemass.fill")
                    } header: {
                        Text("Kept so far")
                    } footer: {
                        Text("Streak counts your current run. Lifetime counts every sober day you've ever logged, so past progress isn't lost on a reset.")
                    }
                }

                if hasSpendData {
                    Section {
                        if isPro {
                            yearAheadRow(
                                label: "Money",
                                value: projectedMoneyAYear,
                                sub: "if you keep going for 12 months",
                                icon: "dollarsign.circle.fill"
                            )
                            yearAheadRow(
                                label: "Calories",
                                value: projectedCaloriesAYear.formatted(),
                                sub: "not drunk over 12 months",
                                icon: "flame.fill"
                            )
                            yearAheadRow(
                                label: "Body fat",
                                value: poundsOfFat(projectedCaloriesAYear),
                                sub: "~3,500 cal per lb",
                                icon: "scalemass.fill"
                            )
                        } else {
                            yearAheadLockedRow
                        }
                    } header: {
                        Text("Your year ahead")
                    } footer: {
                        Text("A projection from your current daily figures, not a promise. Change them any time in Settings.")
                    }
                }

                Section("Bonsai species") {
                    GardenCollectionView(
                        activeStyleID: gardenState?.activeBonsaiStyleID ?? GardenItemCatalog.freeSpeciesID,
                        isPro: isPro,
                        embeddedInList: true
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Theme.background)
                }

                Section("Time milestones") {
                    ForEach(AchievementCatalog.all.filter { $0.kind == .timeMilestone }) { achievementRow($0) }
                }

                Section("Streaks") {
                    ForEach(AchievementCatalog.all.filter { $0.kind == .streak }) { achievementRow($0) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Your progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var trialNudgeRow: some View {
        Button { requestSubsequentLockedFeaturePitch(.progressSheet) } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "gift.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've kept \(lifetimeMoneySaved) so far")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("See what a year of this looks like")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var nextMilestoneRow: some View {
        let next = AchievementCatalog.nextTimeMilestone(after: days)
        return progressRow(
            icon: "flag.fill",
            title: next?.title ?? "Year One",
            detail: next.map { "in \(max(1, $0.dayThreshold - days)) days" } ?? "Crushed it"
        )
    }

    private var nextBenefitRow: some View {
        // `days` is 1-based (start day = Day 1); elapsed full days is days - 1.
        let hours = Double(max(0, days - 1)) * 24
        let next = HealthBenefitCatalog.next(after: hours)
        return progressRow(
            icon: "heart.fill",
            title: next?.title ?? "All unlocked",
            detail: next.map { "at \($0.displayWait)" } ?? ""
        )
    }

    private func progressRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.body())
                if !detail.isEmpty {
                    Text(detail).font(Theme.caption()).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func savedRow(label: String, streak: String, lifetime: String, sub: String, icon: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Theme.body())
                Text(sub).font(Theme.caption()).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(streak)
                    .font(Theme.heading(weight: .semibold))
                    .foregroundStyle(Theme.brandPrimary)
                    .monospacedDigit()
                Text("\(lifetime) lifetime")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    /// Both the free "kept so far" block and the Bloom+ projection are
    /// meaningless without a daily figure, so neither renders at zero.
    private var hasSpendData: Bool {
        (settings?.costPerDayCents ?? 0) > 0 || (settings?.caloriesPerDay ?? 0) > 0
    }

    private var projectedMoneyAYear: String {
        let dollars = Double((settings?.costPerDayCents ?? 0) * 365) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private var projectedCaloriesAYear: Int { (settings?.caloriesPerDay ?? 0) * 365 }

    private func yearAheadRow(label: String, value: String, sub: String, icon: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(Theme.body())
                Text(sub).font(Theme.caption()).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(value)
                .font(Theme.heading(weight: .semibold))
                .foregroundStyle(Theme.brandPrimary)
                .monospacedDigit()
        }
    }

    private var patternsLockedRow: some View {
        Button { requestSubsequentLockedFeaturePitch(.patterns) } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Learn your own pattern")
                        .font(Theme.body())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Bloom+ reads your logged \(HabitVocabulary.urgeNounPlural) back to you: when they hit, what sets them off, how long yours last")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var yearAheadLockedRow: some View {
        Button { requestSubsequentLockedFeaturePitch(.progressSheet) } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("See where this goes")
                        .font(Theme.body())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Bloom+ projects your money, calories, and tree a year out")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Every sober day ever recorded — the basis for lifetime savings so a
    /// relapse reset doesn't wipe the user's accumulated progress.
    private var lifetimeSoberDays: Int { checkIns.filter { $0.wasSober }.count }

    private var lifetimeMoneySaved: String {
        let cents = lifetimeSoberDays * (settings?.costPerDayCents ?? 0)
        let dollars = Double(cents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private var lifetimeCaloriesAvoided: Int { lifetimeSoberDays * (settings?.caloriesPerDay ?? 0) }

    private var savedSoFar: String {
        let cents = days * (settings?.costPerDayCents ?? 0)
        let dollars = Double(cents) / 100
        return Self.currencyFormatter.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private var moneySaved: String { savedSoFar }
    private var caloriesAvoided: Int { days * (settings?.caloriesPerDay ?? 0) }

    /// Calories expressed as pounds of body fat (~3,500 kcal per lb).
    private func poundsOfFat(_ calories: Int) -> String {
        let lbs = Double(calories) / 3500.0
        return "\(lbs.formatted(.number.precision(.fractionLength(lbs < 10 ? 1 : 0)))) lb"
    }

    private func achievementRow(_ a: Achievement) -> some View {
        // An achievement is unlocked if it's ever been earned (persisted in the
        // trophy case) OR the current streak satisfies it. Earned badges show
        // in full color for everyone — gating their *appearance* on Bloom+ made
        // a non-subscriber's hard-won "Perfect Week" look identical to one
        // they'd never earned, which punishes loyalty.
        let everEarned = unlockedAchievements.contains { $0.achievementID == a.id }
        let unlocked = everEarned || days >= a.dayThreshold
        return HStack(spacing: Theme.Space.m) {
            Image(systemName: a.icon)
                .font(.title3)
                .foregroundStyle(unlocked ? Theme.brandPrimary : Theme.textTertiary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title)
                    .foregroundStyle(unlocked ? Theme.textPrimary : Theme.textSecondary)
                Text(a.description).font(Theme.caption()).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if unlocked {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.brandPrimary)
            } else if !isPro {
                Image(systemName: "lock.fill").foregroundStyle(Theme.textTertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !unlocked && !isPro { requestSubsequentLockedFeaturePitch(.progressSheet) } }
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
