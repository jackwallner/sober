package com.jackwallner.sober.ui.bonsai

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

// Port of Shared/Bonsai/BonsaiPaint.swift: painting helpers shared by every bonsai style, in the
// 600x600 design space. Light comes from the upper left. Foliage and wood are opaque layers,
// never alpha stacks. Keep the Swift operation order: the parity fixtures compare the output.

/** A color that can be mixed. */
class RGB(val r: Double, val g: Double, val b: Double) {
    constructor(hex: Int) : this(
        ((hex shr 16) and 0xFF) / 255.0, ((hex shr 8) and 0xFF) / 255.0, (hex and 0xFF) / 255.0,
    )

    val color: BonsaiColor get() = BonsaiColor(r, g, b)

    fun mix(o: RGB, t: Double) = RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)

    /** Toward a dull olive, for a garden that hasn't been tended. */
    fun dried(t: Double): RGB {
        if (t <= 0) return this
        val l = 0.30 * r + 0.59 * g + 0.11 * b
        return mix(RGB(l, l, l).mix(RGB(0xA39A6E), 0.55), t)
    }
}

/** Four foliage tones, dark underside to sunlit tips. */
class FoliageInk(val shadow: RGB, val mid: RGB, val light: RGB, val hi: RGB)

// MARK: - Foliage pads

/**
 * A cloud of round lobes around an elliptical core: the scalloped edge of a foliage pad.
 * `flat` (0...1) shrinks the lower lobes for a flat-bottomed pad.
 */
fun lobedPath(cx: Double, cy: Double, rx: Double, ry: Double, seed: Double, flat: Double = 0.0): BonsaiPath {
    val p = BonsaiPath.ellipseIn(cx - rx * 0.8, cy - ry * 0.8, rx * 1.6, ry * 1.6)
    val lobeR = 0.27 * (rx + ry) / 2
    val n = max(8, min(24, (Math.PI * (rx + ry) / (lobeR * 1.1)).swiftRounded().toInt()))
    for (i in 0 until n) {
        val a = (i + 0.8 * bonsaiNoise(seed, (i * 3 + 1).toDouble())) / n * 2 * Math.PI
        val below = max(0.0, sin(a))
        val rr = lobeR * (0.55 + 0.9 * bonsaiNoise(seed, (i * 3 + 2).toDouble())) * (1 - 0.45 * flat * below)
        val px = cx + cos(a) * rx * 0.78
        val py = cy + sin(a) * ry * 0.78 * (1 - 0.35 * flat * below)
        p.ellipse(px - rr, py - rr, rr * 2, rr * 2)
    }
    return p
}

/**
 * One foliage pad: dark silhouette, a mid body lifted off its underside, a sunlit crown, and a
 * few bright tips. `detail` 0 is a small tuft (no tips).
 */
fun paintPad(
    ctx: BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
    seed: Double, ink: FoliageInk, dry: Double = 0.0, detail: Int = 1, flat: Double = 0.0,
) {
    val shadow = ink.shadow.dried(dry).color
    val mid = ink.mid.dried(dry).color
    val light = ink.light.dried(dry).color
    val hi = ink.hi.dried(dry).color

    val outline = lobedPath(cx, cy, rx, ry, seed, flat)
    ctx.fill(outline, shadow)

    val body = ctx.copy()
    body.clip(outline)
    val bodyPath = lobedPath(cx - rx * 0.04, cy - ry * (0.14 + 0.08 * flat), rx * 0.9, ry * 0.84, seed, flat)
    body.fill(bodyPath, mid)

    val lit = body.copy()
    lit.clip(bodyPath)
    val litPath = lobedPath(cx - rx * 0.2, cy - ry * 0.42, rx * 0.58, ry * 0.44, seed + 3, flat)
    lit.fill(litPath, light)

    if (detail <= 0) return
    // Sunlit flecks along the crown.
    val r0 = (rx + ry) / 2
    for (i in 0 until 7) {
        val u = bonsaiNoise(seed, (40 + i).toDouble())
        val v = bonsaiNoise(seed, (50 + i).toDouble())
        val x = cx - rx * (0.62 - 0.85 * u)
        val y = cy - ry * (0.78 - 0.42 * v)
        val r = r0 * (0.035 + 0.035 * bonsaiNoise(seed, (60 + i).toDouble()))
        lit.fill(BonsaiPath.ellipseIn(x - r, y - r * 0.8, r * 2, r * 1.6), hi)
    }
}

