import SwiftData
import SwiftUI

/// The full garden scene: bonsai centerpiece + placed items + sky/ground.
/// Replaces the old `GardenStageView`.
struct GardenSceneView: View {
    let days: Int
    let vitality: Double
    let placedItemIDs: [String]
    let activeBonsaiStyleID: String
    let isPro: Bool
    var completedTreeStyles: [String] = []
    /// Tapping a rendered element (bonsai or placed item) reports it here.
    var onSelect: ((GardenItem) -> Void)? = nil
    /// Tapped when the user taps the species badge in the top-right corner —
    /// this is the discoverability hook for swapping the active bonsai
    /// without burying the action inside the overflow menu.
    var onSwapBonsai: (() -> Void)? = nil

    private var cycle: (dayInCycle: Int, completed: Int) {
        GardenService.cycleProgress(forDays: days)
    }
    private var dayInCycle: Int { cycle.dayInCycle }
    private var stage: BonsaiStage { GardenService.stage(forDays: days) }

    private var bonsaiStyle: BonsaiStyle {
        switch activeBonsaiStyleID {
        case "cascade-bonsai": return .cascade
        case "windswept-bonsai": return .windswept
        case "sakura-bonsai": return .sakura
        default: return .traditional
        }
    }

    private var activeBonsaiItem: GardenItem? {
        GardenItemCatalog.item(id: activeBonsaiStyleID)
            ?? GardenItemCatalog.all.first { $0.type == .bonsai }
    }

