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

                VStack(spacing: 0) {
                    counterOverlay
                        .padding(.horizontal)
                        .padding(.top, 4)
                    Spacer()
                    bottomStack
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showProgress = true } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Button { showCustomize = true } label: {
                            Image(systemName: "paintbrush.line")
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                        Button(role: .destructive) { showResetAlert = true } label: {
                            Image(systemName: "arrow.counterclockwise.circle")
                        }
                    }
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
                refreshCheckInState()
                checkForUnlocks()
                WidgetSnapshotPump.push(context: context)
            }
            .overlay {
                if showCelebration, let item = celebrationQueue.first {
                    UnlockCelebrationView(item: item) {
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

    private var counterOverlay: some View {
        VStack(spacing: 2) {
            Text("\(days)")
                .font(Theme.bigNumber(64))
                .foregroundStyle(Theme.textPrimary)
            Text(days == 1 ? "Day Sober" : "Days Sober")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            if let start = activeJourney?.startDate {
                Text("Since \(DateHelpers.mediumDate(start)) · \(stage.title)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var bottomStack: some View {
        VStack(spacing: 10) {
            if showTrialNudge {
                trialNudge
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Theme.brandPrimary)
                Text("Today: \(DailyGrowth.note(forDayInCycle: dayInCycle))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            checkInControl
        }
    }

    @ViewBuilder
    private var checkInControl: some View {
        if !checkedInToday && daysMissed > 1 {
            VStack(spacing: 8) {
                Text("Welcome back — you haven't checked in for \(daysMissed) days. Still going strong?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
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
                        showResetAlert = true
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        } else {
            Button {
                CheckInService(context: context).checkIn()
                GardenService(context: context).water()
                refreshCheckInState()
                WidgetSnapshotPump.push(context: context)
            } label: {
                HStack {
                    Image(systemName: checkedInToday ? "checkmark.circle.fill" : "circle")
                    Text(checkedInToday ? "Checked in for today" : "Check in for today")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .disabled(checkedInToday)
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandPrimary)
        }
    }

    // MARK: - Trial nudge

    private var showTrialNudge: Bool {
        days >= 7 && !isPro && !subscriptions.hasClaimedTrial
    }

    private var savedSoFar: String {
        let cents = days * (settingsRows.first?.costPerDayCents ?? 0)
        let dollars = Double(cents) / 100
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: dollars)) ?? "$\(Int(dollars))"
    }

    private var trialNudge: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(Theme.brandPrimary)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
        guard !newItems.isEmpty else { return }
        celebrationQueue = newItems
        withAnimation { showCelebration = true }
    }
}

/// Pull-up sheet for the longer-horizon progress that used to live on Today:
/// next milestone, next health benefit, and the unlock collection.
struct ProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    let days: Int
    let gardenState: GardenState?
    let isPro: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        nextMilestoneCard
                        nextBenefitCard
                    }
                    GardenCollectionView(
                        days: days,
                        unlockedItemIDs: gardenState?.unlockedItemIDs ?? [],
                        isPro: isPro
                    )
                    .frame(minHeight: 360)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var nextMilestoneCard: some View {
        let next = AchievementCatalog.nextTimeMilestone(after: days)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Next Milestone", systemImage: "flag.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(next?.title ?? "Year One")
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
            Text(next.map { "in \(max(1, $0.dayThreshold - days)) days" } ?? "Crushed it")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private var nextBenefitCard: some View {
        let hours = Double(days) * 24
        let next = HealthBenefitCatalog.next(after: hours)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Next Benefit", systemImage: "heart.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(next?.title ?? "All unlocked")
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
            Text(next.map { "at \($0.displayWait)" } ?? "")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
