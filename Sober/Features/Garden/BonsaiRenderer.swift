import SwiftUI

// Native port of design-handoff/output/bonsai/_builder/bonsai-traditional.js.
//
// The JS builder is the design source of truth: 600×600 canvas, pot baseline
// y=460, deterministic procedural geometry. This renders the same geometry
// natively into a SwiftUI Canvas so every day 0–365 is distinct without
// shipping 366 SVGs. Anchor param sets are ported verbatim; in-between days
// linearly interpolate between bracketing anchors (the model growth-schedule.json
// documents). Stable per-slot cluster seeds replace the JS's per-anchor seeds so
// foliage keeps its identity and grows smoothly instead of re-snapping at anchors.

// MARK: - Palette

private enum Pal {
    static let leafDeep   = Color(hex: 0x2F5E45)
    static let leafSage   = Color(hex: 0x519E73)
    static let leafFresh  = Color(hex: 0x7BC68C)
    static let leafLight  = Color(hex: 0xA9D4A8)
    static let leafLightC = Color(hex: 0xC7E5B8)
    static let barkDeep   = Color(hex: 0x3E2A1B)
    static let barkMid    = Color(hex: 0x6B4A2E)
    static let barkLight  = Color(hex: 0xA07B52)
    static let potDark    = Color(hex: 0x3B2A1C)
    static let potMid     = Color(hex: 0x5C402A)
    static let potRim     = Color(hex: 0x2C1F14)
    static let soilDark   = Color(hex: 0x221710)
    static let soilMid    = Color(hex: 0x3A2A1C)
    static let moss       = Color(hex: 0x9DB16E)

