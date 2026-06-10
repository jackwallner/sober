import SwiftData
import SwiftUI

/// The garden scene: a single bonsai centerpiece that grows daily, the grove of
/// completed trees behind it, and the species switcher. Decorations, companion
/// plants, ponds and ground covers were removed — the garden is one tree you
/// grow and (with Bloom+) re-style, nothing half-finished to clutter it.
struct GardenSceneView: View {
    let days: Int
    let vitality: Double
    let activeBonsaiStyleID: String
    let isPro: Bool
    var completedTreeStyles: [String] = []
    /// Tapped when the user taps the species badge — the discoverability hook
    /// for swapping the active bonsai.
    var onSwapBonsai: (() -> Void)? = nil

    private var cycle: (dayInCycle: Int, completed: Int) {
        GardenService.cycleProgress(forDays: days)
    }
    private var dayInCycle: Int { cycle.dayInCycle }
    private var stage: BonsaiStage { GardenService.stage(forDays: days) }

    private var bonsaiStyle: BonsaiStyle {
        Self.styleEnum(for: activeBonsaiStyleID)
    }

    private var activeSpeciesName: String {
        GardenItemCatalog.item(id: activeBonsaiStyleID)?.displayName ?? bonsaiStyle.displayName
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                // ── Sky ──
                skyGradient

                // ── Ground ──
                groundView

                // ── Grove (completed trees, behind centerpiece) ──
                grove(in: s)

                // ── Bonsai (centerpiece) ──
                // `fill: true` zooms the canvas onto the actual plant and
                // bottom-anchors the pot, so the tree fills the frame instead
                // of floating small in a 600pt square.
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
                .onTapGesture { onSwapBonsai?() }
                .position(
                    x: s.width * 0.5,
                    y: groundLineY(s) - centerHeight(container: s) / 2
                )

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

    // MARK: - Sizing

    /// The dirt line — where the pot rests. Leaves room for the ground band.
    private func groundLineY(_ size: CGSize) -> CGFloat {
        size.height - 22
    }

    private func centerWidth(container size: CGSize) -> CGFloat {
        size.width * (stage == .seed ? 0.55 : 1.0)
    }

    private func centerHeight(container size: CGSize) -> CGFloat {
        let topInset = size.height * (stage == .seed ? 0.40 : 0.05)
        return groundLineY(size) - topInset
    }

    // MARK: - Sky & Ground

    private var skyGradient: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Theme.skyGradient)
    }

    private var groundView: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.42, blue: 0.28),
                             Color(red: 0.45, green: 0.32, blue: 0.20)],
                    startPoint: .top, endPoint: .bottom))
                .frame(height: 24)
        }
    }

    // MARK: - Badge

    /// Pure stage / year readout in the top-right corner.
    private var stageBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(Theme.caption())
            if cycle.completed > 0 {
                Text("Year \(cycle.completed + 1) · \(stage.title)")
                    .font(Theme.caption(weight: .bold))
            } else {
                Text(stage.title)
                    .font(Theme.caption(weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(.primary)
        .accessibilityLabel("\(stage.title) stage")
    }

    /// Entry point for swapping the bonsai species. Compact by design — the
    /// garden is the hero, not the chrome. Pro gets a quiet "Switch" chip
    /// (matching the stage badge); free keeps a small branded upsell chip so
    /// the upgrade value stays on the garden itself.
    private var speciesSwitcher: some View {
        Button {
            onSwapBonsai?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isPro ? "arrow.triangle.2.circlepath" : "crown.fill")
                    .font(Theme.caption(weight: .bold))
                Text(isPro ? "Switch" : "Unlock \(GardenItemCatalog.premiumSpecies.count) trees")
                    .font(Theme.caption(weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isPro ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Theme.brandGradient),
                in: Capsule()
            )
            .foregroundStyle(isPro ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .shadow(color: .black.opacity(isPro ? 0 : 0.15), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPro ? "Switch bonsai species — currently \(activeSpeciesName)" : "Unlock more bonsai species with Bloom+")
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
                    style: Self.styleEnum(for: styleID),
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
                    .font(Theme.caption(weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .position(x: size.width - 18, y: baseY - 18)
            }
        }
    }

    static func styleEnum(for id: String) -> BonsaiStyle {
        switch id {
        case "cascade-bonsai", "cascade": return .cascade
        case "windswept-bonsai", "windswept": return .windswept
        case "sakura-bonsai", "sakura": return .sakura
        case "maple-bonsai", "maple": return .maple
        case "pine-bonsai", "pine": return .pine
        default: return .traditional
        }
    }
}

// MARK: - Preview

#Preview {
    GardenSceneView(
        days: 90,
        vitality: 0.85,
        activeBonsaiStyleID: "sakura-bonsai",
        isPro: true,
        completedTreeStyles: ["traditional-bonsai"]
    )
    .frame(height: 320)
    .padding()
}
