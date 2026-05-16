import SwiftUI

/// Renders any garden item (plant, decoration, feature, ground) as a SwiftUI view.
struct GardenItemRenderer: View {
    let item: GardenItem
    let scale: CGFloat        // 0…1 size multiplier
    let opacity: Double       // 0…1
    let vitality: Double      // 0…1, affects color saturation

    var body: some View {
        Group {
            switch item.id {
            // ── Plants ──
            case "bamboo":             BambooPlant(scale: scale, vitality: vitality)
            case "white-lotus":        WhiteLotus(scale: scale, vitality: vitality)
            case "miniature-pine":     MiniaturePine(scale: scale, vitality: vitality)

            // ── Decorations ──
            case "river-stone":        RiverStone(scale: scale)
            case "stone-lantern":      StoneLantern(scale: scale, vitality: vitality)
            case "wind-chime":         WindChime(scale: scale)

            // ── Features ──
            case "koi-pond":           KoiPond(scale: scale, vitality: vitality)
            case "moon-gate":          MoonGate(scale: scale, vitality: vitality)
            case "pagoda":             Pagoda(scale: scale, vitality: vitality)

            // ── Ground ──
            case "moss":               MossGround(scale: scale, vitality: vitality)
            case "zen-garden":         ZenSandGarden(scale: scale, vitality: vitality)

            // ── Bonsai Styles (rendered via BonsaiView, not here) ──
            default:
                Circle()
                    .fill(item.colors.first ?? .gray)
                    .frame(width: 20 * scale, height: 20 * scale)
            }
        }
        .opacity(opacity)
    }
}

// MARK: - Plants

private struct BambooPlant: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let s = scale
        let stalkC = Color(red: 0.40, green: 0.72, blue: 0.38).opacity(0.7 + 0.3 * vitality)
        let leafC = Color(red: 0.30, green: 0.60, blue: 0.28)
        return ZStack(alignment: .bottom) {
            // Three stalks
            ForEach(0..<3) { i in
                let xOff = CGFloat(i - 1) * 6 * s
                let h = (0.7 + 0.3 * CGFloat(i + 1)) * 80 * s
                Capsule()
                    .fill(stalkC)
                    .frame(width: max(2, 4 * s), height: h)
                    .offset(x: xOff, y: -h * 0.5)
                // Node
                Capsule()
                    .fill(leafC.opacity(0.6))
                    .frame(width: max(3, 6 * s), height: 2)
                    .offset(x: xOff, y: -h * 0.35)
            }
            // Small leaves at top
            ForEach(0..<3) { i in
                let angle: Double = Double(i) * 30 - 30
                Capsule()
                    .fill(leafC)
                    .frame(width: 12 * s, height: 3 * s)
                    .rotationEffect(.degrees(angle))
                    .offset(y: -75 * s)
            }
        }
        .frame(width: 40 * s, height: 100 * s)
    }
}

private struct WhiteLotus: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let petalC = Color.white.opacity(0.7 + 0.3 * vitality)
        let centerC = Color(red: 0.90, green: 0.85, blue: 0.60)
        let s = scale
        ZStack {
            // Petals
            ForEach(0..<5) { i in
                Ellipse()
                    .fill(petalC)
                    .frame(width: 10 * s, height: 20 * s)
                    .rotationEffect(.degrees(Double(i) * 72 - 90))
                    .offset(y: -8 * s)
            }
            // Center
            Circle()
                .fill(centerC)
                .frame(width: 6 * s, height: 6 * s)
            // Stem
            Capsule()
                .fill(Color(red: 0.40, green: 0.65, blue: 0.35))
                .frame(width: 2 * s, height: 30 * s)
                .offset(y: 20 * s)
        }
        .frame(width: 30 * s, height: 50 * s)
    }
}

private struct MiniaturePine: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let s = scale
        let foliageC = Color(red: 0.18, green: 0.40, blue: 0.18).opacity(0.7 + 0.3 * vitality)
        let trunkC = Color(red: 0.30, green: 0.22, blue: 0.10)
        ZStack(alignment: .bottom) {
            // Trunk
            Capsule()
                .fill(trunkC)
                .frame(width: 4 * s, height: 30 * s)
            // Foliage layers (triangular)
            ForEach(0..<3) { i in
                let w = (24 - CGFloat(i) * 5) * s
                let h = (12 - CGFloat(i) * 2) * s
                let yOff = CGFloat(i) * (-14 * s)
                Triangle()
                    .fill(foliageC)
                    .frame(width: w, height: h)
                    .offset(y: yOff - 20 * s)
            }
        }
        .frame(width: 30 * s, height: 50 * s)
    }
}

// MARK: - Decorations

private struct RiverStone: View {
    let scale: CGFloat

    var body: some View {
        Ellipse()
            .fill(LinearGradient(
                colors: [Color(red: 0.60, green: 0.58, blue: 0.55),
                         Color(red: 0.45, green: 0.42, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .frame(width: 20 * scale, height: 14 * scale)
    }
}

private struct StoneLantern: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let stoneC = Color(red: 0.50, green: 0.45, blue: 0.38)
        let glowC = Color(red: 0.90, green: 0.70, blue: 0.35).opacity(0.4 + 0.4 * vitality)
        let s = scale
        VStack(spacing: 0) {
            // Top roof (kasa)
            Triangle()
                .fill(stoneC)
                .frame(width: 20 * s, height: 6 * s)
            // Fire window
            RoundedRectangle(cornerRadius: 2)
                .fill(glowC)
                .frame(width: 10 * s, height: 10 * s)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(stoneC, lineWidth: 1.5)
                )
            // Base
            Rectangle()
                .fill(stoneC)
                .frame(width: 14 * s, height: 4 * s)
        }
        .frame(width: 24 * s, height: 26 * s)
    }
}

private struct WindChime: View {
    let scale: CGFloat

