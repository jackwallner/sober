import SwiftUI

// MARK: - Bonsai View

struct BonsaiView: View {
    let stage: BonsaiStage
    let style: BonsaiStyle
    let vitality: Double

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                switch style {
                case .traditional: TraditionalBonsai(stage: stage, vitality: vitality, size: s)
                case .cascade:     CascadeBonsai(stage: stage, vitality: vitality, size: s)
                case .windswept:   WindsweptBonsai(stage: stage, vitality: vitality, size: s)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Style

enum BonsaiStyle: String, CaseIterable, Sendable {
    case traditional
    case cascade
    case windswept

    var displayName: String {
        switch self {
        case .traditional: return "Traditional"
        case .cascade: return "Cascading"
        case .windswept: return "Windswept"
        }
    }
}

// MARK: - Geometry

private struct BonsaiGeometry {
    let trunkBaseWidth: CGFloat
    let trunkTopWidth: CGFloat
    let trunkHeight: CGFloat
    let canopyRadius: CGFloat
    let canopyClusterCount: Int
    let potWidth: CGFloat
    let potHeight: CGFloat

    static func forStage(_ stage: BonsaiStage, size: CGFloat) -> BonsaiGeometry {
        let clusters: Int
        let canopy: CGFloat
        let trunkH: CGFloat
        let baseTrunk: CGFloat

        switch stage {
        case .seed:
            baseTrunk = 0; clusters = 0; canopy = 0; trunkH = 0
        case .sprout:
            baseTrunk = 4; clusters = 2; canopy = size * 0.12; trunkH = size * 0.08
        case .seedling:
            baseTrunk = 6; clusters = 3; canopy = size * 0.18; trunkH = size * 0.15
        case .young:
            baseTrunk = 8; clusters = 4; canopy = size * 0.24; trunkH = size * 0.22
        case .adolescent:
            baseTrunk = 10; clusters = 5; canopy = size * 0.30; trunkH = size * 0.28
        case .mature:
            baseTrunk = 12; clusters = 6; canopy = size * 0.35; trunkH = size * 0.33
        case .refined:
            baseTrunk = 14; clusters = 7; canopy = size * 0.40; trunkH = size * 0.36
        case .ancient:
            baseTrunk = 16; clusters = 8; canopy = size * 0.44; trunkH = size * 0.38
        case .legendary:
            baseTrunk = 18; clusters = 9; canopy = size * 0.48; trunkH = size * 0.40
        }

        let potW = size * (stage == .seed ? 0.3 : 0.35)
        let potH = size * (stage == .seed ? 0.08 : 0.12)

        return BonsaiGeometry(
            trunkBaseWidth: baseTrunk,
            trunkTopWidth: max(2, baseTrunk * 0.35),
            trunkHeight: trunkH,
            canopyRadius: canopy,
            canopyClusterCount: clusters,
            potWidth: potW,
            potHeight: potH
        )
    }
}

// MARK: - Pot

private struct BonsaiPot: View {
    let geo: BonsaiGeometry
    let vitality: Double

    var body: some View {
        let top = geo.potWidth * 0.85
        let bottom = geo.potWidth * 0.70
        let h = geo.potHeight
        let bodyColor = Color(red: 0.65, green: 0.38, blue: 0.22).opacity(0.7 + 0.3 * vitality)

        Path { path in
            path.move(to: CGPoint(x: -top / 2, y: 0))
            path.addLine(to: CGPoint(x: top / 2, y: 0))
            path.addLine(to: CGPoint(x: bottom / 2, y: h))
            path.addLine(to: CGPoint(x: -bottom / 2, y: h))
            path.closeSubpath()
        }
        .fill(bodyColor)

        RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 0.50, green: 0.28, blue: 0.15))
            .frame(width: top + 6, height: 5)

        Capsule()
            .fill(Color(red: 0.20, green: 0.15, blue: 0.08))
            .frame(width: top - 8, height: 6)
            .offset(y: -h * 0.3)
    }
}

// MARK: - Foliage

