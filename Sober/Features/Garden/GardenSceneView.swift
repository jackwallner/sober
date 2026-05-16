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

    private var stage: BonsaiStage { GardenService.stage(forDays: days) }

    private var bonsaiStyle: BonsaiStyle {
        switch activeBonsaiStyleID {
        case "cascade-bonsai": return .cascade
        case "windswept-bonsai": return .windswept
        default: return .traditional
        }
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
                    .position(
                        x: backgroundPosition(for: item, in: s).x,
                        y: backgroundPosition(for: item, in: s).y
                    )
                }

                // ── Ground ──
                groundView

                // ── Bonsai (centerpiece) ──
                BonsaiView(
                    stage: stage,
                    style: bonsaiStyle,
                    vitality: vitality
                )
                .frame(
                    width: bonsaiWidth(container: s),
                    height: bonsaiHeight(container: s)
                )
                .position(x: s.width * 0.5, y: s.height * (stage == .seed ? 0.72 : 0.60))

                // ── Companion Plants (left/right of bonsai) ──
                ForEach(companionPlants) { item in
                    GardenItemRenderer(
                        item: item,
                        scale: itemScale(item, container: s),
                        opacity: 0.85 + 0.15 * vitality,
                        vitality: vitality
                    )
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
                    .position(
                        x: foregroundFeaturePosition(for: item, in: s).x,
                        y: foregroundFeaturePosition(for: item, in: s).y
                    )
                }

                // ── Stage Badge ──
                VStack {
                    HStack {
                        Spacer()
                        stageBadge
                    }
                    Spacer()
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

    private func bonsaiWidth(container size: CGSize) -> CGFloat {
        size.width * (stage == .seed ? 0.08 : 0.35)
    }

    private func bonsaiHeight(container size: CGSize) -> CGFloat {
        size.height * (stage == .seed ? 0.06 : 0.45)
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

    private var stageBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.caption2)
            Text(stage.title)
                .font(.caption.bold())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.primary)
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