    // autumn trio
    static let autumnShadow = Color(hex: 0x5C3D1F)
    static let autumnMid    = Color(hex: 0xB07A3C)
    static let autumnLight  = Color(hex: 0xD8A35E)
    static let autumnHi     = Color(hex: 0xF2D593)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Deterministic noise (matches JS rand01)

private func rand01(_ seed: Double, _ n: Double) -> Double {
    let v = sin(seed * 12.9898 + n * 78.233) * 43758.5453
    return v - v.rounded(.down)
}

// MARK: - Blob silhouette (matches JS blobPath)

private func blobPath(
    cx: Double, cy: Double, rBase: Double,
    seed: Double, points: Int = 13,
    squashY: Double = 0.82, noise: Double = 0.28, tiltDeg: Double = 0
) -> Path {
    let tilt = tiltDeg * .pi / 180
    var pts: [CGPoint] = []
    for i in 0..<points {
        let t = Double(i) / Double(points) * .pi * 2
        let r = rBase * (1 + (rand01(seed, Double(i + 1)) - 0.5) * 2 * noise)
        let x = cos(t + tilt) * r
        let y = sin(t + tilt) * r * squashY
        pts.append(CGPoint(x: cx + x, y: cy + y))
    }
    var path = Path()
    let start = CGPoint(
        x: (pts[points - 1].x + pts[0].x) / 2,
        y: (pts[points - 1].y + pts[0].y) / 2
    )
    path.move(to: start)
    for i in 0..<points {
        let a = pts[i]
        let b = pts[(i + 1) % points]
        let m = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        path.addQuadCurve(to: m, control: a)
    }
    path.closeSubpath()
    return path
}

// MARK: - Cluster spec

private enum Tone { case sage, fresh, autumn }

private struct ClusterSpec {
    var attach: Attach?
    var cx: Double = 300
    var cy: Double = 250
    var size: Double
    var tone: Tone = .sage
    var sat: Double = 1
    /// Stable identity key — gives a consistent seed across anchors so blobs grow
    /// rather than re-snap.
    var key: String
}

private enum Attach: String {
    case crown, upperLeft, upperRight, midLeft, midRight, lowerRight
}

private func stableSeed(_ key: String) -> Double {
    var h: UInt64 = 1469598103934665603
    for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
    return Double(h % 100_000) / 100.0
}

private func draw(
    cluster cx: Double, _ cy: Double, size: Double,
    tone: Tone, saturation: Double, seed: Double,
    in ctx: inout GraphicsContext
) {
    let trio: (Color, Color, Color, Color)
    switch tone {
    case .sage:   trio = (Pal.leafDeep, Pal.leafSage,  Pal.leafFresh, Pal.leafLight)
    case .fresh:  trio = (Pal.leafDeep, Pal.leafFresh, Pal.leafLight, Pal.leafLightC)
    case .autumn: trio = (Pal.autumnShadow, Pal.autumnMid, Pal.autumnLight, Pal.autumnHi)
    }
    let (shadow, mid, midLight, light) = trio
    let sat = max(0.4, saturation)
    let r: (Double) -> Double = { rand01(seed, $0) }
    let tilt = (r(99) - 0.5) * 20

    var g = ctx
    g.translateBy(x: cx, y: cy)

    let shadowBlob = blobPath(cx: size * 0.10, cy: size * 0.14, rBase: size * 1.02,
                              seed: seed * 1.1, points: 13, squashY: 0.82, noise: 0.22, tiltDeg: tilt)
    g.fill(shadowBlob, with: .color(shadow.opacity(0.78 * sat)))

    for i in 0..<3 {
        let a = Double.pi * (0.15 + Double(i) * 0.6)
        let off = size * (0.95 + r(Double(i + 50)) * 0.1)
        let exCx = cos(a) * off + size * 0.06
        let exCy = sin(a) * off * 0.8 + size * 0.06
        let rad = size * (0.08 + r(Double(i + 51)) * 0.05)
        let p = blobPath(cx: exCx, cy: exCy, rBase: rad, seed: seed * 29 + Double(i) * 13,
                         points: 7, squashY: 0.9, noise: 0.35)
        g.fill(p, with: .color(shadow.opacity(0.55 * sat)))
    }

    let midBlob = blobPath(cx: 0, cy: 0, rBase: size * 0.92,
                           seed: seed * 1.3 + 7, points: 14, squashY: 0.86, noise: 0.26, tiltDeg: tilt * 0.7)
    g.fill(midBlob, with: .color(mid.opacity(0.94 * sat)))

    for i in 0..<5 {
        let a = Double(i) / 5 * .pi * 1.4 - .pi * 0.95
        let off = size * (0.32 + r(Double(i * 5 + 2)) * 0.22)
        let cxL = cos(a) * off
        let cyL = sin(a) * off * 0.7 - size * 0.08
        let rad = size * (0.18 + r(Double(i * 5 + 3)) * 0.12)
        let p = blobPath(cx: cxL, cy: cyL, rBase: rad, seed: seed * 17 + Double(i) * 31,
                         points: 9, squashY: 0.9, noise: 0.32)
        g.fill(p, with: .color(midLight.opacity(0.7 * sat)))
    }

    for i in 0..<4 {
        let a = -Double.pi * 0.75 + Double(i) / 4 * .pi * 0.7
        let off = size * (0.45 + r(Double(i * 7 + 9)) * 0.18)
        let cxL = cos(a) * off
        let cyL = sin(a) * off * 0.55 - size * 0.18
        let rad = size * (0.09 + r(Double(i * 7 + 11)) * 0.07)
        let p = blobPath(cx: cxL, cy: cyL, rBase: rad, seed: seed * 23 + Double(i) * 41,
                         points: 8, squashY: 0.95, noise: 0.28)
        g.fill(p, with: .color(light.opacity(0.82 * sat)))
    }
}

// MARK: - Pot (identical every frame)

private func drawPot(in ctx: inout GraphicsContext) {
    var body = Path()
    body.move(to: CGPoint(x: 170, y: 415))
    body.addLine(to: CGPoint(x: 184, y: 460))
    body.addLine(to: CGPoint(x: 416, y: 460))
    body.addLine(to: CGPoint(x: 430, y: 415))
    body.closeSubpath()
    ctx.fill(body, with: .linearGradient(
        Gradient(colors: [Pal.potMid, Pal.potDark]),
        startPoint: CGPoint(x: 300, y: 415), endPoint: CGPoint(x: 300, y: 460)))

    var shade = Path()
    shade.move(to: CGPoint(x: 300, y: 415))
    shade.addLine(to: CGPoint(x: 416, y: 460))
    shade.addLine(to: CGPoint(x: 430, y: 415))
    shade.closeSubpath()
    ctx.fill(shade, with: .color(Pal.potDark.opacity(0.55)))

    ctx.fill(ellipse(300, 413, 130, 9),   with: .color(Pal.potRim))
    ctx.fill(ellipse(300, 411, 130, 8),   with: .color(Pal.potMid))
    ctx.fill(ellipse(300, 412, 124, 6.5), with: .color(Pal.soilMid))
    ctx.fill(ellipse(300, 412.5, 122, 5.5), with: .color(Pal.soilDark))

    let flecks: [(Double, Double, Double, Color, Double)] = [
        (240, 412, 1.8, Pal.barkMid, 0.55), (285, 413, 1.2, Pal.barkLight, 0.4),
        (328, 412, 1.6, Pal.barkMid, 0.5),  (358, 413, 1.2, Pal.barkLight, 0.35),
        (210, 413, 1.4, Pal.barkLight, 0.4),
    ]
    for (x, y, rr, c, op) in flecks {
        ctx.fill(ellipse(x, y, rr, rr), with: .color(c.opacity(op)))
    }
}

private func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

private func fillRotatedEllipse(
    _ ctx: inout GraphicsContext,
    cx: Double, cy: Double, rx: Double, ry: Double,
    deg: Double, color: Color, opacity: Double = 1
) {
    var g = ctx
    g.translateBy(x: cx, y: cy)
    g.rotate(by: .degrees(deg))
    g.fill(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
           with: .color(color.opacity(opacity)))
}

// MARK: - Roots & moss

private func drawRootsAndMoss(_ p: BonsaiParams, in ctx: inout GraphicsContext) {
    if p.exposedRoots > 0 {
        let a = min(1, p.exposedRoots)
        let op = 0.6 + 0.4 * a
        func root(_ d: String) {}
        var r1 = Path()
        r1.move(to: CGPoint(x: 280, y: 411)); r1.addQuadCurve(to: CGPoint(x: 266, y: 410), control: CGPoint(x: 272, y: 408)); r1.addQuadCurve(to: CGPoint(x: 282, y: 412), control: CGPoint(x: 272, y: 412))
        ctx.fill(r1, with: .color(Pal.barkMid.opacity(op)))
        var r2 = Path()
        r2.move(to: CGPoint(x: 295, y: 411)); r2.addQuadCurve(to: CGPoint(x: 282, y: 409), control: CGPoint(x: 288, y: 407)); r2.addQuadCurve(to: CGPoint(x: 296, y: 412), control: CGPoint(x: 290, y: 412))
        ctx.fill(r2, with: .color(Pal.barkDeep.opacity(0.7 * op)))
        var r3 = Path()
        r3.move(to: CGPoint(x: 312, y: 411)); r3.addQuadCurve(to: CGPoint(x: 330, y: 410), control: CGPoint(x: 322, y: 408)); r3.addQuadCurve(to: CGPoint(x: 312, y: 412), control: CGPoint(x: 322, y: 412))
        ctx.fill(r3, with: .color(Pal.barkMid.opacity(op)))
        var r4 = Path()
        r4.move(to: CGPoint(x: 322, y: 411)); r4.addQuadCurve(to: CGPoint(x: 338, y: 409), control: CGPoint(x: 332, y: 407)); r4.addQuadCurve(to: CGPoint(x: 320, y: 412), control: CGPoint(x: 332, y: 412))
        ctx.fill(r4, with: .color(Pal.barkDeep.opacity(0.7 * op)))
    }
    if p.mossOnTrunk > 0 {
        let a = min(1, p.mossOnTrunk)
        let op = 0.55 + 0.45 * a
        let patches: [(Double, Double, Double, Double)] = [
            (292, 408, 5, 2), (302, 406, 6, 2.4), (296, 402, 4, 1.8),
            (307, 397, 3.5, 1.7), (294, 394, 3, 1.4),
        ]
        let n = Int((2 + 3 * a).rounded(.up))
        for (x, y, rx, ry) in patches.prefix(n) {
            ctx.fill(ellipse(x, y, rx, ry), with: .color(Pal.moss.opacity(op)))
        }
    }
}

// MARK: - Trunk

private struct TrunkResult {
    var path: Path
    var branches: [(Path, Double)]   // (path, strokeWidth)
    var gnarl: [(Path, Double)]      // (ellipse path, opacity)
    var attach: [Attach: CGPoint]
}

private func buildTrunk(_ p: BonsaiParams) -> TrunkResult {
    let baseX = 300.0
    let baseY = 410.0
    let heightPx = 70 + 230 * p.trunkHeight
    let tipY = baseY - heightPx
    let tipX = baseX + 12
    let baseW = 8 + 36 * p.trunkThickness
    let midW = baseW * 0.6
    let tipW = max(2.4, baseW * 0.25)
    let midY = (baseY + tipY) / 2
    let midX1 = baseX - 14
    let midX2 = baseX + 18
    let bL = baseX - baseW / 2, bR = baseX + baseW / 2
    let m1L = midX1 - midW / 2, m1R = midX1 + midW / 2
    let m2R = midX2 + midW / 2
    let tL = tipX - tipW / 2, tR = tipX + tipW / 2

    var path = Path()
    path.move(to: CGPoint(x: bL, y: baseY))
    path.addQuadCurve(to: CGPoint(x: m1L, y: midY), control: CGPoint(x: m1L - 4, y: (baseY + midY) / 2))
    path.addQuadCurve(to: CGPoint(x: tL, y: tipY), control: CGPoint(x: m2R - midW - 2, y: (midY + tipY) / 2))
    path.addLine(to: CGPoint(x: tR, y: tipY))
    path.addQuadCurve(to: CGPoint(x: m2R, y: midY), control: CGPoint(x: m2R + 2, y: (midY + tipY) / 2))
    path.addQuadCurve(to: CGPoint(x: bR, y: baseY), control: CGPoint(x: m1R + 4, y: (baseY + midY) / 2))
    path.closeSubpath()

    var branches: [(Path, Double)] = []
    if p.trunkThickness > 0.4 {
        var b1 = Path()
        b1.move(to: CGPoint(x: m1L + 2, y: midY + 4))
        b1.addQuadCurve(to: CGPoint(x: m1L - 36, y: midY - 22), control: CGPoint(x: m1L - 16, y: midY - 6))
        branches.append((b1, max(3, baseW * 0.18)))
        var b2 = Path()
        b2.move(to: CGPoint(x: m2R - 2, y: (midY + tipY) / 2 + 4))
        b2.addQuadCurve(to: CGPoint(x: m2R + 36, y: (midY + tipY) / 2 - 30), control: CGPoint(x: m2R + 18, y: (midY + tipY) / 2 - 14))
        branches.append((b2, max(2.6, baseW * 0.14)))
    }
    if p.trunkThickness > 0.6 {
        var b3 = Path()
        b3.move(to: CGPoint(x: bR - 2, y: baseY - 36))
        b3.addQuadCurve(to: CGPoint(x: bR + 42, y: baseY - 72), control: CGPoint(x: bR + 18, y: baseY - 54))
        branches.append((b3, max(2.4, baseW * 0.12)))
    }

    var gnarl: [(Path, Double)] = []
    if p.trunkGnarl > 0 {
        let a = min(1, p.trunkGnarl)
        let op = 0.5 + 0.5 * a
        gnarl.append((ellipse(midX1 + midW * 0.15, midY + 4, midW * 0.55, 3.6), 0.55 * op))
        gnarl.append((ellipse(midX2 - midW * 0.15, (midY + tipY) / 2, midW * 0.45, 3), 0.5 * op))
        gnarl.append((ellipse((bL + m1L) / 2, (baseY + midY) / 2 + 6, baseW * 0.35, 3.2), 0.45 * op))
    }

    let attach: [Attach: CGPoint] = [
        .crown:      CGPoint(x: tipX, y: tipY - 8),
        .upperLeft:  CGPoint(x: m1L - 36, y: midY - 22),
        .upperRight: CGPoint(x: m2R + 36, y: (midY + tipY) / 2 - 30),
        .midLeft:    CGPoint(x: m1L - 12, y: midY - 4),
        .midRight:   CGPoint(x: m2R + 12, y: (midY + tipY) / 2 - 6),
        .lowerRight: CGPoint(x: bR + 42, y: baseY - 72),
    ]
    return TrunkResult(path: path, branches: branches, gnarl: gnarl, attach: attach)
}

// MARK: - Params + anchors

private struct BonsaiParams {
    var day: Int
    var trunkHeight: Double = 0
    var trunkThickness: Double = 0
    var trunkGnarl: Double = 0
    var mossOnTrunk: Double = 0
    var exposedRoots: Double = 0
    var leafSaturation: Double = 1
    var clusters: [ClusterSpec] = []
}

private func anchorClusters(_ list: [(Attach?, Double, Double, Double, Tone, Double, String)]) -> [ClusterSpec] {
    list.map { (att, cx, cy, size, tone, sat, key) in
        ClusterSpec(attach: att, cx: cx, cy: cy, size: size, tone: tone, sat: sat, key: key)
    }
}

/// Tree anchors (day ≥ 11). Day 10 is a synthetic bridge so 11–13 emerge
/// smoothly from the seedling instead of popping into the day-14 tree.
private let treeAnchors: [BonsaiParams] = [
    BonsaiParams(day: 10, trunkHeight: 0.14, trunkThickness: 0.10, trunkGnarl: 0,
                 mossOnTrunk: 0, exposedRoots: 0, leafSaturation: 0.9,
                 clusters: anchorClusters([(.crown, 300, 250, 18, .fresh, 1, "crown")])),
    BonsaiParams(day: 14, trunkHeight: 0.34, trunkThickness: 0.22, trunkGnarl: 0,
                 mossOnTrunk: 0, exposedRoots: 0, leafSaturation: 0.92,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 32, .fresh, 1, "crown"),
                    (.midLeft, 0, 0, 18, .sage, 1, "midLeft"),
                    (.midRight, 0, 0, 16, .fresh, 1, "midRight")])),
    BonsaiParams(day: 21, trunkHeight: 0.42, trunkThickness: 0.32, trunkGnarl: 0.05,
                 mossOnTrunk: 0, exposedRoots: 0, leafSaturation: 0.95,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 40, .sage, 1, "crown"),
                    (.midLeft, 0, 0, 26, .fresh, 1, "midLeft"),
                    (.midRight, 0, 0, 24, .sage, 1, "midRight")])),
    BonsaiParams(day: 30, trunkHeight: 0.5, trunkThickness: 0.42, trunkGnarl: 0.12,
                 mossOnTrunk: 0, exposedRoots: 0.1, leafSaturation: 0.98,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 50, .sage, 1, "crown"),
                    (.upperLeft, 0, 0, 36, .fresh, 1, "upperLeft"),
                    (.upperRight, 0, 0, 34, .sage, 1, "upperRight"),
                    (.midLeft, 0, 0, 26, .sage, 1, "midLeft")])),
    BonsaiParams(day: 60, trunkHeight: 0.62, trunkThickness: 0.58, trunkGnarl: 0.28,
                 mossOnTrunk: 0.05, exposedRoots: 0.25, leafSaturation: 1.0,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 62, .sage, 1, "crown"),
                    (.upperLeft, 0, 0, 50, .fresh, 1, "upperLeft"),
                    (.upperRight, 0, 0, 46, .sage, 1, "upperRight"),
                    (.midLeft, 0, 0, 34, .sage, 1, "midLeft"),
                    (.midRight, 0, 0, 32, .fresh, 1, "midRight"),
                    (.lowerRight, 0, 0, 26, .sage, 1, "lowerRight")])),
    BonsaiParams(day: 90, trunkHeight: 0.7, trunkThickness: 0.66, trunkGnarl: 0.45,
                 mossOnTrunk: 0.18, exposedRoots: 0.42, leafSaturation: 1.0,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 70, .sage, 1, "crown"),
                    (.upperLeft, 0, 0, 56, .fresh, 1, "upperLeft"),
                    (.upperRight, 0, 0, 52, .sage, 1, "upperRight"),
                    (.midLeft, 0, 0, 40, .sage, 1, "midLeft"),
                    (.midRight, 0, 0, 38, .fresh, 1, "midRight"),
                    (.lowerRight, 0, 0, 32, .sage, 1, "lowerRight"),
                    (nil, 300, 210, 24, .fresh, 1, "free0")])),
    BonsaiParams(day: 180, trunkHeight: 0.78, trunkThickness: 0.78, trunkGnarl: 0.7,
                 mossOnTrunk: 0.45, exposedRoots: 0.65, leafSaturation: 0.96,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 76, .sage, 1, "crown"),
                    (.upperLeft, 0, 0, 62, .fresh, 1, "upperLeft"),
                    (.upperRight, 0, 0, 58, .sage, 1, "upperRight"),
                    (.midLeft, 0, 0, 46, .sage, 1, "midLeft"),
                    (.midRight, 0, 0, 42, .sage, 1, "midRight"),
                    (.lowerRight, 0, 0, 38, .sage, 1, "lowerRight"),
                    (nil, 308, 202, 28, .fresh, 1, "free0"),
                    (nil, 380, 296, 18, .autumn, 0.8, "free1")])),
    BonsaiParams(day: 365, trunkHeight: 0.84, trunkThickness: 0.9, trunkGnarl: 1.0,
                 mossOnTrunk: 0.85, exposedRoots: 0.9, leafSaturation: 1.0,
                 clusters: anchorClusters([
                    (.crown, 0, 0, 82, .sage, 1, "crown"),
                    (.upperLeft, 0, 0, 70, .fresh, 1, "upperLeft"),
                    (.upperRight, 0, 0, 66, .sage, 1, "upperRight"),
                    (.midLeft, 0, 0, 52, .sage, 1, "midLeft"),
                    (.midRight, 0, 0, 48, .sage, 1, "midRight"),
                    (.lowerRight, 0, 0, 42, .sage, 1, "lowerRight"),
                    (nil, 314, 196, 32, .fresh, 1, "free0"),
                    (nil, 232, 262, 20, .autumn, 0.85, "free1"),
                    (nil, 390, 232, 16, .autumn, 0.75, "free2")])),
]

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

