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
func paintPad(_ ctx: inout BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
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

// MARK: - Maple and pine pads
//
// Both are built from straight-edged outlines that nest inside one another
// (`nested`), so each layer paints straight over the last with no clip.

/// A maple pad: a heap of small palmate leaves, each turned out from the
/// middle so the rim reads as lobed leaves. The lower leaves are laid down
/// first and the upper ones over them, every leaf drawn a little in from its
/// own dark edge so the leaves stand apart; the ones up and to the left catch
/// the light. `detail` 0 is a few three-lobed leaves, 1 is more leaves with
/// five lobes, 2 serrates every lobe.
func paintPalmatePad(_ ctx: inout BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
                     seed: Double, ink: FoliageInk, detail: Int, flat: Double = 0.35) {
    func at(_ u: Double, _ v: Double) -> CGPoint {
        CGPoint(x: cx + u * rx, y: cy + v * ry * (v > 0 ? 1 - 0.3 * flat : 1))
    }
    struct Leaf { var outline: [CGPoint]; var heart: CGPoint; var light: Double; var low: Bool }
    let rings: [(r: Double, n: Int)] = detail == 0 ? [(0.58, 7)] : [(0.68, 10), (0.34, 6)]
    let phase = bonsaiNoise(seed, 1) * 2 * .pi
    var slots: [(u: Double, v: Double, axis: Double)] = [(0, -0.06, -Double.pi / 2)]
    for (ring, (r, n)) in rings.enumerated() {
        for j in 0..<n {
            let k = Double(ring * 16 + j)
            let a = phase + (Double(j) + 0.5 * Double(ring) + 0.3 * (bonsaiNoise(seed, 10 + k) - 0.5))
                * 2 * .pi / Double(n)
            slots.append((cos(a) * r, sin(a) * r, a))
        }
    }
    var leaves: [Leaf] = []
    for (i, s) in slots.enumerated() {
        let k = Double(i)
        let axis = s.axis + 0.6 * (bonsaiNoise(seed, 40 + k) - 0.5)
        let len = (detail == 0 ? 0.7 : 0.62) * (0.9 + 0.2 * bonsaiNoise(seed, 50 + k))
        let unit = palmateLeaf(stalk: CGPoint(x: s.u - cos(axis) * len * 0.22, y: s.v - sin(axis) * len * 0.22),
                               axis: axis, length: len, lobes: detail == 0 ? 3 : 5, serrate: detail > 1)
        leaves.append(Leaf(outline: unit.map { at($0.x, $0.y) }, heart: at(s.u, s.v),
                           light: -0.55 * s.u - 0.83 * s.v, low: s.v > 0.45))
    }
    // Lowest first, so the upper leaves lie over them.
    leaves.sort { $0.heart.y > $1.heart.y }
    let core = (0..<24).map { at(cos(Double($0) * .pi / 12) * 0.5, sin(Double($0) * .pi / 12) * 0.5) }
    let split = leaves.count / 2
    for (tier, group) in [leaves[..<split], leaves[split...]].enumerated() {
        var dark = Path(), mid = Path(), lit = Path()
        // Under the leaves, a mass in the body colour, so the gaps between
        // them never open onto the sky.
        if tier == 0 { mid.addPath(polygon(core)) }
        for leaf in group {
            dark.addPath(polygon(leaf.outline))
            // A leaf fans out round its heart, so shrinking it there keeps it inside.
            let face = polygon(scaled(leaf.outline, about: leaf.heart, by: leaf.low ? 0.72 : 0.84))
            if leaf.light > -0.05 { lit.addPath(face) } else { mid.addPath(face) }
        }
        ctx.fill(dark, with: .color(ink.shadow.color))
        ctx.fill(mid, with: .color(ink.mid.color))
        ctx.fill(lit, with: .color(ink.light.color))
    }
    guard detail > 0 else { return }
    // The highest leaves on the crown, sunlit at their hearts.
    var hi = Path()
    for leaf in leaves.suffix(6) where leaf.light > 0.3 {
        hi.addPath(polygon(scaled(leaf.outline, about: leaf.heart, by: 0.5)))
    }
    ctx.fill(hi, with: .color(ink.hi.color))
}

/// One palmate leaf with its stalk at `stalk` and middle lobe along `axis`:
/// broad lobes narrowing to points, the outer pair swept back. Saw-toothed
/// along every lobe edge when `serrate`.
private func palmateLeaf(stalk: CGPoint, axis: Double, length: Double, lobes: Int,
                         serrate: Bool) -> [CGPoint] {
    let fan: [Double] = lobes == 5 ? [-1.25, -0.62, 0, 0.62, 1.25] : [-0.7, 0, 0.7]
    let reach: [Double] = lobes == 5 ? [0.56, 0.86, 1, 0.86, 0.56] : [0.76, 1, 0.76]
    let half = lobes == 5 ? 0.21 : 0.3
    func out(_ a: Double, _ l: Double) -> CGPoint {
        CGPoint(x: stalk.x + cos(a) * l, y: stalk.y + sin(a) * l)
    }
    var pts = [stalk]
    /// Teeth along a lobe edge from `a` to `b`, leaning toward the lobe tip.
    func edge(_ a: CGPoint, _ b: CGPoint, towardEnd: Bool) {
        guard serrate else { return }
        let ex = b.x - a.x, ey = b.y - a.y
        for t in [0.3, 0.64] {
            let base = CGPoint(x: a.x + ex * t, y: a.y + ey * t)
            let tt = towardEnd ? t + 0.14 : t - 0.14
            let tooth = CGPoint(x: a.x + ex * tt + ey * 0.07, y: a.y + ey * tt - ex * 0.07)
            pts.append(contentsOf: towardEnd ? [base, tooth] : [tooth, base])
        }
    }
    for k in fan.indices {
        let a = axis + fan[k], l = length * reach[k]
        if k > 0 { pts.append(out(axis + (fan[k - 1] + fan[k]) / 2, length * 0.36)) }
        let s0 = out(a - half, l * 0.58), tip = out(a, l), s1 = out(a + half, l * 0.58)
        pts.append(s0)
        edge(s0, tip, towardEnd: true)
        pts.append(tip)
        edge(tip, s1, towardEnd: false)
        pts.append(s1)
    }
    return pts
}

/// A pine pad: a low cloud of needles fanning out of the twig beneath it,
/// built as three tiers, each a fringe of needle tips. The dark tier is
/// fringed all round, long over the crown and short along the flat underside;
/// the mid and lit tiers sit higher and smaller, fringed along their tops, so
/// the underside stays dark and the crown's needles catch the light at its
/// top edge. `detail` 0 is a coarse fringe, 1 finer, 2 finest with lit tips.
func paintNeedlePad(_ ctx: inout BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
                    seed: Double, ink: FoliageInk, detail: Int, flat: Double = 0.85) {
    let hub = CGPoint(x: cx, y: cy + ry * 0.7)
    let tufts = detail == 0 ? 36 : (detail == 1 ? 70 : 120)
    let rim = needleRim(cx: cx, cy: cy, rx: rx, ry: ry, seed: seed, tufts: tufts, hub: hub,
                        flat: flat, topOnly: false)
    ctx.fill(polygon(rim), with: .color(ink.shadow.color))

    let bodyO = CGPoint(x: cx, y: cy - ry * 0.2)
    let body = nested(needleRim(cx: cx, cy: bodyO.y, rx: rx * 0.9, ry: ry * 0.72, seed: seed + 1,
                                tufts: tufts, hub: hub, flat: flat, topOnly: true),
                      toward: bodyO, in: rim)
    ctx.fill(polygon(body), with: .color(ink.mid.color))
    if detail > 0 { rakeNeedles(&ctx, from: hub, over: body, around: bodyO, seed: seed, color: ink.light.color, fans: detail == 1 ? 8 : 18) }

    let litO = CGPoint(x: cx - rx * 0.1, y: cy - ry * 0.44)
    let lit = nested(needleRim(cx: litO.x, cy: litO.y, rx: rx * 0.72, ry: ry * 0.44, seed: seed + 2,
                               tufts: tufts * 3 / 4, hub: hub, flat: flat, topOnly: true),
                     toward: litO, in: body)
    ctx.fill(polygon(lit), with: .color(ink.light.color))
    if detail > 0 { rakeNeedles(&ctx, from: hub, over: lit, around: litO, seed: seed + 7, color: ink.hi.color, fans: detail == 1 ? 5 : 12) }
    guard detail > 1 else { return }

    // The lit tier's top needles, bright at their tips.
    var tips = Path()
    let w = max(0.5, (rx + ry) * 0.022)
    for k in stride(from: 1, to: lit.count, by: 2) where lit[k].y < litO.y - ry * 0.12 {
        let tip = lit[k]
        let from = CGPoint(x: tip.x + (litO.x - tip.x) * 0.3, y: tip.y + (litO.y - tip.y) * 0.3)
        let a = atan2(tip.y - from.y, tip.x - from.x)
        let nx = -sin(a) * w, ny = cos(a) * w
        tips.addPath(polygon([CGPoint(x: from.x - nx, y: from.y - ny), tip,
                              CGPoint(x: from.x + nx, y: from.y + ny)]))
    }
    ctx.fill(tips, with: .color(ink.hi.color))
}

/// Fans of fine needles inside `region`, each splayed away from the twig at
/// `hub`: the grain that shows which way a pad's needles grow.
private func rakeNeedles(_ ctx: inout BonsaiLayers, from hub: CGPoint, over region: [CGPoint],
                         around o: CGPoint, seed: Double, color: Color, fans: Int) {
    var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
    for p in region { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) }
    let r0 = (maxX - minX + maxY - minY) / 4
    let reach = r0 * 0.6
    var near: [(CGPoint, CGPoint)] = []
    var path = Path()
    for i in 0..<fans {
        let n = Double(i)
        let a = bonsaiNoise(seed, 200 + n) * 2 * .pi
        let d = rayExit(o, cos(a), sin(a), region, cap: r0 * 4) * (0.1 + 0.7 * bonsaiNoise(seed, 210 + n))
        let p = CGPoint(x: o.x + cos(a) * d, y: o.y + sin(a) * d)
        let dir = atan2(p.y - hub.y, p.x - hub.x)
        // A needle is at most half of r0 long, so only the edges close to
        // its root can cut it short.
        near.removeAll(keepingCapacity: true)
        var e0 = region[region.count - 1]
        for e1 in region {
            if min(e0.x, e1.x) < p.x + reach && max(e0.x, e1.x) > p.x - reach
                && min(e0.y, e1.y) < p.y + reach && max(e0.y, e1.y) > p.y - reach { near.append((e0, e1)) }
            e0 = e1
        }
        for k in -1...1 {
            let na = dir + Double(k) * 0.32 + (bonsaiNoise(seed, 220 + n * 3 + Double(k)) - 0.5) * 0.2
            let ux = cos(na), uy = sin(na)
            var exit = r0
            for (a, b) in near { if let t = crossing(p, ux, uy, a, b), t < exit { exit = t } }
            let len = min(exit * 0.9, r0 * (0.3 + 0.2 * bonsaiNoise(seed, 230 + n * 3 + Double(k))))
            guard len > r0 * 0.08 else { continue }
            let w = max(0.35, r0 * 0.022)
            // Every sliver is wound the same way, so they add up as a union.
            let nx = -uy * w, ny = ux * w
            path.move(to: CGPoint(x: p.x - nx, y: p.y - ny))
            path.addLine(to: CGPoint(x: p.x + ux * len, y: p.y + uy * len))
            path.addLine(to: CGPoint(x: p.x + nx, y: p.y + ny))
            path.closeSubpath()
        }
    }
    ctx.fill(path, with: .color(color))
}