// MARK: - Maple and pine pads
//
// Both are built from straight-edged outlines that nest inside one another (`nested`), so each
// layer paints straight over the last with no clip.

private class Leaf(val outline: List<Pt>, val heart: Pt, val light: Double, val low: Boolean)

/**
 * A maple pad: a heap of small palmate leaves, each turned out from the middle so the rim reads
 * as lobed leaves. `detail` 0 is a few three-lobed leaves, 1 is more leaves with five lobes, 2
 * serrates every lobe.
 */
fun paintPalmatePad(
    ctx: BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
    seed: Double, ink: FoliageInk, detail: Int, flat: Double = 0.35,
) {
    fun at(u: Double, v: Double) = Pt(cx + u * rx, cy + v * ry * (if (v > 0) 1 - 0.3 * flat else 1.0))
    val rings: List<Pair<Double, Int>> = if (detail == 0) listOf(0.58 to 7) else listOf(0.68 to 10, 0.34 to 6)
    val phase = bonsaiNoise(seed, 1.0) * 2 * Math.PI
    class Slot(val u: Double, val v: Double, val axis: Double)
    val slots = arrayListOf(Slot(0.0, -0.06, -Math.PI / 2))
    for ((ring, rn) in rings.withIndex()) {
        val (r, n) = rn
        for (j in 0 until n) {
            val k = (ring * 16 + j).toDouble()
            val a = phase + (j + 0.5 * ring + 0.3 * (bonsaiNoise(seed, 10 + k) - 0.5)) * 2 * Math.PI / n
            slots.add(Slot(cos(a) * r, sin(a) * r, a))
        }
    }
    val leaves = ArrayList<Leaf>()
    for ((i, s) in slots.withIndex()) {
        val k = i.toDouble()
        val axis = s.axis + 0.6 * (bonsaiNoise(seed, 40 + k) - 0.5)
        val len = (if (detail == 0) 0.7 else 0.62) * (0.9 + 0.2 * bonsaiNoise(seed, 50 + k))
        val unit = palmateLeaf(
            Pt(s.u - cos(axis) * len * 0.22, s.v - sin(axis) * len * 0.22),
            axis, len, if (detail == 0) 3 else 5, detail > 1,
        )
        leaves.add(Leaf(unit.map { at(it.x, it.y) }, at(s.u, s.v), -0.55 * s.u - 0.83 * s.v, s.v > 0.45))
    }
    // Lowest first, so the upper leaves lie over them.
    leaves.sortWith { a, b -> b.heart.y.compareTo(a.heart.y) }
    val core = (0 until 24).map { at(cos(it * Math.PI / 12) * 0.5, sin(it * Math.PI / 12) * 0.5) }
    val split = leaves.size / 2
    for ((tier, group) in listOf(leaves.subList(0, split), leaves.subList(split, leaves.size)).withIndex()) {
        val dark = BonsaiPath()
        val mid = BonsaiPath()
        val lit = BonsaiPath()
        // Under the leaves, a mass in the body colour, so the gaps between them never open onto the sky.
        if (tier == 0) mid.addPath(polygon(core))
        for (leaf in group) {
            dark.addPath(polygon(leaf.outline))
            // A leaf fans out round its heart, so shrinking it there keeps it inside.
            val face = polygon(scaled(leaf.outline, leaf.heart, if (leaf.low) 0.72 else 0.84))
            if (leaf.light > -0.05) lit.addPath(face) else mid.addPath(face)
        }
        ctx.fill(dark, ink.shadow.color)
        ctx.fill(mid, ink.mid.color)
        ctx.fill(lit, ink.light.color)
    }
    if (detail <= 0) return
    // The highest leaves on the crown, sunlit at their hearts.
    val hi = BonsaiPath()
    for (leaf in leaves.takeLast(6)) {
        if (leaf.light > 0.3) hi.addPath(polygon(scaled(leaf.outline, leaf.heart, 0.5)))
    }
    ctx.fill(hi, ink.hi.color)
}