private func interpolatedParams(day: Int) -> BonsaiParams {
    let d = min(365, day)
    let lower = treeAnchors.last { $0.day <= d } ?? treeAnchors[0]
    let upper = treeAnchors.first { $0.day >= d } ?? treeAnchors[treeAnchors.count - 1]
    if lower.day == upper.day { return lower }
    let t = Double(d - lower.day) / Double(upper.day - lower.day)

    var p = BonsaiParams(day: d)
    p.trunkHeight    = lerp(lower.trunkHeight, upper.trunkHeight, t)
    p.trunkThickness = lerp(lower.trunkThickness, upper.trunkThickness, t)
    p.trunkGnarl     = lerp(lower.trunkGnarl, upper.trunkGnarl, t)
    p.mossOnTrunk    = lerp(lower.mossOnTrunk, upper.mossOnTrunk, t)
    p.exposedRoots   = lerp(lower.exposedRoots, upper.exposedRoots, t)
    p.leafSaturation = lerp(lower.leafSaturation, upper.leafSaturation, t)

    var keys: [String] = []
    for c in lower.clusters where !keys.contains(c.key) { keys.append(c.key) }
    for c in upper.clusters where !keys.contains(c.key) { keys.append(c.key) }

    for key in keys {
        let lc = lower.clusters.first { $0.key == key }
        let uc = upper.clusters.first { $0.key == key }
        let sizeA = lc?.size ?? 0
        let sizeB = uc?.size ?? 0
        let size = lerp(sizeA, sizeB, t)
        if size < 0.5 { continue }
        let ref = uc ?? lc!
        var spec = ClusterSpec(attach: ref.attach, size: size, tone: ref.tone, sat: ref.sat, key: key)
        if ref.attach == nil {
            spec.cx = lerp(lc?.cx ?? ref.cx, uc?.cx ?? ref.cx, t)
            spec.cy = lerp(lc?.cy ?? ref.cy, uc?.cy ?? ref.cy, t)
        }
        p.clusters.append(spec)
    }
    return p
}

