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
    var size: Double
    var tone: Tone = .sage
    var sat: Double = 1
    var seed: Double
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
    return TrunkResult(path: path, branches: branches, bareBranches: [], gnarl: gnarl, attach: attach)
}

private func trunkCascade(_ p: Params) -> TrunkResult {
    let baseX = 300.0, baseY = 378.0
    let fallPx = 30 + 130 * p.trunkHeight
    let upPx = 10 + 30 * p.trunkHeight
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

    var branches: [(Path, Double)] = []
    if p.trunkThickness > 0.45 {
        var b1 = Path()
        b1.move(to: CGPoint(x: p2.x, y: p2.y + 6))
        b1.addQuadCurve(to: CGPoint(x: p2.x - 44, y: p2.y + 52), control: CGPoint(x: p2.x - 22, y: p2.y + 30))
        branches.append((b1, max(2.6, baseW * 0.14)))
        let midPt = CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2)
        var b2 = Path()
        b2.move(to: midPt)
        b2.addQuadCurve(to: CGPoint(x: midPt.x - 56, y: midPt.y + 28), control: CGPoint(x: midPt.x - 26, y: midPt.y + 18))
        branches.append((b2, max(2.4, baseW * 0.12)))
    }

    let midPt = CGPoint(x: (p2.x + p3.x) / 2, y: (p2.y + p3.y) / 2)
    let attach: [Attach: CGPoint] = [
        .crown:      CGPoint(x: p1.x - 2, y: p1.y - 12),
        .upperLeft:  CGPoint(x: p2.x - 44, y: p2.y + 52 - 8),
        .upperRight: CGPoint(x: midPt.x - 56, y: midPt.y + 28 - 8),
        .midLeft:    CGPoint(x: p3.x - 12, y: p3.y - 22),
        .midRight:   CGPoint(x: p3.x + 14, y: p3.y - 10),
        .lowerRight: CGPoint(x: p3.x - 6, y: p3.y + 10),
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

    // Bare windward (left) branches
    var bare: [(Path, Double, Color, Double)] = []
    if p.trunkThickness > 0.35 {
        let bareSize = max(2, baseW * 0.12)
        var b1 = Path()
        b1.move(to: CGPoint(x: (baseX + midX) / 2, y: (baseY + midY) / 2))
        b1.addQuadCurve(to: CGPoint(x: baseX - 44, y: baseY - 92), control: CGPoint(x: baseX - 18, y: baseY - 80))
        bare.append((b1, bareSize, Pal.barkMid, 1))
        var b2 = Path()
        b2.move(to: CGPoint(x: midX - 4, y: midY + 4))
        b2.addQuadCurve(to: CGPoint(x: midX - 56, y: midY - 28), control: CGPoint(x: midX - 30, y: midY - 18))
        bare.append((b2, bareSize * 0.85, Pal.barkDeep, 0.85))
        var b3 = Path()
        b3.move(to: CGPoint(x: midX - 18, y: midY - 4))
        b3.addQuadCurve(to: CGPoint(x: midX - 60, y: midY - 2), control: CGPoint(x: midX - 40, y: midY - 6))
        bare.append((b3, bareSize * 0.7, Pal.barkMid, 1))
    }

    // Leeward (right) heavy branches into the foliage
    var branches: [(Path, Double)] = []
    if p.trunkThickness > 0.4 {
        var b1 = Path()
        b1.move(to: CGPoint(x: midX + 2, y: midY - 2))
        b1.addQuadCurve(to: CGPoint(x: midX + 48, y: midY - 28), control: CGPoint(x: midX + 26, y: midY - 14))
        branches.append((b1, max(3, baseW * 0.18)))
        var b2 = Path()
        b2.move(to: CGPoint(x: tipX - 6, y: tipY + 6))
        b2.addQuadCurve(to: CGPoint(x: tipX + 42, y: tipY - 14), control: CGPoint(x: tipX + 18, y: tipY - 4))
        branches.append((b2, max(2.6, baseW * 0.14)))
    }

    let attach: [Attach: CGPoint] = [
        .crown:      CGPoint(x: tipX + 24, y: tipY - 10),
        .upperLeft:  CGPoint(x: tipX + 14, y: tipY + 4),
        .upperRight: CGPoint(x: tipX + 56, y: tipY),
        .midLeft:    CGPoint(x: midX + 24, y: midY - 16),
        .midRight:   CGPoint(x: midX + 56, y: midY - 12),
        .lowerRight: CGPoint(x: midX + 70, y: midY + 14),
    ]
    return TrunkResult(path: path, branches: branches, bareBranches: bare, gnarl: gnarl, attach: attach)
}

private func buildTrunk(_ p: Params, style: BonsaiStyle) -> TrunkResult {
    switch style {
    case .cascade:    return trunkCascade(p)
    case .windswept:  return trunkWindswept(p)
    case .traditional: return trunkTraditional(p)
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
    let trunkHeight = lerp(0.20, 0.86, e)
    let trunkThickness = lerp(0.18, style == .cascade ? 0.82 : 0.90, e)
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
    if day >= 90 {
        clusters.append(ClusterSpec(attach: nil, cx: 300, cy: 210,
            size: (sizeBase * 0.42).rounded(), tone: .fresh, seed: 7))
    }
    if day >= 180 {
        clusters.append(ClusterSpec(attach: nil, cx: 380, cy: 296,
            size: (sizeBase * 0.28).rounded(), tone: .autumn, sat: 0.8, seed: 8))
    }
    if day >= 270 {
        clusters.append(ClusterSpec(attach: nil, cx: 232, cy: 262,
            size: (sizeBase * 0.28).rounded(), tone: .autumn, sat: 0.75, seed: 9))
    }

    return Params(day: day,
                  trunkHeight: trunkHeight, trunkThickness: trunkThickness, trunkGnarl: trunkGnarl,
                  leafSaturation: leafSaturation, mossOnTrunk: mossOnTrunk, exposedRoots: exposedRoots,
                  clusters: clusters)
}

// MARK: - Early stages (days 0–7) — bespoke per JS renderEarly

private func drawEarly(_ day: Int, style: BonsaiStyle, in ctx: inout GraphicsContext) {
    let baseY: Double = style == .cascade ? 378 : 410
    let cx = 300.0
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

// MARK: - Content bounds (for fill rendering)

/// Tight bounding box, in the 600×600 design space, of the drawn bonsai for a
/// given day/style. `BonsaiView(fill:)` uses this to zoom the canvas onto the
/// plant so it fills its frame instead of swimming in the 600pt square — the
/// silhouette otherwise only occupies the middle ~45% of the canvas.
func bonsaiContentRect(day: Int, style: BonsaiStyle) -> CGRect {
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
            let base = c.attach.flatMap { tr.attach[$0] } ?? CGPoint(x: c.cx, y: c.cy)
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
                let base: CGPoint = c.attach.flatMap { tr.attach[$0] } ?? CGPoint(x: c.cx, y: c.cy)
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
            ForEach([BonsaiStyle.traditional, .cascade, .windswept], id: \.self) { s in
                Text(s.displayName).font(.caption.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
                    ForEach([0, 1, 3, 5, 7, 10, 14, 21, 30, 60, 90, 180, 365], id: \.self) { d in
                        VStack(spacing: 2) {
                            BonsaiView(day: d, style: s, vitality: 1)
                                .frame(width: 80, height: 80)
                                .background(Color(hex: 0xEBF5DB))
                            Text("d\(d)").font(.caption2)
                        }
                    }
                }
            }
        }.padding()
    }
}