/** One palmate leaf with its stalk at `stalk` and middle lobe along `axis`. Saw-toothed when `serrate`. */
private fun palmateLeaf(stalk: Pt, axis: Double, length: Double, lobes: Int, serrate: Boolean): List<Pt> {
    val fan = if (lobes == 5) doubleArrayOf(-1.25, -0.62, 0.0, 0.62, 1.25) else doubleArrayOf(-0.7, 0.0, 0.7)
    val reach = if (lobes == 5) doubleArrayOf(0.56, 0.86, 1.0, 0.86, 0.56) else doubleArrayOf(0.76, 1.0, 0.76)
    val half = if (lobes == 5) 0.21 else 0.3
    fun out(a: Double, l: Double) = Pt(stalk.x + cos(a) * l, stalk.y + sin(a) * l)
    val pts = arrayListOf(stalk)
    // Teeth along a lobe edge from `a` to `b`, leaning toward the lobe tip.
    fun edge(a: Pt, b: Pt, towardEnd: Boolean) {
        if (!serrate) return
        val ex = b.x - a.x
        val ey = b.y - a.y
        for (t in doubleArrayOf(0.3, 0.64)) {
            val base = Pt(a.x + ex * t, a.y + ey * t)
            val tt = if (towardEnd) t + 0.14 else t - 0.14
            val tooth = Pt(a.x + ex * tt + ey * 0.07, a.y + ey * tt - ex * 0.07)
            if (towardEnd) { pts.add(base); pts.add(tooth) } else { pts.add(tooth); pts.add(base) }
        }
    }
    for (k in fan.indices) {
        val a = axis + fan[k]
        val l = length * reach[k]
        if (k > 0) pts.add(out(axis + (fan[k - 1] + fan[k]) / 2, length * 0.36))
        val s0 = out(a - half, l * 0.58)
        val tip = out(a, l)
        val s1 = out(a + half, l * 0.58)
        pts.add(s0)
        edge(s0, tip, true)
        pts.add(tip)
        edge(tip, s1, false)
        pts.add(s1)
    }
    return pts
}

/**
 * A pine pad: a low cloud of needles fanning out of the twig beneath it, built as three tiers,
 * each a fringe of needle tips. `detail` 0 is a coarse fringe, 1 finer, 2 finest with lit tips.
 */
fun paintNeedlePad(
    ctx: BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
    seed: Double, ink: FoliageInk, detail: Int, flat: Double = 0.85,
) {
    val hub = Pt(cx, cy + ry * 0.7)
    val tufts = if (detail == 0) 36 else if (detail == 1) 70 else 120
    val rim = needleRim(cx, cy, rx, ry, seed, tufts, hub, flat, false)
    ctx.fill(polygon(rim), ink.shadow.color)

    val bodyO = Pt(cx, cy - ry * 0.2)
    val body = nested(needleRim(cx, bodyO.y, rx * 0.9, ry * 0.72, seed + 1, tufts, hub, flat, true), bodyO, rim)
    ctx.fill(polygon(body), ink.mid.color)
    if (detail > 0) rakeNeedles(ctx, hub, body, bodyO, seed, ink.light.color, if (detail == 1) 8 else 18)

    val litO = Pt(cx - rx * 0.1, cy - ry * 0.44)
    val lit = nested(needleRim(litO.x, litO.y, rx * 0.72, ry * 0.44, seed + 2, tufts * 3 / 4, hub, flat, true), litO, body)
    ctx.fill(polygon(lit), ink.light.color)
    if (detail > 0) rakeNeedles(ctx, hub, lit, litO, seed + 7, ink.hi.color, if (detail == 1) 5 else 12)
    if (detail <= 1) return

    // The lit tier's top needles, bright at their tips.
    val tips = BonsaiPath()
    val w = max(0.5, (rx + ry) * 0.022)
    var k = 1
    while (k < lit.size) {
        if (lit[k].y < litO.y - ry * 0.12) {
            val tip = lit[k]
            val from = Pt(tip.x + (litO.x - tip.x) * 0.3, tip.y + (litO.y - tip.y) * 0.3)
            val a = atan2(tip.y - from.y, tip.x - from.x)
            val nx = -sin(a) * w
            val ny = cos(a) * w
            tips.addPath(polygon(listOf(Pt(from.x - nx, from.y - ny), tip, Pt(from.x + nx, from.y + ny))))
        }
        k += 2
    }
    ctx.fill(tips, ink.hi.color)
}