    /// Items that should be rendered in the scene (non-bonsai placed items).
    private var placedItems: [GardenItem] {
        placedItemIDs.compactMap { GardenItemCatalog.item(id: $0) }
            .filter { $0.type != .bonsai }
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                // ── Sky ──
                skyGradient

                // ── Background Features (pagoda, moon gate) ──
                ForEach(backgroundItems) { item in
                    GardenItemRenderer(
                        item: item,
                        scale: itemScale(item, container: s),
                        opacity: 0.6,
                        vitality: vitality
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(item) }
                    .position(
                        x: backgroundPosition(for: item, in: s).x,
                        y: backgroundPosition(for: item, in: s).y
                    )
                }

                // ── Ground ──
                groundView

                // ── Grove (completed trees, behind centerpiece) ──
                grove(in: s)

                // ── Bonsai (centerpiece) ──
                // `fill: true` zooms the canvas onto the actual plant and
                // bottom-anchors the pot, so the tree fills the frame instead
                // of floating small in a 600pt square. The frame spans from
                // just under the top edge down to the ground line, so the
                // canopy uses the full height with no dead sky band.
                BonsaiView(
                    day: dayInCycle,
                    style: bonsaiStyle,
                    vitality: vitality,
                    fill: true
                )
                .frame(
                    width: centerWidth(container: s),
                    height: centerHeight(container: s)
                )
                .contentShape(Rectangle())
                .onTapGesture { if let b = activeBonsaiItem { onSelect?(b) } }
                .position(
                    x: s.width * 0.5,
                    y: groundLineY(s) - centerHeight(container: s) / 2
                )

                // ── Companion Plants (left/right of bonsai) ──
                ForEach(companionPlants) { item in
                    GardenItemRenderer(
                        item: item,
                        scale: itemScale(item, container: s),
                        opacity: 0.85 + 0.15 * vitality,
                        vitality: vitality
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(item) }
                    .position(
                        x: companionPosition(for: item, index: companionPlants.firstIndex(of: item) ?? 0, total: companionPlants.count, in: s).x,
                        y: companionPosition(for: item, index: companionPlants.firstIndex(of: item) ?? 0, total: companionPlants.count, in: s).y
                    )
                }

                // ── Decorations (foreground corners) ──
                ForEach(decorations) { item in
                    GardenItemRenderer(
                        item: item,
                        scale: itemScale(item, container: s),
                        opacity: 0.8 + 0.2 * vitality,
                        vitality: vitality
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(item) }
                    .position(
                        x: decorationPosition(for: item, index: decorations.firstIndex(of: item) ?? 0, in: s).x,
                        y: decorationPosition(for: item, index: decorations.firstIndex(of: item) ?? 0, in: s).y
                    )
                }

                // ── Foreground Features (koi pond at bottom) ──
                ForEach(foregroundFeatures) { item in
                    GardenItemRenderer(
                        item: item,
                        scale: itemScale(item, container: s),
                        opacity: 0.85 + 0.15 * vitality,
                        vitality: vitality
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect?(item) }
                    .position(
                        x: foregroundFeaturePosition(for: item, in: s).x,
                        y: foregroundFeaturePosition(for: item, in: s).y
                    )
                }

                // ── Overlays: stage info (top-right) + species switcher ──
                VStack {
                    HStack {
                        Spacer()
                        stageBadge
                    }
                    Spacer()
                    HStack {
                        speciesSwitcher
                        Spacer()
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Item Filtering

    private var backgroundItems: [GardenItem] {
        placedItems.filter { $0.type == .feature && $0.id != "koi-pond" }
    }

    private var companionPlants: [GardenItem] {
        placedItems.filter { $0.type == .plant }
    }

    private var decorations: [GardenItem] {
        placedItems.filter { $0.type == .decoration }
    }

    private var foregroundFeatures: [GardenItem] {
        placedItems.filter { $0.id == "koi-pond" }
    }

    private var activeGround: GardenItem? {
        placedItems.first { $0.type == .ground }
    }

    // MARK: - Positioning

    private func backgroundPosition(for item: GardenItem, in size: CGSize) -> CGPoint {
        switch item.id {
        case "pagoda":
            return CGPoint(x: size.width * 0.85, y: size.height * 0.28)
        case "moon-gate":
            return CGPoint(x: size.width * 0.15, y: size.height * 0.35)
        default:
            return CGPoint(x: size.width * (0.2 + 0.6 * CGFloat(item.id.hashValue % 10) / 10),
                           y: size.height * 0.30)
        }
    }

    private func companionPosition(for item: GardenItem, index: Int, total: Int, in size: CGSize) -> CGPoint {
        let centerX = size.width * 0.5
        let baseY = size.height * 0.72 - bonsaiHeight(container: size) * 0.15
        if total == 1 {
            return CGPoint(x: centerX + 70, y: baseY) // right side
        }
        let spacing: CGFloat = 55
        let leftOffset = -CGFloat(total - 1) / 2.0 * spacing
        return CGPoint(x: centerX + leftOffset + CGFloat(index) * spacing, y: baseY)
    }

    private func decorationPosition(for item: GardenItem, index: Int, in size: CGSize) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: size.width * 0.08, y: size.height * 0.78),
            CGPoint(x: size.width * 0.92, y: size.height * 0.82),
            CGPoint(x: size.width * 0.12, y: size.height * 0.88),
            CGPoint(x: size.width * 0.88, y: size.height * 0.88),
        ]
        return positions[index % positions.count]
    }

