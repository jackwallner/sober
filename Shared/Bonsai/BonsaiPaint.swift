import SwiftUI

// Painting helpers shared by every bonsai style, in the 600×600 design space.
// Light comes from the upper left. Foliage and wood are opaque layers, never
// alpha stacks, so overlapping pads read as distinct pads and a thirsty tree
// turns olive instead of see-through.

/// A color that can be mixed, which `Color` can't do portably.
struct RGB {
    var r, g, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    var color: Color { Color(red: r, green: g, blue: b) }

    func mix(_ o: RGB, _ t: Double) -> RGB {
        RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    /// Toward a dull olive, for a garden that hasn't been tended.
    func dried(_ t: Double) -> RGB {
        guard t > 0 else { return self }
        let l = 0.30 * r + 0.59 * g + 0.11 * b
        return mix(RGB(r: l, g: l, b: l).mix(RGB(0xA39A6E), 0.55), t)
    }
}

/// Four foliage tones, dark underside to sunlit tips.
struct FoliageInk { var shadow, mid, light, hi: RGB }

// MARK: - Foliage pads

/// A cloud of round lobes around an elliptical core: the scalloped edge of a
/// foliage pad. `flat` (0...1) shrinks the lower lobes for a flat-bottomed pad.
func lobedPath(cx: Double, cy: Double, rx: Double, ry: Double,
               seed: Double, flat: Double = 0) -> Path {
    var p = Path(ellipseIn: CGRect(x: cx - rx * 0.8, y: cy - ry * 0.8, width: rx * 1.6, height: ry * 1.6))
    let lobeR = 0.27 * (rx + ry) / 2
    let n = max(8, min(24, Int((Double.pi * (rx + ry) / (lobeR * 1.1)).rounded())))
    for i in 0..<n {
        let a = (Double(i) + 0.8 * bonsaiNoise(seed, Double(i * 3 + 1))) / Double(n) * 2 * .pi
        let below = max(0, sin(a))
        let rr = lobeR * (0.55 + 0.9 * bonsaiNoise(seed, Double(i * 3 + 2))) * (1 - 0.45 * flat * below)
        let px = cx + cos(a) * rx * 0.78
        let py = cy + sin(a) * ry * 0.78 * (1 - 0.35 * flat * below)
        p.addEllipse(in: CGRect(x: px - rr, y: py - rr, width: rr * 2, height: rr * 2))
    }
    return p
}

/// One foliage pad: dark silhouette, a mid body lifted off its underside, a
/// sunlit crown, and a few bright tips. `detail` 0 is a small tuft (no tips).
func paintPad(_ ctx: inout GraphicsContext, cx: Double, cy: Double, rx: Double, ry: Double,
              seed: Double, ink: FoliageInk, dry: Double = 0, detail: Int = 1, flat: Double = 0) {
    let shadow = ink.shadow.dried(dry).color, mid = ink.mid.dried(dry).color
    let light = ink.light.dried(dry).color, hi = ink.hi.dried(dry).color

    let outline = lobedPath(cx: cx, cy: cy, rx: rx, ry: ry, seed: seed, flat: flat)
    ctx.fill(outline, with: .color(shadow))

    var body = ctx
    body.clip(to: outline)
    let bodyPath = lobedPath(cx: cx - rx * 0.04, cy: cy - ry * (0.14 + 0.08 * flat),
                             rx: rx * 0.9, ry: ry * 0.84, seed: seed, flat: flat)
    body.fill(bodyPath, with: .color(mid))

    var lit = body
    lit.clip(to: bodyPath)
    let litPath = lobedPath(cx: cx - rx * 0.2, cy: cy - ry * 0.42,
                            rx: rx * 0.58, ry: ry * 0.44, seed: seed + 3, flat: flat)
    lit.fill(litPath, with: .color(light))

    guard detail > 0 else { return }
    // Sunlit flecks along the crown.
    let r0 = (rx + ry) / 2
    for i in 0..<7 {
        let u = bonsaiNoise(seed, Double(40 + i)), v = bonsaiNoise(seed, Double(50 + i))
        let x = cx - rx * (0.62 - 0.85 * u), y = cy - ry * (0.78 - 0.42 * v)
        let r = r0 * (0.035 + 0.035 * bonsaiNoise(seed, Double(60 + i)))
        lit.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6)), with: .color(hi))
    }
}

