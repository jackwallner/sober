import SwiftData
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

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
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

                PannableGardenView(
                    days: days,
                    vitality: gardenState?.vitality ?? 1.0,
                    placedItemIDs: gardenState?.placedItemIDs ?? [],
                    activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? "traditional-bonsai",
                    isPro: isPro,
                    completedTreeStyles: gardenState?.completedTreeStyles ?? [],
                    onSelect: { selectedItem = $0 }
                )
                .ignoresSafeArea(edges: .bottom)

                if !showCelebration {
                    VStack(spacing: Theme.Space.m) {
                        counterOverlay
                        Spacer(minLength: Theme.Space.m)
                        bottomStack
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.vertical, Theme.Space.s)
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
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCustomize) { GardenCustomizationView() }
            .sheet(isPresented: $showProgress) {
                ProgressSheet(days: days, gardenState: gardenState, isPro: isPro)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedItem) { item in
                GardenItemDetailView(item: item, unlocked: days >= item.milestoneDays, currentDays: days)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Overlays

    /// Bare counter — no card, no scrim. Heavy text shadow keeps it legible on
    /// both bright sky and dim dusk garden states. Stage / start date are
    /// available in the Progress sheet, not on the spine.
    private var counterOverlay: some View {
        VStack(spacing: 0) {
            Text("\(days)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 2)
                .accessibilityLabel("\(days) \(days == 1 ? "day" : "days") sober")
            Text(days == 1 ? "Day Sober" : "Days Sober")
                .font(.headline)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        }
        .frame(maxWidth: .infinity)
    }

    /// The only floating control. Trial nudge + daily growth note moved into
    /// the Progress sheet so the spine reads as garden + counter + one CTA.
    @ViewBuilder
    private var bottomStack: some View {
        checkInControl
    }

    @ViewBuilder
    private var checkInControl: some View {
        if !checkedInToday && daysMissed > 1 {
            VStack(spacing: 8) {
                Text("Welcome back — you haven't checked in for \(daysMissed) days. Still going strong?")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    Button {
                        let svc = CheckInService(context: context)
                        svc.backfillSoberDays()
                        GardenService(context: context).water()
                        refreshCheckInState()
                        WidgetSnapshotPump.push(context: context)
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
            .background(Theme.gardenOverlayScrim, in: RoundedRectangle(cornerRadius: 18))
        } else {
            Button {
                guard !checkedInToday else { return }
                CheckInService(context: context).checkIn()
                GardenService(context: context).water()
                refreshCheckInState()
                WidgetSnapshotPump.push(context: context)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: checkedInToday ? "checkmark.circle.fill" : "circle")
                    Text(checkedInToday ? "Checked in for today" : "Check in for today")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    checkedInToday ? Theme.checkInDoneFill : AnyShapeStyle(Theme.brandPrimary),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!checkedInToday)
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
        svc.processCycleCompletions(days: days)
        let newItems = svc.processNewUnlocks(days: days)
        for item in newItems where GardenItemCatalog.freeToPlaceIDs.contains(item.id) {
            svc.placeItem(item)
        }
        AchievementService(context: context).processUnlocks(currentDays: days)
        guard !newItems.isEmpty else { return }
        celebrationQueue = newItems
        withAnimation { showCelebration = true }
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
                    } header: {
                        Text("Saved")
                    } footer: {
                        Text("Streak counts your current run; lifetime counts every sober day you've ever logged — past progress isn't lost on a reset.")
                    }
                }

                Section("Garden") {
                    GardenCollectionView(
                        days: days,
                        unlockedItemIDs: gardenState?.unlockedItemIDs ?? [],
                        isPro: isPro
                    )
                    .frame(minHeight: 360)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
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
            .sheet(isPresented: $showPaywall) { PaywallView() }
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
                    Text("You've saved \(savedSoFar) so far")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Try Bloom+ free for 7 days")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
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
        let hours = Double(days) * 24
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
                Text(title).font(.body)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
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
                Text(label).font(.body)
                Text(sub).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(streak)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.brandPrimary)
                    .monospacedDigit()
                Text("\(lifetime) lifetime")
                    .font(.caption2)
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
                Text(a.description).font(.caption).foregroundStyle(Theme.textSecondary)
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