/** Fans of fine needles inside `region`, each splayed away from the twig at `hub`. */
private fun rakeNeedles(
    ctx: BonsaiLayers, hub: Pt, region: List<Pt>, o: Pt, seed: Double, color: BonsaiColor, fans: Int,
) {
    var minX = Double.POSITIVE_INFINITY
    var maxX = Double.NEGATIVE_INFINITY
    var minY = Double.POSITIVE_INFINITY
    var maxY = Double.NEGATIVE_INFINITY
    for (p in region) { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) }
    val r0 = (maxX - minX + maxY - minY) / 4
    val reach = r0 * 0.6
    val near = ArrayList<Pair<Pt, Pt>>()
    val path = BonsaiPath()
    for (i in 0 until fans) {
        val n = i.toDouble()
        val a = bonsaiNoise(seed, 200 + n) * 2 * Math.PI
        val d = rayExit(o, cos(a), sin(a), region, r0 * 4) * (0.1 + 0.7 * bonsaiNoise(seed, 210 + n))
        val p = Pt(o.x + cos(a) * d, o.y + sin(a) * d)
        val dir = atan2(p.y - hub.y, p.x - hub.x)
        // A needle is at most half of r0 long, so only the edges close to its root can cut it short.
        near.clear()
        var e0 = region[region.size - 1]
        for (e1 in region) {
            if (min(e0.x, e1.x) < p.x + reach && max(e0.x, e1.x) > p.x - reach &&
                min(e0.y, e1.y) < p.y + reach && max(e0.y, e1.y) > p.y - reach
            ) near.add(e0 to e1)
            e0 = e1
        }
        for (k in -1..1) {
            val na = dir + k * 0.32 + (bonsaiNoise(seed, 220 + n * 3 + k) - 0.5) * 0.2
            val ux = cos(na)
            val uy = sin(na)
            var exit = r0
            for ((ea, eb) in near) {
                val t = crossing(p, ux, uy, ea, eb)
                if (t != null && t < exit) exit = t
            }
            val len = min(exit * 0.9, r0 * (0.3 + 0.2 * bonsaiNoise(seed, 230 + n * 3 + k)))
            if (len <= r0 * 0.08) continue
            val w = max(0.35, r0 * 0.022)
            // Every sliver is wound the same way, so they add up as a union.
            val nx = -uy * w
            val ny = ux * w
            path.move(p.x - nx, p.y - ny)
            path.line(p.x + ux * len, p.y + uy * len)
            path.line(p.x + nx, p.y + ny)
            path.close()
        }
    }
    ctx.fill(path, color)
}

/**
 * A fringe of needle tips round a flat-bottomed ellipse: `tufts` points alternating with the gaps
 * between them, each pointing away from the twig at `hub` over the crown and outward along the
 * underside. `topOnly` leaves the underside smooth, for a tier sitting inside another.
 */
private fun needleRim(
    cx: Double, cy: Double, rx: Double, ry: Double, seed: Double, tufts: Int,
    hub: Pt, flat: Double, topOnly: Boolean,
): List<Pt> {
    val r0 = (rx + ry) / 2
    val phase = bonsaiNoise(seed, 1.0) * 2 * Math.PI
    fun base(a: Double): Pt {
        val s = sin(a)
        val hump = 1 + 0.06 * sin(5 * a + phase) * max(0.0, -s)
        return Pt(cx + cos(a) * rx * 0.9 * hump, cy + s * ry * hump * (if (s > 0) 1 - 0.33 * flat else 1.04))
    }
    val pts = ArrayList<Pt>()
    val step = 2 * Math.PI / tufts
    for (i in 0 until tufts) {
        val n = i.toDouble()
        pts.add(base(n * step))
        val a = (n + 0.5 + 0.4 * (bonsaiNoise(seed, 160 + n) - 0.5)) * step
        val below = max(0.0, sin(a))
        if (topOnly && sin(a) > -0.15) continue
        val b = base(a)
        val hx = b.x - hub.x
        val hy = b.y - hub.y
        val hl = max(1e-9, hypot(hx, hy))
        val ox = cos(a) / rx
        val oy = sin(a) / ry
        val ol = hypot(ox, oy)
        val k = 0.2 + 0.7 * below
        var dx = hx / hl * (1 - k) + ox / ol * k
        var dy = hy / hl * (1 - k) + oy / ol * k
        val dl = max(1e-9, hypot(dx, dy))
        dx /= dl; dy /= dl
        val clump = 0.55 + 0.45 * sin(a * 7 + phase * 3)
        val len = r0 * (0.15 - 0.11 * below) * (0.45 + 0.55 * clump + 0.35 * bonsaiNoise(seed, 170 + n))
        pts.add(Pt(b.x + dx * len, b.y + dy * len))
    }
    return pts
}

