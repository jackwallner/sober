import SwiftUI

/// The bonsai species gallery shown in the Progress sheet. Bloom+ is the only
/// gate: free users have the starter tree, subscribers can grow any species.
/// Rows are informational here — switching happens in GardenCustomizationView,
/// locked rows lead to the paywall.
struct GardenCollectionView: View {
    let activeStyleID: String
    let isPro: Bool
    /// When true, renders inside a parent `List` (Progress sheet) without nested
    /// navigation or scroll — avoids double scroll and title overlap.
    var embeddedInList: Bool = false

    @State private var showPaywall = false

    private var species: [GardenItem] { GardenItemCatalog.species }

    var body: some View {
        Group {
            if embeddedInList {
                galleryContent
            } else {
                NavigationStack {
                    ScrollView {
                        galleryContent
                            .padding(.horizontal, 16)
                    }
                    .background(Theme.background)
                    .navigationTitle("Species")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(impressionId: "sober_garden_collection_sheet")
        }
    }

    private var galleryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(species) { item in
                SpeciesRow(
                    item: item,
                    isActive: item.id == activeStyleID,
                    isUsable: GardenItemCatalog.canUseSpecies(id: item.id, isPro: isPro),
                    onUpsell: { showPaywall = true }
                )
            }
        }
        .padding(.vertical, embeddedInList ? 4 : 16)
    }
}

// MARK: - Row

private struct SpeciesRow: View {
    let item: GardenItem
    let isActive: Bool
    let isUsable: Bool
    let onUpsell: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumb
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(isUsable ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Text(item.description)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            trailingControl
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isUsable ? Theme.cardSurface : Theme.cardSurfaceLight,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Theme.brandPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    private var thumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.skyGradient)
            BonsaiView(
                day: 120,
                style: GardenSceneView.styleEnum(for: item.id),
                vitality: 1.0,
                fill: true
            )
            .padding(4)
            .blur(radius: isUsable ? 0 : 3)
            if !isUsable {
                Image(systemName: "lock.fill")
                    .font(Theme.caption())
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.35), in: Circle())
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isActive {
            Label("Growing", systemImage: "checkmark.seal.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(Theme.success)
                .accessibilityLabel("Currently growing")
        } else if !isUsable {
            Button("Bloom+", action: onUpsell)
                .font(Theme.caption(weight: .semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandPrimary)
                .controlSize(.mini)
        }
    }
}
