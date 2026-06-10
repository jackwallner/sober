import SwiftUI

// Native port of design-handoff/output/bonsai/_builder/bonsai-builder.js (round 2).
//
// The JS builder is the design source of truth: 600×600 canvas, pot baseline
// y=460 (traditional/windswept) or y=378 soil top (cascade). Growth parameters
// are a pure continuous function of `day` (eased curve), so every day 0–365
// renders distinctly without any anchor table or interpolation. Three styles:
// traditional (vertical S-curve), cascade (drum pot, trunk plunges below
// baseline), windswept (~18° lean, leeward foliage only).

// MARK: - Palette

private enum Pal {
    static let leafDeep   = Color(hex: 0x2F5E45)
    static let leafSage   = Color(hex: 0x519E73)
    static let leafFresh  = Color(hex: 0x7BC68C)
    static let leafLight  = Color(hex: 0xA9D4A8)
    static let leafLightC = Color(hex: 0xC7E5B8)
    static let leafAutumn = Color(hex: 0xD8A35E)
    static let barkDeep   = Color(hex: 0x3E2A1B)
    static let barkMid    = Color(hex: 0x6B4A2E)
    static let barkLight  = Color(hex: 0xA07B52)
    static let potDark    = Color(hex: 0x3B2A1C)
    static let potMid     = Color(hex: 0x5C402A)
    static let potRim     = Color(hex: 0x2C1F14)
    static let soilDark   = Color(hex: 0x221710)
    static let soilMid    = Color(hex: 0x3A2A1C)
    static let moss       = Color(hex: 0x9DB16E)

    static let autumnShadow = Color(hex: 0x5C3D1F)
    static let autumnMid    = Color(hex: 0xB07A3C)
    static let autumnHi     = Color(hex: 0xF2D593)
    static let deepShadow   = Color(hex: 0x1F4630)
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

// MARK: - Cluster (foliage blob)

private enum Tone: String { case sage, fresh, autumn, deep }

private struct ClusterSpec {
    var attach: Attach?
    var cx: Double = 300
    var cy: Double = 250
    /// Extra displacement from the attach point, in mature-tree pixels.
    /// Scaled by `Params.reach` so filler clusters stay inside a young canopy.
    var offset: CGSize = .zero
    var size: Double
    var tone: Tone = .sage
    var sat: Double = 1
    var seed: Double
}

/// Where a cluster is drawn: its trunk/branch attach point plus its offset,
/// shrunk by `reach` so young trees keep every blob touching the silhouette.
private func clusterCenter(_ c: ClusterSpec, trunk: TrunkResult, reach: Double) -> CGPoint {
    let base = c.attach.flatMap { trunk.attach[$0] } ?? CGPoint(x: c.cx, y: c.cy)
    return CGPoint(x: base.x + c.offset.width * reach,
                   y: base.y + c.offset.height * reach)
}

private enum Attach: String {
    case crown, upperLeft, upperRight, midLeft, midRight, lowerRight
}

private func draw(
    cluster cx: Double, _ cy: Double, size: Double,
    tone: Tone, saturation: Double, seed: Double,
    in ctx: inout GraphicsContext
) {
    let trio: (Color, Color, Color, Color)
    switch tone {
    case .sage:   trio = (Pal.leafDeep,     Pal.leafSage,   Pal.leafFresh,   Pal.leafLight)
    case .fresh:  trio = (Pal.leafDeep,     Pal.leafFresh,  Pal.leafLight,   Pal.leafLightC)
    case .autumn: trio = (Pal.autumnShadow, Pal.autumnMid,  Pal.leafAutumn,  Pal.autumnHi)
    case .deep:   trio = (Pal.deepShadow,   Pal.leafDeep,   Pal.leafSage,    Pal.leafFresh)
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

// MARK: - Pot

private func drawPot(style: BonsaiStyle, in ctx: inout GraphicsContext) {
    if style == .cascade {
        // narrower drum pot — soil top at y=378
        var body = Path()
        body.move(to: CGPoint(x: 218, y: 380))
        body.addLine(to: CGPoint(x: 228, y: 460))
        body.addLine(to: CGPoint(x: 372, y: 460))
        body.addLine(to: CGPoint(x: 382, y: 380))
        body.closeSubpath()
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [Pal.potMid, Pal.potDark]),
            startPoint: CGPoint(x: 300, y: 380), endPoint: CGPoint(x: 300, y: 460)))

        var shade = Path()
        shade.move(to: CGPoint(x: 300, y: 380))
        shade.addLine(to: CGPoint(x: 372, y: 460))
        shade.addLine(to: CGPoint(x: 382, y: 380))
        shade.closeSubpath()
        ctx.fill(shade, with: .color(Pal.potDark.opacity(0.55)))

        ctx.fill(ellipse(300, 378, 82, 7), with: .color(Pal.potRim))
        ctx.fill(ellipse(300, 376, 82, 6), with: .color(Pal.potMid))
        ctx.fill(ellipse(300, 377, 76, 5), with: .color(Pal.soilMid))
        ctx.fill(ellipse(300, 378, 74, 4), with: .color(Pal.soilDark))

        let flecks: [(Double, Double, Double, Color, Double)] = [
            (262, 377, 1.4, Pal.barkLight, 0.4),
            (294, 378, 1.6, Pal.barkMid, 0.5),
            (330, 377, 1.2, Pal.barkLight, 0.4),
        ]
        for (x, y, rr, c, op) in flecks {
            ctx.fill(ellipse(x, y, rr, rr), with: .color(c.opacity(op)))
        }
        return
    }

    // traditional & windswept — wide trapezoid, soil top y=411
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

// MARK: - Roots & moss

private func drawRootsAndMoss(_ p: Params, style: BonsaiStyle, in ctx: inout GraphicsContext) {
    let baseY: Double = style == .cascade ? 378 : 411
    if p.exposedRoots > 0 {
        let a = min(1, p.exposedRoots)
        let op = 0.6 + 0.4 * a
        for (a1, ya, a2, yb, a3, yc, color, mul) in [
            (280.0, baseY,     266.0, baseY - 1, 282.0, baseY + 1, Pal.barkMid,  1.0),
            (295.0, baseY,     282.0, baseY - 2, 296.0, baseY + 1, Pal.barkDeep, 0.7),
            (312.0, baseY,     330.0, baseY - 1, 312.0, baseY + 1, Pal.barkMid,  1.0),
            (322.0, baseY,     338.0, baseY - 2, 320.0, baseY + 1, Pal.barkDeep, 0.7),
        ] {
            var path = Path()
            path.move(to: CGPoint(x: a1, y: ya))
            // bend up then back down to ground
            path.addQuadCurve(to: CGPoint(x: a2, y: yb), control: CGPoint(x: (a1 + a2) / 2, y: yb - 2))
            path.addQuadCurve(to: CGPoint(x: a3, y: yc), control: CGPoint(x: (a2 + a3) / 2, y: yb + 2))
            ctx.fill(path, with: .color(color.opacity(op * mul)))
        }
    }
    if p.mossOnTrunk > 0 {
        let a = min(1, p.mossOnTrunk)
        let op = 0.55 + 0.45 * a
        let patches: [(Double, Double, Double, Double)] = [
            (292, baseY - 3,  5, 2),
            (302, baseY - 5,  6, 2.4),
            (296, baseY - 9,  4, 1.8),
            (307, baseY - 14, 3.5, 1.7),
            (294, baseY - 17, 3, 1.4),
        ]
        let n = Int((2 + 3 * a).rounded(.up))
        for (x, y, rx, ry) in patches.prefix(n) {
            ctx.fill(ellipse(x, y, rx, ry), with: .color(Pal.moss.opacity(op)))
        }
    }
}

// MARK: - Trunks (style-specific)

private struct TrunkResult {
    var path: Path
    var branches: [(Path, Double)]      // (path, strokeWidth)
    var bareBranches: [(Path, Double, Color, Double)] // (path, w, color, opacity) — windswept windward
    var gnarl: [(Path, Double)]         // (ellipse path, opacity)
    var attach: [Attach: CGPoint]
}

private func ribbonPath(through pts: [CGPoint], widths: [Double]) -> Path {
    var leftPts: [CGPoint] = []
    var rightPts: [CGPoint] = []
    for i in 0..<pts.count {
        let prev = i == 0 ? pts[1] : pts[i - 1]
        let next = i == pts.count - 1 ? pts[i] : pts[i + 1]
        let dirA = i == 0
            ? CGPoint(x: pts[1].x - pts[0].x, y: pts[1].y - pts[0].y)
            : CGPoint(x: pts[i].x - prev.x, y: pts[i].y - prev.y)
        let dirB = i == pts.count - 1
            ? dirA
            : CGPoint(x: next.x - pts[i].x, y: next.y - pts[i].y)
        let avgX = (dirA.x + dirB.x) / 2, avgY = (dirA.y + dirB.y) / 2
        let len = max(1e-6, hypot(avgX, avgY))
        let nx = -avgY / len, ny = avgX / len
        let w = widths[i] / 2
        leftPts.append(CGPoint(x: pts[i].x + nx * w, y: pts[i].y + ny * w))
        rightPts.append(CGPoint(x: pts[i].x - nx * w, y: pts[i].y - ny * w))
    }
    var all = leftPts
    all.append(contentsOf: rightPts.reversed())
    var path = Path()
    path.move(to: all[0])
    for i in 1..<all.count {
        let prev = all[i - 1], cur = all[i]
        let m = CGPoint(x: (prev.x + cur.x) / 2, y: (prev.y + cur.y) / 2)
        path.addQuadCurve(to: m, control: prev)
    }
    path.closeSubpath()
    return path
}

private func trunkTraditional(_ p: Params) -> TrunkResult {
    let baseX = 300.0, baseY = 410.0
    let heightPx = 70 + 230 * p.trunkHeight
    let tipY = baseY - heightPx
    let tipX = baseX + 12
    let baseW = 8 + 36 * p.trunkThickness
    let midW = baseW * 0.6, tipW = max(2.4, baseW * 0.25)
    let midY = (baseY + tipY) / 2
    let midX1 = baseX - 14, midX2 = baseX + 18
    let bL = baseX - baseW / 2, bR = baseX + baseW / 2
    let m1L = midX1 - midW / 2, m1R = midX1 + midW / 2
    let m2L = midX2 - midW / 2, m2R = midX2 + midW / 2
    let tL = tipX - tipW / 2, tR = tipX + tipW / 2

    var path = Path()
    path.move(to: CGPoint(x: bL, y: baseY))
    path.addQuadCurve(to: CGPoint(x: m1L, y: midY), control: CGPoint(x: m1L - 4, y: (baseY + midY) / 2))
    path.addQuadCurve(to: CGPoint(x: tL, y: tipY), control: CGPoint(x: m2L - 2, y: (midY + tipY) / 2))
    path.addLine(to: CGPoint(x: tR, y: tipY))
    path.addQuadCurve(to: CGPoint(x: m2R, y: midY), control: CGPoint(x: m2R + 2, y: (midY + tipY) / 2))
    path.addQuadCurve(to: CGPoint(x: bR, y: baseY), control: CGPoint(x: m1R + 4, y: (baseY + midY) / 2))
    path.closeSubpath()

    // Branch reach grows with the tree (k=1 at day 365 → original geometry).
    // Branches draw from the day their foliage clusters appear, so a blob is
    // never left floating where its limb hasn't grown yet.
    let k = p.reach
    let ymid2 = (midY + tipY) / 2
    let b1Start = CGPoint(x: m1L + 2, y: midY + 4)
    let b1End = CGPoint(x: b1Start.x - 38 * k, y: b1Start.y - 26 * k)
    let b2Start = CGPoint(x: m2R - 2, y: ymid2 + 4)
    let b2End = CGPoint(x: b2Start.x + 38 * k, y: b2Start.y - 34 * k)
    let b3Start = CGPoint(x: bR - 2, y: baseY - 36)
    let b3End = CGPoint(x: b3Start.x + 44 * k, y: b3Start.y - 36 * k)

    var branches: [(Path, Double)] = []
    if p.day >= 30 {
        var b1 = Path()
        b1.move(to: b1Start)
        b1.addQuadCurve(to: b1End, control: CGPoint(x: b1Start.x - 18 * k, y: b1Start.y - 10 * k))
        branches.append((b1, max(3, baseW * 0.18)))
        var b2 = Path()
        b2.move(to: b2Start)
        b2.addQuadCurve(to: b2End, control: CGPoint(x: b2Start.x + 20 * k, y: b2Start.y - 18 * k))
        branches.append((b2, max(2.6, baseW * 0.14)))
    }
    if p.day >= 60 {
        var b3 = Path()
        b3.move(to: b3Start)
        b3.addQuadCurve(to: b3End, control: CGPoint(x: b3Start.x + 20 * k, y: b3Start.y - 18 * k))
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
        .crown:      CGPoint(x: tipX, y: tipY - 8 * k),
        .upperLeft:  b1End,
        .upperRight: b2End,
        .midLeft:    CGPoint(x: m1L - 12 * k, y: midY - 4 * k),
        .midRight:   CGPoint(x: m2R + 12 * k, y: ymid2 - 6 * k),
        .lowerRight: b3End,
    ]
    return TrunkResult(path: path, branches: branches, bareBranches: [], gnarl: gnarl, attach: attach)
}

private func trunkCascade(_ p: Params) -> TrunkResult {
    let baseX = 300.0, baseY = 378.0
    let fallPx = 30 + 130 * p.trunkHeight
    // Taller riser than the JS source: the crown must clear the pot rim from
    // day 8 so the young cascade doesn't read as a lump on the pot corner.
    let upPx = 24 + 42 * p.trunkHeight
    let sideX = baseX - 80 - 60 * p.trunkHeight
    let baseW = 8 + 32 * p.trunkThickness
    let midW = baseW * 0.55, tipW = max(2.4, baseW * 0.22)

    let p0 = CGPoint(x: baseX, y: baseY)
    let p1 = CGPoint(x: baseX - 16, y: baseY - upPx)
    let p2 = CGPoint(x: baseX - 30, y: baseY + 6)
    let p3 = CGPoint(x: sideX,     y: baseY + fallPx)
    let pts = [p0, p1, p2, p3]
    let widths = [baseW, midW * 1.1, midW, tipW]
    let path = ribbonPath(through: pts, widths: widths)

    var gnarl: [(Path, Double)] = []
    if p.trunkGnarl > 0 {
        let a = min(1, p.trunkGnarl)
        let op = 0.5 + 0.5 * a
        gnarl.append((ellipse(p1.x + 4, p1.y + 2, midW * 0.55, 3.2), 0.5 * op))
        gnarl.append((ellipse(p2.x - 2, p2.y + 4, midW * 0.5, 3), 0.5 * op))
    }

    let k = p.reach
    let midPt = CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2)
    let b1Start = CGPoint(x: p2.x, y: p2.y + 6)
    let b1End = CGPoint(x: b1Start.x - 44 * k, y: b1Start.y + 46 * k)
    let b2End = CGPoint(x: midPt.x - 56 * k, y: midPt.y + 28 * k)