private struct FoliageCluster: View {
    let radius: CGFloat
    let color: Color
    let offset: CGSize
    let opacity: Double

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: radius * 2, height: radius * 2)
            .offset(offset)
            .opacity(opacity)
    }
}

// MARK: - Trunk Path

private func trunkPath(bottom: CGPoint, top: CGPoint, baseWidth: CGFloat, topWidth: CGFloat, curve: CGPoint) -> Path {
    Path { path in
        let midX = (bottom.x + top.x) / 2 + curve.x
        let midY = (bottom.y + top.y) / 2 + curve.y

        path.move(to: CGPoint(x: bottom.x - baseWidth / 2, y: bottom.y))
        path.addQuadCurve(to: CGPoint(x: top.x - topWidth / 2, y: top.y),
                         control: CGPoint(x: midX - baseWidth * 0.4, y: midY))
        path.addLine(to: CGPoint(x: top.x + topWidth / 2, y: top.y))
        path.addQuadCurve(to: CGPoint(x: bottom.x + baseWidth / 2, y: bottom.y),
                         control: CGPoint(x: midX + baseWidth * 0.4, y: midY))
        path.closeSubpath()
    }
}

// MARK: - Traditional

private struct TraditionalBonsai: View {
    let stage: BonsaiStage
    let vitality: Double
    let size: CGFloat
    @State private var clusterOffsets: [(CGSize, Double)] = []
    @State private var hasSeed = false

    private var geo: BonsaiGeometry { BonsaiGeometry.forStage(stage, size: size) }
    private let trunkColor = Color(red: 0.40, green: 0.24, blue: 0.10)
    private let foliageColor = Color(red: 0.32, green: 0.56, blue: 0.28)
    private let foliageLight = Color(red: 0.42, green: 0.68, blue: 0.35)

    var body: some View {
        if stage == .seed {
            Circle()
                .fill(foliageColor)
                .frame(width: 14, height: 14)
                .offset(y: 4)
                .opacity(0.6 + 0.4 * vitality)
        } else if stage == .sprout {
            sproutBody
        } else {
            fullTreeBody
        }
    }

    private var potOffsetY: CGFloat { geo.potHeight * 0.5 + 2 }