    var body: some View {
        let s = scale
        VStack(spacing: 2 * s) {
            // Hook
            Capsule()
                .fill(Color(red: 0.60, green: 0.55, blue: 0.30))
                .frame(width: 2 * s, height: 6 * s)
            // Disc
            Circle()
                .fill(Color(red: 0.70, green: 0.65, blue: 0.45))
                .frame(width: 8 * s, height: 8 * s)
            // Tubes
            HStack(spacing: 3 * s) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(Color(red: 0.65 + 0.05 * Double(i),
                                     green: 0.60 + 0.05 * Double(i),
                                     blue: 0.40 + 0.05 * Double(i)))
                        .frame(width: 2 * s, height: (8 + CGFloat(i) * 3) * s)
                }
            }
        }
        .frame(width: 30 * s, height: 40 * s)
    }
}

// MARK: - Features

private struct KoiPond: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let waterC = Color(red: 0.20, green: 0.50, blue: 0.65).opacity(0.5 + 0.3 * vitality)
        let koiC = Color(red: 0.90, green: 0.50, blue: 0.20)
        let s = scale
        ZStack {
            // Pond
            Ellipse()
                .fill(waterC)
                .frame(width: 50 * s, height: 20 * s)
            // Koi fish
            Ellipse()
                .fill(koiC)
                .frame(width: 10 * s, height: 4 * s)
                .offset(x: -8 * s, y: -2 * s)
            Ellipse()
                .fill(Color(red: 0.95, green: 0.70, blue: 0.30))
                .frame(width: 8 * s, height: 3 * s)
                .offset(x: 10 * s, y: 3 * s)
        }
        .frame(width: 60 * s, height: 30 * s)
    }
}

private struct MoonGate: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let stoneC = Color(red: 0.60, green: 0.52, blue: 0.38).opacity(0.6 + 0.3 * vitality)
        let s = scale
        ZStack {
            // Circle gate
            Circle()
                .stroke(stoneC, lineWidth: 4 * s)
                .frame(width: 30 * s, height: 30 * s)
            // Base pillars
            Rectangle()
                .fill(stoneC)
                .frame(width: 4 * s, height: 12 * s)
                .offset(x: -17 * s, y: 15 * s)
            Rectangle()
                .fill(stoneC)
                .frame(width: 4 * s, height: 12 * s)
                .offset(x: 17 * s, y: 15 * s)
        }
        .frame(width: 50 * s, height: 50 * s)
    }
}

private struct Pagoda: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let woodC = Color(red: 0.60, green: 0.25, blue: 0.10).opacity(0.6 + 0.3 * vitality)
        let roofC = Color(red: 0.75, green: 0.60, blue: 0.30)
        let s = scale
        VStack(spacing: 0) {
            ForEach(0..<3) { i in
                let w = (22 - CGFloat(i) * 3) * s
                // Roof
                Triangle()
                    .fill(roofC)
                    .frame(width: w + 8 * s, height: 5 * s)
                // Body
                Rectangle()
                    .fill(woodC)
                    .frame(width: w, height: 8 * s)
            }
            // Top spire
            Capsule()
                .fill(roofC)
                .frame(width: 3 * s, height: 6 * s)
        }
        .frame(width: 40 * s, height: 55 * s)
    }
}

// MARK: - Ground

private struct MossGround: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let mossC = Color(red: 0.30, green: 0.62, blue: 0.36).opacity(0.5 + 0.4 * vitality)
        // Uneven moss patches
        ZStack {
            ForEach(0..<5) { i in
                let xOff = CGFloat(i - 2) * 20 * scale
                let yOff = CGFloat(i % 3 - 1) * 6 * scale
                Ellipse()
                    .fill(mossC)
                    .frame(width: 30 * scale + CGFloat(i) * 4 * scale,
                           height: 8 * scale + CGFloat(i % 2) * 3 * scale)
                    .offset(x: xOff, y: yOff)
            }
        }
        .frame(height: 20 * scale)
    }
}

private struct ZenSandGarden: View {
    let scale: CGFloat
    let vitality: Double

    var body: some View {
        let sandC = Color(red: 0.90, green: 0.88, blue: 0.80)
        let stoneC = Color(red: 0.65, green: 0.60, blue: 0.50)
        let s = scale
        ZStack {
            // Sand base
            RoundedRectangle(cornerRadius: 4)
                .fill(sandC)
                .frame(width: 80 * s, height: 20 * s)
            // Rake lines (subtle)
            ForEach(0..<6) { i in
                Capsule()
                    .fill(Color(red: 0.80, green: 0.78, blue: 0.70))
                    .frame(width: 60 * s, height: 1)
                    .offset(y: CGFloat(i - 3) * 3 * s)
            }
            // Stone
            Ellipse()
                .fill(stoneC)
                .frame(width: 8 * s, height: 5 * s)
                .offset(x: 15 * s)
        }
        .frame(width: 90 * s, height: 30 * s)
    }
}

// MARK: - Helpers

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
            ForEach(GardenItemCatalog.all.filter { $0.type != .bonsai }) { item in
                VStack {
                    GardenItemRenderer(item: item, scale: 1.5, opacity: 1.0, vitality: 1.0)
                        .frame(height: 80)
                    Text(item.displayName)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