    var branches: [(Path, Double)] = []
    if p.day >= 30 {
        var b1 = Path()
        b1.move(to: b1Start)
        b1.addQuadCurve(to: b1End, control: CGPoint(x: b1Start.x - 22 * k, y: b1Start.y + 24 * k))
        branches.append((b1, max(2.6, baseW * 0.14)))
        var b2 = Path()
        b2.move(to: midPt)
        b2.addQuadCurve(to: b2End, control: CGPoint(x: midPt.x - 26 * k, y: midPt.y + 18 * k))
        branches.append((b2, max(2.4, baseW * 0.12)))
    }

    let attach: [Attach: CGPoint] = [
        .crown:      CGPoint(x: p1.x - 2 * k, y: p1.y - 12 * k),
        .upperLeft:  CGPoint(x: b1End.x, y: b1End.y - 8 * k),
        .upperRight: CGPoint(x: b2End.x, y: b2End.y - 8 * k),
        .midLeft:    CGPoint(x: p3.x - 12 * k, y: p3.y - 22 * k),
        .midRight:   CGPoint(x: p3.x + 14 * k, y: p3.y - 10 * k),
        .lowerRight: CGPoint(x: p3.x - 6 * k, y: p3.y + 10 * k),
    ]
    return TrunkResult(path: path, branches: branches, bareBranches: [], gnarl: gnarl, attach: attach)
}

private func trunkWindswept(_ p: Params) -> TrunkResult {
    let baseX = 300.0, baseY = 410.0
    let heightPx = 70 + 220 * p.trunkHeight
    let leanRad = 18.0 * .pi / 180
    let tipX = baseX + sin(leanRad) * heightPx + 8
    let tipY = baseY - cos(leanRad) * heightPx
    let baseW = 8 + 34 * p.trunkThickness
    let midW = baseW * 0.55, tipW = max(2.4, baseW * 0.22)
    let midX = (baseX + tipX) / 2 + 14
    let midY = (baseY + tipY) / 2 + 4

    let pts = [
        CGPoint(x: baseX, y: baseY),
        CGPoint(x: midX, y: midY),
        CGPoint(x: tipX, y: tipY),
    ]
    let widths = [baseW, midW * 1.05, tipW]
    let path = ribbonPath(through: pts, widths: widths)

    var gnarl: [(Path, Double)] = []
    if p.trunkGnarl > 0 {
        let a = min(1, p.trunkGnarl)
        let op = 0.5 + 0.5 * a
        gnarl.append((ellipse(midX - 2, midY + 2, midW * 0.55, 3.6), 0.55 * op))
    }

    let k = p.reach

    // Bare windward (left) branches — decorative dead wood, scaled with growth.
    var bare: [(Path, Double, Color, Double)] = []
    if p.trunkThickness > 0.35 {
        let bareSize = max(2, baseW * 0.12)
        let s1 = CGPoint(x: (baseX + midX) / 2, y: (baseY + midY) / 2)
        var b1 = Path()
        b1.move(to: s1)
        b1.addQuadCurve(
            to: CGPoint(x: s1.x + (baseX - 44 - s1.x) * k, y: s1.y + (baseY - 92 - s1.y) * k),
            control: CGPoint(x: s1.x + (baseX - 18 - s1.x) * k, y: s1.y + (baseY - 80 - s1.y) * k))
        bare.append((b1, bareSize, Pal.barkMid, 1))
        var b2 = Path()
        b2.move(to: CGPoint(x: midX - 4, y: midY + 4))
        b2.addQuadCurve(to: CGPoint(x: midX - 4 - 52 * k, y: midY + 4 - 32 * k),
                        control: CGPoint(x: midX - 4 - 26 * k, y: midY + 4 - 22 * k))
        bare.append((b2, bareSize * 0.85, Pal.barkDeep, 0.85))
        var b3 = Path()
        b3.move(to: CGPoint(x: midX - 18, y: midY - 4))
        b3.addQuadCurve(to: CGPoint(x: midX - 18 - 42 * k, y: midY - 4 + 2 * k),
                        control: CGPoint(x: midX - 18 - 22 * k, y: midY - 4 - 2 * k))
        bare.append((b3, bareSize * 0.7, Pal.barkMid, 1))
    }

    // Leeward (right) heavy branches into the foliage. Drawn from the day the
    // leeward clusters exist so foliage always has wood to sit on.
    var branches: [(Path, Double)] = []
    if p.day >= 30 {
        var b1 = Path()
        b1.move(to: CGPoint(x: midX + 2, y: midY - 2))
        b1.addQuadCurve(to: CGPoint(x: midX + 2 + 46 * k, y: midY - 2 - 26 * k),
                        control: CGPoint(x: midX + 2 + 24 * k, y: midY - 2 - 12 * k))
        branches.append((b1, max(3, baseW * 0.18)))
        var b2 = Path()
        b2.move(to: CGPoint(x: tipX - 6, y: tipY + 6))
        b2.addQuadCurve(to: CGPoint(x: tipX - 6 + 48 * k, y: tipY + 6 - 20 * k),
                        control: CGPoint(x: tipX - 6 + 24 * k, y: tipY + 6 - 10 * k))
        branches.append((b2, max(2.6, baseW * 0.14)))
    }

    let attach: [Attach: CGPoint] = [
        .crown:      CGPoint(x: tipX + 24 * k, y: tipY - 10 * k),
        .upperLeft:  CGPoint(x: tipX + 14 * k, y: tipY + 4 * k),
        .upperRight: CGPoint(x: tipX + 56 * k, y: tipY),
        .midLeft:    CGPoint(x: midX + 24 * k, y: midY - 16 * k),
        .midRight:   CGPoint(x: midX + 56 * k, y: midY - 12 * k),
        .lowerRight: CGPoint(x: midX + 70 * k, y: midY + 14 * k),
    ]
    return TrunkResult(path: path, branches: branches, bareBranches: bare, gnarl: gnarl, attach: attach)
}

private func buildTrunk(_ p: Params, style: BonsaiStyle) -> TrunkResult {
    switch style {
    case .cascade:    return trunkCascade(p)
    case .windswept:  return trunkWindswept(p)
    case .traditional: return trunkTraditional(p)
    // Sakura/Maple/Pine each have their own self-contained render path and never
    // reach this trunk/cluster pipeline; these keep the switch exhaustive.
    case .sakura, .maple, .pine: return trunkTraditional(p)
    }
}

// MARK: - Params (pure continuous function of day, matches JS paramsForDay)

