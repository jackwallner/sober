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
                PaywallView(impressionId: "sober_garden_customize_sheet")
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
                                // Refresh widget/watch immediately so the home-screen
                                // tree matches the species the user just picked.
                                WidgetSnapshotPump.push(context: context)
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
                                            .font(Theme.subhead(weight: .bold))
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
                                    .font(Theme.caption())
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
                .font(Theme.caption())
                .foregroundStyle(isPlaced ? Theme.brandPrimary : Theme.textSecondary)

            Button(isPlaced ? "Remove" : "Place") {
                let svc = GardenService(context: context)
                if isPlaced {
                    svc.removeItem(item)
                } else {
                    svc.placeItem(item)
                }
                // Keep the widget/watch snapshot in sync with placed decorations.
                WidgetSnapshotPump.push(context: context)
            }
            .buttonStyle(.bordered)
            .tint(isPlaced ? .red : Theme.brandPrimary)
            .font(Theme.caption())
            .controlSize(.small)
        }
    }

    // MARK: - Free Preview

    private var freePreview: some View {
        let species = GardenItemCatalog.all.filter { $0.type == .bonsai }
        return ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Grow a whole grove with Bloom+")
                        .font(Theme.title(weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("Every species is a different shape of resilience. Swap between them and watch each one grow with your streak.")
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                bonsaiPitch

                // What else unlocks as the streak grows.
                let extras = GardenItemCatalog.all.filter { $0.type != .bonsai }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plus decorations as you go")
                        .font(Theme.caption(weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(extras.prefix(6)) { item in
                        let isUnlocked = unlockedItems.contains(item)
                        HStack {
                            Image(systemName: isUnlocked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isUnlocked ? Theme.success : Theme.textTertiary)
                            Text("\(item.displayName) · Day \(item.milestoneDays)")
                                .font(Theme.caption())
                                .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 8)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            upgradeBar(treeCount: species.count)
        }
    }

    /// Sticky purchase bar pinned to the bottom so the upgrade CTA is always on
    /// screen — the value proof scrolls above it instead of pushing it off the
    /// fold (the old layout buried the button ~700pt down).
    private func upgradeBar(treeCount: Int) -> some View {
        VStack(spacing: 6) {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Unlock all \(treeCount) trees")
                }
                .font(Theme.body(weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .foregroundStyle(.white)
            }
            Text("Swap any species anytime · keep every decoration you earn")
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

    /// The headline Bloom+ pitch: each bonsai species rendered at a mature day
    /// alongside the one-line story of what it represents, so the value of the
    /// upgrade is concrete and visual rather than a feature bullet.
    private var bonsaiPitch: some View {
        let species = GardenItemCatalog.all.filter { $0.type == .bonsai }
        return VStack(spacing: 10) {
            ForEach(species) { style in
                let earned = days >= style.milestoneDays
                HStack(spacing: 12) {
                    BonsaiView(day: 60, style: bonsaiStyleEnum(for: style.id), vitality: 1.0)
                        .frame(width: 60, height: 60)
                        .background(Theme.skyGradient, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(style.displayName)
                                .font(Theme.subhead(weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            if earned {
                                Text("Unlocked")
                                    .font(Theme.caption(weight: .bold))
                                    .foregroundStyle(Theme.success)
                            } else {
                                Text("Day \(style.milestoneDays)")
                                    .font(Theme.caption(weight: .bold))
                                    .foregroundStyle(Theme.brandPrimary)
                            }
                        }
                        Text(style.description)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.body())
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
        case "sakura-bonsai": return .sakura
        case "maple-bonsai": return .maple
        case "pine-bonsai": return .pine
        default: return .traditional
        }
    }
}
