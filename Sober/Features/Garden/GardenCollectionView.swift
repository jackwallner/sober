import SwiftUI

/// A vertical milestone timeline of everything you can grow or place.
/// Anchored around your next unlock — earned items above (full color),
/// upcoming items below (dimmed, with countdown).
struct GardenCollectionView: View {
    let days: Int
    let unlockedItemIDs: [String]
    let isPro: Bool
    /// When true, renders inside a parent `List` (Progress sheet) without nested
    /// navigation or scroll — avoids double scroll and title overlap.
    var embeddedInList: Bool = false

    @State private var showPaywall = false

    private var allItems: [GardenItem] {
        GardenItemCatalog.all.sorted { $0.milestoneDays < $1.milestoneDays }
    }
    private var unlockedCount: Int { allItems.filter { $0.milestoneDays <= days }.count }
    private var nextItem: GardenItem? { allItems.first { $0.milestoneDays > days } }

    var body: some View {
        Group {
            if embeddedInList {
                timelineContent
            } else {
                NavigationStack {
                    ScrollView {
                        timelineContent
                    }
                    .background(Theme.background)
                    .navigationTitle("Collection")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(impressionId: "sober_garden_collection_sheet")
        }
    }

    private var timelineContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, embeddedInList ? 0 : 16)
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
                .padding(.horizontal, embeddedInList ? 0 : 16)
            }
        }
        .padding(.vertical, embeddedInList ? 4 : 16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = nextItem {
                Text("\(unlockedCount) of \(allItems.count) earned")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                Text("Next: \(next.displayName)")
                    .font(Theme.heading(weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("in \(next.milestoneDays - days) day\(next.milestoneDays - days == 1 ? "" : "s")")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.brandPrimary)
            } else {
                Text("\(unlockedCount) of \(allItems.count) earned")
                    .font(Theme.subhead())
                    .foregroundStyle(Theme.textSecondary)
                Text("Everything is grown")
                    .font(Theme.heading(weight: .semibold))
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
                        .font(Theme.caption(weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(item.milestoneDays)")
                        .font(Theme.caption(weight: .bold))
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
                        .font(Theme.subhead(weight: .semibold))
                        .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    if item.type != .bonsai {
                        Text(item.type.displayCategory)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.textTertiary)
                    }
                    statusLine
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                trailingControl
            }
            if isNext || isUnlocked {
                Text(item.description)
                    .font(Theme.caption())
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
                    .font(Theme.caption())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusLine: some View {
        if isUnlocked {
            Text(item.milestoneDays <= 0 ? "Earned from the start" : "Earned at day \(item.milestoneDays)")
                .font(Theme.caption())
                .foregroundStyle(Theme.success)
        } else {
            Text("\(daysAway) day\(daysAway == 1 ? "" : "s") to go")
                .font(Theme.caption())
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
                Button("Bloom+", action: onUpsell)
                    .font(Theme.caption(weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)
                    .controlSize(.mini)
            }
        }
    }
}
