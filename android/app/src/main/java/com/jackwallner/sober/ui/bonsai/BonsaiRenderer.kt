package com.jackwallner.sober.ui.bonsai

import kotlin.math.max
import kotlin.math.min

// Line-for-line port of Shared/Bonsai/BonsaiRenderer.swift (with BonsaiPaint, BonsaiScene and
// BonsaiWind beside it). Everything here is deterministic Double math, so Android draws the
// same tree as iOS. Keep the Swift operation order: scripts/sync-android-bonsai.py records the
// Swift scenes and BonsaiParityTest compares this port against them.
//
// Porting notes:
// - Swift value-type context copies (`var g = ctx`) become `ctx.copy()`.
// - Swift's .rounded() is schoolbook rounding, see swiftRounded().
// - Path booleans (union, intersection, subtracting) stay lazy in BonsaiPath; BonsaiView
//   combines them with Compose PathOperation once per scene.

// MARK: - Palette

private fun hex(v: Int) = BonsaiColor.hex(v)

private object Pal {
    val leafSage = hex(0x519E73)
    val leafFresh = hex(0x7BC68C)
    val leafLight = hex(0xA9D4A8)
    val barkDeep = hex(0x3E2A1B)
    val barkMid = hex(0x6B4A2E)
    val barkLight = hex(0xA07B52)
    val potDark = hex(0x3B2A1C)
    val potMid = hex(0x5C402A)
    val potRim = hex(0x2C1F14)
    val soilDark = hex(0x221710)
    val soilMid = hex(0x3A2A1C)
}

private fun ellipse(cx: Double, cy: Double, rx: Double, ry: Double) =
    BonsaiPath.ellipseIn(cx - rx, cy - ry, rx * 2, ry * 2)

private fun gradient(colors: List<BonsaiColor>, sx: Double, sy: Double, ex: Double, ey: Double) =
    BonsaiInk.Linear(colors, Pt(sx, sy), Pt(ex, ey))

private fun fillRotatedEllipse(
    ctx: BonsaiLayers, cx: Double, cy: Double, rx: Double, ry: Double,
    deg: Double, color: BonsaiColor, opacity: Double = 1.0,
) {
    val g = ctx.copy()
    g.translateBy(cx, cy)
    g.rotate(deg)
    g.fill(BonsaiPath.ellipseIn(-rx, -ry, rx * 2, ry * 2), color.opacity(opacity))
}


// MARK: - Cluster (foliage blob)

private enum class Tone { Sage, Fresh, Autumn, Deep }

private enum class Attach { Crown, UpperLeft, UpperRight, MidLeft, MidRight, LowerRight }

private class ClusterSpec(
    val attach: Attach?,
    val size: Double,
    val seed: Double,
    val tone: Tone = Tone.Sage,
    val sat: Double = 1.0,
    val cx: Double = 300.0,
    val cy: Double = 250.0,
    /** Extra displacement from the attach point, in mature-tree pixels. */
    val offsetW: Double = 0.0,
    val offsetH: Double = 0.0,
)

/** Where a cluster is drawn: its trunk/branch attach point plus its offset, shrunk by `reach`. */
private fun clusterCenter(c: ClusterSpec, trunk: TrunkResult, reach: Double): Pt {
    val base = c.attach?.let { trunk.attach[it] } ?: Pt(c.cx, c.cy)
    return Pt(base.x + c.offsetW * reach, base.y + c.offsetH * reach)
}

private fun drawCluster(
    cx: Double, cy: Double, size: Double, tone: Tone, saturation: Double, seed: Double, ctx: BonsaiLayers,
) {
    val ink = when (tone) {
        Tone.Sage -> FoliageInk(RGB(0x2F5E45), RGB(0x519E73), RGB(0x7BC68C), RGB(0xA9D4A8))
        Tone.Fresh -> FoliageInk(RGB(0x3B6E4E), RGB(0x6BB57F), RGB(0x9CD39C), RGB(0xC7E5B8))
        Tone.Deep -> FoliageInk(RGB(0x1F4630), RGB(0x2F5E45), RGB(0x519E73), RGB(0x7BC68C))
        // Sunlit late growth from day 180: a yellower green under the same dark outline.
        Tone.Autumn -> FoliageInk(RGB(0x3B6E4E), RGB(0x78B472), RGB(0xA6D394), RGB(0xCFE7B4))
    }
    paintPad(
        ctx, cx, cy, size, size * 0.78, seed * 7.3, ink,
        dry = min(0.7, max(0.0, 1 - saturation) * 1.4), detail = if (size > 10) 1 else 0, flat = 0.5,
    )
}

// MARK: - Pot

private fun drawPot(style: BonsaiStyle, ctx: BonsaiLayers) {
    if (style == BonsaiStyle.Cascade) {
        paintPotFeet(ctx, 228.0, 372.0, 460.0, Pal.potRim)
        // narrower drum pot, soil top at y=378
        val body = BonsaiPath()
        body.move(218.0, 380.0)
        body.line(228.0, 460.0)
        body.line(372.0, 460.0)
        body.line(382.0, 380.0)
        body.close()
        ctx.fill(body, gradient(listOf(Pal.potMid, Pal.potDark), 300.0, 380.0, 300.0, 460.0))

        val shade = BonsaiPath()
        shade.move(300.0, 380.0)
        shade.line(372.0, 460.0)
        shade.line(382.0, 380.0)
        shade.close()
        ctx.fill(shade, Pal.potDark.opacity(0.55))

        ctx.fill(ellipse(300.0, 378.0, 82.0, 7.0), Pal.potRim)
        ctx.fill(ellipse(300.0, 376.0, 82.0, 6.0), Pal.potMid)
        ctx.fill(ellipse(300.0, 377.0, 76.0, 5.0), Pal.soilMid)
        ctx.fill(ellipse(300.0, 378.0, 74.0, 4.0), Pal.soilDark)

        val flecks = listOf(
            doubleArrayOf(262.0, 377.0, 1.4, 0.4) to Pal.barkLight,
            doubleArrayOf(294.0, 378.0, 1.6, 0.5) to Pal.barkMid,
            doubleArrayOf(330.0, 377.0, 1.2, 0.4) to Pal.barkLight,
        )
        for ((f, c) in flecks) ctx.fill(ellipse(f[0], f[1], f[2], f[2]), c.opacity(f[3]))
        return
    }

    // traditional & windswept: wide trapezoid, soil top y=411
    paintPotFeet(ctx, 184.0, 416.0, 460.0, Pal.potRim)
    val body = BonsaiPath()
    body.move(170.0, 415.0)
    body.line(184.0, 460.0)
    body.line(416.0, 460.0)
    body.line(430.0, 415.0)
    body.close()
    ctx.fill(body, gradient(listOf(Pal.potMid, Pal.potDark), 300.0, 415.0, 300.0, 460.0))

    val shade = BonsaiPath()
    shade.move(300.0, 415.0)
    shade.line(416.0, 460.0)
    shade.line(430.0, 415.0)
    shade.close()
    ctx.fill(shade, Pal.potDark.opacity(0.55))

    ctx.fill(ellipse(300.0, 413.0, 130.0, 9.0), Pal.potRim)
    ctx.fill(ellipse(300.0, 411.0, 130.0, 8.0), Pal.potMid)
    ctx.fill(ellipse(300.0, 412.0, 124.0, 6.5), Pal.soilMid)
    ctx.fill(ellipse(300.0, 412.5, 122.0, 5.5), Pal.soilDark)

    val flecks = listOf(
        doubleArrayOf(240.0, 412.0, 1.8, 0.55) to Pal.barkMid, doubleArrayOf(285.0, 413.0, 1.2, 0.4) to Pal.barkLight,
        doubleArrayOf(328.0, 412.0, 1.6, 0.5) to Pal.barkMid, doubleArrayOf(358.0, 413.0, 1.2, 0.35) to Pal.barkLight,
        doubleArrayOf(210.0, 413.0, 1.4, 0.4) to Pal.barkLight,
    )
    for ((f, c) in flecks) ctx.fill(ellipse(f[0], f[1], f[2], f[2]), c.opacity(f[3]))
}

// MARK: - Roots & moss

private fun drawRootsAndMoss(p: Params, style: BonsaiStyle, ctx: BonsaiLayers) {
    val baseY = if (style == BonsaiStyle.Cascade) 378.0 else 411.0
    if (p.exposedRoots > 0) {
        val a = min(1.0, p.exposedRoots)
        val op = 0.6 + 0.4 * a
        class Root(
            val a1: Double, val ya: Double, val a2: Double, val yb: Double,
            val a3: Double, val yc: Double, val color: BonsaiColor, val mul: Double,
        )
        for (r in listOf(
            Root(280.0, baseY, 266.0, baseY - 1, 282.0, baseY + 1, Pal.barkMid, 1.0),
            Root(295.0, baseY, 282.0, baseY - 2, 296.0, baseY + 1, Pal.barkDeep, 0.7),
            Root(312.0, baseY, 330.0, baseY - 1, 312.0, baseY + 1, Pal.barkMid, 1.0),
            Root(322.0, baseY, 338.0, baseY - 2, 320.0, baseY + 1, Pal.barkDeep, 0.7),
        )) {
            val path = BonsaiPath()
            path.move(r.a1, r.ya)
            // bend up then back down to ground
            path.quad(Pt(r.a2, r.yb), Pt((r.a1 + r.a2) / 2, r.yb - 2))
            path.quad(Pt(r.a3, r.yc), Pt((r.a2 + r.a3) / 2, r.yb + 2))
            ctx.fill(path, r.color.opacity(op * r.mul))
        }
    }
    paintSoilMoss(
        ctx, 300.0, baseY, if (style == BonsaiStyle.Cascade) 58.0 else 70.0,
        p.mossOnTrunk, if (style == BonsaiStyle.Windswept) 31.0 else 17.0,
    )
}

// MARK: - Trunks (style-specific)

/** A limb as one quadratic curve, `w` thick where it leaves the trunk. */
private class Bough(val from: Pt, val ctrl: Pt, val to: Pt, val w: Double)

private class TrunkResult(
    val path: BonsaiPath,
    /** Where the trunk meets the soil. */
    val base: Pt,
    val baseW: Double,
    /** Sideways run per unit rise at the base. */
    val lean: Double = 0.0,
    val branches: List<Bough>,
    /** Windswept windward dead wood (jin). */
    val bareBranches: List<Bough>,
    val attach: Map<Attach, Pt>,
    /** Filled and shaded in order; empty means [path]. */
    val parts: List<BonsaiPath> = emptyList(),
    /** Base to tip of the upright stem, for the seed leaves. */
    val spine: List<Pt> = emptyList(),
)

/** How far a part that first grows on day `from` has filled out: buds at 30%, full after three weeks. */
private fun budding(day: Int, from: Int) = 0.3 + 0.7 * smoothstepS(from.toDouble(), from + 21.0, day.toDouble())

/** 0 for the day-8 whip, 1 once the trunk has its adult girth and swing. */
private fun girth(day: Int) = 0.4 + 0.6 * smoothstepS(8.0, 45.0, day.toDouble())
private fun swing(day: Int) = 0.3 + 0.7 * smoothstepS(8.0, 60.0, day.toDouble())

