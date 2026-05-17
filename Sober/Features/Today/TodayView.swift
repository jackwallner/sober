import SwiftData
import SwiftUI

struct TodayView: View {
    var goToGarden: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var gardenStates: [GardenState]
    @State private var showResetAlert = false
    @State private var checkedInToday = false
    @State private var daysMissed: Int = 0
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var celebrationQueue: [GardenItem] = []
    @State private var showCelebration = false
    @Query private var settingsRows: [UserSettings]

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = activeJourney else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var isPro: Bool { subscriptions.isProSubscriber }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    counterCard
                        .padding(.horizontal)

                    checkInSection
                        .padding(.horizontal)

                    if showTrialNudge {
                        trialNudgeCard
                            .padding(.horizontal)
                    }

                    gardenPreviewCard
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        nextMilestoneCard
                        nextBenefitCard
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - State

    private func refreshCheckInState() {
        let svc = CheckInService(context: context)
        checkedInToday = svc.hasCheckedIn()
        daysMissed = svc.daysSinceLastCheckIn()
    }

    // MARK: - Unlock Check

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

    // MARK: - Cards

    private var counterCard: some View {
        HeroCard {
            VStack(spacing: 6) {
                Text("\(days)")
                    .font(Theme.bigNumber(96))
                Text(days == 1 ? "Day Sober" : "Days Sober")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                if let start = activeJourney?.startDate {
                    Text("Since \(DateHelpers.mediumDate(start))")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Check-in / catch-up

    @ViewBuilder
    private var checkInSection: some View {
        if !checkedInToday && daysMissed > 1 {
            catchUpCard
        } else {
            checkInCard
        }
    }

    private var checkInCard: some View {
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

    private var catchUpCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("You haven't checked in for \(daysMissed) day\(daysMissed == 1 ? "" : "s"). Still going strong?")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    let svc = CheckInService(context: context)
                    svc.backfillSoberDays()
                    GardenService(context: context).water()
                    refreshCheckInState()
                    WidgetSnapshotPump.push(context: context)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Yes, still sober")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandPrimary)

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Text("I had a slip")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(Theme.textSecondary)
            }
        }
    }

    // MARK: Garden preview

    private var gardenPreviewCard: some View {
        let stage = GardenService.stage(forDays: days)
        let style: BonsaiStyle = {
            switch gardenState?.activeBonsaiStyleID {
            case "cascade-bonsai": return .cascade
            case "windswept-bonsai": return .windswept
            default: return .traditional
            }
        }()
        let vitality = gardenState?.vitality ?? 1.0

        return Button(action: goToGarden) {
            SectionCard {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Bonsai")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Day \(dayInCycle) · \(stage.title)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.skyGradient)
                        BonsaiView(day: dayInCycle, style: style, vitality: vitality)
                            .padding(8)
                    }
                    .frame(height: 200)
                    .allowsHitTesting(false)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Theme.brandPrimary)
                        Text("Today's growth: \(DailyGrowth.note(forDayInCycle: dayInCycle))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Trial nudge

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

    private var trialNudgeCard: some View {
        Button { showPaywall = true } label: {
            SectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(Theme.brandPrimary)
                        Text("You've saved \(savedSoFar) so far")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("Put a little back into your growth — try Bloom+ free for 7 days. New species, your growth history, and more.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text("Start free trial")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.brandPrimary)
                }
            }
        }
        .buttonStyle(.plain)
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