/// A fringe of needle tips round a flat-bottomed ellipse: `tufts` points
/// alternating with the gaps between them, each pointing away from the twig
/// at `hub` over the crown and outward along the underside. Lengths come in
/// clumps, the way needles grow in bunches. `topOnly` leaves the underside
/// smooth, for a tier sitting inside another.
private func needleRim(cx: Double, cy: Double, rx: Double, ry: Double, seed: Double, tufts: Int,
                       hub: CGPoint, flat: Double, topOnly: Bool) -> [CGPoint] {
    let r0 = (rx + ry) / 2
    let phase = bonsaiNoise(seed, 1) * 2 * .pi
    // The solid pad fills about the cloud the old scalloped pad did; the
    // needle tips reach its outer edge.
    func base(_ a: Double) -> CGPoint {
        let s = sin(a)
        let hump = 1 + 0.06 * sin(5 * a + phase) * max(0, -s)
        return CGPoint(x: cx + cos(a) * rx * 0.9 * hump,
                       y: cy + s * ry * hump * (s > 0 ? 1 - 0.33 * flat : 1.04))
    }
    var pts: [CGPoint] = []
    let step = 2 * Double.pi / Double(tufts)
    for i in 0..<tufts {
        let n = Double(i)
        pts.append(base(n * step))
        let a = (n + 0.5 + 0.4 * (bonsaiNoise(seed, 160 + n) - 0.5)) * step
        let below = max(0, sin(a))
        if topOnly && sin(a) > -0.15 { continue }
        let b = base(a)
        let hx = b.x - hub.x, hy = b.y - hub.y, hl = max(1e-9, hypot(hx, hy))
        let ox = cos(a) / rx, oy = sin(a) / ry, ol = hypot(ox, oy)
        let k = 0.2 + 0.7 * below
        var dx = hx / hl * (1 - k) + ox / ol * k, dy = hy / hl * (1 - k) + oy / ol * k
        let dl = max(1e-9, hypot(dx, dy))
        dx /= dl; dy /= dl
        let clump = 0.55 + 0.45 * sin(a * 7 + phase * 3)
        let len = r0 * (0.15 - 0.11 * below) * (0.45 + 0.55 * clump + 0.35 * bonsaiNoise(seed, 170 + n))
        pts.append(CGPoint(x: b.x + dx * len, y: b.y + dy * len))
    }
    return pts
}