private fun trunkTraditional(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 410.0
    val heightPx = 70 + 230 * p.trunkHeight
    val tipY = baseY - heightPx
    val s = swing(p.day)
    val tipX = baseX + 12 * s
    val baseW = (8 + 44 * p.trunkThickness) * girth(p.day)
    val midW = baseW * 0.6
    val tipW = max(2.4, baseW * 0.25)
    val midY = (baseY + tipY) / 2

    // An S-curve: the lower trunk swings left, the upper trunk back right.
    val stem = listOf(
        Pt(baseX, baseY),
        Pt(baseX - 12 * s, baseY - heightPx * 0.38),
        Pt(baseX + 16 * s, baseY - heightPx * 0.74),
        Pt(tipX, tipY),
    )
    val (pts, widths) = rooted(stem, listOf(baseW, baseW * 0.74, midW * 0.82, tipW), 4 + baseW * 0.6)
    val path = woodRibbon(pts, widths)
    val (spine, ws) = smoothSpine(pts, widths)

    /** The trunk's left or right edge at height `y`. */
    fun edge(y: Double, side: Double): Double {
        for (i in 1 until spine.size) {
            if (spine[i].y <= y) {
                val a = spine[i - 1]
                val b = spine[i]
                val t = (a.y - y) / max(1e-6, a.y - b.y)
                return a.x + (b.x - a.x) * t + side * (ws[i - 1] + (ws[i] - ws[i - 1]) * t) / 2
            }
        }
        return tipX + side * tipW / 2
    }

    // Branch reach grows with the tree (k=1 at day 365). Each limb lengthens from the day it buds.
    val k = p.reach
    val k14 = k * budding(p.day, 14)
    val k30 = k * budding(p.day, 30)
    val k60 = k * budding(p.day, 60)
    val ymid2 = (midY + tipY) / 2
    val b1Start = Pt(edge(midY + 4, -1.0) + 3, midY + 4)
    val b1End = Pt(b1Start.x - 38 * k30, b1Start.y - 26 * k30)
    val b2Start = Pt(edge(ymid2 + 4, 1.0) - 3, ymid2 + 4)
    val b2End = Pt(b2Start.x + 38 * k30, b2Start.y - 34 * k30)
    val b3Start = Pt(edge(baseY - 36, 1.0) - 3, baseY - 36)
    val b3End = Pt(
        b3Start.x + (baseX + baseW / 2 - 2 + 44 * k - b3Start.x) * budding(p.day, 60),
        b3Start.y - 36 * k60,
    )

    val branches = ArrayList<Bough>()
    if (p.day >= 30) {
        val g = budding(p.day, 30)
        branches.add(Bough(b1Start, Pt(b1Start.x - 18 * k30, b1Start.y - 10 * k30), b1End, max(3.0, baseW * 0.22) * (0.6 + 0.4 * g)))
        branches.add(Bough(b2Start, Pt(b2Start.x + 20 * k30, b2Start.y - 18 * k30), b2End, max(2.6, baseW * 0.18) * (0.6 + 0.4 * g)))
    }
    if (p.day >= 60) {
        val g = budding(p.day, 60)
        branches.add(Bough(b3Start, Pt(b3Start.x + 20 * k60, b3Start.y - 18 * k60), b3End, max(2.6, baseW * 0.2) * (0.6 + 0.4 * g)))
    }

    val attach = mapOf(
        Attach.Crown to Pt(tipX, tipY - 8 * k),
        Attach.UpperLeft to b1End,
        Attach.UpperRight to b2End,
        Attach.MidLeft to Pt(edge(midY, -1.0) - 12 * k14, midY - 4 * k14),
        Attach.MidRight to Pt(edge(ymid2, 1.0) + 12 * k14, ymid2 - 6 * k14),
        Attach.LowerRight to b3End,
    )
    return TrunkResult(
        path, Pt(baseX, baseY), baseW, branches = branches, bareBranches = emptyList(), attach = attach, spine = spine,
    )
}

private fun trunkCascade(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 378.0
    val th = p.trunkHeight
    val s = swing(p.day)
    val baseW = (8 + 32 * p.trunkThickness) * girth(p.day)
    val elbowW = baseW * 0.8
    val tipW = max(2.4, baseW * 0.24)

    // One trunk (kengai): a short riser leaning to the left rim, an arch over it, then the fall
    // down the outside of the pot to below its foot. The fall never crosses the pot face.
    val upPx = 28 + 40 * th
    val p0 = Pt(baseX, baseY)
    val p1 = Pt(baseX - 34 * s, baseY - upPx)
    val over = Pt(208 - 6 * th, baseY - 14)
    val full = listOf(
        p1,
        Pt((p1.x + over.x) / 2 - 2, p1.y + 2),
        over,
        Pt(196 - 18 * th, baseY + 20 + 50 * th),
        Pt(204 - 8 * th, baseY + 30 + 130 * th),
    )
    val (dense, _) = smoothSpine(full, List(full.size) { 1.0 }, 12)
    val cum = arrayListOf(0.0)
    for (i in 1 until dense.size) cum.add(cum[i - 1] + hypot(dense[i].x - dense[i - 1].x, dense[i].y - dense[i - 1].y))
    val total = max(1.0, cum.lastOrNull() ?: 1.0)

    /** The point `f` of the way along the full fall. */
    fun along(f: Double): Pt {
        val d = max(0.0, min(1.0, f)) * total
        val i = cum.indexOfFirst { it >= d }
        if (i <= 0) return dense[0]
        val t = (d - cum[i - 1]) / max(1e-6, cum[i] - cum[i - 1])
        return lerpP(dense[i - 1], dense[i], t)
    }
    // The fall grows out of the elbow: over the rim by day 20, down the pot by day 45, then lengthens.
    val grown = 0.03 + 0.97 * smoothstepS(8.0, 45.0, p.day.toDouble())
    val fallPts = ArrayList<Pt>()
    for (i in dense.indices) if (cum[i] < grown * total) fallPts.add(dense[i])
    fallPts.add(along(grown))
    val fallWs = fallPts.indices.map { i ->
        val t = i.toDouble() / max(1, fallPts.size - 1).toDouble()
        elbowW + (tipW - elbowW) * pow(t, 1.2)
    }

    /** A point on the grown fall, riding its tip until the fall reaches it. */
    fun on(f: Double): Pt = along(min(f, grown))

    val (riserPts, riserWs) = rooted(listOf(p0, p1), listOf(baseW, elbowW), 4 + baseW * 0.6)
    val riser = woodRibbon(riserPts, riserWs).intersection(BonsaiPath.rect(0.0, 0.0, 600.0, baseY + 2))
    val fall = woodRibbon(fallPts, fallWs, 1)
    val elbow = BonsaiPath.ellipseIn(p1.x - elbowW / 2, p1.y - elbowW / 2, elbowW, elbowW)
    val fallPart = fall.union(elbow)

    val k = p.reach
    val k14 = k * budding(p.day, 14)
    val k30 = k * budding(p.day, 30)
    val k60 = k * budding(p.day, 60)
    // Pads alternate down the fall: out from the arch, in toward the pot below the rim, then out, in and the tip.
    val ulFrom = on(0.34)
    val urFrom = on(0.56)
    val ulEnd = Pt(ulFrom.x - 34 * k30, ulFrom.y + 4 * k30)
    val urEnd = Pt(urFrom.x + 26 * k30, urFrom.y + 10 * k30)

    val branches = ArrayList<Bough>()
    if (p.day >= 30) {
        val w = 0.6 + 0.4 * budding(p.day, 30)
        branches.add(Bough(ulFrom, Pt(ulFrom.x - 18 * k30, ulFrom.y - 6 * k30), ulEnd, max(2.6, baseW * 0.2) * w))
        branches.add(Bough(urFrom, Pt(urFrom.x + 12 * k30, urFrom.y - 2 * k30), urEnd, max(2.4, baseW * 0.17) * w))
    }

    val mid = on(0.76)
    val low = on(0.9)
    val tip = on(1.0)
    val attach = mapOf(
        Attach.Crown to Pt(p1.x + 6 * k, p1.y - 14 * k),
        Attach.UpperLeft to Pt(ulEnd.x, ulEnd.y - 8 * k30),
        Attach.UpperRight to Pt(urEnd.x, urEnd.y - 6 * k30),
        Attach.MidLeft to Pt(mid.x - 20 * k14, mid.y - 6 * k14),
        Attach.MidRight to Pt(low.x + 18 * k14, low.y - 4 * k14),
        Attach.LowerRight to Pt(tip.x - 4 * k60, tip.y + 6 * k60),
    )
    return TrunkResult(
        riser.union(fallPart), p0, baseW, branches = branches, bareBranches = emptyList(), attach = attach,
        parts = listOf(riser, fallPart), spine = listOf(p0, p1),
    )
}

private fun trunkWindswept(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 410.0
    val heightPx = 70 + 220 * p.trunkHeight
    // The lean sets in as the whip hardens, from the day-7 sprout's upright.
    val s = swing(p.day)
    val leanRad = 18.0 * s * Math.PI / 180
    val tipX = baseX + sin(leanRad) * heightPx + 8 * s
    val tipY = baseY - cos(leanRad) * heightPx
    val baseW = (8 + 40 * p.trunkThickness) * girth(p.day)
    val midW = baseW * 0.55
    val tipW = max(2.4, baseW * 0.22)
    val midX = (baseX + tipX) / 2 + 14 * s
    val midY = (baseY + tipY) / 2 + 4

    // Starts below the soil line, straight on along the lean, so the base reads as planted.
    val lean = (midX - baseX) / (baseY - midY)
    val depth = 4 + baseW * 0.6
    val pts = listOf(
        Pt(baseX - depth * lean, baseY + depth),
        Pt(baseX, baseY),
        Pt(midX, midY),
        Pt(tipX, tipY),
    )
    val widths = listOf(baseW * 1.04, baseW, midW * 1.05, tipW)
    val path = woodRibbon(pts, widths)

    val k = p.reach
    val k14 = k * budding(p.day, 14)
    val k30 = k * budding(p.day, 30)
    val k60 = k * budding(p.day, 60)

    // Bare windward (left) branches: decorative dead wood, scaled with growth.
    val bare = ArrayList<Bough>()
    if (p.day >= 67) {
        val g = budding(p.day, 67)
        val kb = k * g
        val bareSize = max(3.0, baseW * 0.22) * (0.6 + 0.4 * g)
        val s1 = Pt((baseX + midX) / 2, (baseY + midY) / 2)
        bare.add(
            Bough(
                s1,
                Pt(s1.x + (baseX - 18 - s1.x) * kb, s1.y + (baseY - 80 - s1.y) * kb),
                Pt(s1.x + (baseX - 44 - s1.x) * kb, s1.y + (baseY - 92 - s1.y) * kb), bareSize,
            ),
        )
        val s2 = Pt(midX - 4, midY + 4)
        bare.add(Bough(s2, Pt(s2.x - 26 * kb, s2.y - 22 * kb), Pt(s2.x - 52 * kb, s2.y - 32 * kb), bareSize * 0.85))
        // Starts on the trunk's centre line; the tip keeps its old target.
        val s3 = Pt(midX - 18, midY - 4)
        bare.add(Bough(Pt(midX - 2, midY - 4), Pt(s3.x - 22 * kb, s3.y - 2 * kb), Pt(s3.x - 42 * kb, s3.y + 2 * kb), bareSize * 0.7))
    }

    // Leeward (right) heavy branches into the foliage.
    val branches = ArrayList<Bough>()
    if (p.day >= 30) {
        val w = 0.6 + 0.4 * budding(p.day, 30)
        val s1 = Pt(midX + 2, midY - 2)
        branches.add(Bough(s1, Pt(s1.x + 24 * k30, s1.y - 12 * k30), Pt(s1.x + 46 * k30, s1.y - 26 * k30), max(3.0, baseW * 0.22) * w))
        val s2 = Pt(tipX - 6, tipY + 6)
        branches.add(Bough(s2, Pt(s2.x + 24 * k30, s2.y - 10 * k30), Pt(s2.x + 48 * k30, s2.y - 20 * k30), max(2.6, baseW * 0.18) * w))
    }

    val attach = mapOf(
        Attach.Crown to Pt(tipX + 24 * k, tipY - 10 * k),
        Attach.UpperLeft to Pt(tipX + 14 * k30, tipY + 4 * k30),
        Attach.UpperRight to Pt(tipX + 56 * k30, tipY),
        Attach.MidLeft to Pt(midX + 24 * k14, midY - 16 * k14),
        Attach.MidRight to Pt(midX + 56 * k14, midY - 12 * k14),
        Attach.LowerRight to Pt(midX + 70 * k60, midY + 14 * k60),
    )
    return TrunkResult(
        path, Pt(baseX, baseY), baseW, lean = lean, branches = branches, bareBranches = bare, attach = attach,
        spine = pts.drop(1),
    )
}