private struct Params {
    var day: Int
    var trunkHeight: Double
    var trunkThickness: Double
    var trunkGnarl: Double
    var leafSaturation: Double
    var mossOnTrunk: Double
    var exposedRoots: Double
    /// 0→1 canopy growth factor (1 at day 365). Scales branch lengths and
    /// cluster attach offsets so foliage hugs a young trunk instead of
    /// floating at mature-tree distances.
    var reach: Double
    var clusters: [ClusterSpec]
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

private func eased(_ day: Int) -> Double {
    if day >= 365 { return 1 }
    let t = Double(day) / 365
    return 1 - pow(1 - t, 1.6)
}

private func paramsForDay(_ day: Int, style: BonsaiStyle) -> Params {
    let e = eased(day)
    // Height starts low so day 8 (first day of the trunk pipeline) reads as a
    // grown-up version of the day-7 sprout, not a sudden adult tree.
    let trunkHeight = lerp(0.10, 0.86, e)
    let trunkThickness = lerp(0.14, style == .cascade ? 0.82 : 0.90, e)
    let trunkGnarl = max(0, Double(day - 21) / Double(365 - 21))
    let leafSaturation = day < 14
        ? lerp(0.85, 0.95, Double(day) / 14)
        : lerp(0.95, 1.0, Double(day - 14) / Double(365 - 14))
    let mossOnTrunk = day < 60 ? 0 : min(1, Double(day - 60) / Double(365 - 60))
    let exposedRoots = day < 21 ? 0 : min(1, Double(day - 21) / Double(180 - 21))

    let sizeBase = lerp(14, 82, e)
    var clusters: [ClusterSpec] = []
    clusters.append(ClusterSpec(attach: .crown,
        size: (sizeBase * 1.0).rounded(), tone: day < 21 ? .fresh : .sage, seed: 1))
    if day >= 14 {
        clusters.append(ClusterSpec(attach: .midLeft,
            size: (sizeBase * 0.55).rounded(), tone: .fresh, seed: 2))
        clusters.append(ClusterSpec(attach: .midRight,
            size: (sizeBase * 0.52).rounded(), tone: .sage, seed: 3))
    }
    if day >= 30 {
        clusters.append(ClusterSpec(attach: .upperLeft,
            size: (sizeBase * 0.75).rounded(), tone: .fresh, seed: 4))
        clusters.append(ClusterSpec(attach: .upperRight,
            size: (sizeBase * 0.72).rounded(), tone: .sage, seed: 5))
    }
    if day >= 60 {
        clusters.append(ClusterSpec(attach: .lowerRight,
            size: (sizeBase * 0.5).rounded(), tone: .sage, seed: 6))
    }
    // Ambient canopy fillers — anchored to trunk attach points (not fixed
    // canvas coordinates) so they stay inside the silhouette on every style.
    if day >= 90 {
        clusters.append(ClusterSpec(attach: .crown, offset: CGSize(width: -12, height: 32),
            size: (sizeBase * 0.42).rounded(), tone: .fresh, seed: 7))
    }
    if day >= 180 {
        clusters.append(ClusterSpec(attach: .midRight, offset: CGSize(width: 16, height: 12),
            size: (sizeBase * 0.28).rounded(), tone: .autumn, sat: 0.8, seed: 8))
    }
    if day >= 270 {
        clusters.append(ClusterSpec(attach: .midLeft, offset: CGSize(width: -14, height: -8),
            size: (sizeBase * 0.28).rounded(), tone: .autumn, sat: 0.75, seed: 9))
    }

    return Params(day: day,
                  trunkHeight: trunkHeight, trunkThickness: trunkThickness, trunkGnarl: trunkGnarl,
                  leafSaturation: leafSaturation, mossOnTrunk: mossOnTrunk, exposedRoots: exposedRoots,
                  reach: sizeBase / 82,
                  clusters: clusters)
}

// MARK: - Early stages (days 0–7) — bespoke per JS renderEarly

private func drawEarly(_ day: Int, style: BonsaiStyle, in ctx: inout GraphicsContext) {
    let baseY: Double = style == .cascade ? 378 : 410
    let cx = 300.0
    var ctx = ctx
    if style == .cascade {
        // Shrink the sprout so day 7 hands off smoothly to the cascade's short
        // riser on day 8 instead of towering over it.
        ctx.translateBy(x: cx, y: baseY)
        ctx.scaleBy(x: 0.62, y: 0.62)
        ctx.translateBy(x: -cx, y: -baseY)
    }
    switch day {
    case 0:
        ctx.fill(ellipse(cx, baseY + 1, 22, 3.5), with: .color(Pal.barkDeep.opacity(0.55)))
        ctx.fill(ellipse(cx + 1, baseY - 2, 7, 4), with: .color(Pal.barkMid))
        ctx.fill(ellipse(cx - 0.5, baseY - 3, 4.5, 2.6), with: .color(Pal.barkLight.opacity(0.85)))
        ctx.fill(ellipse(cx - 1.5, baseY - 3.5, 2, 1.2), with: .color(Color(hex: 0xE0BD8E).opacity(0.7)))
    case 1:
        ctx.fill(ellipse(cx, baseY + 1, 14, 2.4), with: .color(Pal.barkDeep.opacity(0.5)))
        var stem = Path()
        stem.move(to: CGPoint(x: cx - 0.5, y: baseY - 1))
        stem.addQuadCurve(to: CGPoint(x: cx + 0.5, y: baseY - 16), control: CGPoint(x: cx + 0.5, y: baseY - 9))
        ctx.stroke(stem, with: .color(Pal.leafSage), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx + 0.5, cy: baseY - 18, rx: 5, ry: 3, deg: -12, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx - 0.5, cy: baseY - 19, rx: 3, ry: 1.8, deg: -12, color: Pal.leafLight, opacity: 0.8)
    case 2:
        ctx.fill(ellipse(cx, baseY + 1, 14, 2.4), with: .color(Pal.barkDeep.opacity(0.5)))
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx + 1, y: baseY - 20), control: CGPoint(x: cx + 1, y: baseY - 14))
        ctx.stroke(stem, with: .color(Pal.leafSage), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 5, cy: baseY - 20, rx: 6, ry: 3.4, deg: -26, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx + 5, cy: baseY - 21, rx: 6, ry: 3.4, deg: 26, color: Pal.leafFresh)
    case 3:
        let stemH = 22.0
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx, y: baseY - stemH), control: CGPoint(x: cx + 1, y: baseY - stemH * 0.5))
        ctx.stroke(stem, with: .color(Pal.leafFresh), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 9, cy: baseY - stemH - 1, rx: 10, ry: 5, deg: -22, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx - 11, cy: baseY - stemH - 3, rx: 6, ry: 3, deg: -22, color: Pal.leafLight, opacity: 0.8)
        fillRotatedEllipse(&ctx, cx: cx + 9, cy: baseY - stemH - 1, rx: 10, ry: 5, deg: 22, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx + 11, cy: baseY - stemH - 3, rx: 6, ry: 3, deg: 22, color: Pal.leafLight, opacity: 0.8)
    case 4:
        let stemH = 32.0
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx, y: baseY - stemH), control: CGPoint(x: cx + 1.5, y: baseY - stemH * 0.5))
        ctx.stroke(stem, with: .color(Pal.leafFresh), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 10, cy: baseY - 16, rx: 11, ry: 5, deg: -26, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx + 10, cy: baseY - 16, rx: 11, ry: 5, deg: 26, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx - 4, cy: baseY - stemH - 1, rx: 5, ry: 3, deg: -12, color: Pal.leafLight)
        fillRotatedEllipse(&ctx, cx: cx + 5, cy: baseY - stemH - 1, rx: 5, ry: 3, deg: 12, color: Pal.leafLight)
    case 5:
        let stemH = 42.0
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx + 1, y: baseY - stemH), control: CGPoint(x: cx + 2, y: baseY - stemH * 0.5))
        ctx.stroke(stem, with: .color(Pal.leafSage), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 10, cy: baseY - 18, rx: 11, ry: 5, deg: -30, color: Pal.leafSage, opacity: 0.9)
        fillRotatedEllipse(&ctx, cx: cx + 10, cy: baseY - 18, rx: 11, ry: 5, deg: 30, color: Pal.leafSage, opacity: 0.9)
        fillRotatedEllipse(&ctx, cx: cx - 6, cy: baseY - stemH - 2, rx: 7, ry: 3.4, deg: -18, color: Pal.leafFresh)
        fillRotatedEllipse(&ctx, cx: cx + 7, cy: baseY - stemH - 1, rx: 7, ry: 3.4, deg: 18, color: Pal.leafFresh)
        ctx.fill(ellipse(cx + 1, baseY - stemH - 5, 5, 3), with: .color(Pal.leafLight))
    case 6:
        let stemH = 58.0
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx + 1, y: baseY - stemH), control: CGPoint(x: cx - 1, y: baseY - stemH * 0.5))
        ctx.stroke(stem, with: .color(Pal.barkLight), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 9, cy: baseY - 26, rx: 10, ry: 4, deg: -26, color: Pal.leafSage)
        fillRotatedEllipse(&ctx, cx: cx + 10, cy: baseY - 38, rx: 10, ry: 4, deg: 26, color: Pal.leafSage)
        draw(cluster: cx + 1, baseY - stemH - 3, size: 12, tone: .fresh, saturation: 0.9, seed: 6, in: &ctx)
    default: // 7
        let stemH = 78.0
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: baseY))
        stem.addQuadCurve(to: CGPoint(x: cx + 1, y: baseY - stemH * 0.7), control: CGPoint(x: cx - 2, y: baseY - stemH * 0.4))
        stem.addQuadCurve(to: CGPoint(x: cx + 2, y: baseY - stemH), control: CGPoint(x: cx + 3, y: baseY - stemH * 0.9))
        ctx.stroke(stem, with: .color(Pal.barkLight), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        fillRotatedEllipse(&ctx, cx: cx - 10, cy: baseY - 38, rx: 10, ry: 4, deg: -22, color: Pal.leafSage)
        fillRotatedEllipse(&ctx, cx: cx + 11, cy: baseY - 54, rx: 10, ry: 4, deg: 22, color: Pal.leafSage)
        fillRotatedEllipse(&ctx, cx: cx - 9, cy: baseY - 68, rx: 9, ry: 3.8, deg: -26, color: Pal.leafFresh)
        draw(cluster: cx + 2, baseY - stemH - 2, size: 14, tone: .fresh, saturation: 0.9, seed: 7, in: &ctx)
    }
}

// MARK: - Sakura (cherry-blossom) bonsai — native port of bonsai-sakura.js
//
// A self-contained render path used when `style == .sakura`. Unlike the
// traditional/cascade/windswept trunks (shared trunk + leaf-cluster pipeline),
// the sakura is a single-fork trunk carrying blossom pads, falling petals, and
// its own celadon-glazed pot. It is a CONTINUOUS function of day from 0 (a teeny
// complete cherry) to 365 — no separate early-stage path. One shared scale
// `sakuraScale(day)` enlarges every dimension so the tree is self-similar and
// only ever grows; ~17 limbs and ~38 blossom tufts emerge at staggered days.

private enum SakuraPal {
    static let bloomDeep  = Color(hex: 0xD77FA6)
    static let bloomMid   = Color(hex: 0xF2B2CD)
    static let bloomLight = Color(hex: 0xFBD7E6)
    static let bloomHi    = Color(hex: 0xFFF1F7)
    static let center     = Color(hex: 0xF2C773)
    static let barkDeep   = Color(hex: 0x4A3526)
    static let barkMid    = Color(hex: 0x7C5B45)
    static let barkLight  = Color(hex: 0xAD8C70)
    static let lenticel   = Color(hex: 0x5A4233)
    static let potDark    = Color(hex: 0x5E7E6F)
    static let potMid     = Color(hex: 0x8AAE9C)
    static let potLight   = Color(hex: 0xBDD6C7)
    static let potRim     = Color(hex: 0x4C6A5C)
    static let potGlaze   = Color(hex: 0xD6E7DC)
    static let soilDark   = Color(hex: 0x221710)
    static let soilMid    = Color(hex: 0x3A2A1C)
}

private func clamp01(_ x: Double) -> Double { x < 0 ? 0 : (x > 1 ? 1 : x) }

private func smoothstepS(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
    let t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)
}

private func ramp(_ day: Double, _ start: Double, _ end: Double, _ power: Double) -> Double {
    pow(clamp01((day - start) / (end - start)), power)
}

// One shared scale drives every dimension → self-similar growth, no morphing.
private func sakuraScale(_ d: Int) -> Double { ramp(Double(d), 0, 430, 0.5) }
private func sakuraBark(_ d: Int) -> Double { smoothstepS(70, 400, Double(d)) }
private func sakuraPetalAmt(_ d: Int) -> Double { ramp(Double(d), 45, 365, 1.0) }

private struct SakuraCanopy {
    var cX: Double, cY: Double, Rx: Double, Ry: Double
    var forkX: Double, forkY: Double, g: Double, baseW: Double
}

private func sakuraCanopy(_ day: Int) -> SakuraCanopy {
    let baseY = 410.0
    let g = sakuraScale(day)
    let forkLen = 10 + 162 * g
    let forkY = baseY - forkLen
    let forkX = 303.0
    let Rx = 8 + 138 * g
    let Ry = 5 + 58 * g
    let baseW = 2.5 + 44 * g
    return SakuraCanopy(cX: forkX, cY: forkY - Ry * 0.40, Rx: Rx, Ry: Ry,
                        forkX: forkX, forkY: forkY, g: g, baseW: baseW)
}

private struct SakuraLimb { let a, r, s, seed, app, span: Double }

private let sakuraLimbs: [SakuraLimb] = [
    SakuraLimb(a: 90,  r: 0.08, s: 1.00, seed: 1,  app: 0,   span: 1),
    SakuraLimb(a: 124, r: 0.48, s: 0.90, seed: 2,  app: 7,   span: 16),
    SakuraLimb(a: 56,  r: 0.48, s: 0.90, seed: 3,  app: 13,  span: 16),
    SakuraLimb(a: 150, r: 0.70, s: 0.80, seed: 4,  app: 22,  span: 18),
    SakuraLimb(a: 30,  r: 0.70, s: 0.80, seed: 5,  app: 31,  span: 18),
    SakuraLimb(a: 96,  r: 0.56, s: 0.78, seed: 6,  app: 42,  span: 16),
    SakuraLimb(a: 112, r: 0.80, s: 0.70, seed: 7,  app: 54,  span: 18),
    SakuraLimb(a: 67,  r: 0.80, s: 0.70, seed: 8,  app: 67,  span: 18),
    SakuraLimb(a: 20,  r: 0.62, s: 0.66, seed: 9,  app: 84,  span: 20),
    SakuraLimb(a: 160, r: 0.62, s: 0.66, seed: 10, app: 104, span: 20),
    SakuraLimb(a: 44,  r: 0.40, s: 0.66, seed: 11, app: 126, span: 20),
    SakuraLimb(a: 136, r: 0.40, s: 0.66, seed: 12, app: 150, span: 20),
    SakuraLimb(a: 80,  r: 0.70, s: 0.62, seed: 13, app: 178, span: 22),
    SakuraLimb(a: 104, r: 0.68, s: 0.62, seed: 14, app: 210, span: 22),
    SakuraLimb(a: 38,  r: 0.82, s: 0.56, seed: 15, app: 248, span: 24),
    SakuraLimb(a: 146, r: 0.82, s: 0.56, seed: 16, app: 290, span: 24),
    SakuraLimb(a: 90,  r: 0.74, s: 0.58, seed: 17, app: 332, span: 24),
]