/// `poly` with each point held a little inside `outer` along its ray from
/// `o`, so an inner layer always sits inside the one under it and paints
/// without a clip. `o` must lie inside `outer`.
private func nested(_ poly: [CGPoint], toward o: CGPoint, in outer: [CGPoint],
                    margin: Double = 0.94) -> [CGPoint] {
    // The outline's edges binned by the angle they cover as seen from `o`,
    // so each ray only tests the few edges it can cross. Edge i runs from
    // point i-1 to point i; the bins are filled in two passes into one array.
    let bins = 64
    let width = 2 * Double.pi / Double(bins)
    let angle = outer.map { atan2($0.y - o.y, $0.x - o.x) }
    var span = [(first: Int, count: Int)](repeating: (0, 0), count: outer.count)
    var start = [Int](repeating: 0, count: bins + 1)
    for i in outer.indices {
        let t0 = angle[i == 0 ? outer.count - 1 : i - 1], t1 = angle[i]
        let sweep = (t1 - t0).remainder(dividingBy: 2 * .pi)
        let lo = sweep >= 0 ? t0 : t0 + sweep
        span[i] = (Int(((lo + 2 * .pi) / width).rounded(.down)), Int(abs(sweep) / width) + 2)
        for k in span[i].first..<(span[i].first + span[i].count) { start[k % bins + 1] += 1 }
    }
    for b in 0..<bins { start[b + 1] += start[b] }
    var fill = start
    var edges = [Int](repeating: 0, count: start[bins])
    for i in outer.indices {
        for k in span[i].first..<(span[i].first + span[i].count) {
            edges[fill[k % bins]] = i
            fill[k % bins] += 1
        }
    }
    return poly.map { p in
        let vx = p.x - o.x, vy = p.y - o.y
        let len = hypot(vx, vy)
        guard len > 1e-9 else { return o }
        let dx = vx / len, dy = vy / len
        let bin = Int(((atan2(dy, dx) + 2 * .pi) / width).rounded(.down)) % bins
        var exit = len / margin
        for e in start[bin]..<start[bin + 1] {
            let i = edges[e]
            let a = outer[i == 0 ? outer.count - 1 : i - 1], b = outer[i]
            if let t = crossing(o, dx, dy, a, b), t < exit { exit = t }
        }
        let r = min(len, exit * margin)
        return CGPoint(x: o.x + dx * r, y: o.y + dy * r)
    }
}