private fun buildTrunk(p: Params, style: BonsaiStyle): TrunkResult = when (style) {
    BonsaiStyle.Cascade -> trunkCascade(p)
    BonsaiStyle.Windswept -> trunkWindswept(p)
    // Sakura/Maple/Pine each have their own render path and never reach this pipeline.
    else -> trunkTraditional(p)
}

// MARK: - Params (pure continuous function of day)

private class Params(
    val day: Int,
    val trunkHeight: Double,
    val trunkThickness: Double,
    val trunkGnarl: Double,
    val leafSaturation: Double,
    val mossOnTrunk: Double,
    val exposedRoots: Double,
    /** 0 to 1 canopy growth factor (1 at day 365). */
    val reach: Double,
    val clusters: List<ClusterSpec>,
)

private fun lerp(a: Double, b: Double, t: Double) = a + (b - a) * t

private fun eased(day: Int): Double {
    if (day >= 365) return 1.0
    val t = day / 365.0
    return 1 - pow(1 - t, 1.6)
}

private fun paramsForDay(day: Int, style: BonsaiStyle): Params {
    val e = eased(day)
    // Height starts low so day 8 stands about as tall as the day-7 sprout.
    val trunkHeight = lerp(0.04, 0.86, e)
    val trunkThickness = lerp(0.14, if (style == BonsaiStyle.Cascade) 0.82 else 0.90, e)
    val trunkGnarl = max(0.0, (day - 21).toDouble() / (365 - 21).toDouble())
    val leafSaturation = if (day < 14) lerp(0.85, 0.95, day / 14.0)
    else lerp(0.95, 1.0, (day - 14).toDouble() / (365 - 14).toDouble())
    val mossOnTrunk = if (day < 60) 0.0 else min(1.0, (day - 60).toDouble() / (365 - 60).toDouble())
    val exposedRoots = if (day < 21) 0.0 else min(1.0, (day - 21).toDouble() / (180 - 21).toDouble())

    val sizeBase = lerp(14.0, 82.0, e)
    val clusters = ArrayList<ClusterSpec>()
    // The cascade's sprout is drawn small, so its crown starts small too.
    val cas = style == BonsaiStyle.Cascade
    val crownK = if (cas) 0.55 + 0.45 * smoothstepS(8.0, 45.0, day.toDouble()) else 1.0
    // The cascade's foliage is smaller pads strung down its fall.
    fun pick(k: Double, cascade: Double) = if (cas) cascade else k
    clusters.add(
        ClusterSpec(Attach.Crown, (sizeBase * crownK * pick(1.0, 0.6)).swiftRounded(), 1.0, if (day < 21) Tone.Fresh else Tone.Sage),
    )
    // Each pad buds small on its day and fills out over the next three weeks.
    fun bud(k: Double, from: Int) = (sizeBase * k * budding(day, from)).swiftRounded()
    if (day >= 14) {
        clusters.add(ClusterSpec(Attach.MidLeft, bud(pick(0.55, 0.42), 14), 2.0, Tone.Fresh))
        clusters.add(ClusterSpec(Attach.MidRight, bud(pick(0.52, 0.36), 14), 3.0, Tone.Sage))
    }
    if (day >= 30) {
        clusters.add(ClusterSpec(Attach.UpperLeft, bud(pick(0.75, 0.5), 30), 4.0, Tone.Fresh))
        clusters.add(ClusterSpec(Attach.UpperRight, bud(pick(0.72, 0.42), 30), 5.0, Tone.Sage))
    }
    if (day >= 60) {
        clusters.add(ClusterSpec(Attach.LowerRight, bud(pick(0.5, 0.3), 60), 6.0, Tone.Sage))
    }
    // Ambient canopy fillers anchored to trunk attach points.
    if (day >= 90) {
        clusters.add(
            ClusterSpec(
                Attach.Crown, bud(pick(0.42, 0.34), 90), 7.0, Tone.Fresh,
                offsetW = if (cas) -30.0 else -12.0, offsetH = if (cas) 8.0 else 32.0,
            ),
        )
    }
    if (day >= 180) {
        clusters.add(ClusterSpec(Attach.MidRight, bud(pick(0.28, 0.22), 180), 8.0, Tone.Autumn, offsetW = 16.0, offsetH = 12.0))
    }
    if (day >= 270) {
        clusters.add(ClusterSpec(Attach.MidLeft, bud(pick(0.28, 0.22), 270), 9.0, Tone.Autumn, offsetW = -14.0, offsetH = -8.0))
    }

    return Params(
        day, trunkHeight, trunkThickness, trunkGnarl, leafSaturation, mossOnTrunk, exposedRoots,
        sizeBase / 82, clusters,
    )
}

// MARK: - Early stages (days 0 to 7)

private fun drawEarly(day: Int, style: BonsaiStyle, outer: BonsaiLayers) {
    val baseY = if (style == BonsaiStyle.Cascade) 378.0 else 410.0
    val cx = 300.0
    val ctx = outer.copy()
    if (style == BonsaiStyle.Cascade) {
        // Shrink the sprout so day 7 hands off smoothly to the cascade's short riser on day 8.
        ctx.translateBy(cx, baseY)
        ctx.scaleBy(0.45, 0.45)
        ctx.translateBy(-cx, -baseY)
    }
    fun stem(width: Double, color: BonsaiColor, build: BonsaiPath.() -> Unit) {
        ctx.stroke(BonsaiPath().apply(build), color, width, BonsaiCap.Round)
    }
    when (day) {
        0 -> {
            ctx.fill(ellipse(cx, baseY + 1, 22.0, 3.5), Pal.barkDeep.opacity(0.55))
            ctx.fill(ellipse(cx + 1, baseY - 2, 7.0, 4.0), Pal.barkMid)
            ctx.fill(ellipse(cx - 0.5, baseY - 3, 4.5, 2.6), Pal.barkLight.opacity(0.85))
            ctx.fill(ellipse(cx - 1.5, baseY - 3.5, 2.0, 1.2), hex(0xE0BD8E).opacity(0.7))
        }
        1 -> {
            ctx.fill(ellipse(cx, baseY + 1, 14.0, 2.4), Pal.barkDeep.opacity(0.5))
            stem(3.2, Pal.leafSage) { move(cx - 0.5, baseY - 1); quad(Pt(cx + 0.5, baseY - 16), Pt(cx + 0.5, baseY - 9)) }
            fillRotatedEllipse(ctx, cx + 0.5, baseY - 18, 5.0, 3.0, -12.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 0.5, baseY - 19, 3.0, 1.8, -12.0, Pal.leafLight, 0.8)
        }
        2 -> {
            ctx.fill(ellipse(cx, baseY + 1, 14.0, 2.4), Pal.barkDeep.opacity(0.5))
            stem(2.8, Pal.leafSage) { move(cx, baseY); quad(Pt(cx + 1, baseY - 20), Pt(cx + 1, baseY - 14)) }
            fillRotatedEllipse(ctx, cx - 5, baseY - 20, 6.0, 3.4, -26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 5, baseY - 21, 6.0, 3.4, 26.0, Pal.leafFresh)
        }
        3 -> {
            val stemH = 22.0
            stem(2.2, Pal.leafFresh) { move(cx, baseY); quad(Pt(cx, baseY - stemH), Pt(cx + 1, baseY - stemH * 0.5)) }
            fillRotatedEllipse(ctx, cx - 9, baseY - stemH - 1, 10.0, 5.0, -22.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 11, baseY - stemH - 3, 6.0, 3.0, -22.0, Pal.leafLight, 0.8)
            fillRotatedEllipse(ctx, cx + 9, baseY - stemH - 1, 10.0, 5.0, 22.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 11, baseY - stemH - 3, 6.0, 3.0, 22.0, Pal.leafLight, 0.8)
        }
        4 -> {
            val stemH = 32.0
            stem(2.4, Pal.leafFresh) { move(cx, baseY); quad(Pt(cx, baseY - stemH), Pt(cx + 1.5, baseY - stemH * 0.5)) }
            fillRotatedEllipse(ctx, cx - 10, baseY - 16, 11.0, 5.0, -26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 10, baseY - 16, 11.0, 5.0, 26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 4, baseY - stemH - 1, 5.0, 3.0, -12.0, Pal.leafLight)
            fillRotatedEllipse(ctx, cx + 5, baseY - stemH - 1, 5.0, 3.0, 12.0, Pal.leafLight)
        }
        5 -> {
            val stemH = 42.0
            stem(2.6, Pal.leafSage) { move(cx, baseY); quad(Pt(cx + 1, baseY - stemH), Pt(cx + 2, baseY - stemH * 0.5)) }
            fillRotatedEllipse(ctx, cx - 10, baseY - 18, 11.0, 5.0, -30.0, Pal.leafSage, 0.9)
            fillRotatedEllipse(ctx, cx + 10, baseY - 18, 11.0, 5.0, 30.0, Pal.leafSage, 0.9)
            fillRotatedEllipse(ctx, cx - 6, baseY - stemH - 2, 7.0, 3.4, -18.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 7, baseY - stemH - 1, 7.0, 3.4, 18.0, Pal.leafFresh)
            ctx.fill(ellipse(cx + 1, baseY - stemH - 5, 5.0, 3.0), Pal.leafLight)
        }
        6 -> {
            val stemH = 58.0
            stem(2.8, Pal.barkLight) { move(cx, baseY); quad(Pt(cx + 1, baseY - stemH), Pt(cx - 1, baseY - stemH * 0.5)) }
            fillRotatedEllipse(ctx, cx - 9, baseY - 26, 10.0, 4.0, -26.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx + 10, baseY - 38, 10.0, 4.0, 26.0, Pal.leafSage)
            drawCluster(cx + 1, baseY - stemH - 3, 12.0, Tone.Fresh, 0.9, 6.0, ctx)
        }
        else -> { // 7
            val stemH = 78.0
            stem(3.2, Pal.barkLight) {
                move(cx, baseY)
                quad(Pt(cx + 1, baseY - stemH * 0.7), Pt(cx - 2, baseY - stemH * 0.4))
                quad(Pt(cx + 2, baseY - stemH), Pt(cx + 3, baseY - stemH * 0.9))
            }
            fillRotatedEllipse(ctx, cx - 10, baseY - 38, 10.0, 4.0, -22.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx + 11, baseY - 54, 10.0, 4.0, 22.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx - 9, baseY - 68, 9.0, 3.8, -26.0, Pal.leafFresh)
            drawCluster(cx + 2, baseY - stemH - 2, 14.0, Tone.Fresh, 0.9, 7.0, ctx)
        }
    }
}

