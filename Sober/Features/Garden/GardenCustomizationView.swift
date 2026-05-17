import SwiftData
import SwiftUI

/// Pro-gated garden customization screen: swap bonsai style, add/remove items.
/// Free users see a preview + upsell. Pro users get full drag-to-place.
struct GardenCustomizationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptions
    @Query private var gardenStates: [GardenState]
    @Query(sort: \SobrietyJourney.startDate, order: .reverse) private var journeys: [SobrietyJourney]

    @State private var showPaywall = false

    private var gardenState: GardenState? { gardenStates.first }
    private var days: Int {
        guard let j = journeys.first(where: { $0.isActive }) else { return 0 }
        return SobrietyService.daysSinceStart(j.startDate)
    }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: days).dayInCycle }
    private var isPro: Bool { subscriptions.isProSubscriber }

    /// All items the user has earned through milestones.
    private var unlockedItems: [GardenItem] {
        GardenItemCatalog.unlocked(atDays: days)
    }

    /// Items currently placed in the garden.
    private var placedIDs: [String] {
        gardenState?.placedItemIDs ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if isPro {
                    proCustomization
                } else {
                    freePreview
                }
            }
            .navigationTitle("Customize Garden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Pro Customization

    private var proCustomization: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Garden Preview
                gardenPreview

                // Bonsai Style Picker
                bonsaiStyleSection

                // Item Categories
                ForEach(categoriesWithItems(), id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding()
        }
        .background(Theme.background)
    }

    private var gardenPreview: some View {
        GardenSceneView(
            days: days,
            vitality: gardenState?.vitality ?? 1.0,
            placedItemIDs: gardenState?.placedItemIDs ?? [],
            activeBonsaiStyleID: gardenState?.activeBonsaiStyleID ?? "traditional-bonsai",
            isPro: true
        )
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var bonsaiStyleSection: some View {
        let allStyles = GardenItemCatalog.all.filter { $0.type == .bonsai }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Bonsai Species")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allStyles) { style in
                        let earned = days >= style.milestoneDays
                        let isActive = gardenState?.activeBonsaiStyleID == style.id
                        Button {
                            if earned {
                                GardenService(context: context).setBonsaiStyle(style.id)
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    BonsaiView(
                                        day: earned ? dayInCycle : 60,
                                        style: bonsaiStyleEnum(for: style.id),
                                        vitality: 1.0
                                    )
                                    .frame(width: 80, height: 80)
                                    .blur(radius: earned ? 0 : 6)

                                    if !earned {
                                        Image(systemName: "lock.fill")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.black.opacity(0.35), in: Circle())
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isActive ? Theme.brandPrimary : Color.clear, lineWidth: 2)
                                )

                                Text(earned ? style.displayName : "Day \(style.milestoneDays)")
                                    .font(.caption)
                                    .foregroundStyle(isActive ? Theme.brandPrimary : Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ category: String) -> some View {
        let items = unlockedItems.filter {
            GardenItemType.allCases.first(where: { $0.displayCategory == category }) == $0.type
        }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(category)

                let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        itemCard(item)
                    }
                }
            }
        }
    }

    private func itemCard(_ item: GardenItem) -> some View {
        let isPlaced = placedIDs.contains(item.id)
        return VStack(spacing: 6) {
            GardenItemRenderer(item: item, scale: 1.2, opacity: 1.0, vitality: 1.0)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(Theme.cardSurfaceLight, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPlaced ? Theme.brandPrimary : Color.clear, lineWidth: 2)
                )

            Text(item.displayName)
                .font(.caption2)
                .foregroundStyle(isPlaced ? Theme.brandPrimary : Theme.textSecondary)

            Button(isPlaced ? "Remove" : "Place") {
                let svc = GardenService(context: context)
                if isPlaced {
                    svc.removeItem(item)
                } else {
                    svc.placeItem(item)
                }
            }
            .buttonStyle(.bordered)
            .tint(isPlaced ? .red : Theme.brandPrimary)
            .font(.caption)
            .controlSize(.small)
        }
    }

    // MARK: - Free Preview

    private var freePreview: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Blurred garden preview
                gardenPreview
                    .blur(radius: 8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                    }

                // Upsell
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.brandPrimary)

                    Text("Customize Your Garden")
                        .font(.title2.bold())

                    Text("Unlock new plants, decorations, and bonsai styles as your streak grows. Subscribe to arrange them in your garden.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                    // Show what they'd unlock
                    let allItems = GardenItemCatalog.all.filter { $0.type != .bonsai }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You'll unlock:")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.textSecondary)

                        ForEach(allItems.prefix(6)) { item in
                            let isUnlocked = unlockedItems.contains(item)
                            HStack {
                                Image(systemName: isUnlocked ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isUnlocked ? Theme.success : Theme.textTertiary)
                                Text("\(item.displayName) — Day \(item.milestoneDays)")
                                    .font(.caption)
                                    .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                }
                .padding()

                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Bloom+")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.background)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
    }

    private func categoriesWithItems() -> [String] {
        GardenItemType.allCases
            .filter { $0 != .bonsai }
            .filter { type in
                unlockedItems.contains(where: { $0.type == type })
            }
            .map(\.displayCategory)
    }

    private func bonsaiStyleEnum(for id: String) -> BonsaiStyle {
        switch id {
        case "cascade-bonsai": return .cascade
        case "windswept-bonsai": return .windswept
        default: return .traditional
        }
    }
}