private func scaled(_ pts: [CGPoint], about o: CGPoint, by k: Double) -> [CGPoint] {
    pts.map { CGPoint(x: o.x + ($0.x - o.x) * k, y: o.y + ($0.y - o.y) * k) }
}

/// Distance from `o` (inside `poly`) along the unit direction (dx, dy) to the
/// edge of `poly`, or `cap` when the edge is further.
private func rayExit(_ o: CGPoint, _ dx: Double, _ dy: Double, _ poly: [CGPoint], cap: Double) -> Double {
    var best = cap
    var a = poly[poly.count - 1]
    for b in poly {
        if let t = crossing(o, dx, dy, a, b), t < best { best = t }
        a = b
    }
    return best
}

/// Where the ray from `o` along (dx, dy) crosses the segment a-b, if it does.
private func crossing(_ o: CGPoint, _ dx: Double, _ dy: Double, _ a: CGPoint, _ b: CGPoint) -> Double? {
    let ex = b.x - a.x, ey = b.y - a.y
    let den = dx * ey - dy * ex
    guard abs(den) > 1e-12 else { return nil }
    let wx = a.x - o.x, wy = a.y - o.y
    let t = (wx * ey - wy * ex) / den, u = (wx * dy - wy * dx) / den
    return t > 1e-9 && u >= 0 && u < 1 ? t : nil
}