private fun clamp01(x: Double) = if (x < 0) 0.0 else if (x > 1) 1.0 else x

private fun smoothstepS(e0: Double, e1: Double, x: Double): Double {
    val t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)
}

private fun ramp(day: Double, start: Double, end: Double, power: Double) = pow(clamp01((day - start) / (end - start)), power)

private fun lerpP(a: Pt, b: Pt, t: Double) = Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)

private fun rand01(seed: Double, n: Double) = bonsaiNoise(seed, n)

// MARK: - Sakura (cherry-blossom) bonsai
//
// A self-contained render path used when `style == Sakura`: a single-fork trunk carrying blossom
// pads, falling petals, and its own celadon-glazed pot. A continuous function of day from 0 to 365.

private object SakuraPal {
    val bloomMid = hex(0xF2B2CD)
    val bloomLight = hex(0xFBD7E6)
    val center = hex(0xF2C773)
    val barkDeep = hex(0x4A3526)
    val barkMid = hex(0x7C5B45)
    val barkLight = hex(0xAD8C70)
    val lenticel = hex(0x5A4233)
    val potDark = hex(0x5E7E6F)
    val potMid = hex(0x8AAE9C)
    val potLight = hex(0xBDD6C7)
    val potRim = hex(0x4C6A5C)
    val potGlaze = hex(0xD6E7DC)
    val soilDark = hex(0x221710)
    val soilMid = hex(0x3A2A1C)
}

private fun sakuraScale(d: Int) = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun sakuraBark(d: Int) = smoothstepS(70.0, 400.0, d.toDouble())
private fun sakuraPetalAmt(d: Int) = ramp(d.toDouble(), 45.0, 365.0, 1.0)

private class Canopy(
    val cX: Double, val cY: Double, val rx: Double, val ry: Double,
    val forkX: Double, val forkY: Double, val g: Double, val baseW: Double,
)

private fun sakuraCanopy(day: Int): Canopy {
    val baseY = 410.0
    val g = sakuraScale(day)
    // The trunk forks low and the crown rides above the fork.
    val forkLen = 10 + 130 * g
    val forkY = baseY - forkLen
    val forkX = 303.0
    val rx = 8 + 138 * g
    val ry = 5 + 62 * g
    val baseW = 2.5 + 46 * g
    return Canopy(forkX, forkY - ry * 0.9, rx, ry, forkX, forkY, g, baseW)
}

private class CanopyLimb(val a: Double, val r: Double, val s: Double, val seed: Double, val app: Double, val span: Double)

private val sakuraLimbs = listOf(
    CanopyLimb(90.0, 0.08, 1.00, 1.0, 0.0, 1.0),
    CanopyLimb(124.0, 0.48, 0.90, 2.0, 7.0, 16.0),
    CanopyLimb(56.0, 0.48, 0.90, 3.0, 13.0, 16.0),
    CanopyLimb(150.0, 0.70, 0.80, 4.0, 22.0, 18.0),
    CanopyLimb(30.0, 0.70, 0.80, 5.0, 31.0, 18.0),
    CanopyLimb(96.0, 0.56, 0.78, 6.0, 42.0, 16.0),
    CanopyLimb(112.0, 0.80, 0.70, 7.0, 54.0, 18.0),
    CanopyLimb(67.0, 0.80, 0.70, 8.0, 67.0, 18.0),
    CanopyLimb(20.0, 0.62, 0.66, 9.0, 84.0, 20.0),
    CanopyLimb(160.0, 0.62, 0.66, 10.0, 104.0, 20.0),
    CanopyLimb(44.0, 0.40, 0.66, 11.0, 126.0, 20.0),
    CanopyLimb(136.0, 0.40, 0.66, 12.0, 150.0, 20.0),
    CanopyLimb(80.0, 0.70, 0.62, 13.0, 178.0, 22.0),
    CanopyLimb(104.0, 0.68, 0.62, 14.0, 210.0, 22.0),
    CanopyLimb(38.0, 0.82, 0.56, 15.0, 248.0, 24.0),
    CanopyLimb(146.0, 0.82, 0.56, 16.0, 290.0, 24.0),
    CanopyLimb(90.0, 0.74, 0.58, 17.0, 332.0, 24.0),
)

private class CanopyTuft(val ang: Double, val rad: Double, val app: Double, val sz: Double, val span: Double, val seed: Double)

private val sakuraTufts: List<CanopyTuft> = run {
    val n = 38
    (0 until n).map { i ->
        val u = rand01(700.0, (i + 1).toDouble())
        val v = rand01(810.0, (i + 1).toDouble())
        CanopyTuft(
            ang = Math.PI * (0.07 + 0.86 * u),
            rad = 0.06 + 0.70 * sqrt(v),
            app = 2 + pow(i.toDouble() / n, 0.92) * 356,
            sz = 0.48 + 0.42 * rand01(920.0, (i + 1).toDouble()),
            span = 9 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
            seed = 200.0 + i,
        )
    }
}

// A soft painterly blossom cluster (shadow, mid, lit clumps, highlights).
private val sakuraInk = FoliageInk(RGB(0xD98AAE), RGB(0xEFA6C4), RGB(0xF9CFE0), RGB(0xFFF4F8))

private fun sakuraCluster(ctx: BonsaiLayers, cx: Double, cy: Double, size: Double, seed: Double, squashY: Double, detail: Int) {
    paintPad(ctx, cx, cy, size, size * squashY, seed, sakuraInk, detail = detail, flat = 0.3)
}

private fun drawSakuraPot(ctx: BonsaiLayers) {
    paintPotFeet(ctx, 184.0, 416.0, 460.0, SakuraPal.potRim)
    val body = BonsaiPath()
    body.move(170.0, 415.0)
    body.line(184.0, 460.0)
    body.line(416.0, 460.0)
    body.line(430.0, 415.0)
    body.close()
    ctx.fill(body, gradient(listOf(SakuraPal.potMid, SakuraPal.potDark), 300.0, 415.0, 300.0, 460.0))

    val glaze = BonsaiPath()
    glaze.move(182.0, 417.0)
    glaze.line(196.0, 452.0)
    glaze.line(268.0, 452.0)
    glaze.line(260.0, 417.0)
    glaze.close()
    ctx.fill(glaze, SakuraPal.potGlaze.opacity(0.30))

    val shade = BonsaiPath()
    shade.move(300.0, 415.0)
    shade.line(416.0, 460.0)
    shade.line(430.0, 415.0)
    shade.close()
    ctx.fill(shade, SakuraPal.potDark.opacity(0.45))

    val rim = BonsaiPath()
    rim.move(184.0, 460.0)
    rim.line(416.0, 460.0)
    rim.line(408.0, 456.0)
    rim.line(192.0, 456.0)
    rim.close()
    ctx.fill(rim, SakuraPal.potRim.opacity(0.55))

    ctx.fill(ellipse(300.0, 413.0, 130.0, 9.0), SakuraPal.potRim)
    ctx.fill(ellipse(300.0, 411.0, 130.0, 8.0), SakuraPal.potMid)
    ctx.fill(ellipse(300.0, 410.0, 126.0, 6.5), SakuraPal.potLight.opacity(0.7))
    ctx.fill(ellipse(300.0, 412.0, 124.0, 6.5), SakuraPal.soilMid)
    ctx.fill(ellipse(300.0, 412.5, 122.0, 5.5), SakuraPal.soilDark)
    ctx.fill(ellipse(240.0, 412.0, 1.8, 1.8), SakuraPal.barkMid.opacity(0.5))
    ctx.fill(ellipse(328.0, 412.0, 1.6, 1.6), SakuraPal.barkMid.opacity(0.45))
    ctx.fill(ellipse(285.0, 413.0, 1.2, 1.2), SakuraPal.barkLight.opacity(0.4))
}

private class ForkTrunk(val path: BonsaiPath, val wood: BonsaiPath, val at: (Double) -> Pair<Pt, Double>)

/** A trunk from the soil at (300, baseY) to the fork, bowing left by `bend`. */
private fun forkTrunk(baseY: Double, forkX: Double, forkY: Double, bend: Double, baseW: Double, topW: Double): ForkTrunk {
    val at: (Double) -> Pair<Pt, Double> = { t ->
        forkSpine(baseY, forkX, forkY, bend, t) to (topW + (baseW - topW) * pow(1 - t, 1.7))
    }
    val samples = (0..6).map { at(it / 6.0) }
    val (pts, ws) = rooted(samples.map { it.first }, samples.map { it.second }, 4 + baseW * 0.6)
    val path = woodRibbon(pts, ws, 3)
    return ForkTrunk(path, path.union(nebariPath(300.0, baseY, baseW, 1.0)), at)
}

/** A point on that trunk's centre line, `t` 0 at the soil to 1 at the fork. */
private fun forkSpine(baseY: Double, forkX: Double, forkY: Double, bend: Double, t: Double): Pt {
    val u = 1 - t
    val cx = 300 - 2 * bend
    val cy = (baseY + forkY) / 2
    return Pt(u * u * 300 + 2 * u * t * cx + t * t * forkX, u * u * baseY + 2 * u * t * cy + t * t * forkY)
}

/** Where a crown limb leaves the trunk: upright limbs at the fork, side limbs a little lower. */
private fun limbStart(angleDeg: Double, baseY: Double, forkX: Double, forkY: Double, bend: Double): Pt {
    val t = 1 - 0.3 * (1 - sin(angleDeg * Math.PI / 180))
    return forkSpine(baseY, forkX, forkY, bend, t)
}

