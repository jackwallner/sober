import SwiftUI

/// Shows all garden items — unlocked and locked — grouped by category.
/// Unlocked items are full-color. Locked items show their milestone requirement.
/// Pro upsell on items that can't be placed.
struct GardenCollectionView: View {
    let days: Int
    let unlockedItemIDs: [String]
    let isPro: Bool

    @State private var showPaywall = false

    private var allItems: [GardenItem] { GardenItemCatalog.all }
    private var unlockedItems: [GardenItem] { allItems.filter { unlockedItemIDs.contains($0.id) || $0.milestoneDays <= days } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progress Header
                    progressHeader

                    // Grouped by type
                    ForEach(GardenItemType.allCases, id: \.rawValue) { type in
                        let items = allItems.filter { $0.type == type }
                        if !items.isEmpty {
                            categorySection(type: type, items: items)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Collection")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var progressHeader: some View {
        let unlocked = unlockedItems.count
        let total = allItems.count
        let pct = total > 0 ? Double(unlocked) / Double(total) : 0

        return VStack(spacing: 12) {
            // Stats
            HStack {
                StatBlock(label: "Unlocked", value: "\(unlocked)")
                StatBlock(label: "Total", value: "\(total)")
                StatBlock(label: "Progress", value: "\(Int(pct * 100))%")
            }

            // Progress bar
            ProgressView(value: pct)
                .tint(Theme.brandGradient)
        }
        .padding()
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }

    private func categorySection(type: GardenItemType, items: [GardenItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(type.displayCategory)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    let isUnlocked = unlockedItems.contains(item) || item.milestoneDays <= days
                    collectionCard(item: item, isUnlocked: isUnlocked)
                }
            }
        }
    }

    private func collectionCard(item: GardenItem, isUnlocked: Bool) -> some View {
        VStack(spacing: 6) {
            // Item rendering
            if isUnlocked {
                GardenItemRenderer(item: item, scale: 1.0, opacity: 1.0, vitality: 1.0)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
            } else {
                ZStack {
                    GardenItemRenderer(item: item, scale: 1.0, opacity: 0.2, vitality: 0.3)
                        .frame(height: 55)

                    // Lock overlay
                    VStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text("Day \(item.milestoneDays)")
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            Text(item.displayName)
                .font(.caption2)
                .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textTertiary)
                .lineLimit(1)

            // Place/Subscribe button
            if isUnlocked {
                if GardenItemCatalog.canPlace(item, isPro: isPro, currentPlacedCount: 0) || item.type == .bonsai {
                    Label("Available", systemImage: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(Theme.success)
                } else {
                    Button("Pro to place") { showPaywall = true }
                        .buttonStyle(.bordered)
                        .tint(Theme.brandPrimary)
                        .font(.caption2)
                        .controlSize(.mini)
                }
            } else {
                Text("Unlocks in \(item.milestoneDays - days) days")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(8)
        .background(Theme.cardSurfaceLight, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper

private struct StatBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.brandGradient)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