/// Deterministic noise in 0..<1 (the renderer's `rand01`).
func bonsaiNoise(_ seed: Double, _ n: Double) -> Double {
    let v = sin(seed * 12.9898 + n * 78.233) * 43758.5453
    return v - v.rounded(.down)
}

// MARK: - Wood

/// A smooth tapered limb through `pts` (Catmull-Rom), `widths` per point. The
/// base end is cut square (it sits in soil or a trunk); the tip is rounded.
func woodRibbon(through pts: [CGPoint], widths: [Double], perSegment: Int = 8) -> Path {
    guard pts.count >= 2 else { return Path() }
    let (spine, ws) = smoothSpine(through: pts, widths: widths, perSegment: perSegment)
    return ribbon(spine: spine, widths: ws)
}

/// The centre line `woodRibbon` draws, densely sampled, with its widths.
func smoothSpine(through pts: [CGPoint], widths: [Double], perSegment: Int = 8) -> ([CGPoint], [Double]) {
    var spine: [CGPoint] = [], ws: [Double] = []
    for i in 0..<(pts.count - 1) {
        let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
        for s in 0..<perSegment {
            let t = Double(s) / Double(perSegment)
            spine.append(catmull(p0, p1, p2, p3, t))
            ws.append(widths[i] + (widths[i + 1] - widths[i]) * t)
        }
    }
    spine.append(pts[pts.count - 1]); ws.append(widths[widths.count - 1])
    return (spine, ws)
}

/// A limb along one quadratic curve, tapering from `w0` to `w1`.
func boughPath(from p0: CGPoint, control c: CGPoint, to p1: CGPoint, w0: Double, w1: Double) -> Path {
    var spine: [CGPoint] = [], ws: [Double] = []
    let n = 10
    for i in 0...n {
        let t = Double(i) / Double(n), u = 1 - t
        spine.append(CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                             y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y))
        ws.append(w0 + (w1 - w0) * t)
    }
    return ribbon(spine: spine, widths: ws)
}

private func catmull(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
    let t2 = t * t, t3 = t2 * t
    func f(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
    }
    return CGPoint(x: f(p0.x, p1.x, p2.x, p3.x), y: f(p0.y, p1.y, p2.y, p3.y))
}

private func ribbon(spine: [CGPoint], widths: [Double]) -> Path {
    var left: [CGPoint] = [], right: [CGPoint] = []
    for i in spine.indices {
        let a = spine[max(0, i - 1)], b = spine[min(spine.count - 1, i + 1)]
        let len = max(1e-6, hypot(b.x - a.x, b.y - a.y))
        let nx = -(b.y - a.y) / len, ny = (b.x - a.x) / len
        let w = widths[i] / 2
        left.append(CGPoint(x: spine[i].x + nx * w, y: spine[i].y + ny * w))
        right.append(CGPoint(x: spine[i].x - nx * w, y: spine[i].y - ny * w))
    }
    var p = Path()
    p.move(to: left[0])
    for pt in left.dropFirst() { p.addLine(to: pt) }
    // Rounded tip: half a circle from the left edge round to the right one.
    let n = spine.count - 1, tip = spine[n], r = widths[n] / 2
    let a0 = atan2(left[n].y - tip.y, left[n].x - tip.x)
    let ahead = atan2(tip.y - spine[n - 1].y, tip.x - spine[n - 1].x)
    let sweep = (ahead - a0).remainder(dividingBy: 2 * .pi) > 0 ? Double.pi : -Double.pi
    for k in 1..<6 {
        let a = a0 + sweep * Double(k) / 6
        p.addLine(to: CGPoint(x: tip.x + cos(a) * r, y: tip.y + sin(a) * r))
    }
    for pt in right.reversed() { p.addLine(to: pt) }
    p.closeSubpath()
    return p
}