/**
 * `poly` with each point held a little inside `outer` along its ray from `o`, so an inner layer
 * always sits inside the one under it and paints without a clip. `o` must lie inside `outer`.
 */
private fun nested(poly: List<Pt>, o: Pt, outer: List<Pt>, margin: Double = 0.94): List<Pt> {
    // The outline's edges binned by the angle they cover as seen from `o`, so each ray only tests
    // the few edges it can cross. Edge i runs from point i-1 to point i.
    val bins = 64
    val width = 2 * Math.PI / bins
    val angle = outer.map { atan2(it.y - o.y, it.x - o.x) }
    val spanFirst = IntArray(outer.size)
    val spanCount = IntArray(outer.size)
    val start = IntArray(bins + 1)
    for (i in outer.indices) {
        val t0 = angle[if (i == 0) outer.size - 1 else i - 1]
        val t1 = angle[i]
        val sweep = (t1 - t0).ieeeRemainder(2 * Math.PI)
        val lo = if (sweep >= 0) t0 else t0 + sweep
        spanFirst[i] = floor((lo + 2 * Math.PI) / width).toInt()
        spanCount[i] = (abs(sweep) / width).toInt() + 2
        for (k in spanFirst[i] until spanFirst[i] + spanCount[i]) start[k % bins + 1] += 1
    }
    for (b in 0 until bins) start[b + 1] += start[b]
    val fill = start.copyOf()
    val edges = IntArray(start[bins])
    for (i in outer.indices) {
        for (k in spanFirst[i] until spanFirst[i] + spanCount[i]) {
            edges[fill[k % bins]] = i
            fill[k % bins] += 1
        }
    }
    return poly.map { p ->
        val vx = p.x - o.x
        val vy = p.y - o.y
        val len = hypot(vx, vy)
        if (len <= 1e-9) return@map o
        val dx = vx / len
        val dy = vy / len
        val bin = floor((atan2(dy, dx) + 2 * Math.PI) / width).toInt() % bins
        var exit = len / margin
        for (e in start[bin] until start[bin + 1]) {
            val i = edges[e]
            val a = outer[if (i == 0) outer.size - 1 else i - 1]
            val b = outer[i]
            val t = crossing(o, dx, dy, a, b)
            if (t != null && t < exit) exit = t
        }
        val r = min(len, exit * margin)
        Pt(o.x + dx * r, o.y + dy * r)
    }
}

private fun scaled(pts: List<Pt>, o: Pt, k: Double) = pts.map { Pt(o.x + (it.x - o.x) * k, o.y + (it.y - o.y) * k) }

/** Distance from `o` (inside `poly`) along the unit direction (dx, dy) to the edge of `poly`, or `cap`. */
private fun rayExit(o: Pt, dx: Double, dy: Double, poly: List<Pt>, cap: Double): Double {
    var best = cap
    var a = poly[poly.size - 1]
    for (b in poly) {
        val t = crossing(o, dx, dy, a, b)
        if (t != null && t < best) best = t
        a = b
    }
    return best
}

/** Where the ray from `o` along (dx, dy) crosses the segment a-b, if it does. */
private fun crossing(o: Pt, dx: Double, dy: Double, a: Pt, b: Pt): Double? {
    val ex = b.x - a.x
    val ey = b.y - a.y
    val den = dx * ey - dy * ex
    if (abs(den) <= 1e-12) return null
    val wx = a.x - o.x
    val wy = a.y - o.y
    val t = (wx * ey - wy * ex) / den
    val u = (wx * dy - wy * dx) / den
    return if (t > 1e-9 && u >= 0 && u < 1) t else null
}

/** A closed outline, always wound the same way, so outlines added into one path fill as their union. */
private fun polygon(pts: List<Pt>): BonsaiPath {
    var area = 0.0
    var a = pts[pts.size - 1]
    for (b in pts) {
        area += a.x * b.y - b.x * a.y
        a = b
    }
    val p = BonsaiPath()
    p.addLines(if (area < 0) pts.reversed() else pts)
    p.close()
    return p
}

// MARK: - Wood