private struct SakuraTuft { let ang, rad, app, sz, span, seed: Double }

private let sakuraTufts: [SakuraTuft] = {
    var out: [SakuraTuft] = []
    let N = 38
    for i in 0..<N {
        let u = rand01(700, Double(i + 1)), v = rand01(810, Double(i + 1))
        out.append(SakuraTuft(
            ang: .pi * (0.07 + 0.86 * u),
            rad: 0.06 + 0.70 * sqrt(v),
            app: 2 + pow(Double(i) / Double(N), 0.92) * 356,
            sz: 0.48 + 0.42 * rand01(920, Double(i + 1)),
            span: 9 + (rand01(930, Double(i + 1)) * 6).rounded(),
            seed: 200 + Double(i)
        ))
    }
    return out
}()

// A soft painterly blossom cluster (shadow → mid → lit clumps → highlights).
private func sakuraCluster(
    _ ctx: inout GraphicsContext, cx: Double, cy: Double, size: Double,
    seed: Double, squashY: Double = 0.84, noise: Double = 0.28,
    clumps: Int = 4, lights: Int = 3, sat: Double = 1, opacity: Double = 1, tilt: Double = 0
) {
    let shadow = SakuraPal.bloomDeep, mid = SakuraPal.bloomMid
    let light = SakuraPal.bloomLight, hi = SakuraPal.bloomHi
    let r: (Double) -> Double = { rand01(seed, $0) }

    var g = ctx
    g.translateBy(x: cx, y: cy)
    g.opacity = opacity

    let sh = blobPath(cx: size * 0.10, cy: size * 0.13, rBase: size * 1.02,
                      seed: seed * 1.1, points: 10, squashY: squashY, noise: noise * 0.85, tiltDeg: tilt)
    g.fill(sh, with: .color(shadow.opacity(0.8 * sat)))

    let md = blobPath(cx: 0, cy: 0, rBase: size * 0.92,
                      seed: seed * 1.3 + 7, points: 11, squashY: squashY + 0.03, noise: noise, tiltDeg: tilt * 0.6)
    g.fill(md, with: .color(mid.opacity(0.96 * sat)))

    for i in 0..<clumps {
        let a = Double(i) / Double(max(1, clumps)) * .pi * 1.4 - .pi * 0.95
        let off = size * (0.30 + r(Double(i * 5 + 2)) * 0.22)
        let rad = size * (0.20 + r(Double(i * 5 + 3)) * 0.12)
        let p = blobPath(cx: cos(a) * off, cy: sin(a) * off * 0.7 - size * 0.08, rBase: rad,
                         seed: seed * 17 + Double(i) * 31, points: 8, squashY: 0.9, noise: 0.32)
        g.fill(p, with: .color(light.opacity(0.72 * sat)))
    }

    for i in 0..<lights {
        let a = -Double.pi * 0.78 + Double(i) / Double(max(1, lights)) * .pi * 0.72
        let off = size * (0.44 + r(Double(i * 7 + 9)) * 0.18)
        let rad = size * (0.10 + r(Double(i * 7 + 11)) * 0.07)
        let p = blobPath(cx: cos(a) * off, cy: sin(a) * off * 0.55 - size * 0.18, rBase: rad,
                         seed: seed * 23 + Double(i) * 41, points: 8, squashY: 0.95, noise: 0.28)
        g.fill(p, with: .color(hi.opacity(0.85 * sat)))
    }
}

private func drawSakuraPot(_ ctx: inout GraphicsContext) {
    var body = Path()
    body.move(to: CGPoint(x: 170, y: 415))
    body.addLine(to: CGPoint(x: 184, y: 460))
    body.addLine(to: CGPoint(x: 416, y: 460))
    body.addLine(to: CGPoint(x: 430, y: 415))
    body.closeSubpath()
    ctx.fill(body, with: .linearGradient(
        Gradient(colors: [SakuraPal.potMid, SakuraPal.potDark]),
        startPoint: CGPoint(x: 300, y: 415), endPoint: CGPoint(x: 300, y: 460)))

    var glaze = Path()
    glaze.move(to: CGPoint(x: 182, y: 417))
    glaze.addLine(to: CGPoint(x: 196, y: 452))
    glaze.addLine(to: CGPoint(x: 268, y: 452))
    glaze.addLine(to: CGPoint(x: 260, y: 417))
    glaze.closeSubpath()
    ctx.fill(glaze, with: .color(SakuraPal.potGlaze.opacity(0.30)))

    var shade = Path()
    shade.move(to: CGPoint(x: 300, y: 415))
    shade.addLine(to: CGPoint(x: 416, y: 460))
    shade.addLine(to: CGPoint(x: 430, y: 415))
    shade.closeSubpath()
    ctx.fill(shade, with: .color(SakuraPal.potDark.opacity(0.45)))

    var rim = Path()
    rim.move(to: CGPoint(x: 184, y: 460))
    rim.addLine(to: CGPoint(x: 416, y: 460))
    rim.addLine(to: CGPoint(x: 408, y: 456))
    rim.addLine(to: CGPoint(x: 192, y: 456))
    rim.closeSubpath()
    ctx.fill(rim, with: .color(SakuraPal.potRim.opacity(0.55)))

    ctx.fill(ellipse(300, 413, 130, 9),    with: .color(SakuraPal.potRim))
    ctx.fill(ellipse(300, 411, 130, 8),    with: .color(SakuraPal.potMid))
    ctx.fill(ellipse(300, 410, 126, 6.5),  with: .color(SakuraPal.potLight.opacity(0.7)))
    ctx.fill(ellipse(300, 412, 124, 6.5),  with: .color(SakuraPal.soilMid))
    ctx.fill(ellipse(300, 412.5, 122, 5.5), with: .color(SakuraPal.soilDark))
    ctx.fill(ellipse(240, 412, 1.8, 1.8),  with: .color(SakuraPal.barkMid.opacity(0.5)))
    ctx.fill(ellipse(328, 412, 1.6, 1.6),  with: .color(SakuraPal.barkMid.opacity(0.45)))
    ctx.fill(ellipse(285, 413, 1.2, 1.2),  with: .color(SakuraPal.barkLight.opacity(0.4)))
}

