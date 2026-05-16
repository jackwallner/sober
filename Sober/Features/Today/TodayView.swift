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
    @State private var showSettings = false
    @State private var celebrationQueue: [GardenItem] = []
    @State private var showCelebration = false

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = activeJourney else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var isPro: Bool { subscriptions.isProSubscriber }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    counterCard
                        .padding(.horizontal)

                    checkInCard

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
                    WidgetSnapshotPump.push(context: context)
                }
            } message: {
                Text("Your day counter will restart at zero. Your history is kept.")
            }
            .onAppear {
                checkedInToday = CheckInService(context: context).hasCheckedIn()
                checkForUnlocks()
                applyVitalityDecay()
                WidgetSnapshotPump.push(context: context)
            }
            // Celebration overlay — replays each queued unlock in order.
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
        }
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

    private func applyVitalityDecay() {
        let checkInSvc = CheckInService(context: context)
        let lastCheckIn = checkInSvc.lastCheckInDate()
        GardenService(context: context).applyVitalityDecay(lastCheckIn: lastCheckIn)
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

    private var gardenPreviewCard: some View {
        let stage = GardenService.stage(forDays: days)
        return Button(action: goToGarden) {
            SectionCard {
                HStack(spacing: 14) {
                    GardenSceneView(
                        days: days,
                        vitality: gardenState?.vitality ?? 1.0,
                        placedItemIDs: gardenState?.placedItemIDs ?? [],
                        activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? "traditional-bonsai",
                        isPro: isPro,
                        completedTreeStyles: gardenState?.completedTreeStyles ?? []
                    )
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Garden")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(stage.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var checkInCard: some View {
        Button {
            CheckInService(context: context).checkIn()
            GardenService(context: context).water()
            checkedInToday = true
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
        .padding(.horizontal)
    }

    private var nextMilestoneCard: some View {
        let next = AchievementCatalog.nextTimeMilestone(after: days)
        return VStack(alignment: .leading, spacing: 4) {
            Label("Next Milestone", systemImage: "flag.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Text(next?.title ?? "Year One")
                .font(.headline)
            Text(next.map { "in \(max(1, $0.dayThreshold - days)) days" } ?? "Crushed it")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .lineLimit(2)
            Text(next.map { "at \($0.displayWait)" } ?? "")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
