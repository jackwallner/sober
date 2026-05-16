import SwiftData
import SwiftUI

/// Dedicated Garden tab: a full-bleed, explorable scene of everything you've
/// grown. Pinch to zoom, drag to roam, tap any element to inspect it.
struct GardenView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]
    @Query private var gardenStates: [GardenState]

    @State private var showCustomize = false
    @State private var showCollection = false
    @State private var selectedItem: GardenItem?

    private var activeJourney: SobrietyJourney? { journeys.first { $0.isActive } }
    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = activeJourney else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var isPro: Bool { subscriptions.isProSubscriber }
    private var cycle: (dayInCycle: Int, completed: Int) {
        GardenService.cycleProgress(forDays: days)
    }
    private var stage: BonsaiStage { GardenService.stage(forDays: days) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PannableGardenView(
                    days: days,
                    vitality: gardenState?.vitality ?? 1.0,
                    placedItemIDs: gardenState?.placedItemIDs ?? [],
                    activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? "traditional-bonsai",
                    isPro: isPro,
                    completedTreeStyles: gardenState?.completedTreeStyles ?? [],
                    onSelect: { selectedItem = $0 }
                )
                .frame(maxHeight: .infinity)
                .padding(.horizontal)

                infoBar
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            .padding(.vertical, 8)
            .background(Theme.background)
            .navigationTitle("Garden")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCustomize = true } label: {
                        Image(systemName: "paintbrush.line")
                    }
                }
            }
            .sheet(isPresented: $showCustomize) { GardenCustomizationView() }
            .sheet(isPresented: $showCollection) {
                GardenCollectionView(
                    days: days,
                    unlockedItemIDs: gardenState?.unlockedItemIDs ?? [],
                    isPro: isPro
                )
            }
            .sheet(item: $selectedItem) { item in
                GardenItemDetailView(item: item, unlocked: days >= item.milestoneDays, currentDays: days)
                    .presentationDetents([.medium])
            }
        }
    }

    private var infoBar: some View {
        HeroCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cycle.completed > 0 ? "Year \(cycle.completed + 1) · \(stage.title)" : stage.title)
                        .font(.headline)
                    Text("Day \(days) · pinch to zoom, drag to explore")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button { showCollection = true } label: {
                    Label("Collection", systemImage: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Tap-to-inspect detail for any garden element.
struct GardenItemDetailView: View {
    let item: GardenItem
    let unlocked: Bool
    let currentDays: Int

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Theme.ringTrack)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            GardenItemRenderer(
                item: item,
                scale: 2.2,
                opacity: unlocked ? 1.0 : 0.3,
                vitality: 1.0
            )
            .frame(height: 110)

            VStack(spacing: 6) {
                Text(item.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(item.type.displayCategory)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            statusPill

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private var statusPill: some View {
        Group {
            if unlocked {
                Label("Earned at day \(item.milestoneDays)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
            } else {
                Label("Unlocks in \(item.milestoneDays - currentDays) days", systemImage: "lock.fill")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            (unlocked ? Theme.success.opacity(0.15) : Theme.cardSurface),
            in: Capsule()
        )
    }
}