private func drawSakuraTrunk(day: Int, c: SakuraCanopy, in ctx: inout GraphicsContext) {
    let baseX = 300.0, baseY = 410.0
    let topW = max(2.2, c.baseW * 0.42)
    let midY = (baseY + c.forkY) / 2
    let bend = 2 + 7 * c.g
    let bL = baseX - c.baseW / 2, bR = baseX + c.baseW / 2
    let mL = baseX - bend - topW * 0.55, mR = baseX - bend + topW * 0.55
    let tL = c.forkX - topW / 2, tR = c.forkX + topW / 2

    var trunk = Path()
    trunk.move(to: CGPoint(x: bL, y: baseY))
    trunk.addQuadCurve(to: CGPoint(x: mL, y: midY), control: CGPoint(x: bL - 2, y: midY + 8))
    trunk.addQuadCurve(to: CGPoint(x: tL, y: c.forkY), control: CGPoint(x: mL + 2, y: (midY + c.forkY) / 2))
    trunk.addLine(to: CGPoint(x: tR, y: c.forkY))
    trunk.addQuadCurve(to: CGPoint(x: mR, y: midY), control: CGPoint(x: mR + 2, y: (midY + c.forkY) / 2))
    trunk.addQuadCurve(to: CGPoint(x: bR, y: baseY), control: CGPoint(x: bR + 2, y: midY + 8))
    trunk.closeSubpath()

    let tb = trunk.boundingRect
    ctx.fill(trunk, with: .linearGradient(
        Gradient(colors: [SakuraPal.barkLight, SakuraPal.barkMid, SakuraPal.barkDeep]),
        startPoint: CGPoint(x: tb.minX, y: tb.midY), endPoint: CGPoint(x: tb.maxX, y: tb.midY)))

    let lc = sakuraBark(day)
    let forkLen = baseY - c.forkY
    if lc > 0.05 && c.baseW > 14 {
        let rows = Int((2 + 5 * lc).rounded())
        for i in 0..<rows {
            let ty = lerp(baseY - 8, c.forkY + 6, Double(i) / Double(max(1, rows - 1)))
            let tw = lerp(c.baseW, topW, (baseY - ty) / max(1, forkLen))
            let lx = baseX - tw * 0.28 - bend * ((baseY - ty) / max(1, forkLen))
            let ll = max(2.4, tw * 0.5)
            var line = Path()
            line.move(to: CGPoint(x: lx, y: ty))
            line.addLine(to: CGPoint(x: lx + ll, y: ty))
            ctx.stroke(line, with: .color(SakuraPal.lenticel.opacity(0.5 * lc)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }
}

private func sakuraPetal(_ ctx: inout GraphicsContext, x: Double, y: Double, s: Double,
                         rotDeg: Double, color: Color, opacity: Double) {
    var p = Path()
    p.move(to: CGPoint(x: 0, y: -s))
    p.addQuadCurve(to: CGPoint(x: s * 0.5, y: s * 0.62), control: CGPoint(x: s, y: -s * 0.35))
    p.addQuadCurve(to: CGPoint(x: 0, y: s * 0.5), control: CGPoint(x: s * 0.18, y: s * 0.18))
    p.addQuadCurve(to: CGPoint(x: -s * 0.5, y: s * 0.62), control: CGPoint(x: -s * 0.18, y: s * 0.18))
    p.addQuadCurve(to: CGPoint(x: 0, y: -s), control: CGPoint(x: -s, y: -s * 0.35))
    p.closeSubpath()
    var g = ctx
    g.translateBy(x: x, y: y)
    g.rotate(by: .degrees(rotDeg))
    g.fill(p, with: .color(color.opacity(opacity)))
}

private func drawSakuraPetals(day: Int, c: SakuraCanopy, in ctx: inout GraphicsContext) {
    let amt = sakuraPetalAmt(day)
    if amt < 0.02 { return }
    let fallN = Int((amt * 30).rounded())
    for i in 0..<fallN {
        let h1 = rand01(71, Double(i + 1)), h2 = rand01(89, Double(i + 3))
        sakuraPetal(&ctx, x: 300 + (h1 - 0.5) * 158, y: 408.5 + h2 * 5.5,
                    s: 3 + rand01(53, Double(i)) * 2, rotDeg: (h1 - 0.5) * 120,
                    color: h2 > 0.5 ? SakuraPal.bloomLight : SakuraPal.bloomMid, opacity: 0.92)
    }
    let airN = Int((amt * 12).rounded())
    for i in 0..<airN {
        let h1 = rand01(131, Double(i + 1)), h2 = rand01(167, Double(i + 5)), h3 = rand01(199, Double(i + 9))
        let y0 = c.cY + c.Ry * 0.5 + h2 * (430 - (c.cY + c.Ry * 0.5))
        sakuraPetal(&ctx, x: c.cX + (h1 - 0.5) * c.Rx * 2.0, y: min(y0, 432),
                    s: 3 + h3 * 2.4, rotDeg: (h1 - 0.5) * 150,
                    color: h3 > 0.5 ? SakuraPal.bloomLight : SakuraPal.bloomMid, opacity: 0.85)
    }
}

private struct SakuraBlossom { var tx, ty, size, seed: Double; var accent: Bool; var light: Bool }

func drawSakura(day rawDay: Int, in ctx: inout GraphicsContext) {
    let day = max(0, min(365, rawDay))
    let c = sakuraCanopy(day)
    let padBase = 6 + 34 * c.g

    struct Limb { let L: SakuraLimb; let e, tx, ty, size: Double; let branch: Bool }
    var limbItems: [Limb] = []
    for L in sakuraLimbs {
        let e = L.app == 0 ? 1.0 : smoothstepS(L.app, L.app + L.span, Double(day))
        if e < 0.02 { continue }
        let ar = L.a * .pi / 180
        let tx = c.cX + cos(ar) * c.Rx * L.r * e
        let ty = c.cY - sin(ar) * c.Ry * L.r * e
        limbItems.append(Limb(L: L, e: e, tx: tx, ty: ty,
                              size: padBase * L.s * (0.6 + 0.4 * e), branch: L.app != 0))
    }

    drawSakuraPot(&ctx)

    // Branches sit behind the trunk, painted back-to-front (lowest on screen first).
    for it in limbItems.sorted(by: { $0.ty > $1.ty }) where it.branch {
        let ar = it.L.a * .pi / 180
        let mx = (c.forkX + it.tx) / 2 - sin(ar) * 5 * c.g
        let my = (c.forkY + it.ty) / 2 - 8 * c.g * it.e
        let w = max(1.8, c.baseW * 0.20 * (0.4 + 0.6 * it.e))
        var b = Path()
        b.move(to: CGPoint(x: c.forkX, y: c.forkY))
        b.addQuadCurve(to: CGPoint(x: it.tx, y: it.ty), control: CGPoint(x: mx, y: my))
        ctx.stroke(b, with: .color(SakuraPal.barkMid), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    drawSakuraTrunk(day: day, c: c, in: &ctx)

    var blossoms: [SakuraBlossom] = limbItems.map {
        SakuraBlossom(tx: $0.tx, ty: $0.ty, size: $0.size, seed: $0.L.seed,
                      accent: Int($0.L.seed) % 3 == 0, light: false)
    }
    for T in sakuraTufts {
        let e = smoothstepS(T.app, T.app + T.span, Double(day))
        if e < 0.02 { continue }
        let rr = T.rad * (0.35 + 0.65 * e)
        let tx = c.cX + cos(T.ang) * c.Rx * rr
        let ty = c.cY - sin(T.ang) * c.Ry * rr
        blossoms.append(SakuraBlossom(tx: tx, ty: ty, size: padBase * T.sz * (0.6 + 0.4 * e),
                                      seed: T.seed, accent: false, light: true))
    }

    for it in blossoms.sorted(by: { $0.ty > $1.ty }) {
        let clumps = it.light ? 0 : 2
        let lights = it.light ? 1 : 2
        sakuraCluster(&ctx, cx: it.tx, cy: it.ty, size: it.size, seed: it.seed * 5 + 2,
                      squashY: 0.86, noise: 0.30, clumps: clumps, lights: lights, sat: 1, opacity: 1)
        if c.g > 0.45 && it.accent {
            ctx.fill(ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                     with: .color(SakuraPal.center.opacity(0.4)))
        }
    }

    drawSakuraPetals(day: day, c: c, in: &ctx)
}

/// Tight content box for the sakura, in the 600×600 design space, used by
/// `BonsaiView(fill:)` to zoom the canvas onto the plant.
func sakuraContentRect(day: Int) -> CGRect {
    let d = min(365, max(0, day))
    let c = sakuraCanopy(d)
    let padBase = 6 + 34 * c.g
    var minX = 170.0, maxX = 430.0
    var minY = 410.0
    let maxY = 464.0    // pot footprint always anchors the bottom
    minX = min(minX, c.cX - c.Rx - padBase)
    maxX = max(maxX, c.cX + c.Rx + padBase)
    minY = min(minY, c.cY - c.Ry - padBase * 1.3)

    var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    let minDim = 230.0
    if rect.width < minDim { rect = rect.insetBy(dx: -(minDim - rect.width) / 2, dy: 0) }
    if rect.height < minDim { rect = rect.insetBy(dx: 0, dy: -(minDim - rect.height) / 2) }
    return rect
}

// MARK: - Maple (Japanese maple) bonsai — native port of bonsai-maple.js
//
// Warm autumn crimson→orange→gold lacy vase canopy, vertical bark striping,
// iron-charcoal rectangular pot, 5-point star leaves. Same continuous-growth
// discipline as Sakura; used when `style == .maple`.

private enum MaplePal {
    static let folDeep   = Color(hex: 0x8C2E22)
    static let folMid    = Color(hex: 0xC8472A)
    static let folLight  = Color(hex: 0xE87B33)
    static let folHi     = Color(hex: 0xF4B24B)
    static let folEmber  = Color(hex: 0x9E3320)
    static let barkDeep  = Color(hex: 0x43342B)
    static let barkMid   = Color(hex: 0x6E594A)
    static let barkLight = Color(hex: 0x9C8676)
    static let barkStripe = Color(hex: 0x574539)
    static let potDark   = Color(hex: 0x26282B)
    static let potMid    = Color(hex: 0x3C4045)
    static let potLight  = Color(hex: 0x565C63)
    static let potRim    = Color(hex: 0x1A1B1D)
    static let potGlaze  = Color(hex: 0x6B7178)
    static let soilDark  = Color(hex: 0x211712)
    static let soilMid   = Color(hex: 0x37281D)
}

private func mapleScale(_ d: Int) -> Double { ramp(Double(d), 0, 430, 0.5) }
private func mapleBark(_ d: Int) -> Double { smoothstepS(70, 400, Double(d)) }
private func mapleFall(_ d: Int) -> Double { ramp(Double(d), 55, 365, 1.0) }

private struct MapleCanopy {
    var cX: Double, cY: Double, Rx: Double, Ry: Double
    var forkX: Double, forkY: Double, g: Double, baseW: Double
}

private func mapleCanopy(_ day: Int) -> MapleCanopy {
    let baseY = 410.0
    let g = mapleScale(day)
    let forkLen = 12 + 182 * g
    let forkY = baseY - forkLen
    let forkX = 304.0
    let Rx = 8 + 132 * g
    let Ry = 6 + 74 * g
    let baseW = 2.4 + 38 * g
    return MapleCanopy(cX: forkX, cY: forkY - Ry * 0.34, Rx: Rx, Ry: Ry,
                       forkX: forkX, forkY: forkY, g: g, baseW: baseW)
}

private struct MapleLimb { let a, r, s, seed, app, span: Double }

private let mapleLimbs: [MapleLimb] = [
    MapleLimb(a: 90,  r: 0.10, s: 1.00, seed: 1,  app: 0,   span: 1),
    MapleLimb(a: 120, r: 0.46, s: 0.88, seed: 2,  app: 7,   span: 16),
    MapleLimb(a: 60,  r: 0.46, s: 0.88, seed: 3,  app: 13,  span: 16),
    MapleLimb(a: 142, r: 0.66, s: 0.78, seed: 4,  app: 22,  span: 18),
    MapleLimb(a: 38,  r: 0.66, s: 0.78, seed: 5,  app: 31,  span: 18),
    MapleLimb(a: 96,  r: 0.62, s: 0.80, seed: 6,  app: 42,  span: 16),
    MapleLimb(a: 108, r: 0.84, s: 0.70, seed: 7,  app: 54,  span: 18),
    MapleLimb(a: 72,  r: 0.84, s: 0.70, seed: 8,  app: 67,  span: 18),
    MapleLimb(a: 26,  r: 0.58, s: 0.66, seed: 9,  app: 84,  span: 20),
    MapleLimb(a: 154, r: 0.58, s: 0.66, seed: 10, app: 104, span: 20),
    MapleLimb(a: 50,  r: 0.38, s: 0.66, seed: 11, app: 126, span: 20),
    MapleLimb(a: 130, r: 0.38, s: 0.66, seed: 12, app: 150, span: 20),
    MapleLimb(a: 84,  r: 0.74, s: 0.62, seed: 13, app: 178, span: 22),
    MapleLimb(a: 100, r: 0.72, s: 0.62, seed: 14, app: 210, span: 22),
    MapleLimb(a: 44,  r: 0.80, s: 0.56, seed: 15, app: 248, span: 24),
    MapleLimb(a: 138, r: 0.80, s: 0.56, seed: 16, app: 290, span: 24),
    MapleLimb(a: 90,  r: 0.86, s: 0.58, seed: 17, app: 332, span: 24),
]

private struct MapleTuft { let ang, rad, app, sz, span, seed: Double }

private let mapleTufts: [MapleTuft] = {
    var out: [MapleTuft] = []
    let N = 46
    for i in 0..<N {
        let u = rand01(700, Double(i + 1)), v = rand01(810, Double(i + 1))
        out.append(MapleTuft(
            ang: .pi * (0.05 + 0.90 * u),
            rad: 0.05 + 0.74 * sqrt(v),
            app: 2 + pow(Double(i) / Double(N), 0.92) * 356,
            sz: 0.40 + 0.40 * rand01(920, Double(i + 1)),
            span: 9 + (rand01(930, Double(i + 1)) * 6).rounded(),
            seed: 200 + Double(i)
        ))
    }
    return out
}()

private func mapleCluster(
    _ ctx: inout GraphicsContext, cx: Double, cy: Double, size: Double,
    seed: Double, squashY: Double = 0.84, noise: Double = 0.34,
    clumps: Int = 4, lights: Int = 3, sat: Double = 1, opacity: Double = 1, tilt: Double = 0
) {
    let shadow = MaplePal.folDeep, mid = MaplePal.folMid
    let light = MaplePal.folLight, hi = MaplePal.folHi
    let r: (Double) -> Double = { rand01(seed, $0) }
    var g = ctx
    g.translateBy(x: cx, y: cy)
    g.opacity = opacity

    let sh = blobPath(cx: size * 0.10, cy: size * 0.13, rBase: size * 1.02,
                      seed: seed * 1.1, points: 11, squashY: squashY, noise: noise * 0.9, tiltDeg: tilt)
    g.fill(sh, with: .color(shadow.opacity(0.82 * sat)))
    let md = blobPath(cx: 0, cy: 0, rBase: size * 0.92,
                      seed: seed * 1.3 + 7, points: 12, squashY: squashY + 0.02, noise: noise, tiltDeg: tilt * 0.6)
    g.fill(md, with: .color(mid.opacity(0.96 * sat)))
    for i in 0..<clumps {
        let a = Double(i) / Double(max(1, clumps)) * .pi * 1.4 - .pi * 0.95
        let off = size * (0.30 + r(Double(i * 5 + 2)) * 0.24)
        let rad = size * (0.18 + r(Double(i * 5 + 3)) * 0.12)
        let p = blobPath(cx: cos(a) * off, cy: sin(a) * off * 0.7 - size * 0.08, rBase: rad,
                         seed: seed * 17 + Double(i) * 31, points: 8, squashY: 0.9, noise: 0.4)
        g.fill(p, with: .color(light.opacity(0.74 * sat)))
    }
    for i in 0..<lights {
        let a = -Double.pi * 0.78 + Double(i) / Double(max(1, lights)) * .pi * 0.72
        let off = size * (0.44 + r(Double(i * 7 + 9)) * 0.18)
        let rad = size * (0.09 + r(Double(i * 7 + 11)) * 0.07)
        let p = blobPath(cx: cos(a) * off, cy: sin(a) * off * 0.55 - size * 0.18, rBase: rad,
                         seed: seed * 23 + Double(i) * 41, points: 7, squashY: 0.95, noise: 0.34)
        g.fill(p, with: .color(hi.opacity(0.85 * sat)))
    }
}

private func drawMaplePot(_ ctx: inout GraphicsContext) {
    var body = Path()
    body.move(to: CGPoint(x: 176, y: 418))
    body.addLine(to: CGPoint(x: 186, y: 460))
    body.addLine(to: CGPoint(x: 414, y: 460))
    body.addLine(to: CGPoint(x: 424, y: 418))
    body.closeSubpath()
    ctx.fill(body, with: .linearGradient(
        Gradient(colors: [MaplePal.potMid, MaplePal.potDark]),
        startPoint: CGPoint(x: 300, y: 418), endPoint: CGPoint(x: 300, y: 460)))

    var glaze = Path()
    glaze.move(to: CGPoint(x: 186, y: 420))
    glaze.addLine(to: CGPoint(x: 198, y: 452))
    glaze.addLine(to: CGPoint(x: 262, y: 452))
    glaze.addLine(to: CGPoint(x: 256, y: 420))
    glaze.closeSubpath()
    ctx.fill(glaze, with: .color(MaplePal.potGlaze.opacity(0.16)))

    var shade = Path()
    shade.move(to: CGPoint(x: 300, y: 418))
    shade.addLine(to: CGPoint(x: 414, y: 460))
    shade.addLine(to: CGPoint(x: 424, y: 418))
    shade.closeSubpath()
    ctx.fill(shade, with: .color(MaplePal.potDark.opacity(0.5)))

    var rim = Path()
    rim.move(to: CGPoint(x: 186, y: 460))
    rim.addLine(to: CGPoint(x: 414, y: 460))
    rim.addLine(to: CGPoint(x: 406, y: 455))
    rim.addLine(to: CGPoint(x: 194, y: 455))
    rim.closeSubpath()
    ctx.fill(rim, with: .color(MaplePal.potRim.opacity(0.6)))

    var lip = Path()
    lip.move(to: CGPoint(x: 168, y: 410))
    lip.addLine(to: CGPoint(x: 432, y: 410))
    lip.addLine(to: CGPoint(x: 424, y: 421))
    lip.addLine(to: CGPoint(x: 176, y: 421))
    lip.closeSubpath()
    ctx.fill(lip, with: .color(MaplePal.potLight.opacity(0.9)))

    var lipHi = Path()
    lipHi.move(to: CGPoint(x: 168, y: 410))
    lipHi.addLine(to: CGPoint(x: 432, y: 410))
    lipHi.addLine(to: CGPoint(x: 430, y: 414))
    lipHi.addLine(to: CGPoint(x: 170, y: 414))
    lipHi.closeSubpath()
    ctx.fill(lipHi, with: .color(MaplePal.potGlaze.opacity(0.4)))

    var lipShadow = Path()
    lipShadow.move(to: CGPoint(x: 176, y: 421))
    lipShadow.addLine(to: CGPoint(x: 424, y: 421))
    lipShadow.addLine(to: CGPoint(x: 421, y: 425))
    lipShadow.addLine(to: CGPoint(x: 179, y: 425))
    lipShadow.closeSubpath()
    ctx.fill(lipShadow, with: .color(MaplePal.potRim.opacity(0.5)))

    ctx.fill(ellipse(300, 412, 124, 6.5),  with: .color(MaplePal.soilMid))
    ctx.fill(ellipse(300, 412.5, 122, 5.5), with: .color(MaplePal.soilDark))
    ctx.fill(ellipse(242, 412, 1.8, 1.8),  with: .color(MaplePal.barkMid.opacity(0.5)))
    ctx.fill(ellipse(330, 412, 1.6, 1.6),  with: .color(MaplePal.barkMid.opacity(0.45)))
    ctx.fill(ellipse(286, 413, 1.2, 1.2),  with: .color(MaplePal.barkLight.opacity(0.4)))
}

private func drawMapleTrunk(day: Int, c: MapleCanopy, in ctx: inout GraphicsContext) {
    let baseX = 300.0, baseY = 410.0
    let topW = max(2.0, c.baseW * 0.40)
    let midY = (baseY + c.forkY) / 2
    let bend = 3 + 9 * c.g
    let bL = baseX - c.baseW / 2, bR = baseX + c.baseW / 2
    let mL = baseX - bend - topW * 0.55, mR = baseX - bend + topW * 0.55
    let tL = c.forkX - topW / 2, tR = c.forkX + topW / 2

    var trunk = Path()
    trunk.move(to: CGPoint(x: bL, y: baseY))
    trunk.addQuadCurve(to: CGPoint(x: mL, y: midY), control: CGPoint(x: bL - 2, y: midY + 8))
    trunk.addQuadCurve(to: CGPoint(x: tL, y: c.forkY), control: CGPoint(x: mL + 2, y: (midY + c.forkY) / 2))
    trunk.addLine(to: CGPoint(x: tR, y: c.forkY))
    trunk.addQuadCurve(to: CGPoint(x: mR, y: midY), control: CGPoint(x: mR + 2, y: (midY + c.forkY) / 2))
    trunk.addQuadCurve(to: CGPoint(x: bR, y: baseY), control: CGPoint(x: bR + 2, y: midY + 8))
    trunk.closeSubpath()

    let tb = trunk.boundingRect
    ctx.fill(trunk, with: .linearGradient(
        Gradient(colors: [MaplePal.barkLight, MaplePal.barkMid, MaplePal.barkDeep]),
        startPoint: CGPoint(x: tb.minX, y: tb.midY), endPoint: CGPoint(x: tb.maxX, y: tb.midY)))

    let lc = mapleBark(day)
    if lc > 0.05 && c.baseW > 12 {
        let n = Int((2 + 3 * lc).rounded())
        for i in 0..<n {
            let fx = lerp(-0.3, 0.3, Double(i) / Double(max(1, n - 1)))
            let x0 = baseX + fx * c.baseW * 0.7
            let x1 = c.forkX + fx * topW * 0.7 - bend
            var s = Path()
            s.move(to: CGPoint(x: x0, y: baseY - 4))
            s.addQuadCurve(to: CGPoint(x: x1, y: c.forkY + 4), control: CGPoint(x: (x0 + x1) / 2 - bend * 0.5, y: midY))
            ctx.stroke(s, with: .color(MaplePal.barkStripe.opacity(0.4 * lc)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }
}

private func mapleLeaf(_ ctx: inout GraphicsContext, x: Double, y: Double, s: Double,
                       rotDeg: Double, color: Color, opacity: Double) {
    var p = Path()
    for i in 0..<5 {
        let a = Double(i) / 5 * .pi * 2 - .pi / 2
        let aInner = a + .pi / 5
        let outer = CGPoint(x: cos(a) * s, y: sin(a) * s)
        let inner = CGPoint(x: cos(aInner) * s * 0.42, y: sin(aInner) * s * 0.42)
        if i == 0 { p.move(to: outer) } else { p.addLine(to: outer) }
        p.addLine(to: inner)
    }
    p.closeSubpath()
    var g = ctx
    g.translateBy(x: x, y: y)
    g.rotate(by: .degrees(rotDeg))
    g.fill(p, with: .color(color.opacity(opacity)))
}

private func drawMapleLeaves(day: Int, c: MapleCanopy, in ctx: inout GraphicsContext) {
    let amt = mapleFall(day)
    if amt < 0.02 { return }
    let fallN = Int((amt * 26).rounded())
    for i in 0..<fallN {
        let h1 = rand01(71, Double(i + 1)), h2 = rand01(89, Double(i + 3)), h3 = rand01(53, Double(i))
        let fill = h3 > 0.6 ? MaplePal.folHi : (h3 > 0.3 ? MaplePal.folLight : MaplePal.folMid)
        mapleLeaf(&ctx, x: 300 + (h1 - 0.5) * 160, y: 408 + h2 * 6, s: 3.2 + h3 * 2,
                  rotDeg: (h1 - 0.5) * 180, color: fill, opacity: 0.92)
    }
    let airN = Int((amt * 10).rounded())
    for i in 0..<airN {
        let h1 = rand01(131, Double(i + 1)), h2 = rand01(167, Double(i + 5)), h3 = rand01(199, Double(i + 9))
        let y0 = c.cY + c.Ry * 0.5 + h2 * (430 - (c.cY + c.Ry * 0.5))
        let fill = h3 > 0.5 ? MaplePal.folLight : MaplePal.folMid
        mapleLeaf(&ctx, x: c.cX + (h1 - 0.5) * c.Rx * 2.0, y: min(y0, 432), s: 3 + h3 * 2.2,
                  rotDeg: (h1 - 0.5) * 200, color: fill, opacity: 0.85)
    }
}

func drawMaple(day rawDay: Int, in ctx: inout GraphicsContext) {
    let day = max(0, min(365, rawDay))
    let c = mapleCanopy(day)
    let padBase = 5 + 30 * c.g

    struct Limb { let L: MapleLimb; let e, tx, ty, size: Double; let branch: Bool }
    var limbItems: [Limb] = []
    for L in mapleLimbs {
        let e = L.app == 0 ? 1.0 : smoothstepS(L.app, L.app + L.span, Double(day))
        if e < 0.02 { continue }
        let ar = L.a * .pi / 180
        let tx = c.cX + cos(ar) * c.Rx * L.r * e
        let ty = c.cY - sin(ar) * c.Ry * L.r * e
        limbItems.append(Limb(L: L, e: e, tx: tx, ty: ty,
                              size: padBase * L.s * (0.6 + 0.4 * e), branch: L.app != 0))
    }

    drawMaplePot(&ctx)

    for it in limbItems.sorted(by: { $0.ty > $1.ty }) where it.branch {
        let ar = it.L.a * .pi / 180
        let mx = (c.forkX + it.tx) / 2 - sin(ar) * 5 * c.g
        let my = (c.forkY + it.ty) / 2 - 6 * c.g * it.e
        let w = max(1.6, c.baseW * 0.17 * (0.4 + 0.6 * it.e))
        var b = Path()
        b.move(to: CGPoint(x: c.forkX, y: c.forkY))
        b.addQuadCurve(to: CGPoint(x: it.tx, y: it.ty), control: CGPoint(x: mx, y: my))
        ctx.stroke(b, with: .color(MaplePal.barkMid), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    drawMapleTrunk(day: day, c: c, in: &ctx)

    struct Fol { var tx, ty, size, seed: Double; var accent: Bool; var light: Bool }
    var fol: [Fol] = limbItems.map {
        Fol(tx: $0.tx, ty: $0.ty, size: $0.size, seed: $0.L.seed,
            accent: Int($0.L.seed) % 3 == 0, light: false)
    }
    for T in mapleTufts {
        let e = smoothstepS(T.app, T.app + T.span, Double(day))
        if e < 0.02 { continue }
        let rr = T.rad * (0.35 + 0.65 * e)
        let tx = c.cX + cos(T.ang) * c.Rx * rr
        let ty = c.cY - sin(T.ang) * c.Ry * rr
        fol.append(Fol(tx: tx, ty: ty, size: padBase * T.sz * (0.6 + 0.4 * e),
                       seed: T.seed, accent: false, light: true))
    }

    for it in fol.sorted(by: { $0.ty > $1.ty }) {
        let clumps = it.light ? 0 : 2
        let lights = it.light ? 1 : 2
        mapleCluster(&ctx, cx: it.tx, cy: it.ty, size: it.size, seed: it.seed * 5 + 2,
                     squashY: 0.84, noise: 0.36, clumps: clumps, lights: lights, sat: 1, opacity: 1)
        if c.g > 0.45 && it.accent {
            ctx.fill(ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                     with: .color(MaplePal.folEmber.opacity(0.4)))
        }
    }

    drawMapleLeaves(day: day, c: c, in: &ctx)
}

func mapleContentRect(day: Int) -> CGRect {
    let d = min(365, max(0, day))
    let c = mapleCanopy(d)
    let padBase = 5 + 30 * c.g
    var minX = 168.0, maxX = 432.0
    var minY = 410.0
    let maxY = 462.0
    minX = min(minX, c.cX - c.Rx - padBase)
    maxX = max(maxX, c.cX + c.Rx + padBase)
    minY = min(minY, c.cY - c.Ry - padBase * 1.3)
    var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    let minDim = 230.0
    if rect.width < minDim { rect = rect.insetBy(dx: -(minDim - rect.width) / 2, dy: 0) }
    if rect.height < minDim { rect = rect.insetBy(dx: 0, dy: -(minDim - rect.height) / 2) }
    return rect
}

// MARK: - Pine (Japanese black pine) bonsai — native port of bonsai-pine.js
//
// Evergreen blue-green needle pads in flat horizontal tiers (built bottom-up),
// a gnarled S-curved leaning trunk with plated bark + moss, pale spring candles,
// and an unglazed brown stoneware drum pot. Used when `style == .pine`.

private enum PinePal {
    static let needDeep  = Color(hex: 0x1E3A30)
    static let needMid   = Color(hex: 0x2F6149)
    static let needLight = Color(hex: 0x4C8A63)
    static let needHi    = Color(hex: 0x7FB583)
    static let candle    = Color(hex: 0xB7C68A)
    static let barkDeep  = Color(hex: 0x33271F)
    static let barkMid   = Color(hex: 0x5A4636)
    static let barkLight = Color(hex: 0x897059)
    static let barkPlate = Color(hex: 0x3E2F24)
    static let barkMoss  = Color(hex: 0x6E7A4E)
    static let potDark   = Color(hex: 0x5A3D2A)
    static let potMid    = Color(hex: 0x825939)
    static let potLight  = Color(hex: 0xA8794F)
    static let potRim    = Color(hex: 0x432C1D)
    static let potSpeck  = Color(hex: 0xC49A6A)
    static let soilDark  = Color(hex: 0x211611)
    static let soilMid   = Color(hex: 0x36271C)
}

private func pineScale(_ d: Int) -> Double { ramp(Double(d), 0, 430, 0.5) }
private func pineBark(_ d: Int) -> Double { smoothstepS(60, 380, Double(d)) }
private func pineNeedle(_ d: Int) -> Double { ramp(Double(d), 60, 365, 1.0) }
private func pineCandle(_ d: Int) -> Double {
    smoothstepS(20, 120, Double(d)) * (1 - smoothstepS(150, 230, Double(d)))
}

private func lerpP(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

private struct PineCanopy { var topX, topY, baseX, baseY, g, baseW: Double }

private func pineCanopy(_ day: Int) -> PineCanopy {
    let baseX = 296.0, baseY = 412.0
    let g = pineScale(day)
    let topLen = 14 + 168 * g
    let topY = baseY - topLen
    let lean = 10 + 26 * g
    let topX = baseX + lean
    let baseW = 3 + 50 * g
    return PineCanopy(topX: topX, topY: topY, baseX: baseX, baseY: baseY, g: g, baseW: baseW)
}

private struct PinePad { let side, hFrac, reach, wFrac, app, span, seed: Double }

private let pinePads: [PinePad] = [
    PinePad(side: 0,  hFrac: 1.00, reach: 0.00, wFrac: 0.62, app: 0,   span: 1,  seed: 1),
    PinePad(side: 1,  hFrac: 0.62, reach: 0.95, wFrac: 0.95, app: 8,   span: 20, seed: 2),
    PinePad(side: -1, hFrac: 0.46, reach: 0.85, wFrac: 0.85, app: 26,  span: 22, seed: 3),
    PinePad(side: 1,  hFrac: 0.80, reach: 0.62, wFrac: 0.72, app: 70,  span: 24, seed: 4),
    PinePad(side: -1, hFrac: 0.86, reach: 0.40, wFrac: 0.58, app: 150, span: 28, seed: 5),
    PinePad(side: 1,  hFrac: 0.30, reach: 1.05, wFrac: 0.70, app: 250, span: 30, seed: 6),
]

private struct PineTuft { let padU, fx, fy, app, sz, span, seed: Double }

private let pineTufts: [PineTuft] = {
    var out: [PineTuft] = []
    let N = 30
    for i in 0..<N {
        out.append(PineTuft(
            padU: rand01(610, Double(i + 1)),
            fx: (rand01(700, Double(i + 1)) - 0.5) * 1.7,
            fy: (rand01(810, Double(i + 1)) - 0.5) * 0.7,
            app: 4 + pow(Double(i) / Double(N), 0.9) * 354,
            sz: 0.30 + 0.30 * rand01(920, Double(i + 1)),
            span: 10 + (rand01(930, Double(i + 1)) * 6).rounded(),
            seed: 300 + Double(i)
        ))
    }
    return out
}()

private func needleCluster(
    _ ctx: inout GraphicsContext, cx: Double, cy: Double, w: Double, h: Double,
    seed: Double, noise: Double = 0.30, clumps: Int = 4, lights: Int = 3, sat: Double = 1, opacity: Double = 1
) {
    let shadow = PinePal.needDeep, mid = PinePal.needMid
    let light = PinePal.needLight, hi = PinePal.needHi
    let r: (Double) -> Double = { rand01(seed, $0) }
    let sq = h / w
    var g = ctx
    g.translateBy(x: cx, y: cy)
    g.opacity = opacity

    let sh = blobPath(cx: 0, cy: h * 0.22, rBase: w * 1.02, seed: seed * 1.1, points: 12, squashY: sq, noise: noise * 0.85, tiltDeg: 0)
    g.fill(sh, with: .color(shadow.opacity(0.85 * sat)))
    let md = blobPath(cx: 0, cy: 0, rBase: w * 0.94, seed: seed * 1.3 + 7, points: 13, squashY: sq + 0.03, noise: noise, tiltDeg: 0)
    g.fill(md, with: .color(mid.opacity(0.96 * sat)))
    for i in 0..<clumps {
        let fx = (Double(i) / Double(max(1, clumps - 1)) - 0.5) * 1.7
        let off = w * fx
        let rad = w * (0.22 + r(Double(i * 5 + 3)) * 0.13)
        let p = blobPath(cx: off, cy: -h * 0.18, rBase: rad, seed: seed * 17 + Double(i) * 31, points: 8, squashY: 0.62, noise: 0.36)
        g.fill(p, with: .color(light.opacity(0.72 * sat)))
    }
    for i in 0..<lights {
        let fx = (Double(i) / Double(max(1, lights - 1)) - 0.5) * 1.5
        let rad = w * (0.10 + r(Double(i * 7 + 11)) * 0.06)
        let p = blobPath(cx: w * fx, cy: -h * 0.34, rBase: rad, seed: seed * 23 + Double(i) * 41, points: 7, squashY: 0.7, noise: 0.3)
        g.fill(p, with: .color(hi.opacity(0.8 * sat)))
    }
}

private func drawPinePot(_ ctx: inout GraphicsContext) {
    var body = Path()
    body.move(to: CGPoint(x: 188, y: 414))
    body.addQuadCurve(to: CGPoint(x: 196, y: 458), control: CGPoint(x: 186, y: 440))
    body.addLine(to: CGPoint(x: 404, y: 458))
    body.addQuadCurve(to: CGPoint(x: 412, y: 414), control: CGPoint(x: 414, y: 440))
    body.closeSubpath()
    ctx.fill(body, with: .linearGradient(
        Gradient(colors: [PinePal.potMid, PinePal.potDark]),
        startPoint: CGPoint(x: 300, y: 414), endPoint: CGPoint(x: 300, y: 458)))

    var shade = Path()
    shade.move(to: CGPoint(x: 300, y: 414))
    shade.addQuadCurve(to: CGPoint(x: 404, y: 458), control: CGPoint(x: 412, y: 440))
    shade.addLine(to: CGPoint(x: 300, y: 458))
    shade.closeSubpath()
    ctx.fill(shade, with: .color(PinePal.potDark.opacity(0.4)))

    var hl = Path()
    hl.move(to: CGPoint(x: 196, y: 420))
    hl.addQuadCurve(to: CGPoint(x: 200, y: 450), control: CGPoint(x: 193, y: 436))
    hl.addLine(to: CGPoint(x: 236, y: 450))
    hl.addQuadCurve(to: CGPoint(x: 232, y: 420), control: CGPoint(x: 230, y: 434))
    hl.closeSubpath()
    ctx.fill(hl, with: .color(PinePal.potLight.opacity(0.22)))

    ctx.fill(ellipse(300, 414, 112, 11),  with: .color(PinePal.potRim))
    ctx.fill(ellipse(300, 412, 112, 10),  with: .color(PinePal.potMid))
    ctx.fill(ellipse(300, 411, 108, 8.5), with: .color(PinePal.potLight.opacity(0.55)))
    ctx.fill(ellipse(300, 412.5, 103, 6.5), with: .color(PinePal.soilMid))
    ctx.fill(ellipse(300, 413, 101, 5.5), with: .color(PinePal.soilDark))
    ctx.fill(ellipse(250, 430, 1.6, 1.6), with: .color(PinePal.potSpeck.opacity(0.4)))
    ctx.fill(ellipse(340, 440, 1.4, 1.4), with: .color(PinePal.potSpeck.opacity(0.35)))
    ctx.fill(ellipse(300, 448, 1.5, 1.5), with: .color(PinePal.potSpeck.opacity(0.3)))
    ctx.fill(ellipse(225, 412, 1.6, 1.6), with: .color(PinePal.barkMid.opacity(0.45)))
    ctx.fill(ellipse(352, 412, 1.4, 1.4), with: .color(PinePal.barkMid.opacity(0.4)))
}

private func drawPineTrunk(day: Int, c: PineCanopy, in ctx: inout GraphicsContext) {
    let baseX = c.baseX, baseY = c.baseY, topX = c.topX, topY = c.topY
    let baseW = c.baseW, topW = max(2.2, baseW * 0.30), g = c.g
    let lean = topX - baseX
    let p0 = CGPoint(x: baseX, y: baseY)
    let p1 = CGPoint(x: baseX - 6 - 4 * g, y: lerp(baseY, topY, 0.34))
    let p2 = CGPoint(x: baseX + lean * 0.7, y: lerp(baseY, topY, 0.68))
    let p3 = CGPoint(x: topX, y: topY)
    func bez(_ t: Double) -> CGPoint {
        let a = lerpP(p0, p1, t), b = lerpP(p1, p2, t), cc = lerpP(p2, p3, t)
        return lerpP(lerpP(a, b, t), lerpP(b, cc, t), t)
    }
    func tangent(_ t: Double) -> CGPoint {
        let a = lerpP(p0, p1, t), b = lerpP(p1, p2, t), cc = lerpP(p2, p3, t)
        let ab = lerpP(a, b, t), bc = lerpP(b, cc, t)
        return CGPoint(x: bc.x - ab.x, y: bc.y - ab.y)
    }
    let widthAt: (Double) -> Double = { lerp(baseW, topW, $0) }
    func side(_ sign: Double) -> [CGPoint] {
        let steps = 5
        var pts: [CGPoint] = []
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let pt = bez(t), tg = tangent(t)
            let len = max(hypot(tg.x, tg.y), 1)
            let nx = -tg.y / len, ny = tg.x / len
            let w = widthAt(t) / 2
            pts.append(CGPoint(x: pt.x + sign * nx * w, y: pt.y + sign * ny * w))
        }
        return pts
    }
    let lPts = side(1), rPts = Array(side(-1).reversed())
    var trunk = Path()
    trunk.move(to: lPts[0])
    for i in 1..<lPts.count { trunk.addLine(to: lPts[i]) }
    for pt in rPts { trunk.addLine(to: pt) }
    trunk.closeSubpath()
    let tb = trunk.boundingRect
    ctx.fill(trunk, with: .linearGradient(
        Gradient(colors: [PinePal.barkLight, PinePal.barkMid, PinePal.barkDeep]),
        startPoint: CGPoint(x: tb.minX, y: tb.midY), endPoint: CGPoint(x: tb.maxX, y: tb.midY)))

    let lc = pineBark(day)
    if lc > 0.05 && baseW > 12 {
        let n = Int((3 + 5 * lc).rounded())
        for i in 0..<n {
            let t = (Double(i) + 0.5) / Double(n)
            let pt = bez(t), w = widthAt(t)
            var s = Path()
            s.move(to: CGPoint(x: pt.x - w * 0.3, y: pt.y))
            s.addQuadCurve(to: CGPoint(x: pt.x + w * 0.3, y: pt.y), control: CGPoint(x: pt.x, y: pt.y + 2))
            ctx.stroke(s, with: .color(PinePal.barkPlate.opacity(0.45 * lc)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        ctx.fill(ellipse(baseX - baseW * 0.25, baseY - 4, 2 + lc, 2 + lc), with: .color(PinePal.barkMoss.opacity(0.4 * lc)))
        ctx.fill(ellipse(baseX + baseW * 0.18, baseY - 2, 1.6 + lc, 1.6 + lc), with: .color(PinePal.barkMoss.opacity(0.32 * lc)))
    }
}

private func pineNeedlePair(_ ctx: inout GraphicsContext, x: Double, y: Double, s: Double,
                            rotDeg: Double, color: Color, opacity: Double) {
    var g = ctx
    g.translateBy(x: x, y: y)
    g.rotate(by: .degrees(rotDeg))
    let st = StrokeStyle(lineWidth: 1.5, lineCap: .round)
    var a = Path(); a.move(to: .zero); a.addLine(to: CGPoint(x: -s * 0.3, y: s))
    var b = Path(); b.move(to: .zero); b.addLine(to: CGPoint(x: s * 0.3, y: s))
    g.stroke(a, with: .color(color.opacity(opacity)), style: st)
    g.stroke(b, with: .color(color.opacity(opacity)), style: st)
}

func drawPine(day rawDay: Int, in ctx: inout GraphicsContext) {
    let day = max(0, min(365, rawDay))
    let c = pineCanopy(day)

    drawPinePot(&ctx)
    drawPineTrunk(day: day, c: c, in: &ctx)

    func padCentre(_ p: PinePad, _ e: Double) -> (x: Double, y: Double, w: Double, h: Double) {
        let y = lerp(c.baseY, c.topY, p.hFrac)
        let leanAtH = lerp(0, c.topX - c.baseX, p.hFrac)
        let padW = (10 + 78 * c.g) * p.wFrac
        let x = c.baseX + leanAtH + p.side * p.reach * padW * 0.65 * e
        let w = padW * (0.5 + 0.5 * e)
        return (x, y, w, w * 0.42)
    }

    struct PadLive { let p: PinePad; let e, x, y, w, h: Double }
    var live: [PadLive] = []
    for p in pinePads {
        let e = p.app == 0 ? 1.0 : smoothstepS(p.app, p.app + p.span, Double(day))
        if e < 0.02 { continue }
        let cc = padCentre(p, e)
        live.append(PadLive(p: p, e: e, x: cc.x, y: cc.y, w: cc.w, h: cc.h))
    }

    for it in live.sorted(by: { $0.y > $1.y }) where it.p.app != 0 {
        let leanAtH = lerp(0, c.topX - c.baseX, it.p.hFrac)
        let sx = c.baseX + leanAtH
        let w = max(1.8, c.baseW * 0.16 * (0.5 + 0.5 * it.e))
        var b = Path()
        b.move(to: CGPoint(x: sx, y: it.y + 2))
        b.addQuadCurve(to: CGPoint(x: it.x, y: it.y), control: CGPoint(x: (sx + it.x) / 2, y: it.y + 4))
        ctx.stroke(b, with: .color(PinePal.barkDeep), style: StrokeStyle(lineWidth: w, lineCap: .round))
    }

    struct NItem { var x, y, w, h, seed: Double; var light: Bool }
    var items: [NItem] = live.map { NItem(x: $0.x, y: $0.y, w: $0.w, h: $0.h, seed: $0.p.seed, light: false) }
    if !live.isEmpty {
        for T in pineTufts {
            let e = smoothstepS(T.app, T.app + T.span, Double(day))
            if e < 0.02 { continue }
            let host = live[Int(floor(T.padU * Double(live.count))) % live.count]
            let ex = 0.4 + 0.6 * e
            let x = host.x + T.fx * host.w * ex
            let y = host.y + T.fy * host.h
            let w = host.w * T.sz * (0.6 + 0.4 * e)
            items.append(NItem(x: x, y: y, w: w, h: w * 0.5, seed: T.seed, light: true))
        }
    }
    for it in items.sorted(by: { $0.y < $1.y }) {
        let clumps = it.light ? 0 : 4
        let lights = it.light ? 1 : 3
        needleCluster(&ctx, cx: it.x, cy: it.y, w: it.w, h: it.h, seed: it.seed * 5 + 2,
                      noise: 0.32, clumps: clumps, lights: lights, sat: 1, opacity: 1)
    }

    let cand = pineCandle(day)
    if cand > 0.06 && c.g > 0.3 {
        for it in live where Int(it.p.seed) % 2 == 0 {
            for k in 0..<2 {
                let cx = it.x + (rand01(it.p.seed * 3, Double(k + 1)) - 0.5) * it.w * 1.2
                let cy = it.y - it.h * 0.7 - 3 * cand
                var s = Path()
                s.move(to: CGPoint(x: cx, y: cy))
                s.addLine(to: CGPoint(x: cx, y: cy - 5 * cand))
                ctx.stroke(s, with: .color(PinePal.candle.opacity(0.6 * cand)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    let amt = pineNeedle(day)
    if amt >= 0.02 {
        let n = Int((amt * 22).rounded())
        for i in 0..<n {
            let h1 = rand01(71, Double(i + 1)), h2 = rand01(89, Double(i + 3)), h3 = rand01(53, Double(i))
            let fill = h3 > 0.5 ? PinePal.needMid : PinePal.needDeep
            pineNeedlePair(&ctx, x: 300 + (h1 - 0.5) * 140, y: 408 + h2 * 6, s: 4 + h3 * 3,
                           rotDeg: (h1 - 0.5) * 160, color: fill, opacity: 0.7)
        }
    }
}

func pineContentRect(day: Int) -> CGRect {
    let d = min(365, max(0, day))
    let c = pineCanopy(d)
    var minX = 186.0, maxX = 414.0
    var minY = 410.0
    let maxY = 460.0
    for p in pinePads {
        let e = p.app == 0 ? 1.0 : smoothstepS(p.app, p.app + p.span, Double(d))
        if e < 0.02 { continue }
        let y = lerp(c.baseY, c.topY, p.hFrac)
        let leanAtH = lerp(0, c.topX - c.baseX, p.hFrac)
        let padW = (10 + 78 * c.g) * p.wFrac
        let x = c.baseX + leanAtH + p.side * p.reach * padW * 0.65 * e
        let w = padW * (0.5 + 0.5 * e)
        let h = w * 0.42
        minX = min(minX, x - w); maxX = max(maxX, x + w)
        minY = min(minY, y - h * 1.6)
    }
    minY = min(minY, c.topY - 10)
    var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    let minDim = 230.0
    if rect.width < minDim { rect = rect.insetBy(dx: -(minDim - rect.width) / 2, dy: 0) }
    if rect.height < minDim { rect = rect.insetBy(dx: 0, dy: -(minDim - rect.height) / 2) }
    return rect
}

// MARK: - Content bounds (for fill rendering)

/// Tight bounding box, in the 600×600 design space, of the drawn bonsai for a
/// given day/style. `BonsaiView(fill:)` uses this to zoom the canvas onto the
/// plant so it fills its frame instead of swimming in the 600pt square — the
/// silhouette otherwise only occupies the middle ~45% of the canvas.
func bonsaiContentRect(day: Int, style: BonsaiStyle) -> CGRect {
    if style == .sakura { return sakuraContentRect(day: day) }
    if style == .maple { return mapleContentRect(day: day) }
    if style == .pine { return pineContentRect(day: day) }
    let d = min(365, max(0, day))
    var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
    func include(_ x: Double, _ y: Double) {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }

    // Pot footprint is always part of the silhouette.
    if style == .cascade {
        include(218, 360); include(382, 462)
    } else {
        include(170, 380); include(430, 464)
    }

    if d <= 7 {
        // Sprout: a small region just above the soil. Bounded so a single
        // stem doesn't zoom to absurd magnification.
        let baseY: Double = style == .cascade ? 378 : 410
        include(250, baseY - 92); include(350, baseY + 6)
    } else {
        let p = paramsForDay(d, style: style)
        let tr = buildTrunk(p, style: style)
        let tb = tr.path.boundingRect
        include(tb.minX, tb.minY); include(tb.maxX, tb.maxY)
        for c in p.clusters {
            let base = clusterCenter(c, trunk: tr, reach: p.reach)
            let r = c.size * 1.18   // blob radius ≈ size, plus a little slack
            include(base.x - r, base.y - r); include(base.x + r, base.y + r)
        }
    }

    var rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    // Floor on each dimension so young plants don't over-zoom.
    let minDim = 230.0
    if rect.width < minDim { rect = rect.insetBy(dx: -(minDim - rect.width) / 2, dy: 0) }
    if rect.height < minDim { rect = rect.insetBy(dx: 0, dy: -(minDim - rect.height) / 2) }
    return rect
}

// MARK: - Public View

struct BonsaiView: View {
    let day: Int
    let style: BonsaiStyle
    let vitality: Double
    /// When true, zoom and bottom-anchor the canvas onto the plant so it fills
    /// the frame (pot resting at the bottom edge) instead of being centered in
    /// the 600pt design square with empty margins. Used for the home
    /// centerpiece so the tree commands the garden real estate.
    var fill: Bool = false

    var body: some View {
        Canvas { context, size in
            let rect = fill ? bonsaiContentRect(day: day, style: style)
                            : CGRect(x: 0, y: 0, width: 600, height: 600)
            let pad = fill ? 1.04 : 1.0
            let scale = min(size.width / (rect.width * pad),
                            size.height / (rect.height * pad))
            let drawnW = rect.width * scale
            let drawnH = rect.height * scale
            var ctx = context
            // Center horizontally; center (default) or bottom-anchor (fill) the
            // focus rect inside the frame.
            let offX = (size.width - drawnW) / 2 - rect.minX * scale
            let offY = fill
                ? (size.height - drawnH) - rect.minY * scale
                : (size.height - drawnH) / 2 - rect.minY * scale
            ctx.translateBy(x: offX, y: offY)
            ctx.scaleBy(x: scale, y: scale)

            if style == .sakura {
                drawSakura(day: day, in: &ctx)
                return
            }
            if style == .maple {
                drawMaple(day: day, in: &ctx)
                return
            }
            if style == .pine {
                drawPine(day: day, in: &ctx)
                return
            }

            drawPot(style: style, in: &ctx)

            if day <= 7 {
                drawRootsAndMoss(paramsForDay(day, style: style), style: style, in: &ctx)
                drawEarly(max(0, day), style: style, in: &ctx)
                return
            }

            let p = paramsForDay(min(365, day), style: style)
            drawRootsAndMoss(p, style: style, in: &ctx)
            let tr = buildTrunk(p, style: style)

            for (b, w, c, op) in tr.bareBranches {
                ctx.stroke(b, with: .color(c.opacity(op)),
                           style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
            for (b, w) in tr.branches {
                ctx.stroke(b, with: .color(Pal.barkMid),
                           style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
            let trunkRect = tr.path.boundingRect
            ctx.fill(tr.path, with: .linearGradient(
                Gradient(colors: [Pal.barkLight, Pal.barkMid, Pal.barkDeep]),
                startPoint: CGPoint(x: trunkRect.minX, y: 300),
                endPoint: CGPoint(x: trunkRect.maxX, y: 300)))
            for (gp, op) in tr.gnarl {
                ctx.fill(gp, with: .color(Pal.barkDeep.opacity(op)))
            }

            let satFactor = 0.7 + 0.3 * max(0, min(1, vitality))
            for c in p.clusters {
                let base = clusterCenter(c, trunk: tr, reach: p.reach)
                draw(cluster: base.x, base.y, size: c.size,
                     tone: c.tone, saturation: p.leafSaturation * c.sat * satFactor,
                     seed: c.seed, in: &ctx)
            }
        }
        .accessibilityLabel(Text("Bonsai, day \(day)"))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 8) {
            ForEach([BonsaiStyle.traditional, .cascade, .windswept, .sakura, .maple, .pine], id: \.self) { s in
                Text(s.displayName).font(Theme.caption(weight: .bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
                    ForEach([0, 1, 3, 5, 7, 10, 14, 21, 30, 60, 90, 180, 365], id: \.self) { d in
                        VStack(spacing: 2) {
                            BonsaiView(day: d, style: s, vitality: 1)
                                .frame(width: 80, height: 80)
                                .background(Color(hex: 0xEBF5DB))
                            Text("d\(d)").font(Theme.caption())
                        }
                    }
                }
            }
        }.padding()
    }
}