// MARK: - Public View

struct BonsaiView: View {
    let day: Int
    let style: BonsaiStyle
    let vitality: Double

    var body: some View {
        Canvas { context, size in
            // Uniform scale of the authored 600×600 space, centered.
            let scale = min(size.width, size.height) / 600
            var ctx = context
            ctx.translateBy(x: (size.width - 600 * scale) / 2,
                            y: (size.height - 600 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)

            drawPot(in: &ctx)

            if day <= 10 {
                drawEarly(min(day, 10), into: &ctx)
            } else {
                let p = interpolatedParams(day: day)
                drawRootsAndMoss(p, in: &ctx)
                let tr = buildTrunk(p)
                for (b, w) in tr.branches {
                    ctx.stroke(b, with: .color(Pal.barkMid),
                               style: StrokeStyle(lineWidth: w, lineCap: .round))
                }
                ctx.fill(tr.path, with: .linearGradient(
                    Gradient(colors: [Pal.barkLight, Pal.barkMid, Pal.barkDeep]),
                    startPoint: CGPoint(x: tr.path.boundingRect.minX, y: 300),
                    endPoint: CGPoint(x: tr.path.boundingRect.maxX, y: 300)))
                for (gp, op) in tr.gnarl {
                    ctx.fill(gp, with: .color(Pal.barkDeep.opacity(op)))
                }
                let satFactor = 0.7 + 0.3 * max(0, min(1, vitality))
                let ordered = p.clusters
                for c in ordered {
                    let base: CGPoint = c.attach.flatMap { tr.attach[$0] } ?? CGPoint(x: c.cx, y: c.cy)
                    draw(cluster: base.x, base.y, size: c.size,
                         tone: c.tone, saturation: p.leafSaturation * c.sat * satFactor,
                         seed: stableSeed(c.key), in: &ctx)
                }
            }
        }
        .accessibilityLabel(Text("Bonsai, day \(day)"))
    }

    // Early stages — bespoke per the JS renderEarly. Undefined days snap down
    // to the nearest defined frame (round 1; designer densifies 1–30 in round 2).
    private func drawEarly(_ day: Int, into ctx: inout GraphicsContext) {
        let defined = [0, 1, 3, 5, 7, 10]
        let d = defined.last { $0 <= day } ?? 0
        let cx = 300.0, soilY = 410.0

        switch d {
        case 0:
            ctx.fill(ellipse(cx, soilY + 1, 22, 3.5), with: .color(Pal.barkDeep.opacity(0.55)))
            ctx.fill(ellipse(cx + 1, soilY - 2, 7, 4), with: .color(Pal.barkMid))
            ctx.fill(ellipse(cx - 0.5, soilY - 3, 4.5, 2.6), with: .color(Pal.barkLight.opacity(0.85)))
            ctx.fill(ellipse(cx - 1.5, soilY - 3.5, 2, 1.2), with: .color(Color(hex: 0xE0BD8E).opacity(0.7)))
        case 1:
            ctx.fill(ellipse(cx, soilY + 1, 14, 2.4), with: .color(Pal.barkDeep.opacity(0.5)))
            var stem = Path()
            stem.move(to: CGPoint(x: cx - 0.5, y: soilY - 1))
            stem.addQuadCurve(to: CGPoint(x: cx + 0.5, y: soilY - 16), control: CGPoint(x: cx + 0.5, y: soilY - 9))
            ctx.stroke(stem, with: .color(Pal.leafSage), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            fillRotatedEllipse(&ctx, cx: cx + 0.5, cy: soilY - 18, rx: 5, ry: 3, deg: -12, color: Pal.leafFresh)
            fillRotatedEllipse(&ctx, cx: cx - 0.5, cy: soilY - 19, rx: 3, ry: 1.8, deg: -12, color: Pal.leafLight, opacity: 0.8)
        case 3:
            let stemH = 22.0
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: soilY))
            stem.addQuadCurve(to: CGPoint(x: cx, y: soilY - stemH), control: CGPoint(x: cx + 1, y: soilY - stemH * 0.5))
            ctx.stroke(stem, with: .color(Pal.leafFresh), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            fillRotatedEllipse(&ctx, cx: cx - 9, cy: soilY - stemH - 1, rx: 10, ry: 5, deg: -22, color: Pal.leafFresh)
            fillRotatedEllipse(&ctx, cx: cx - 11, cy: soilY - stemH - 3, rx: 6, ry: 3, deg: -22, color: Pal.leafLight, opacity: 0.8)
            fillRotatedEllipse(&ctx, cx: cx + 9, cy: soilY - stemH - 1, rx: 10, ry: 5, deg: 22, color: Pal.leafFresh)
            fillRotatedEllipse(&ctx, cx: cx + 11, cy: soilY - stemH - 3, rx: 6, ry: 3, deg: 22, color: Pal.leafLight, opacity: 0.8)
        case 5:
            let stemH = 42.0
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: soilY))
            stem.addQuadCurve(to: CGPoint(x: cx + 1, y: soilY - stemH), control: CGPoint(x: cx + 2, y: soilY - stemH * 0.5))
            ctx.stroke(stem, with: .color(Pal.leafSage), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            fillRotatedEllipse(&ctx, cx: cx - 10, cy: soilY - 18, rx: 11, ry: 5, deg: -30, color: Pal.leafSage, opacity: 0.9)
            fillRotatedEllipse(&ctx, cx: cx + 10, cy: soilY - 18, rx: 11, ry: 5, deg: 30, color: Pal.leafSage, opacity: 0.9)
            fillRotatedEllipse(&ctx, cx: cx - 6, cy: soilY - stemH - 2, rx: 7, ry: 3.4, deg: -18, color: Pal.leafFresh)
            fillRotatedEllipse(&ctx, cx: cx + 7, cy: soilY - stemH - 1, rx: 7, ry: 3.4, deg: 18, color: Pal.leafFresh)
            ctx.fill(ellipse(cx + 1, soilY - stemH - 5, 5, 3), with: .color(Pal.leafLight))
        case 7:
            let stemH = 78.0
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: soilY))
            stem.addQuadCurve(to: CGPoint(x: cx + 1, y: soilY - stemH * 0.7), control: CGPoint(x: cx - 2, y: soilY - stemH * 0.4))
            stem.addQuadCurve(to: CGPoint(x: cx + 2, y: soilY - stemH), control: CGPoint(x: cx + 3, y: soilY - stemH * 0.9))
            ctx.stroke(stem, with: .color(Pal.barkLight), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            fillRotatedEllipse(&ctx, cx: cx - 10, cy: soilY - 38, rx: 10, ry: 4, deg: -22, color: Pal.leafSage)
            fillRotatedEllipse(&ctx, cx: cx + 11, cy: soilY - 54, rx: 10, ry: 4, deg: 22, color: Pal.leafSage)
            fillRotatedEllipse(&ctx, cx: cx - 9, cy: soilY - 68, rx: 9, ry: 3.8, deg: -26, color: Pal.leafFresh)
            draw(cluster: cx + 2, soilY - stemH - 2, size: 14, tone: .fresh, saturation: 0.9, seed: 7, in: &ctx)
        default: // 10
            let stemH = 118.0
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: soilY))
            stem.addQuadCurve(to: CGPoint(x: cx + 2, y: soilY - 60), control: CGPoint(x: cx - 4, y: soilY - 30))
            stem.addQuadCurve(to: CGPoint(x: cx + 3, y: soilY - stemH), control: CGPoint(x: cx + 6, y: soilY - 90))
            ctx.stroke(stem, with: .color(Pal.barkLight), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            fillRotatedEllipse(&ctx, cx: cx - 12, cy: soilY - 50, rx: 9, ry: 3.6, deg: -30, color: Pal.leafSage)
            fillRotatedEllipse(&ctx, cx: cx + 13, cy: soilY - 82, rx: 9, ry: 3.6, deg: 28, color: Pal.leafSage)
            draw(cluster: cx - 16, soilY - stemH + 18, size: 16, tone: .sage, saturation: 0.9, seed: 11, in: &ctx)
            draw(cluster: cx + 6, soilY - stemH - 2, size: 22, tone: .fresh, saturation: 1.0, seed: 12, in: &ctx)
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
            ForEach([0, 1, 3, 5, 7, 10, 14, 21, 30, 60, 90, 180, 365], id: \.self) { d in
                VStack {
                    BonsaiView(day: d, style: .traditional, vitality: 1)
                        .frame(width: 90, height: 90)
                        .background(Color(hex: 0xEBF5DB))
                    Text("d\(d)").font(.caption2)
                }
            }
        }.padding()
    }
}