private fun drawSakuraTrunk(day: Int, c: Canopy, ctx: BonsaiLayers) {
    val baseY = 410.0
    val topW = max(2.2, c.baseW * 0.28)
    val trunk = forkTrunk(baseY, c.forkX, c.forkY, 2 + 7 * c.g, c.baseW, topW)
    val g = ctx.copy()
    g.clip(BonsaiPath.rect(0.0, 0.0, 600.0, baseY + 2))
    val tb = trunk.wood.boundingRect()
    g.fill(trunk.wood, gradient(listOf(SakuraPal.barkLight, SakuraPal.barkMid, SakuraPal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY))
    shadeWood(g, trunk.path, c.baseW * 0.7, SakuraPal.barkDeep, SakuraPal.barkLight)

    // Cherry bark: short horizontal lenticels.
    val lc = sakuraBark(day)
    if (lc > 0.05 && c.baseW > 14) {
        val lines = g.copy()
        lines.clip(trunk.path)
        val rows = (3 + 6 * lc).swiftRounded().toInt()
        for (i in 0 until rows) {
            val t = 0.08 + 0.8 * i / max(1, rows - 1).toDouble()
            val (pt, w) = trunk.at(t)
            val off = (bonsaiNoise(77.0, i.toDouble()) - 0.5) * w * 0.4
            val line = BonsaiPath()
            line.move(pt.x + off - w * 0.22, pt.y)
            line.line(pt.x + off + w * 0.22, pt.y)
            lines.stroke(line, SakuraPal.lenticel.opacity(0.45 * lc), 1.6, BonsaiCap.Round)
        }
    }
}

/** A petal of size `s` at (x, y), turned `rotDeg`. */
private fun sakuraPetal(x: Double, y: Double, s: Double, rotDeg: Double): BonsaiPath {
    val p = BonsaiPath()
    p.move(0.0, -s)
    p.quad(Pt(s * 0.5, s * 0.62), Pt(s, -s * 0.35))
    p.quad(Pt(0.0, s * 0.5), Pt(s * 0.18, s * 0.18))
    p.quad(Pt(-s * 0.5, s * 0.62), Pt(-s * 0.18, s * 0.18))
    p.quad(Pt(0.0, -s), Pt(-s, -s * 0.35))
    p.close()
    return p.applying(Affine().translatedBy(x, y).rotated(rotDeg * Math.PI / 180))
}

/** The petals lying on the soil, which never move. */
private fun drawSakuraFallen(day: Int, ctx: BonsaiLayers) {
    val amt = sakuraPetalAmt(day)
    if (amt < 0.02) return
    val fallN = (amt * 30).swiftRounded().toInt()
    for (i in 0 until fallN) {
        val h1 = rand01(71.0, (i + 1).toDouble())
        val h2 = rand01(89.0, (i + 3).toDouble())
        ctx.fill(
            sakuraPetal(300 + (h1 - 0.5) * 158, 408.5 + h2 * 5.5, 3 + rand01(53.0, i.toDouble()) * 2, (h1 - 0.5) * 120),
            (if (h2 > 0.5) SakuraPal.bloomLight else SakuraPal.bloomMid).opacity(0.92),
        )
    }
}

/** The petals in mid-air, each on its own fall, worked out every frame. */
private fun drawSakuraAir(day: Int, c: Canopy, wind: BonsaiWind?, ctx: BonsaiAirCanvas) {
    val amt = sakuraPetalAmt(day)
    if (amt < 0.02) return
    val airN = (amt * 12).swiftRounded().toInt()
    for (i in 0 until airN) {
        val h1 = rand01(131.0, (i + 1).toDouble())
        val h2 = rand01(167.0, (i + 5).toDouble())
        val h3 = rand01(199.0, (i + 9).toDouble())
        val top = c.cY + c.ry * 0.5
        val y0 = top + h2 * (430 - top)
        val x0 = c.cX + (h1 - 0.5) * c.rx * 2.0
        val color = if (h3 > 0.5) SakuraPal.bloomLight else SakuraPal.bloomMid
        if (wind == null) {
            ctx.fill(sakuraPetal(x0, min(y0, 432.0), 3 + h3 * 2.4, (h1 - 0.5) * 150), color.opacity(0.85))
            continue
        }
        // Lands on the soil inside the pot, where the fallen petals lie.
        val f = wind.fall(h2, h3, c.cX + (h1 - 0.5) * c.rx * 1.6, top, 409 + 5 * h3, (h1 - 0.5) * 150)
        ctx.fill(sakuraPetal(f.x, f.y, 3 + h3 * 2.4, f.rotDeg), color.opacity(0.85 * f.opacity))
    }
}

private class Blossom(val tx: Double, val ty: Double, val size: Double, val seed: Double, val accent: Boolean, val light: Boolean)

private class LimbItem(val limb: CanopyLimb, val e: Double, val tx: Double, val ty: Double, val size: Double)

private fun canopyLimbItems(limbs: List<CanopyLimb>, c: Canopy, day: Int, padBase: Double): List<LimbItem> {
    val items = ArrayList<LimbItem>()
    for (l in limbs) {
        val e = if (l.app == 0.0) 1.0 else smoothstepS(l.app, l.app + l.span, day.toDouble())
        if (e < 0.02) continue
        val ar = l.a * Math.PI / 180
        val tx = c.cX + cos(ar) * c.rx * l.r * e
        val ty = c.cY - sin(ar) * c.ry * l.r * e
        // Every pad has wood under it, the leader included.
        items.add(LimbItem(l, e, tx, ty, padBase * l.s * (0.6 + 0.4 * e)))
    }
    return items
}

private fun sakuraScene(day: Int): BonsaiScene {
    val c = sakuraCanopy(day)
    val padBase = 6 + 34 * c.g
    val pivot = Pt(c.forkX, 410.0)
    val limbItems = canopyLimbItems(sakuraLimbs, c, day, padBase)

    val ctx = BonsaiLayers()
    drawSakuraPot(ctx)
    paintSoilMoss(ctx, 300.0, 410.0, 70.0, sakuraBark(day), 23.0)
    val plant = ctx.copy()
    plant.move(BonsaiMotion.Bent)

    // Branches sit behind the trunk, painted back-to-front (lowest on screen first).
    for (it in limbItems.sortedByDescending { it.ty }) {
        val ar = it.limb.a * Math.PI / 180
        val st = limbStart(it.limb.a, 410.0, c.forkX, c.forkY, 2 + 7 * c.g)
        val tip = Pt(it.tx, it.ty)
        val mx = (st.x + it.tx) / 2 - sin(ar) * 5 * c.g
        val my = (st.y + it.ty) / 2 - 8 * c.g * it.e
        val w = max(1.8, c.baseW * 0.24 * (0.4 + 0.6 * it.e))
        val b = boughPath(st, Pt(mx, my), tip, w, max(1.2, w * 0.35))
        val limb = plant.copy()
        limb.move(BonsaiMotion.Limb(st, tip))
        limb.fill(b, SakuraPal.barkMid)
        shadeWood(limb, b, w, SakuraPal.barkDeep, SakuraPal.barkLight)
    }

    drawSakuraTrunk(day, c, plant)

    val blossoms = ArrayList<Blossom>()
    for (it in limbItems) blossoms.add(Blossom(it.tx, it.ty, it.size, it.limb.seed, it.limb.seed.toInt() % 3 == 0, false))
    for (t in sakuraTufts) {
        val e = smoothstepS(t.app, t.app + t.span, day.toDouble())
        if (e < 0.02) continue
        val rr = t.rad * (0.35 + 0.65 * e)
        val tx = c.cX + cos(t.ang) * c.rx * rr
        val ty = c.cY - sin(t.ang) * c.ry * rr
        blossoms.add(Blossom(tx, ty, padBase * t.sz * (0.6 + 0.4 * e), t.seed, false, true))
    }

    for (it in blossoms.sortedByDescending { it.ty }) {
        val g = plant.copy()
        g.move(BonsaiMotion.Drift(Pt(it.tx, it.ty)))
        sakuraCluster(g, it.tx, it.ty, it.size, it.seed * 5 + 2, 0.8, if (it.size > 10) 1 else 0)
        if (c.g > 0.45 && it.accent) {
            g.fill(
                ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                SakuraPal.center.opacity(0.4),
            )
        }
    }

    drawSakuraFallen(day, ctx)
    return BonsaiScene(ctx, pivot) { g, wind -> drawSakuraAir(day, c, wind, g) }
}

/** Tight content box for the sakura, in the 600x600 design space, used by `BonsaiView(fill:)`. */
fun sakuraContentRect(day: Int): BRect {
    val d = min(365, max(0, day))
    val c = sakuraCanopy(d)
    val padBase = 6 + 34 * c.g
    var minX = 170.0
    var maxX = 430.0
    var minY = 410.0
    val maxY = 466.0 // pot feet always anchor the bottom
    minX = min(minX, c.cX - c.rx - padBase)
    maxX = max(maxX, c.cX + c.rx + padBase)
    minY = min(minY, c.cY - c.ry - padBase * 1.3)
    return floorRect(BRect(minX, minY, maxX - minX, maxY - minY))
}

/** Floor on each dimension so young plants don't over-zoom; height grows upward only. */
private fun floorRect(r: BRect): BRect {
    var rect = r
    val minDim = 230.0
    if (rect.width < minDim) rect = rect.insetBy(-(minDim - rect.width) / 2, 0.0)
    if (rect.height < minDim) rect = BRect(rect.minX, rect.maxY - minDim, rect.width, minDim)
    return rect
}

// MARK: - Maple (Japanese maple) bonsai

private object MaplePal {
    val folLight = hex(0xE87B33)
    val folMid = hex(0xC8472A)
    val folHi = hex(0xF4B24B)
    val folEmber = hex(0x9E3320)
    val barkDeep = hex(0x43342B)
    val barkMid = hex(0x6E594A)
    val barkLight = hex(0x9C8676)
    val barkStripe = hex(0x574539)
    val potDark = hex(0x26282B)
    val potMid = hex(0x3C4045)
    val potLight = hex(0x565C63)
    val potRim = hex(0x1A1B1D)
    val potGlaze = hex(0x6B7178)
    val soilDark = hex(0x211712)
    val soilMid = hex(0x37281D)
}

private fun mapleScale(d: Int) = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun mapleBark(d: Int) = smoothstepS(70.0, 400.0, d.toDouble())
private fun mapleFall(d: Int) = ramp(d.toDouble(), 55.0, 365.0, 1.0)

private fun mapleCanopy(day: Int): Canopy {
    val baseY = 410.0
    val g = mapleScale(day)
    val forkLen = 12 + 146 * g
    val forkY = baseY - forkLen
    val forkX = 304.0
    val rx = 8 + 132 * g
    val ry = 6 + 74 * g
    val baseW = 2.4 + 42 * g
    return Canopy(forkX, forkY - ry * 0.8, rx, ry, forkX, forkY, g, baseW)
}

private val mapleLimbs = listOf(
    CanopyLimb(90.0, 0.10, 1.00, 1.0, 0.0, 1.0),
    CanopyLimb(120.0, 0.46, 0.88, 2.0, 7.0, 16.0),
    CanopyLimb(60.0, 0.46, 0.88, 3.0, 13.0, 16.0),
    CanopyLimb(142.0, 0.66, 0.78, 4.0, 22.0, 18.0),
    CanopyLimb(38.0, 0.66, 0.78, 5.0, 31.0, 18.0),
    CanopyLimb(96.0, 0.62, 0.80, 6.0, 42.0, 16.0),
    CanopyLimb(108.0, 0.84, 0.70, 7.0, 54.0, 18.0),
    CanopyLimb(72.0, 0.84, 0.70, 8.0, 67.0, 18.0),
    CanopyLimb(26.0, 0.58, 0.66, 9.0, 84.0, 20.0),
    CanopyLimb(154.0, 0.58, 0.66, 10.0, 104.0, 20.0),
    CanopyLimb(50.0, 0.38, 0.66, 11.0, 126.0, 20.0),
    CanopyLimb(130.0, 0.38, 0.66, 12.0, 150.0, 20.0),
    CanopyLimb(84.0, 0.74, 0.62, 13.0, 178.0, 22.0),
    CanopyLimb(100.0, 0.72, 0.62, 14.0, 210.0, 22.0),
    CanopyLimb(44.0, 0.80, 0.56, 15.0, 248.0, 24.0),
    CanopyLimb(138.0, 0.80, 0.56, 16.0, 290.0, 24.0),
    CanopyLimb(90.0, 0.86, 0.58, 17.0, 332.0, 24.0),
)

private val mapleTufts: List<CanopyTuft> = run {
    val n = 46
    (0 until n).map { i ->
        val u = rand01(700.0, (i + 1).toDouble())
        val v = rand01(810.0, (i + 1).toDouble())
        CanopyTuft(
            ang = Math.PI * (0.05 + 0.90 * u),
            rad = 0.05 + 0.74 * sqrt(v),
            app = 2 + pow(i.toDouble() / n, 0.92) * 356,
            sz = 0.40 + 0.40 * rand01(920.0, (i + 1).toDouble()),
            span = 9 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
            seed = 200.0 + i,
        )
    }
}

private val mapleInk = FoliageInk(RGB(0x9A3424), RGB(0xC8472A), RGB(0xE87B33), RGB(0xF4B24B))

private fun drawMaplePot(ctx: BonsaiLayers) {
    paintPotFeet(ctx, 186.0, 414.0, 460.0, MaplePal.potRim)
    val body = BonsaiPath()
    body.move(176.0, 418.0)
    body.line(186.0, 460.0)
    body.line(414.0, 460.0)
    body.line(424.0, 418.0)
    body.close()
    ctx.fill(body, gradient(listOf(MaplePal.potMid, MaplePal.potDark), 300.0, 418.0, 300.0, 460.0))

    fun poly(color: BonsaiColor, vararg pts: Double) {
        val p = BonsaiPath()
        p.move(pts[0], pts[1])
        for (i in 1 until pts.size / 2) p.line(pts[2 * i], pts[2 * i + 1])
        p.close()
        ctx.fill(p, color)
    }
    poly(MaplePal.potGlaze.opacity(0.16), 186.0, 420.0, 198.0, 452.0, 262.0, 452.0, 256.0, 420.0)
    poly(MaplePal.potDark.opacity(0.5), 300.0, 418.0, 414.0, 460.0, 424.0, 418.0)
    poly(MaplePal.potRim.opacity(0.6), 186.0, 460.0, 414.0, 460.0, 406.0, 455.0, 194.0, 455.0)
    poly(MaplePal.potLight.opacity(0.9), 168.0, 410.0, 432.0, 410.0, 424.0, 421.0, 176.0, 421.0)
    poly(MaplePal.potGlaze.opacity(0.4), 168.0, 410.0, 432.0, 410.0, 430.0, 414.0, 170.0, 414.0)
    poly(MaplePal.potRim.opacity(0.5), 176.0, 421.0, 424.0, 421.0, 421.0, 425.0, 179.0, 425.0)

    ctx.fill(ellipse(300.0, 412.0, 124.0, 6.5), MaplePal.soilMid)
    ctx.fill(ellipse(300.0, 412.5, 122.0, 5.5), MaplePal.soilDark)
    ctx.fill(ellipse(242.0, 412.0, 1.8, 1.8), MaplePal.barkMid.opacity(0.5))
    ctx.fill(ellipse(330.0, 412.0, 1.6, 1.6), MaplePal.barkMid.opacity(0.45))
    ctx.fill(ellipse(286.0, 413.0, 1.2, 1.2), MaplePal.barkLight.opacity(0.4))
}

private fun drawMapleTrunk(day: Int, c: Canopy, ctx: BonsaiLayers) {
    val baseY = 410.0
    val trunk = forkTrunk(baseY, c.forkX, c.forkY, 3 + 9 * c.g, c.baseW, max(2.0, c.baseW * 0.26))
    val g = ctx.copy()
    g.clip(BonsaiPath.rect(0.0, 0.0, 600.0, baseY + 2))
    val tb = trunk.wood.boundingRect()
    g.fill(trunk.wood, gradient(listOf(MaplePal.barkLight, MaplePal.barkMid, MaplePal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY))
    // Maple bark: long vertical striping that follows the trunk.
    shadeWood(g, trunk.path, c.baseW * 0.7, MaplePal.barkDeep, MaplePal.barkLight, mapleBark(day), MaplePal.barkStripe)
}

/** A five-point leaf of size `s` at (x, y), turned `rotDeg`. */
private fun mapleLeaf(x: Double, y: Double, s: Double, rotDeg: Double): BonsaiPath {
    val p = BonsaiPath()
    for (i in 0 until 5) {
        val a = i / 5.0 * Math.PI * 2 - Math.PI / 2
        val aInner = a + Math.PI / 5
        val outer = Pt(cos(a) * s, sin(a) * s)
        val inner = Pt(cos(aInner) * s * 0.42, sin(aInner) * s * 0.42)
        if (i == 0) p.move(outer) else p.line(outer)
        p.line(inner)
    }
    p.close()
    return p.applying(Affine().translatedBy(x, y).rotated(rotDeg * Math.PI / 180))
}

/** The leaves lying on the soil, which never move. */
private fun drawMapleFallen(day: Int, ctx: BonsaiLayers) {
    val amt = mapleFall(day)
    if (amt < 0.02) return
    val fallN = (amt * 26).swiftRounded().toInt()
    for (i in 0 until fallN) {
        val h1 = rand01(71.0, (i + 1).toDouble())
        val h2 = rand01(89.0, (i + 3).toDouble())
        val h3 = rand01(53.0, i.toDouble())
        val fill = if (h3 > 0.6) MaplePal.folHi else if (h3 > 0.3) MaplePal.folLight else MaplePal.folMid
        ctx.fill(mapleLeaf(300 + (h1 - 0.5) * 160, 408 + h2 * 6, 3.2 + h3 * 2, (h1 - 0.5) * 180), fill.opacity(0.92))
    }
}

/** The leaves in mid-air, each on its own fall, worked out every frame. */
private fun drawMapleAir(day: Int, c: Canopy, wind: BonsaiWind?, ctx: BonsaiAirCanvas) {
    val amt = mapleFall(day)
    if (amt < 0.02) return
    val airN = (amt * 10).swiftRounded().toInt()
    for (i in 0 until airN) {
        val h1 = rand01(131.0, (i + 1).toDouble())
        val h2 = rand01(167.0, (i + 5).toDouble())
        val h3 = rand01(199.0, (i + 9).toDouble())
        val top = c.cY + c.ry * 0.5
        val y0 = top + h2 * (430 - top)
        val x0 = c.cX + (h1 - 0.5) * c.rx * 2.0
        val fill = if (h3 > 0.5) MaplePal.folLight else MaplePal.folMid
        if (wind == null) {
            ctx.fill(mapleLeaf(x0, min(y0, 432.0), 3 + h3 * 2.2, (h1 - 0.5) * 200), fill.opacity(0.85))
            continue
        }
        // Lands on the soil inside the pot, where the fallen leaves lie.
        val f = wind.fall(h2, h3, c.cX + (h1 - 0.5) * c.rx * 1.6, top, 408 + 6 * h3, (h1 - 0.5) * 200)
        ctx.fill(mapleLeaf(f.x, f.y, 3 + h3 * 2.2, f.rotDeg), fill.opacity(0.85 * f.opacity))
    }
}

/** `detail` is the scene's level of detail (see [bonsaiScene]). */
private fun mapleScene(day: Int, detail: Int): BonsaiScene {
    val c = mapleCanopy(day)
    val padBase = 5 + 30 * c.g
    val pivot = Pt(c.forkX, 410.0)
    val limbItems = canopyLimbItems(mapleLimbs, c, day, padBase)

    val ctx = BonsaiLayers()
    drawMaplePot(ctx)
    paintSoilMoss(ctx, 300.0, 410.0, 70.0, mapleBark(day), 29.0)
    val plant = ctx.copy()
    plant.move(BonsaiMotion.Bent)

    for (it in limbItems.sortedByDescending { it.ty }) {
        val ar = it.limb.a * Math.PI / 180
        val st = limbStart(it.limb.a, 410.0, c.forkX, c.forkY, 3 + 9 * c.g)
        val tip = Pt(it.tx, it.ty)
        val mx = (st.x + it.tx) / 2 - sin(ar) * 5 * c.g
        val my = (st.y + it.ty) / 2 - 6 * c.g * it.e
        val w = max(1.6, c.baseW * 0.21 * (0.4 + 0.6 * it.e))
        val b = boughPath(st, Pt(mx, my), tip, w, max(1.1, w * 0.35))
        val limb = plant.copy()
        limb.move(BonsaiMotion.Limb(st, tip))
        limb.fill(b, MaplePal.barkMid)
        shadeWood(limb, b, w, MaplePal.barkDeep, MaplePal.barkLight)
    }

    drawMapleTrunk(day, c, plant)

    val fol = ArrayList<Blossom>()
    for (it in limbItems) fol.add(Blossom(it.tx, it.ty, it.size, it.limb.seed, it.limb.seed.toInt() % 3 == 0, false))
    // A tuft never sits further out than the limbs near its angle reach, so it can't float past the young canopy.
    fun reach(ang: Double): Double =
        limbItems.maxOfOrNull { it.limb.r * it.e * max(0.0, cos(ang - it.limb.a * Math.PI / 180)) } ?: 0.0
    for (t in mapleTufts) {
        val e = smoothstepS(t.app, t.app + t.span, day.toDouble())
        if (e < 0.02) continue
        val rr = min(t.rad * (0.35 + 0.65 * e), reach(t.ang) + 0.12)
        val tx = c.cX + cos(t.ang) * c.rx * rr
        val ty = c.cY - sin(t.ang) * c.ry * rr
        fol.add(Blossom(tx, ty, padBase * t.sz * (0.6 + 0.4 * e), t.seed, false, true))
    }

    for (it in fol.sortedByDescending { it.ty }) {
        val g = plant.copy()
        g.move(BonsaiMotion.Drift(Pt(it.tx, it.ty)))
        paintPalmatePad(g, it.tx, it.ty, it.size, it.size * 0.78, it.seed * 5 + 2, mapleInk, padDetail(it.size, detail))
        if (c.g > 0.45 && it.accent) {
            g.fill(
                ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                MaplePal.folEmber.opacity(0.4),
            )
        }
    }

    drawMapleFallen(day, ctx)
    return BonsaiScene(ctx, pivot) { g, wind -> drawMapleAir(day, c, wind, g) }
}

/**
 * How much texture a maple or pine pad of half-width `size` gets at the scene's level of detail:
 * thumbnails keep the silhouette, the full-size tree gets every lobe and needle.
 */
private fun padDetail(size: Double, detail: Int): Int = when (detail) {
    0 -> 0
    1 -> if (size > 10) 1 else 0
    else -> if (size > 12) 2 else if (size > 6) 1 else 0
}

fun mapleContentRect(day: Int): BRect {
    val d = min(365, max(0, day))
    val c = mapleCanopy(d)
    val padBase = 5 + 30 * c.g
    var minX = 168.0
    var maxX = 432.0
    var minY = 410.0
    val maxY = 466.0
    minX = min(minX, c.cX - c.rx - padBase)
    maxX = max(maxX, c.cX + c.rx + padBase)
    minY = min(minY, c.cY - c.ry - padBase * 1.3)
    return floorRect(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Pine (Japanese black pine) bonsai

private object PinePal {
    val needMid = hex(0x2F6149)
    val needDeep = hex(0x1E3A30)
    val candle = hex(0xB7C68A)
    val barkDeep = hex(0x33271F)
    val barkMid = hex(0x5A4636)
    val barkLight = hex(0x897059)
    val barkPlate = hex(0x3E2F24)
    val potDark = hex(0x5A3D2A)
    val potMid = hex(0x825939)
    val potLight = hex(0xA8794F)
    val potRim = hex(0x432C1D)
    val potSpeck = hex(0xC49A6A)
    val soilDark = hex(0x211611)
    val soilMid = hex(0x36271C)
}

private fun pineScale(d: Int) = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun pineBark(d: Int) = smoothstepS(60.0, 380.0, d.toDouble())
private fun pineNeedle(d: Int) = ramp(d.toDouble(), 60.0, 365.0, 1.0)
private fun pineCandle(d: Int) = smoothstepS(20.0, 120.0, d.toDouble()) * (1 - smoothstepS(150.0, 230.0, d.toDouble()))

private class PineCanopy(
    val topX: Double, val topY: Double, val baseX: Double, val baseY: Double, val g: Double, val baseW: Double,
)

private fun pineCanopy(day: Int): PineCanopy {
    val baseX = 296.0
    val baseY = 412.0
    val g = pineScale(day)
    val topLen = 14 + 168 * g
    val topY = baseY - topLen
    val lean = 10 + 26 * g
    val topX = baseX + lean
    val baseW = 3 + 50 * g
    return PineCanopy(topX, topY, baseX, baseY, g, baseW)
}

private class PinePad(val side: Double, val hFrac: Double, val reach: Double, val wFrac: Double, val app: Double, val span: Double, val seed: Double)

private val pinePads = listOf(
    PinePad(0.0, 1.00, 0.00, 0.62, 0.0, 1.0, 1.0),
    PinePad(1.0, 0.62, 0.95, 0.95, 8.0, 20.0, 2.0),
    PinePad(-1.0, 0.46, 0.85, 0.85, 26.0, 22.0, 3.0),
    PinePad(1.0, 0.80, 0.62, 0.72, 70.0, 24.0, 4.0),
    PinePad(-1.0, 0.86, 0.40, 0.58, 150.0, 28.0, 5.0),
    PinePad(1.0, 0.30, 1.05, 0.70, 250.0, 30.0, 6.0),
)

private class PineTuft(
    val padU: Double, val fx: Double, val fy: Double, val app: Double, val sz: Double,
    val span: Double, val seed: Double, var host: Int = 0,
)

private val pineTufts: List<PineTuft> = run {
    val n = 30
    val out = (0 until n).map { i ->
        PineTuft(
            padU = rand01(610.0, (i + 1).toDouble()),
            fx = (rand01(700.0, (i + 1).toDouble()) - 0.5) * 1.7,
            fy = (rand01(810.0, (i + 1).toDouble()) - 0.5) * 0.7,
            app = 4 + pow(i.toDouble() / n, 0.9) * 354,
            sz = 0.30 + 0.30 * rand01(920.0, (i + 1).toDouble()),
            span = 10 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
            seed = 300.0 + i,
        )
    }
    // Pin each tuft to a pad that is already showing when the tuft first shows.
    for (t in out) {
        val first = (0..365).firstOrNull { smoothstepS(t.app, t.app + t.span, it.toDouble()) >= 0.02 } ?: 365
        val ready = pinePads.indices.filter {
            val p = pinePads[it]
            p.app == 0.0 || smoothstepS(p.app, p.app + p.span, first.toDouble()) >= 0.02
        }
        t.host = ready[min(ready.size - 1, (t.padU * ready.size).toInt())]
    }
    out
}

private val pineInk = FoliageInk(RGB(0x1E3A30), RGB(0x2F6149), RGB(0x4C8A63), RGB(0x7FB583))

private fun drawPinePot(ctx: BonsaiLayers) {
    paintPotFeet(ctx, 196.0, 404.0, 458.0, PinePal.potRim)
    val body = BonsaiPath()
    body.move(188.0, 414.0)
    body.quad(Pt(196.0, 458.0), Pt(186.0, 440.0))
    body.line(404.0, 458.0)
    body.quad(Pt(412.0, 414.0), Pt(414.0, 440.0))
    body.close()
    ctx.fill(body, gradient(listOf(PinePal.potMid, PinePal.potDark), 300.0, 414.0, 300.0, 458.0))

    val shade = BonsaiPath()
    shade.move(300.0, 414.0)
    shade.quad(Pt(404.0, 458.0), Pt(412.0, 440.0))
    shade.line(300.0, 458.0)
    shade.close()
    ctx.fill(shade, PinePal.potDark.opacity(0.4))

    val hl = BonsaiPath()
    hl.move(196.0, 420.0)
    hl.quad(Pt(200.0, 450.0), Pt(193.0, 436.0))
    hl.line(236.0, 450.0)
    hl.quad(Pt(232.0, 420.0), Pt(230.0, 434.0))
    hl.close()
    ctx.fill(hl, PinePal.potLight.opacity(0.22))

    ctx.fill(ellipse(300.0, 414.0, 112.0, 11.0), PinePal.potRim)
    ctx.fill(ellipse(300.0, 412.0, 112.0, 10.0), PinePal.potMid)
    ctx.fill(ellipse(300.0, 411.0, 108.0, 8.5), PinePal.potLight.opacity(0.55))
    ctx.fill(ellipse(300.0, 412.5, 103.0, 6.5), PinePal.soilMid)
    ctx.fill(ellipse(300.0, 413.0, 101.0, 5.5), PinePal.soilDark)
    ctx.fill(ellipse(250.0, 430.0, 1.6, 1.6), PinePal.potSpeck.opacity(0.4))
    ctx.fill(ellipse(340.0, 440.0, 1.4, 1.4), PinePal.potSpeck.opacity(0.35))
    ctx.fill(ellipse(300.0, 448.0, 1.5, 1.5), PinePal.potSpeck.opacity(0.3))
    ctx.fill(ellipse(225.0, 412.0, 1.6, 1.6), PinePal.barkMid.opacity(0.45))
    ctx.fill(ellipse(352.0, 412.0, 1.4, 1.4), PinePal.barkMid.opacity(0.4))
}

private fun drawPineTrunk(day: Int, c: PineCanopy, ctx: BonsaiLayers) {
    val baseX = c.baseX
    val baseY = c.baseY
    val topX = c.topX
    val topY = c.topY
    val baseW = c.baseW
    val topW = max(2.2, baseW * 0.30)
    val g = c.g
    val lean = topX - baseX
    val p0 = Pt(baseX, baseY)
    val p1 = Pt(baseX - 6 - 4 * g, lerp(baseY, topY, 0.34))
    val p2 = Pt(baseX + lean * 0.7, lerp(baseY, topY, 0.68))
    val p3 = Pt(topX, topY)
    fun bez(t: Double): Pt {
        val a = lerpP(p0, p1, t)
        val b = lerpP(p1, p2, t)
        val cc = lerpP(p2, p3, t)
        return lerpP(lerpP(a, b, t), lerpP(b, cc, t), t)
    }
    fun widthAt(t: Double) = lerp(baseW, topW, t)
    val spine = (0..12).map { bez(it / 12.0) }
    // Shading follows the trunk alone; the root flare only takes the fill.
    val (pts, ws) = rooted(spine, (0..12).map { widthAt(it / 12.0) }, 4 + baseW * 0.6)
    val trunk = woodRibbon(pts, ws, 2)
    val flared = trunk.union(nebariPath(baseX, baseY, baseW, 1.0))
    val wood = ctx.copy()
    wood.clip(BonsaiPath.rect(0.0, 0.0, 600.0, baseY + 2))
    val tb = flared.boundingRect()
    wood.fill(flared, gradient(listOf(PinePal.barkLight, PinePal.barkMid, PinePal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY))
    shadeWood(wood, trunk, baseW * 0.7, PinePal.barkDeep, PinePal.barkLight)

    val lc = pineBark(day)
    if (lc > 0.05 && baseW > 12) {
        val n = (3 + 5 * lc).swiftRounded().toInt()
        for (i in 0 until n) {
            val t = (i + 0.5) / n
            val pt = bez(t)
            val w = widthAt(t)
            val s = BonsaiPath()
            s.move(pt.x - w * 0.3, pt.y)
            s.quad(Pt(pt.x + w * 0.3, pt.y), Pt(pt.x, pt.y + 2))
            ctx.stroke(s, PinePal.barkPlate.opacity(0.45 * lc), 1.8, BonsaiCap.Round)
        }
    }
}

private fun pineNeedlePair(ctx: BonsaiLayers, x: Double, y: Double, s: Double, rotDeg: Double, color: BonsaiColor, opacity: Double) {
    val g = ctx.copy()
    g.translateBy(x, y)
    g.rotate(rotDeg)
    val a = BonsaiPath().apply { move(0.0, 0.0); line(-s * 0.3, s) }
    val b = BonsaiPath().apply { move(0.0, 0.0); line(s * 0.3, s) }
    g.stroke(a, color.opacity(opacity), 1.5, BonsaiCap.Round)
    g.stroke(b, color.opacity(opacity), 1.5, BonsaiCap.Round)
}

private class PadLive(val p: PinePad, val e: Double, val x: Double, val y: Double, val w: Double, val h: Double)

/** The pads alive on `day`, in [pinePads] order. */
private fun pineLivePads(day: Int, c: PineCanopy): List<PadLive> {
    val live = ArrayList<PadLive>()
    for (p in pinePads) {
        val e = if (p.app == 0.0) 1.0 else smoothstepS(p.app, p.app + p.span, day.toDouble())
        if (e < 0.02) continue
        val y = lerp(c.baseY, c.topY, p.hFrac)
        val leanAtH = lerp(0.0, c.topX - c.baseX, p.hFrac)
        val padW = (10 + 78 * c.g) * p.wFrac
        val x = c.baseX + leanAtH + p.side * p.reach * padW * 0.65 * e
        val w = padW * (0.2 + 0.8 * e)
        live.add(PadLive(p, e, x, y, w, w * 0.42))
    }
    return live
}

private class NItem(val x: Double, val y: Double, val w: Double, val h: Double, val seed: Double, val light: Boolean)

/** Every needle blob painted on `day`: the pads themselves plus the tufts that sit on top of them. */
private fun pineNeedleItems(day: Int, live: List<PadLive>): List<NItem> {
    val items = ArrayList<NItem>()
    for (l in live) items.add(NItem(l.x, l.y, l.w, l.h, l.p.seed, false))
    if (live.isEmpty()) return items
    for (t in pineTufts) {
        val e = smoothstepS(t.app, t.app + t.span, day.toDouble())
        if (e < 0.02) continue
        val host = live.firstOrNull { it.p.seed == pinePads[t.host].seed } ?: continue
        val ex = 0.4 + 0.6 * e
        val x = host.x + t.fx * host.w * ex
        val y = host.y + t.fy * host.h
        val w = host.w * t.sz * (0.6 + 0.4 * e)
        items.add(NItem(x, y, w, w * 0.5, t.seed, true))
    }
    return items
}

/** `detail` is the scene's level of detail (see [bonsaiScene]). */
private fun pineScene(day: Int, detail: Int): BonsaiScene {
    val c = pineCanopy(day)
    val pivot = Pt(c.baseX, c.baseY)

    val ctx = BonsaiLayers()
    drawPinePot(ctx)
    paintSoilMoss(ctx, c.baseX, c.baseY, 62.0, pineBark(day), 41.0)
    val plant = ctx.copy()
    plant.move(BonsaiMotion.Bent)
    drawPineTrunk(day, c, plant)

    val live = pineLivePads(day, c)

    for (it in live.sortedByDescending { it.y }) {
        if (it.p.app == 0.0) continue
        val leanAtH = lerp(0.0, c.topX - c.baseX, it.p.hFrac)
        val sx = c.baseX + leanAtH
        val w = max(1.8, c.baseW * 0.2 * (0.5 + 0.5 * it.e))
        val from = Pt(sx, it.y + 2)
        val tip = Pt(it.x, it.y)
        val b = boughPath(from, Pt((sx + it.x) / 2, it.y + 4), tip, w, max(1.2, w * 0.4))
        val limb = plant.copy()
        limb.move(BonsaiMotion.Limb(from, tip))
        limb.fill(b, PinePal.barkMid)
        shadeWood(limb, b, w, PinePal.barkDeep, PinePal.barkLight)
    }

    val items = pineNeedleItems(day, live)
    for (it in items.sortedBy { it.y }) {
        val g = plant.copy()
        g.move(BonsaiMotion.Drift(Pt(it.x, it.y)))
        paintNeedlePad(g, it.x, it.y, it.w, it.h, it.seed * 5 + 2, pineInk, padDetail(it.w, detail))
    }

    val cand = pineCandle(day)
    if (cand > 0.06 && c.g > 0.3) {
        for (it in live) {
            if (it.p.seed.toInt() % 2 != 0) continue
            for (k in 0 until 2) {
                val cx = it.x + (rand01(it.p.seed * 3, (k + 1).toDouble()) - 0.5) * it.w * 1.2
                val cy = it.y - it.h * 0.7 - 3 * cand
                val s = BonsaiPath()
                s.move(cx, cy)
                s.line(cx, cy - 5 * cand)
                val g = plant.copy()
                g.move(BonsaiMotion.Drift(Pt(cx, cy)))
                g.stroke(s, PinePal.candle.opacity(0.6 * cand), 2.0, BonsaiCap.Round)
            }
        }
    }

    val amt = pineNeedle(day)
    if (amt >= 0.02) {
        val n = (amt * 22).swiftRounded().toInt()
        for (i in 0 until n) {
            val h1 = rand01(71.0, (i + 1).toDouble())
            val h2 = rand01(89.0, (i + 3).toDouble())
            val h3 = rand01(53.0, i.toDouble())
            val fill = if (h3 > 0.5) PinePal.needMid else PinePal.needDeep
            pineNeedlePair(ctx, 300 + (h1 - 0.5) * 140, 408 + h2 * 6, 4 + h3 * 3, (h1 - 0.5) * 160, fill, 0.7)
        }
    }
    return BonsaiScene(ctx, pivot)
}

fun pineContentRect(day: Int): BRect {
    val d = min(365, max(0, day))
    val c = pineCanopy(d)
    var minX = 186.0
    var maxX = 414.0
    var minY = 410.0
    val maxY = 464.0
    // Measure every blob the pine paints, not just the pads (blob slack from the old blob jitter).
    val blobSlack = 1.36
    for (it in pineNeedleItems(d, pineLivePads(d, c))) {
        minX = min(minX, it.x - it.w * blobSlack)
        maxX = max(maxX, it.x + it.w * blobSlack)
        minY = min(minY, it.y - it.h * 1.6)
    }
    minY = min(minY, c.topY - 10)
    return floorRect(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Content bounds (for fill rendering)

/**
 * Tight bounding box, in the 600x600 design space, of the drawn bonsai for a given day/style.
 * `BonsaiView(fill:)` uses this to zoom the canvas onto the plant.
 */
fun bonsaiContentRect(day: Int, style: BonsaiStyle): BRect {
    val d = min(365, max(0, day))
    return BonsaiSceneCache.rect(BonsaiSceneCache.RectKey(style, d)) {
        when (style) {
            BonsaiStyle.Sakura -> sakuraContentRect(d)
            BonsaiStyle.Maple -> mapleContentRect(d)
            BonsaiStyle.Pine -> pineContentRect(d)
            else -> classicContentRect(d, style)
        }
    }
}

private fun classicContentRect(d: Int, style: BonsaiStyle): BRect {
    var minX = 1e9
    var minY = 1e9
    var maxX = -1e9
    var maxY = -1e9
    fun include(x: Double, y: Double) {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }

    // Pot footprint is always part of the silhouette.
    if (style == BonsaiStyle.Cascade) {
        include(218.0, 360.0); include(382.0, 465.0)
    } else {
        include(170.0, 380.0); include(430.0, 466.0)
    }

    if (d <= 7) {
        // Sprout: a small region just above the soil.
        val baseY = if (style == BonsaiStyle.Cascade) 378.0 else 410.0
        include(250.0, baseY - 92); include(350.0, baseY + 6)
    } else {
        val p = paramsForDay(d, style)
        val tr = buildTrunk(p, style)
        val tb = tr.path.boundingRect()
        include(tb.minX, tb.minY); include(tb.maxX, tb.maxY)
        for (c in p.clusters) {
            val base = clusterCenter(c, tr, p.reach)
            val r = c.size * 1.18 // blob radius is about size, plus a little slack
            include(base.x - r, base.y - r); include(base.x + r, base.y + r)
        }
    }
    return floorRect(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Scenes

/**
 * The recorded tree for `day`, built on first use and then reused every frame. `scale` (screen
 * pixels per design unit) picks how much leaf and needle texture the maple and pine carry;
 * vitality only tints the three classic styles' foliage.
 */
fun bonsaiScene(day: Int, style: BonsaiStyle, vitality: Double, scale: Double): BonsaiScene {
    val d = min(365, max(0, day))
    val textured = style == BonsaiStyle.Maple || style == BonsaiStyle.Pine
    val classic = style == BonsaiStyle.Traditional || style == BonsaiStyle.Cascade || style == BonsaiStyle.Windswept
    val detail = if (!textured) 0 else if (scale < 0.2) 0 else if (scale < 0.5) 1 else 2
    val key = BonsaiSceneCache.Key(style, d, detail, if (classic && d > 7) vitality else 1.0)
    return BonsaiSceneCache.scene(key) {
        when (style) {
            BonsaiStyle.Sakura -> sakuraScene(d)
            BonsaiStyle.Maple -> mapleScene(d, detail)
            BonsaiStyle.Pine -> pineScene(d, detail)
            else -> classicScene(d, style, vitality)
        }
    }
}

/** Traditional, cascade and windswept: the shared trunk and cluster pipeline. */
private fun classicScene(day: Int, style: BonsaiStyle, vitality: Double): BonsaiScene {
    val ctx = BonsaiLayers()
    drawPot(style, ctx)
    val pivot = Pt(300.0, if (style == BonsaiStyle.Cascade) 378.0 else 410.0)

    if (day <= 7) {
        drawRootsAndMoss(paramsForDay(day, style), style, ctx)
        if (day > 0) ctx.move(BonsaiMotion.Bent)
        drawEarly(day, style, ctx)
        return BonsaiScene(ctx, pivot, sprout = true)
    }

    val p = paramsForDay(day, style)
    drawRootsAndMoss(p, style, ctx)
    val tr = buildTrunk(p, style)
    ctx.move(BonsaiMotion.Bent)

    // Jin: windward dead wood, bleached silver-grey.
    for (b in tr.bareBranches) {
        val jin = boughPath(b.from, b.ctrl, b.to, b.w, max(1.0, b.w * 0.3))
        ctx.fill(jin, hex(0xA99D8A))
        shadeWood(ctx, jin, b.w, hex(0x6B6052), hex(0xE2DACB))
    }
    for (b in tr.branches) {
        val bough = boughPath(b.from, b.ctrl, b.to, b.w, max(1.2, b.w * 0.4))
        ctx.fill(bough, Pal.barkMid)
        shadeWood(ctx, bough, b.w, Pal.barkDeep, Pal.barkLight)
    }
    val trunkRect = tr.path.boundingRect()
    val bark = gradient(listOf(Pal.barkLight, Pal.barkMid, Pal.barkDeep), trunkRect.minX, 300.0, trunkRect.maxX, 300.0)
    val nebari = nebariPath(tr.base.x, tr.base.y, tr.baseW, 0.4 + 0.6 * p.exposedRoots, tr.lean)
    // Upright trunks stop at the soil; the cascade spills over the rim.
    val tctx = ctx.copy()
    if (style != BonsaiStyle.Cascade) {
        tctx.clip(BonsaiPath.rect(0.0, 0.0, 600.0, tr.base.y + 2))
    }
    for ((i, part) in tr.parts.ifEmpty { listOf(tr.path) }.withIndex()) {
        tctx.fill(if (i == 0) part.union(nebari) else part, bark)
        // Shade the wood alone: the flare's outline would leave seams.
        shadeWood(tctx, part, tr.baseW * 0.7, Pal.barkDeep, Pal.barkLight, p.trunkGnarl, Pal.barkDeep)
    }

    drawSeedLeaves(day, style, tr.spine, ctx)

    val satFactor = 0.7 + 0.3 * max(0.0, min(1.0, vitality))
    for (c in p.clusters) {
        val base = clusterCenter(c, tr, p.reach)
        val g = ctx.copy()
        g.move(BonsaiMotion.Drift(base))
        drawCluster(base.x, base.y, c.size, c.tone, p.leafSaturation * c.sat * satFactor, c.seed, g)
    }
    return BonsaiScene(ctx, pivot)
}

/** The day-7 sprout's three leaves, kept on the young trunk and shrinking away under the first pads. */
private fun drawSeedLeaves(day: Int, style: BonsaiStyle, spine: List<Pt>, ctx: BonsaiLayers) {
    val fade = 1 - smoothstepS(14.0, 36.0, day.toDouble())
    val base = spine.firstOrNull()
    val tip = spine.lastOrNull()
    if (fade <= 0 || base == null || tip == null || base.y <= tip.y) return
    val s = fade * (if (style == BonsaiStyle.Cascade) 0.45 else 1.0)

    /** The spine's point at `f` of the way up from the soil to the tip. */
    fun at(f: Double): Pt {
        val y = base.y - (base.y - tip.y) * f
        for (i in 1 until spine.size) {
            if (spine[i].y <= y) {
                val a = spine[i - 1]
                val b = spine[i]
                val t = (a.y - y) / max(1e-6, a.y - b.y)
                return Pt(a.x + (b.x - a.x) * t, y)
            }
        }
        return tip
    }
    class SeedLeaf(val f: Double, val side: Double, val deg: Double, val color: BonsaiColor)
    for (l in listOf(
        SeedLeaf(0.49, -1.0, -22.0, Pal.leafSage), SeedLeaf(0.69, 1.0, 22.0, Pal.leafSage),
        SeedLeaf(0.87, -1.0, -26.0, Pal.leafFresh),
    )) {
        val p = at(l.f)
        fillRotatedEllipse(ctx, p.x + l.side * 10 * s, p.y, 10 * s, 4 * s, l.deg, l.color)
    }
}