/// A closed outline, always wound the same way, so outlines added into one
/// path fill as their union instead of cancelling where they overlap.
private func polygon(_ pts: [CGPoint]) -> Path {
    var area = 0.0
    var a = pts[pts.count - 1]
    for b in pts {
        area += a.x * b.y - b.x * a.y
        a = b
    }
    var p = Path()
    p.addLines(area < 0 ? pts.reversed() : pts)
    p.closeSubpath()
    return p
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

/// `pts` with a point added `depth` below the first, straight on along the
/// opening segment, so a trunk's square end and its shading run under the
/// soil instead of stopping in a step above it.
func rooted(_ pts: [CGPoint], _ widths: [Double], depth: Double) -> ([CGPoint], [Double]) {
    guard pts.count >= 2 else { return (pts, widths) }
    let dx = pts[0].x - pts[1].x, dy = pts[0].y - pts[1].y
    guard dy > 1e-6 else { return (pts, widths) }
    let s = depth / dy
    return ([CGPoint(x: pts[0].x + dx * s, y: pts[0].y + depth)] + pts, [widths[0]] + widths)
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
func shadeWood(_ ctx: inout BonsaiLayers, _ path: Path, width: Double,
               dark: Color, light: Color, grain: Double = 0, grainColor: Color? = nil) {
    // Two soft steps on each flank approximate a curved surface. Each is the
    // wood less a shifted copy of itself, cut once here rather than clipped
    // on every frame.
    for (k, op) in [(0.44, 0.3), (0.24, 0.32)] {
        ctx.fill(path.subtracting(path.offsetBy(dx: -width * k, dy: -width * k * 0.15)),
                 with: .color(dark.opacity(op)))
    }
    for (k, op) in [(0.3, 0.22), (0.14, 0.26)] {
        ctx.fill(path.subtracting(path.offsetBy(dx: width * k, dy: 0)), with: .color(light.opacity(op)))
    }
    guard grain > 0.02, let grainColor else { return }
    var g = ctx
    g.clip(to: path)
    let lw = max(0.8, width * 0.035)
    for k in [0.2, -0.36] {
        g.stroke(path.offsetBy(dx: width * k, dy: 0), with: .color(grainColor.opacity(0.28 * grain)),
                 style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}

/// The root flare where a trunk of width `w` meets the soil at (x, y).
/// `lean` is the trunk's sideways run per unit of rise, so the flare's top
/// follows a leaning trunk instead of leaving a corner where they meet.
func nebariPath(x: Double, y: Double, w: Double, spread: Double, lean: Double = 0) -> Path {
    // The top sits inside the trunk, so only the concave flanks show.
    let f = w * 0.34 * spread, h = w * 0.55, top = x + lean * h
    var p = Path()
    p.move(to: CGPoint(x: x - w / 2 - f, y: y + 1.5))
    p.addQuadCurve(to: CGPoint(x: top - w * 0.25, y: y - h),
                   control: CGPoint(x: x - w * 0.42 + lean * h * 0.6, y: y - h * 0.15))
    p.addLine(to: CGPoint(x: top + w * 0.25, y: y - h))
    p.addQuadCurve(to: CGPoint(x: x + w / 2 + f, y: y + 1.5),
                   control: CGPoint(x: x + w * 0.42 + lean * h * 0.6, y: y - h * 0.15))
    p.closeSubpath()
    return p
}

// MARK: - Soil and pot

private let mossDark = RGB(0x4F6436).color, mossMid = RGB(0x6E874A).color

/// Cushions of moss on the soil around a trunk, filling in as `amount` grows.
func paintSoilMoss(_ ctx: inout BonsaiLayers, cx: Double, y: Double, spread: Double,
                   amount: Double, seed: Double) {
    guard amount > 0.02 else { return }
    // Each cushion is a few small domes sunk into the soil.
    let n = Int((2 + 5 * amount).rounded())
    for i in 0..<n {
        let u = bonsaiNoise(seed, Double(i * 2 + 1)), v = bonsaiNoise(seed, Double(i * 2 + 2))
        let x = cx + (u - 0.5) * 2 * spread * (0.35 + 0.65 * amount)
        let yy = y + 1 + (v - 0.5) * 2
        let soil = Path(CGRect(x: x - 20, y: yy - 12, width: 40, height: 12.5))
        for k in 0..<3 {
            let r = (2.2 + 2.4 * bonsaiNoise(seed, Double(i * 5 + k + 20))) * (0.6 + 0.4 * amount)
            let dx = (Double(k) - 1) * r * 1.3
            ctx.fill(Path(ellipseIn: CGRect(x: x + dx - r, y: yy - r * 0.8, width: r * 2, height: r * 1.6))
                        .intersection(soil), with: .color(mossDark))
            ctx.fill(Path(ellipseIn: CGRect(x: x + dx - r * 0.75, y: yy - r * 0.85, width: r * 1.3, height: r * 1.0))
                        .intersection(soil), with: .color(mossMid))
        }
    }
}

/// Two short feet under a pot whose base runs from `left` to `right` at `y`.
func paintPotFeet(_ ctx: inout BonsaiLayers, left: Double, right: Double, y: Double, color: Color) {
    let w = min(22, (right - left) * 0.11), h = 4.5, inset = (right - left) * 0.09
    for x in [left + inset, right - inset - w] {
        ctx.fill(Path(roundedRect: CGRect(x: x, y: y - 1, width: w, height: h + 1), cornerRadius: 1.5),
                 with: .color(color))
    }
}