/** A smooth tapered limb through `pts` (Catmull-Rom), `widths` per point. The base end is cut square. */
fun woodRibbon(pts: List<Pt>, widths: List<Double>, perSegment: Int = 8): BonsaiPath {
    if (pts.size < 2) return BonsaiPath()
    val (spine, ws) = smoothSpine(pts, widths, perSegment)
    return ribbon(spine, ws)
}

/** `pts` with a point added `depth` below the first, straight on along the opening segment. */
fun rooted(pts: List<Pt>, widths: List<Double>, depth: Double): Pair<List<Pt>, List<Double>> {
    if (pts.size < 2) return pts to widths
    val dx = pts[0].x - pts[1].x
    val dy = pts[0].y - pts[1].y
    if (dy <= 1e-6) return pts to widths
    val s = depth / dy
    return (listOf(Pt(pts[0].x + dx * s, pts[0].y + depth)) + pts) to (listOf(widths[0]) + widths)
}

/** The centre line `woodRibbon` draws, densely sampled, with its widths. */
fun smoothSpine(pts: List<Pt>, widths: List<Double>, perSegment: Int = 8): Pair<List<Pt>, List<Double>> {
    val spine = ArrayList<Pt>()
    val ws = ArrayList<Double>()
    for (i in 0 until pts.size - 1) {
        val p0 = pts[max(0, i - 1)]
        val p1 = pts[i]
        val p2 = pts[i + 1]
        val p3 = pts[min(pts.size - 1, i + 2)]
        for (s in 0 until perSegment) {
            val t = s.toDouble() / perSegment
            spine.add(catmull(p0, p1, p2, p3, t))
            ws.add(widths[i] + (widths[i + 1] - widths[i]) * t)
        }
    }
    spine.add(pts[pts.size - 1]); ws.add(widths[widths.size - 1])
    return spine to ws
}

/** A limb along one quadratic curve, tapering from `w0` to `w1`. */
fun boughPath(p0: Pt, c: Pt, p1: Pt, w0: Double, w1: Double): BonsaiPath {
    val spine = ArrayList<Pt>()
    val ws = ArrayList<Double>()
    val n = 10
    for (i in 0..n) {
        val t = i.toDouble() / n
        val u = 1 - t
        spine.add(Pt(u * u * p0.x + 2 * u * t * c.x + t * t * p1.x, u * u * p0.y + 2 * u * t * c.y + t * t * p1.y))
        ws.add(w0 + (w1 - w0) * t)
    }
    return ribbon(spine, ws)
}

private fun catmull(p0: Pt, p1: Pt, p2: Pt, p3: Pt, t: Double): Pt {
    val t2 = t * t
    val t3 = t2 * t
    fun f(a: Double, b: Double, c: Double, d: Double) =
        0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
    return Pt(f(p0.x, p1.x, p2.x, p3.x), f(p0.y, p1.y, p2.y, p3.y))
}

private fun ribbon(spine: List<Pt>, widths: List<Double>): BonsaiPath {
    val left = ArrayList<Pt>()
    val right = ArrayList<Pt>()
    for (i in spine.indices) {
        val a = spine[max(0, i - 1)]
        val b = spine[min(spine.size - 1, i + 1)]
        val len = max(1e-6, hypot(b.x - a.x, b.y - a.y))
        val nx = -(b.y - a.y) / len
        val ny = (b.x - a.x) / len
        val w = widths[i] / 2
        left.add(Pt(spine[i].x + nx * w, spine[i].y + ny * w))
        right.add(Pt(spine[i].x - nx * w, spine[i].y - ny * w))
    }
    val p = BonsaiPath()
    p.move(left[0])
    for (i in 1 until left.size) p.line(left[i])
    // Rounded tip: half a circle from the left edge round to the right one.
    val n = spine.size - 1
    val tip = spine[n]
    val r = widths[n] / 2
    val a0 = atan2(left[n].y - tip.y, left[n].x - tip.x)
    val ahead = atan2(tip.y - spine[n - 1].y, tip.x - spine[n - 1].x)
    val sweep = if ((ahead - a0).ieeeRemainder(2 * Math.PI) > 0) Math.PI else -Math.PI
    for (k in 1 until 6) {
        val a = a0 + sweep * k / 6
        p.line(tip.x + cos(a) * r, tip.y + sin(a) * r)
    }
    for (i in right.indices.reversed()) p.line(right[i])
    p.close()
    return p
}

