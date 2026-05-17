import SwiftUI

/// A vertical milestone timeline of everything you can grow or place.
/// Anchored around your next unlock — earned items above (full color),
/// upcoming items below (dimmed, with countdown).
struct GardenCollectionView: View {
    let days: Int
    let unlockedItemIDs: [String]
    let isPro: Bool

    @State private var showPaywall = false

    private var allItems: [GardenItem] {
        GardenItemCatalog.all.sorted { $0.milestoneDays < $1.milestoneDays }
    }
    private var unlockedCount: Int { allItems.filter { $0.milestoneDays <= days }.count }
    private var nextItem: GardenItem? { allItems.first { $0.milestoneDays > days } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                    ForEach(Array(allItems.enumerated()), id: \.element.id) { idx, item in
                        TimelineRow(
                            item: item,
                            days: days,
                            isLast: idx == allItems.count - 1,
                            isNext: item.id == nextItem?.id,
                            isPro: isPro,
                            onUpsell: { showPaywall = true }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("Collection")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = nextItem {
                Text("\(unlockedCount) of \(allItems.count) earned")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text("Next: \(next.displayName)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("in \(next.milestoneDays - days) day\(next.milestoneDays - days == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.brandPrimary)
            } else {
                Text("\(unlockedCount) of \(allItems.count) earned")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text("Everything is grown")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Row

private struct TimelineRow: View {
    let item: GardenItem
    let days: Int
    let isLast: Bool
    let isNext: Bool
    let isPro: Bool
    let onUpsell: () -> Void

    private var isUnlocked: Bool { days >= item.milestoneDays }
    private var daysAway: Int { max(0, item.milestoneDays - days) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            railColumn
            cardColumn
        }
    }

    // MARK: Rail (day marker + connecting line)

    private var railColumn: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(markerFill)
                    .frame(width: 36, height: 36)
                if isUnlocked {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(item.milestoneDays)")
                        .font(.caption2.bold())
                        .foregroundStyle(isNext ? .white : Theme.textTertiary)
                }
            }
            if !isLast {
                Rectangle()
                    .fill(Theme.ringTrack)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 36)
    }

    private var markerFill: Color {
        if isUnlocked { return Theme.brandPrimary }
        if isNext { return Theme.brandPrimary.opacity(0.55) }
        return Theme.cardSurface
    }

    // MARK: Card column

    private var cardColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                rendererThumb
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                    Text(item.type.displayCategory)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                    statusLine
                }
                Spacer(minLength: 0)
                trailingControl
            }
            if isNext || isUnlocked {
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isNext ? Theme.brandPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .padding(.bottom, 10)
    }

    private var rowBackground: Color {
        isUnlocked ? Theme.cardSurface : Theme.cardSurfaceLight
    }

    private var rendererThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.cardSurfaceLight.opacity(isUnlocked ? 1.0 : 0.5))
            GardenItemRenderer(
                item: item,
                scale: 0.9,
                opacity: isUnlocked ? 1.0 : 0.25,
                vitality: isUnlocked ? 1.0 : 0.3
            )
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 56, height: 56)
    }

    @ViewBuilder
    private var statusLine: some View {
        if isUnlocked {
            Text("Earned at day \(item.milestoneDays)")
                .font(.caption2)
                .foregroundStyle(Theme.success)
        } else {
            Text("\(daysAway) day\(daysAway == 1 ? "" : "s") to go")
                .font(.caption2)
                .foregroundStyle(isNext ? Theme.brandPrimary : Theme.textTertiary)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isUnlocked {
            let canPlace = GardenItemCatalog.canPlace(item, isPro: isPro, currentPlacedCount: 0) || item.type == .bonsai
            if canPlace {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.success)
            } else {
                Button("Pro", action: onUpsell)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)
                    .controlSize(.mini)
            }
        }
    }
}