    private var sproutBody: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(foliageColor)
                .frame(width: 4, height: 20)
                .opacity(0.8 + 0.2 * vitality)
            Circle()
                .fill(foliageLight)
                .frame(width: 20, height: 20)
                .opacity(0.8 + 0.2 * vitality)
        }
        .offset(y: -potOffsetY - 6)
    }

    private var fullTreeBody: some View {
        let clusters = min(geo.canopyClusterCount, 7)
        let centerY = -potOffsetY - geo.trunkHeight * 0.85

        return ZStack {
            trunkPath(bottom: CGPoint(x: 0, y: -potOffsetY),
                      top: CGPoint(x: 0, y: -potOffsetY - geo.trunkHeight),
                      baseWidth: geo.trunkBaseWidth, topWidth: geo.trunkTopWidth, curve: .zero)
                .fill(trunkColor)
                .opacity(0.7 + 0.3 * vitality)

            // Branches
            ForEach(0..<max(0, clusters - 2), id: \.self) { i in
                let t = CGFloat(i) / CGFloat(max(1, clusters - 2))
                let branchX: CGFloat = t < 0.5 ? -1 : 1
                let branchY = -potOffsetY - geo.trunkHeight * (0.3 + t * 0.5)
                let branchLen = geo.trunkHeight * 0.15 * (1 - t * 0.3)

                Capsule()
                    .fill(trunkColor.opacity(0.8))
                    .frame(width: branchLen, height: max(2, geo.trunkBaseWidth * 0.3 * (1 - t * 0.2)))
                    .rotationEffect(.degrees(branchX > 0 ? -20 : 20))
                    .position(x: branchX * geo.trunkBaseWidth * 0.3, y: branchY)
            }

            // Foliage clusters
            Group {
                if clusters >= 1 {
                    FoliageCluster(radius: geo.canopyRadius * 0.55, color: foliageColor,
                                   offset: CGSize(width: 0, height: centerY), opacity: 0.9)
                }
                if clusters >= 2 {
                    FoliageCluster(radius: geo.canopyRadius * 0.45, color: foliageLight,
                                   offset: CGSize(width: -geo.canopyRadius * 0.60, height: centerY + geo.canopyRadius * 0.25), opacity: 0.85)
                }
                if clusters >= 3 {
                    FoliageCluster(radius: geo.canopyRadius * 0.45, color: foliageLight,
                                   offset: CGSize(width: geo.canopyRadius * 0.60, height: centerY + geo.canopyRadius * 0.25), opacity: 0.85)
                }
                if clusters >= 4 {
                    FoliageCluster(radius: geo.canopyRadius * 0.40, color: foliageColor,
                                   offset: CGSize(width: -geo.canopyRadius * 0.90, height: centerY + geo.canopyRadius * 0.55), opacity: 0.75)
                }
                if clusters >= 5 {
                    FoliageCluster(radius: geo.canopyRadius * 0.40, color: foliageColor,
                                   offset: CGSize(width: geo.canopyRadius * 0.90, height: centerY + geo.canopyRadius * 0.55), opacity: 0.75)
                }
                if clusters >= 6 {
                    FoliageCluster(radius: geo.canopyRadius * 0.30, color: foliageLight,
                                   offset: CGSize(width: -geo.canopyRadius * 1.10, height: centerY + geo.canopyRadius * 0.35), opacity: 0.60)
                }
                if clusters >= 7 {
                    FoliageCluster(radius: geo.canopyRadius * 0.30, color: foliageLight,
                                   offset: CGSize(width: geo.canopyRadius * 1.10, height: centerY + geo.canopyRadius * 0.35), opacity: 0.60)
                }
            }

            BonsaiPot(geo: geo, vitality: vitality)
                .offset(y: -2)
        }
        .offset(y: size * 0.08)
    }
}

// MARK: - Cascade

private struct CascadeBonsai: View {
    let stage: BonsaiStage
    let vitality: Double
    let size: CGFloat

    private var geo: BonsaiGeometry { BonsaiGeometry.forStage(stage, size: size) }
    private let trunkColor = Color(red: 0.40, green: 0.24, blue: 0.10)
    private let foliageColor = Color(red: 0.28, green: 0.48, blue: 0.22)
    private let foliageLight = Color(red: 0.38, green: 0.60, blue: 0.30)

    var body: some View {
        if stage == .seed {
            Circle()
                .fill(foliageColor)
                .frame(width: 14, height: 14)
                .offset(y: 4)
                .opacity(0.6 + 0.4 * vitality)
        } else if stage == .sprout {
            sproutBody
        } else {
            fullTreeBody
        }
    }

    private var potOffsetY: CGFloat { geo.potHeight * 0.5 + 2 }

    private var sproutBody: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(foliageColor)
                .frame(width: 4, height: 20)
            Circle()
                .fill(foliageLight)
                .frame(width: 20, height: 20)
        }
        .offset(x: 10, y: -potOffsetY - 6)
    }

    private var fullTreeBody: some View {
        let upHeight = geo.trunkHeight * 0.3
        let cascadeH = geo.trunkHeight * 0.9
        let cascadeW = geo.trunkHeight * 0.35

        return ZStack {
            trunkPath(bottom: CGPoint(x: 0, y: -potOffsetY),
                      top: CGPoint(x: cascadeW, y: -potOffsetY - upHeight + cascadeH),
                      baseWidth: geo.trunkBaseWidth, topWidth: geo.trunkTopWidth,
                      curve: CGPoint(x: cascadeW * 0.5, y: -upHeight * 0.5))
                .fill(trunkColor)
                .opacity(0.7 + 0.3 * vitality)

            let clusters = min(geo.canopyClusterCount, 7)
            let baseY = -potOffsetY - upHeight * 0.5

            ForEach(0..<clusters, id: \.self) { i in
                let t = CGFloat(i) / CGFloat(max(1, clusters - 1))
                let x = cascadeW * t * 0.8 + CGFloat(i % 3 - 1) * geo.canopyRadius * 0.3 * 0.3
                let y = baseY + cascadeH * t * 0.7 + CGFloat(i % 2) * geo.canopyRadius * 0.3
                let r = geo.canopyRadius * (0.30 + 0.20 * (1 - t))
                let c: Color = i.isMultiple(of: 2) ? foliageColor : foliageLight
                let op = 0.7 + 0.2 * (1 - t)

                FoliageCluster(radius: r, color: c,
                               offset: CGSize(width: x, height: y), opacity: op)
            }

            BonsaiPot(geo: geo, vitality: vitality)
                .offset(y: -2)
        }
        .offset(y: size * 0.08)
    }
}

