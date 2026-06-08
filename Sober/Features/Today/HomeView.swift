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
    @State private var showSlipAlert = false
    @State private var checkedInToday = false
    @State private var daysMissed = 0
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showCustomize = false
    @State private var showProgress = false
    @State private var selectedItem: GardenItem?
    @State private var celebrationQueue: [GardenItem] = []
    @State private var showCelebration = false
    @State private var recapItems: [GardenItem] = []
    @State private var showRecap = false
    @State private var showCheckInDetail = false
    @State private var showReviewPrompt = false
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
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
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }
    private var stage: BonsaiStage { GardenService.stage(forDays: days) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if !showCelebration && !showRecap {
                    VStack(spacing: Theme.Space.l) {
                        counterHeader
                        gardenCard
                        checkInControl
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
            .alert("It's okay. You're still on the journey.", isPresented: $showSlipAlert) {
                Button("Not yet", role: .cancel) {}
                Button("Start fresh") {
                    SobrietyService(context: context).reset()
                    GardenService(context: context).resetForNewJourney()
                    refreshCheckInState()
                    WidgetSnapshotPump.push(context: context)
                }
            } message: {
                Text("Slips happen. Your history stays, and your tree carries everything you've already grown. Begin a new day when you're ready.")
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
                checkForUnlocks()
                WidgetSnapshotPump.push(context: context)
            }
            .overlay {
                if showCelebration, let item = celebrationQueue.first {
                    UnlockCelebrationView(
                        item: item,
                        canPlace: isPro || GardenItemCatalog.freeToPlaceIDs.contains(item.id)
                    ) {
                        celebrationQueue.removeFirst()
                        if celebrationQueue.isEmpty {
                            withAnimation { showCelebration = false }
                            WidgetSnapshotPump.push(context: context)
                            recordPositiveMomentForReview()
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .fullScreenCover(isPresented: $showRecap) {
                UnlockRecapView(items: recapItems, days: days) {
                    showRecap = false
                    recapItems = []
                    WidgetSnapshotPump.push(context: context)
                    recordPositiveMomentForReview()
                }
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $showCheckInDetail) {
                CheckInDetailSheet()
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(impressionId: "sober_home_sheet")
            }
            .sheet(isPresented: $showCustomize) { GardenCustomizationView() }
            .sheet(isPresented: $showProgress) {
                ProgressSheet(days: days, gardenState: gardenState, isPro: isPro)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedItem) { item in
                GardenItemDetailView(item: item, unlocked: days >= item.milestoneDays, currentDays: days)
                    .presentationDetents([.medium])
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
            .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
                guard let presentation else { return }
                defer { reviewPromptCoordinator.clear() }
                guard !showPaywall, !showCelebration else { return }
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
                .foregroundStyle(Theme.brandPrimary)
                .accessibilityLabel("\(days) \(days == 1 ? "day" : "days") sober")
            Text(days == 1 ? "Day Sober" : "Days Sober")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The garden, framed as a card that claims all the vertical space between
    /// the counter and the CTA. The scene fits the bonsai to whatever height it
    /// gets (see `BonsaiView(fill:)`), so expanding the card grows the tree
    /// rather than opening a dead sky band. A content-driven floor keeps a
    /// sparse early garden generous while a rich one (placed items, a grove)
    /// pushes for even more room.
    private var gardenCard: some View {
        PannableGardenView(
            days: days,
            vitality: gardenState?.vitality ?? 1.0,
            placedItemIDs: gardenState?.placedItemIDs ?? [],
            activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? "traditional-bonsai",
            isPro: isPro,
            completedTreeStyles: gardenState?.completedTreeStyles ?? [],
            onSelect: { selectedItem = $0 },
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

    /// How much "stuff" is in the garden — placed decorations plus completed
    /// trees in the grove. Drives the card's minimum height so the real estate
    /// scales with content.
    private var gardenContentScore: Int {
        (gardenState?.placedItemIDs.count ?? 0) + (gardenState?.completedTreeStyles.count ?? 0)
    }

    private var gardenMinHeight: CGFloat {
        let stageBoost: CGFloat = stage == .seed ? 0 : 60
        return 300 + stageBoost + min(120, CGFloat(gardenContentScore) * 16)
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
                        recordPositiveMomentForReview()
                    } label: {
                        Label("Still sober", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)

                    Button(role: .destructive) {
                        showSlipAlert = true
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
        } else if checkedInToday {
            // After check-in, show what the action actually accomplished rather
            // than a static "done" pill, so the tap feels consequential.
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today is logged")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Your bonsai is watered · \(days)-day streak going")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textSecondary)
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
                recordPositiveMomentForReview()
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

    // MARK: - State

    private func refreshCheckInState() {
        let svc = CheckInService(context: context)
        checkedInToday = svc.hasCheckedIn()
        daysMissed = svc.daysSinceLastCheckIn()
    }

    private func checkForUnlocks() {
        let svc = GardenService(context: context)
        // Capture the prior notification watermark *before* processNewUnlocks
        // advances it. A watermark of 0 with multiple unlocks means this is the
        // first check after a back-dated onboarding date.
        let firstCheck = (gardenState?.lastUnlockNotifiedAtDays ?? 0) == 0
        svc.processCycleCompletions(days: days)
        let newItems = svc.processNewUnlocks(days: days)
        for item in newItems where GardenItemCatalog.freeToPlaceIDs.contains(item.id) {
            svc.placeItem(item)
        }
        AchievementService(context: context).processUnlocks(currentDays: days)
        guard !newItems.isEmpty else { return }

        // On a fresh start with several already-earned milestones, recap them
        // all at once instead of cycling through individual celebrations.
        if firstCheck && newItems.count > 2 {
            recapItems = newItems
            withAnimation { showRecap = true }
        } else {
            celebrationQueue = newItems
            withAnimation { showCelebration = true }
        }
    }

    private func recordPositiveMomentForReview() {
        ReviewPromptTracker.recordPositiveMoment()
        NotificationCenter.default.post(name: .soberPositiveMomentForReview, object: nil)
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedOnboarding),
              !reviewPromptShownThisSession,
              !showCelebration,
              !showPaywall,
              !showCheckInDetail,
              !showReviewPrompt
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !showCelebration,
                  !showPaywall,
                  !showCheckInDetail,
                  !showReviewPrompt,
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

    @State private var showPaywall = false

    private var settings: UserSettings? { settingsRows.first }
    private var showTrialNudge: Bool { days >= 7 && !isPro && !subscriptions.hasClaimedTrial }

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

                if isPro {
                    Section {
                        savedRow(label: "Money", streak: moneySaved, lifetime: lifetimeMoneySaved, sub: "$\((settings?.costPerDayCents ?? 0) / 100) / day", icon: "dollarsign.circle.fill")
                        savedRow(label: "Calories", streak: caloriesAvoided.formatted(), lifetime: lifetimeCaloriesAvoided.formatted(), sub: "\(settings?.caloriesPerDay ?? 0) / day", icon: "flame.fill")
                        savedRow(label: "Body fat", streak: poundsOfFat(caloriesAvoided), lifetime: poundsOfFat(lifetimeCaloriesAvoided), sub: "~3,500 cal per lb", icon: "scalemass.fill")
                    } header: {
                        Text("Saved")
                    } footer: {
                        Text("Streak counts your current run. Lifetime counts every sober day you've ever logged, so past progress isn't lost on a reset.")
                    }
                }

                Section("Garden collection") {
                    GardenCollectionView(
                        days: days,
                        unlockedItemIDs: gardenState?.unlockedItemIDs ?? [],
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(impressionId: "sober_progress_sheet")
            }
        }
    }

    private var trialNudgeRow: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "gift.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've saved \(lifetimeMoneySaved) so far")
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Start your free Bloom+ trial")
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
        .onTapGesture { if !unlocked && !isPro { showPaywall = true } }
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