/**
 * Rounds a trunk or limb: a shadowed right flank, a lit left flank, and bark fissures that follow
 * its outline. `grain` (0...1) is how weathered it is.
 */
fun shadeWood(
    ctx: BonsaiLayers, path: BonsaiPath, width: Double,
    dark: BonsaiColor, light: BonsaiColor, grain: Double = 0.0, grainColor: BonsaiColor? = null,
) {
    // Two soft steps on each flank approximate a curved surface. Each is the wood less a shifted
    // copy of itself, cut once here rather than clipped on every frame.
    for ((k, op) in listOf(0.44 to 0.3, 0.24 to 0.32)) {
        ctx.fill(path.subtracting(path.offsetBy(-width * k, -width * k * 0.15)), dark.opacity(op))
    }
    for ((k, op) in listOf(0.3 to 0.22, 0.14 to 0.26)) {
        ctx.fill(path.subtracting(path.offsetBy(width * k, 0.0)), light.opacity(op))
    }
    if (grain <= 0.02 || grainColor == null) return
    val g = ctx.copy()
    g.clip(path)
    val lw = max(0.8, width * 0.035)
    for (k in doubleArrayOf(0.2, -0.36)) {
        g.stroke(path.offsetBy(width * k, 0.0), grainColor.opacity(0.28 * grain), lw, BonsaiCap.Round)
    }
}

/**
 * The root flare where a trunk of width `w` meets the soil at (x, y). `lean` is the trunk's
 * sideways run per unit of rise, so the flare's top follows a leaning trunk.
 */
fun nebariPath(x: Double, y: Double, w: Double, spread: Double, lean: Double = 0.0): BonsaiPath {
    // The top sits inside the trunk, so only the concave flanks show.
    val f = w * 0.34 * spread
    val h = w * 0.55
    val top = x + lean * h
    val p = BonsaiPath()
    p.move(x - w / 2 - f, y + 1.5)
    p.quad(Pt(top - w * 0.25, y - h), Pt(x - w * 0.42 + lean * h * 0.6, y - h * 0.15))
    p.line(top + w * 0.25, y - h)
    p.quad(Pt(x + w / 2 + f, y + 1.5), Pt(x + w * 0.42 + lean * h * 0.6, y - h * 0.15))
    p.close()
    return p
}

// MARK: - Soil and pot

private val mossDark = RGB(0x4F6436).color
private val mossMid = RGB(0x6E874A).color

/** Cushions of moss on the soil around a trunk, filling in as `amount` grows. */
fun paintSoilMoss(ctx: BonsaiLayers, cx: Double, y: Double, spread: Double, amount: Double, seed: Double) {
    if (amount <= 0.02) return
    // Each cushion is a few small domes sunk into the soil.
    val n = (2 + 5 * amount).swiftRounded().toInt()
    for (i in 0 until n) {
        val u = bonsaiNoise(seed, (i * 2 + 1).toDouble())
        val v = bonsaiNoise(seed, (i * 2 + 2).toDouble())
        val x = cx + (u - 0.5) * 2 * spread * (0.35 + 0.65 * amount)
        val yy = y + 1 + (v - 0.5) * 2
        val soil = BonsaiPath.rect(x - 20, yy - 12, 40.0, 12.5)
        for (k in 0 until 3) {
            val r = (2.2 + 2.4 * bonsaiNoise(seed, (i * 5 + k + 20).toDouble())) * (0.6 + 0.4 * amount)
            val dx = (k - 1) * r * 1.3
            ctx.fill(BonsaiPath.ellipseIn(x + dx - r, yy - r * 0.8, r * 2, r * 1.6).intersection(soil), mossDark)
            ctx.fill(BonsaiPath.ellipseIn(x + dx - r * 0.75, yy - r * 0.85, r * 1.3, r * 1.0).intersection(soil), mossMid)
        }
    }
}

/** Two short feet under a pot whose base runs from `left` to `right` at `y`. */
fun paintPotFeet(ctx: BonsaiLayers, left: Double, right: Double, y: Double, color: BonsaiColor) {
    val w = min(22.0, (right - left) * 0.11)
    val h = 4.5
    val inset = (right - left) * 0.09
    for (x in doubleArrayOf(left + inset, right - inset - w)) {
        ctx.fill(BonsaiPath.roundedRect(x, y - 1, w, h + 1, 1.5), color)
    }
}