    private func foregroundFeaturePosition(for item: GardenItem, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.85)
    }

    // MARK: - Sizing

    /// The dirt line — where the pot rests. Leaves room for the ground band.
    private func groundLineY(_ size: CGSize) -> CGFloat {
        size.height - 22
    }

    // The centerpiece frame. `BonsaiView(fill:)` fits the plant to whatever
    // frame we give it (pot bottom-anchored), so we hand it the full width and
    // the whole column from just under the top edge down to the ground line —
    // the canopy then climbs the full height with no empty sky overhead. A
    // seedling gets a shorter, narrower frame so it reads as small, not as a
    // giant zoomed sprout.
    private func centerWidth(container size: CGSize) -> CGFloat {
        size.width * (stage == .seed ? 0.55 : 1.0)
    }

    private func centerHeight(container size: CGSize) -> CGFloat {
        let topInset = size.height * (stage == .seed ? 0.40 : 0.05)
        return groundLineY(size) - topInset
    }

    // Retained for companion-plant positioning, which references the
    // centerpiece height to sit plants beside the trunk.
    private func bonsaiHeight(container size: CGSize) -> CGFloat {
        centerHeight(container: size)
    }

    private func itemScale(_ item: GardenItem, container size: CGSize) -> CGFloat {
        let base: CGFloat
        switch item.size {
        case .small:  base = 0.3
        case .medium: base = 0.5
        case .large:  base = 0.7
        }
        return min(size.width, size.height) / 300 * base
    }

    // MARK: - Sky & Ground

    private var skyGradient: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Theme.skyGradient)
    }

    private var groundView: some View {
        VStack {
            Spacer()
            if let ground = activeGround {
                GardenItemRenderer(item: ground, scale: 1.5, opacity: 0.9, vitality: vitality)
                    .frame(height: 30)
            } else {
                // Default dirt ground
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.42, blue: 0.28),
                                 Color(red: 0.45, green: 0.32, blue: 0.20)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: 24)
            }
        }
    }

    // MARK: - Badge

    // Pure stage/year readout. The swap action lives in `speciesSwitcher`
    // below, so this no longer pretends to be a button.
    private var stageBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.caption2)
            if cycle.completed > 0 {
                Text("Year \(cycle.completed + 1) · \(stage.title)")
                    .font(.caption.bold())
            } else {
                Text(stage.title)
                    .font(.caption.bold())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .accessibilityLabel("\(stage.title) stage")
    }

    private var activeSpeciesName: String {
        activeBonsaiItem?.displayName ?? bonsaiStyle.displayName
    }

    /// The obvious, branded entry point for swapping the bonsai species. For
    /// Pro it names the current tree and reads as "tap to switch"; for free it
    /// pitches the locked species so the upgrade value is on the garden itself,
    /// not buried in a menu.
    private var speciesSwitcher: some View {
        Button {
            onSwapBonsai?()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isPro ? "arrow.triangle.2.circlepath" : "crown.fill")
                    .font(.caption.weight(.bold))
                Text(isPro ? "\(activeSpeciesName) · Switch" : "Unlock 4 trees")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .opacity(0.85)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.brandGradient, in: Capsule())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPro ? "Switch bonsai species" : "Unlock more bonsai species with Bloom+")
    }

    // MARK: - Grove (completed trees)

    @ViewBuilder
    private func grove(in size: CGSize) -> some View {
        let trees = completedTreeStyles
        if !trees.isEmpty {
            let maxVisible = 6
            let visible = Array(trees.prefix(maxVisible))
            let overflow = trees.count - visible.count
            let treeW = min(size.width * 0.18, 64)
            let treeH = treeW
            let baseY = size.height * 0.78
            let spread = min(size.width * 0.88, CGFloat(visible.count) * treeW * 0.82)
            let step = visible.count > 1 ? spread / CGFloat(visible.count - 1) : 0
            let startX = (size.width - spread) / 2

            ForEach(Array(visible.enumerated()), id: \.offset) { idx, styleID in
                BonsaiView(
                    day: 365,
                    style: styleEnum(for: styleID),
                    vitality: 1.0
                )
                .frame(width: treeW, height: treeH)
                .opacity(0.78)
                .position(
                    x: visible.count == 1 ? size.width * 0.5 : startX + CGFloat(idx) * step,
                    y: baseY
                )
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .position(x: size.width - 18, y: baseY - 18)
            }
        }
    }

    private func styleEnum(for id: String) -> BonsaiStyle {
        switch id {
        case "cascade-bonsai", "cascade": return .cascade
        case "windswept-bonsai", "windswept": return .windswept
        case "sakura-bonsai", "sakura": return .sakura
        default: return .traditional
        }
    }
}

// MARK: - Preview

#Preview {
    GardenSceneView(
        days: 90,
        vitality: 0.85,
        placedItemIDs: ["moss", "bamboo", "stone-lantern", "koi-pond", "pagoda"],
        activeBonsaiStyleID: "traditional-bonsai",
        isPro: true
    )
    .frame(height: 320)
    .padding()
}
