import SwiftData
import SwiftUI

/// Bonsai species picker. Bloom+ is the only gate: a subscriber can switch to
/// any species freely, a free user gets the one starter tree and a paywall for
/// the rest. There are no day-locks and no decorations here anymore — the
/// garden is one tree you grow and re-style.
struct GardenCustomizationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var gardenStates: [GardenState]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]


    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }
    private var isPro: Bool { subscriptions.isProSubscriber }
    private var activeStyleID: String { gardenState?.activeBonsaiStyleID ?? GardenItemCatalog.freeSpeciesID }
    private var species: [GardenItem] { GardenItemCatalog.species }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    gardenPreview
                    if isPro {
                        proHeader
                    } else {
                        freeHeader
                    }
                    speciesGrid
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Your Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isPro { upgradeBar }
            }
        }
    }

    // MARK: - Preview

    private var gardenPreview: some View {
        GardenSceneView(
            days: days,
            vitality: gardenState?.vitality ?? 1.0,
            activeBonsaiStyleID: activeStyleID,
            isPro: isPro,
            completedTreeStyles: gardenState?.completedTreeStyles ?? []
        )
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Headers

    private var proHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bonsai Species")
                .font(Theme.body())
                .foregroundStyle(Theme.textPrimary)
            Text("Switch anytime. Your day count and growth carry over to whichever tree you choose.")
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var freeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bonsai Species")
                .font(Theme.body())
                .foregroundStyle(Theme.textPrimary)
            Text("Bloom+ unlocks every species so you can switch your tree whenever you like. Your streak grows whichever one you pick.")
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Species Grid

    private var speciesGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 104), spacing: 14)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(species) { item in
                speciesCard(item)
            }
        }
    }

    private func speciesCard(_ item: GardenItem) -> some View {
        let style = GardenSceneView.styleEnum(for: item.id)
        let unlocked = GardenItemCatalog.canUseSpecies(id: item.id, isPro: isPro)
        let isActive = activeStyleID == item.id
        return Button {
            if unlocked {
                GardenService(context: context).setBonsaiStyle(item.id)
                // Refresh widget/watch immediately so the home-screen tree
                // matches the species the user just picked.
                WidgetSnapshotPump.push(context: context)
            } else {
                requestSubsequentLockedFeaturePitch(.gardenSpecies)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    // Render at the user's *current* growth so the preview is the
                    // tree they'd actually get, not a generic mature one.
                    BonsaiView(day: unlocked ? dayInCycle : 120, style: style, vitality: 1.0, fill: true)
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                        .blur(radius: unlocked ? 0 : 5)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(Theme.subhead(weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                }
                .background(Theme.skyGradient, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? Theme.brandPrimary : Color.clear, lineWidth: 2.5)
                )

                HStack(spacing: 5) {
                    Text(item.displayName)
                        .font(Theme.caption(weight: isActive ? .bold : .regular))
                        .foregroundStyle(isActive ? Theme.brandPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.caption())
                            .foregroundStyle(Theme.brandPrimary)
                    } else if !unlocked {
                        Image(systemName: "crown.fill")
                            .font(Theme.caption())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Upgrade Bar (free users)

    private var upgradeBar: some View {
        VStack(spacing: 6) {
            Button {
                requestSubsequentLockedFeaturePitch(.gardenSpecies)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Unlock all \(species.count) trees")
                }
                .font(Theme.body(weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .foregroundStyle(.white)
            }
            Text("Swap any species anytime · your streak keeps growing")
                .font(Theme.caption())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .background(alignment: .top) {
            Theme.background
                .overlay(Rectangle().fill(Theme.ringTrack).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