// MARK: - Windswept

private struct WindsweptBonsai: View {
    let stage: BonsaiStage
    let vitality: Double
    let size: CGFloat

    private var geo: BonsaiGeometry { BonsaiGeometry.forStage(stage, size: size) }
    private let trunkColor = Color(red: 0.50, green: 0.30, blue: 0.12)
    private let foliageColor = Color(red: 0.22, green: 0.42, blue: 0.18)
    private let foliageLight = Color(red: 0.32, green: 0.52, blue: 0.25)

    var body: some View {
        if stage == .seed {
            Circle()
                .fill(foliageColor)
                .frame(width: 14, height: 14)
                .offset(y: 4)
                .opacity(0.6 + 0.4 * vitality)
        } else if stage == .sprout {
            sproutBody
        } else {
            fullTreeBody
        }
    }

    private var potOffsetY: CGFloat { geo.potHeight * 0.5 + 2 }

    private var sproutBody: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(foliageColor)
                .frame(width: 4, height: 20)
                .rotationEffect(.degrees(15))
            Circle()
                .fill(foliageLight)
                .frame(width: 20, height: 20)
        }
        .offset(x: 8, y: -potOffsetY - 6)
    }

    private var fullTreeBody: some View {
        let leanX = geo.trunkHeight * 0.25

        return ZStack {
            trunkPath(bottom: CGPoint(x: 0, y: -potOffsetY),
                      top: CGPoint(x: leanX, y: -potOffsetY - geo.trunkHeight),
                      baseWidth: geo.trunkBaseWidth, topWidth: geo.trunkTopWidth,
                      curve: CGPoint(x: leanX * 0.5, y: -geo.trunkHeight * 0.3))
                .fill(trunkColor)
                .opacity(0.7 + 0.3 * vitality)

            let clusters = min(geo.canopyClusterCount, 7)
            let centerY = -potOffsetY - geo.trunkHeight * 0.8
            let baseX = leanX + geo.trunkHeight * 0.05

            ForEach(0..<clusters, id: \.self) { i in
                let t = CGFloat(i) / CGFloat(max(1, clusters - 1))
                let x = baseX + geo.canopyRadius * 0.3 + t * geo.canopyRadius * 0.5 + CGFloat(i % 3) * geo.canopyRadius * 0.15
                let y = centerY + (t - 0.5) * geo.canopyRadius * 0.6
                let r = geo.canopyRadius * (0.35 - t * 0.10)
                let c: Color = i.isMultiple(of: 2) ? foliageColor : foliageLight
                let op = 0.75 + 0.15 * (1 - t)

                FoliageCluster(radius: r, color: c,
                               offset: CGSize(width: x, height: y), opacity: op)
            }

            BonsaiPot(geo: geo, vitality: vitality)
                .offset(y: -2)
        }
        .offset(y: size * 0.08)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ForEach([BonsaiStage.seed, .sprout, .seedling, .young, .adolescent, .mature, .refined, .ancient, .legendary], id: \.rawValue) { stage in
            BonsaiView(stage: stage, style: .traditional, vitality: 1.0)
                .frame(height: 80)
                .border(.gray.opacity(0.2))
        }
    }
    .padding()
}