/// Rounds a trunk or limb: a shadowed right flank, a lit left flank, and bark
/// fissures that follow its outline. `grain` (0...1) is how weathered it is.
func shadeWood(_ ctx: inout GraphicsContext, _ path: Path, width: Double,
               dark: Color, light: Color, grain: Double = 0, grainColor: Color? = nil) {
    var g = ctx
    g.clip(to: path)
    // Two soft steps on each flank approximate a curved surface.
    for (k, op) in [(0.44, 0.3), (0.24, 0.32)] {
        var s = g
        s.clip(to: path.offsetBy(dx: -width * k, dy: -width * k * 0.15), options: .inverse)
        s.fill(path, with: .color(dark.opacity(op)))
    }
    for (k, op) in [(0.3, 0.22), (0.14, 0.26)] {
        var l = g
        l.clip(to: path.offsetBy(dx: width * k, dy: 0), options: .inverse)
        l.fill(path, with: .color(light.opacity(op)))
    }
    guard grain > 0.02, let grainColor else { return }
    let lw = max(0.8, width * 0.035)
    for k in [0.2, -0.36] {
        g.stroke(path.offsetBy(dx: width * k, dy: 0), with: .color(grainColor.opacity(0.28 * grain)),
                 style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}

/// The root flare where a trunk of width `w` meets the soil at (x, y).
func nebariPath(x: Double, y: Double, w: Double, spread: Double) -> Path {
    // The top sits inside the trunk, so only the concave flanks show.
    let f = w * 0.34 * spread, h = w * 0.55
    var p = Path()
    p.move(to: CGPoint(x: x - w / 2 - f, y: y + 1.5))
    p.addQuadCurve(to: CGPoint(x: x - w * 0.25, y: y - h), control: CGPoint(x: x - w * 0.42, y: y - h * 0.15))
    p.addLine(to: CGPoint(x: x + w * 0.25, y: y - h))
    p.addQuadCurve(to: CGPoint(x: x + w / 2 + f, y: y + 1.5), control: CGPoint(x: x + w * 0.42, y: y - h * 0.15))
    p.closeSubpath()
    return p
}

// MARK: - Soil and pot

private let mossDark = RGB(0x4F6436).color, mossMid = RGB(0x6E874A).color

/// Cushions of moss on the soil around a trunk, filling in as `amount` grows.
func paintSoilMoss(_ ctx: inout GraphicsContext, cx: Double, y: Double, spread: Double,
                   amount: Double, seed: Double) {
    guard amount > 0.02 else { return }
    // Each cushion is a few small domes sunk into the soil.
    let n = Int((2 + 5 * amount).rounded())
    for i in 0..<n {
        let u = bonsaiNoise(seed, Double(i * 2 + 1)), v = bonsaiNoise(seed, Double(i * 2 + 2))
        let x = cx + (u - 0.5) * 2 * spread * (0.35 + 0.65 * amount)
        let yy = y + 1 + (v - 0.5) * 2
        var g = ctx
        g.clip(to: Path(CGRect(x: x - 20, y: yy - 12, width: 40, height: 12.5)))
        for k in 0..<3 {
            let r = (2.2 + 2.4 * bonsaiNoise(seed, Double(i * 5 + k + 20))) * (0.6 + 0.4 * amount)
            let dx = (Double(k) - 1) * r * 1.3
            g.fill(Path(ellipseIn: CGRect(x: x + dx - r, y: yy - r * 0.8, width: r * 2, height: r * 1.6)),
                   with: .color(mossDark))
            g.fill(Path(ellipseIn: CGRect(x: x + dx - r * 0.75, y: yy - r * 0.85, width: r * 1.3, height: r * 1.0)),
                   with: .color(mossMid))
        }
    }
}

/// Two short feet under a pot whose base runs from `left` to `right` at `y`.
func paintPotFeet(_ ctx: inout GraphicsContext, left: Double, right: Double, y: Double, color: Color) {
    let w = min(22, (right - left) * 0.11), h = 4.5, inset = (right - left) * 0.09
    for x in [left + inset, right - inset - w] {
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y - 1, width: w, height: h + 1), cornerRadius: 1.5),
                 with: .color(color))
    }
}
