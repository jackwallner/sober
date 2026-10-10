package com.jackwallner.sober.ui.bonsai

import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.floor

// Line-for-line port of Shared/Bonsai/BonsaiRenderer.swift. Everything here is pure
// deterministic Double math, so Android draws the same tree as iOS. Keep the Swift
// operation order: parity tests compare the emitted commands against the Swift output.
//
// Porting notes:
// - Swift value-type context copies (`var g = ctx`) become save()/restore() pairs.
// - Swift's .rounded() is schoolbook rounding (half away from zero), see swiftRounded().
// - sin/cos/pow/hypot go through StrictMath so JVM and Android agree bit-for-bit.
//
// Source of truth for parity: scripts/sync-android-bonsai.py records the Swift output.

private fun sin(x: Double) = StrictMath.sin(x)
private fun cos(x: Double) = StrictMath.cos(x)
private fun pow(x: Double, y: Double) = StrictMath.pow(x, y)
private fun hypot(x: Double, y: Double) = StrictMath.hypot(x, y)
private fun sqrt(x: Double) = StrictMath.sqrt(x)

/** Swift's Double.rounded(): nearest, ties away from zero. */
private fun Double.swiftRounded(): Double {
    if (isNaN() || isInfinite()) return this
    val f = floor(this)
    val diff = this - f
    return if (this >= 0) (if (diff >= 0.5) f + 1 else f) else (if (diff > 0.5) f + 1 else f)
}

// MARK: - Palette

private object Pal {
    val leafDeep = BonsaiColor.hex(0x2F5E45)
    val leafSage = BonsaiColor.hex(0x519E73)
    val leafFresh = BonsaiColor.hex(0x7BC68C)
    val leafLight = BonsaiColor.hex(0xA9D4A8)
    val leafLightC = BonsaiColor.hex(0xC7E5B8)
    val leafAutumn = BonsaiColor.hex(0xD8A35E)
    val barkDeep = BonsaiColor.hex(0x3E2A1B)
    val barkMid = BonsaiColor.hex(0x6B4A2E)
    val barkLight = BonsaiColor.hex(0xA07B52)
    val potDark = BonsaiColor.hex(0x3B2A1C)
    val potMid = BonsaiColor.hex(0x5C402A)
    val potRim = BonsaiColor.hex(0x2C1F14)
    val soilDark = BonsaiColor.hex(0x221710)
    val soilMid = BonsaiColor.hex(0x3A2A1C)
    val moss = BonsaiColor.hex(0x9DB16E)

    val autumnShadow = BonsaiColor.hex(0x5C3D1F)
    val autumnMid = BonsaiColor.hex(0xB07A3C)
    val autumnHi = BonsaiColor.hex(0xF2D593)
    val deepShadow = BonsaiColor.hex(0x1F4630)
}

// MARK: - Small helpers

private fun solid(color: BonsaiColor) = BonsaiPaint.Solid(color)

private fun BonsaiGraphics.fillColor(path: BonsaiPath, color: BonsaiColor) = fill(path, solid(color))

private fun BonsaiGraphics.strokeRound(path: BonsaiPath, color: BonsaiColor, width: Double) =
    stroke(path, solid(color), width, BonsaiCap.Round)

private fun gradient(colors: List<BonsaiColor>, sx: Double, sy: Double, ex: Double, ey: Double) =
    BonsaiPaint.LinearGradient(colors, Pt(sx, sy), Pt(ex, ey))

// MARK: - Deterministic noise (matches JS rand01)

private fun rand01(seed: Double, n: Double): Double {
    val v = sin(seed * 12.9898 + n * 78.233) * 43758.5453
    return v - floor(v)
}

// MARK: - Blob silhouette (matches JS blobPath)

private fun blobPath(
    cx: Double, cy: Double, rBase: Double,
    seed: Double, points: Int = 13,
    squashY: Double = 0.82, noise: Double = 0.28, tiltDeg: Double = 0.0,
): BonsaiPath {
    val tilt = tiltDeg * PI / 180
    val px = DoubleArray(points)
    val py = DoubleArray(points)
    for (i in 0 until points) {
        val t = i.toDouble() / points.toDouble() * PI * 2
        val r = rBase * (1 + (rand01(seed, (i + 1).toDouble()) - 0.5) * 2 * noise)
        val x = cos(t + tilt) * r
        val y = sin(t + tilt) * r * squashY
        px[i] = cx + x
        py[i] = cy + y
    }
    val path = BonsaiPath()
    path.move((px[points - 1] + px[0]) / 2, (py[points - 1] + py[0]) / 2)
    for (i in 0 until points) {
        val j = (i + 1) % points
        path.quad(
            to = Pt((px[i] + px[j]) / 2, (py[i] + py[j]) / 2),
            control = Pt(px[i], py[i]),
        )
    }
    path.close()
    return path
}

private fun ellipse(cx: Double, cy: Double, rx: Double, ry: Double): BonsaiPath {
    val p = BonsaiPath()
    p.ellipse(cx - rx, cy - ry, rx * 2, ry * 2)
    return p
}

private fun fillRotatedEllipse(
    ctx: BonsaiGraphics,
    cx: Double, cy: Double, rx: Double, ry: Double,
    deg: Double, color: BonsaiColor, opacity: Double = 1.0,
) {
    ctx.save()
    ctx.translate(cx, cy)
    ctx.rotate(deg * PI / 180)
    val p = BonsaiPath()
    p.ellipse(-rx, -ry, rx * 2, ry * 2)
    ctx.fillColor(p, color.opacity(opacity))
    ctx.restore()
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

/**
 * Where a cluster is drawn: its trunk/branch attach point plus its offset,
 * shrunk by `reach` so young trees keep every blob touching the silhouette.
 */
private fun clusterCenter(c: ClusterSpec, trunk: TrunkResult, reach: Double): Pt {
    val base = c.attach?.let { trunk.attach[it] } ?: Pt(c.cx, c.cy)
    return Pt(base.x + c.offsetW * reach, base.y + c.offsetH * reach)
}

private fun drawCluster(
    cx: Double, cy: Double, size: Double,
    tone: Tone, saturation: Double, seed: Double,
    ctx: BonsaiGraphics,
) {
    val shadow: BonsaiColor
    val mid: BonsaiColor
    val midLight: BonsaiColor
    val light: BonsaiColor
    when (tone) {
        Tone.Sage -> { shadow = Pal.leafDeep; mid = Pal.leafSage; midLight = Pal.leafFresh; light = Pal.leafLight }
        Tone.Fresh -> { shadow = Pal.leafDeep; mid = Pal.leafFresh; midLight = Pal.leafLight; light = Pal.leafLightC }
        Tone.Autumn -> { shadow = Pal.autumnShadow; mid = Pal.autumnMid; midLight = Pal.leafAutumn; light = Pal.autumnHi }
        Tone.Deep -> { shadow = Pal.deepShadow; mid = Pal.leafDeep; midLight = Pal.leafSage; light = Pal.leafFresh }
    }
    val sat = maxOf(0.4, saturation)
    fun r(n: Double) = rand01(seed, n)
    val tilt = (r(99.0) - 0.5) * 20

    ctx.save()
    ctx.translate(cx, cy)

    val shadowBlob = blobPath(
        cx = size * 0.10, cy = size * 0.14, rBase = size * 1.02,
        seed = seed * 1.1, points = 13, squashY = 0.82, noise = 0.22, tiltDeg = tilt,
    )
    ctx.fillColor(shadowBlob, shadow.opacity(0.78 * sat))

    for (i in 0 until 3) {
        val a = PI * (0.15 + i.toDouble() * 0.6)
        val off = size * (0.95 + r((i + 50).toDouble()) * 0.1)
        val exCx = cos(a) * off + size * 0.06
        val exCy = sin(a) * off * 0.8 + size * 0.06
        val rad = size * (0.08 + r((i + 51).toDouble()) * 0.05)
        val p = blobPath(
            cx = exCx, cy = exCy, rBase = rad, seed = seed * 29 + i.toDouble() * 13,
            points = 7, squashY = 0.9, noise = 0.35,
        )
        ctx.fillColor(p, shadow.opacity(0.55 * sat))
    }

    val midBlob = blobPath(
        cx = 0.0, cy = 0.0, rBase = size * 0.92,
        seed = seed * 1.3 + 7, points = 14, squashY = 0.86, noise = 0.26, tiltDeg = tilt * 0.7,
    )
    ctx.fillColor(midBlob, mid.opacity(0.94 * sat))

    for (i in 0 until 5) {
        val a = i.toDouble() / 5 * PI * 1.4 - PI * 0.95
        val off = size * (0.32 + r((i * 5 + 2).toDouble()) * 0.22)
        val cxL = cos(a) * off
        val cyL = sin(a) * off * 0.7 - size * 0.08
        val rad = size * (0.18 + r((i * 5 + 3).toDouble()) * 0.12)
        val p = blobPath(
            cx = cxL, cy = cyL, rBase = rad, seed = seed * 17 + i.toDouble() * 31,
            points = 9, squashY = 0.9, noise = 0.32,
        )
        ctx.fillColor(p, midLight.opacity(0.7 * sat))
    }

    for (i in 0 until 4) {
        val a = -PI * 0.75 + i.toDouble() / 4 * PI * 0.7
        val off = size * (0.45 + r((i * 7 + 9).toDouble()) * 0.18)
        val cxL = cos(a) * off
        val cyL = sin(a) * off * 0.55 - size * 0.18
        val rad = size * (0.09 + r((i * 7 + 11).toDouble()) * 0.07)
        val p = blobPath(
            cx = cxL, cy = cyL, rBase = rad, seed = seed * 23 + i.toDouble() * 41,
            points = 8, squashY = 0.95, noise = 0.28,
        )
        ctx.fillColor(p, light.opacity(0.82 * sat))
    }
    ctx.restore()
}

// MARK: - Pot

private class Fleck(val x: Double, val y: Double, val r: Double, val color: BonsaiColor, val opacity: Double)

private fun drawPot(style: BonsaiStyle, ctx: BonsaiGraphics) {
    if (style == BonsaiStyle.Cascade) {
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
        ctx.fillColor(shade, Pal.potDark.opacity(0.55))

        ctx.fillColor(ellipse(300.0, 378.0, 82.0, 7.0), Pal.potRim)
        ctx.fillColor(ellipse(300.0, 376.0, 82.0, 6.0), Pal.potMid)
        ctx.fillColor(ellipse(300.0, 377.0, 76.0, 5.0), Pal.soilMid)
        ctx.fillColor(ellipse(300.0, 378.0, 74.0, 4.0), Pal.soilDark)

        val flecks = listOf(
            Fleck(262.0, 377.0, 1.4, Pal.barkLight, 0.4),
            Fleck(294.0, 378.0, 1.6, Pal.barkMid, 0.5),
            Fleck(330.0, 377.0, 1.2, Pal.barkLight, 0.4),
        )
        for (f in flecks) ctx.fillColor(ellipse(f.x, f.y, f.r, f.r), f.color.opacity(f.opacity))
        return
    }

    // traditional & windswept: wide trapezoid, soil top y=411
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
    ctx.fillColor(shade, Pal.potDark.opacity(0.55))

    ctx.fillColor(ellipse(300.0, 413.0, 130.0, 9.0), Pal.potRim)
    ctx.fillColor(ellipse(300.0, 411.0, 130.0, 8.0), Pal.potMid)
    ctx.fillColor(ellipse(300.0, 412.0, 124.0, 6.5), Pal.soilMid)
    ctx.fillColor(ellipse(300.0, 412.5, 122.0, 5.5), Pal.soilDark)

    val flecks = listOf(
        Fleck(240.0, 412.0, 1.8, Pal.barkMid, 0.55), Fleck(285.0, 413.0, 1.2, Pal.barkLight, 0.4),
        Fleck(328.0, 412.0, 1.6, Pal.barkMid, 0.5), Fleck(358.0, 413.0, 1.2, Pal.barkLight, 0.35),
        Fleck(210.0, 413.0, 1.4, Pal.barkLight, 0.4),
    )
    for (f in flecks) ctx.fillColor(ellipse(f.x, f.y, f.r, f.r), f.color.opacity(f.opacity))
}

// MARK: - Roots & moss

private class Root(
    val a1: Double, val ya: Double, val a2: Double, val yb: Double,
    val a3: Double, val yc: Double, val color: BonsaiColor, val mul: Double,
)

private class Patch(val x: Double, val y: Double, val rx: Double, val ry: Double)

private fun drawRootsAndMoss(p: Params, style: BonsaiStyle, ctx: BonsaiGraphics) {
    val baseY: Double = if (style == BonsaiStyle.Cascade) 378.0 else 411.0
    if (p.exposedRoots > 0) {
        val a = minOf(1.0, p.exposedRoots)
        val op = 0.6 + 0.4 * a
        val roots = listOf(
            Root(280.0, baseY, 266.0, baseY - 1, 282.0, baseY + 1, Pal.barkMid, 1.0),
            Root(295.0, baseY, 282.0, baseY - 2, 296.0, baseY + 1, Pal.barkDeep, 0.7),
            Root(312.0, baseY, 330.0, baseY - 1, 312.0, baseY + 1, Pal.barkMid, 1.0),
            Root(322.0, baseY, 338.0, baseY - 2, 320.0, baseY + 1, Pal.barkDeep, 0.7),
        )
        for (r in roots) {
            val path = BonsaiPath()
            path.move(r.a1, r.ya)
            // bend up then back down to ground
            path.quad(to = Pt(r.a2, r.yb), control = Pt((r.a1 + r.a2) / 2, r.yb - 2))
            path.quad(to = Pt(r.a3, r.yc), control = Pt((r.a2 + r.a3) / 2, r.yb + 2))
            ctx.fillColor(path, r.color.opacity(op * r.mul))
        }
    }
    if (p.mossOnTrunk > 0) {
        val a = minOf(1.0, p.mossOnTrunk)
        val op = 0.55 + 0.45 * a
        val patches = listOf(
            Patch(292.0, baseY - 3, 5.0, 2.0),
            Patch(302.0, baseY - 5, 6.0, 2.4),
            Patch(296.0, baseY - 9, 4.0, 1.8),
            Patch(307.0, baseY - 14, 3.5, 1.7),
            Patch(294.0, baseY - 17, 3.0, 1.4),
        )
        val n = ceil(2 + 3 * a).toInt()
        for (pt in patches.take(n)) {
            ctx.fillColor(ellipse(pt.x, pt.y, pt.rx, pt.ry), Pal.moss.opacity(op))
        }
    }
}

// MARK: - Trunks (style-specific)

private class StrokedPath(val path: BonsaiPath, val width: Double)
private class BareBranch(val path: BonsaiPath, val width: Double, val color: BonsaiColor, val opacity: Double)
private class GnarlPath(val path: BonsaiPath, val opacity: Double)

private class TrunkResult(
    val path: BonsaiPath,
    val branches: List<StrokedPath>,
    val bareBranches: List<BareBranch>,
    val gnarl: List<GnarlPath>,
    val attach: Map<Attach, Pt>,
)

/**
 * x on a quadratic Bezier at a given y. The trunk edge curves are monotonic in
 * y, so a bisection on t is exact enough to plant a branch on the silhouette.
 */
private fun quadXAtY(y: Double, p0: Pt, c: Pt, p2: Pt): Double {
    var lo = 0.0
    var hi = 1.0
    for (unused in 0 until 24) {
        val t = (lo + hi) / 2
        val yy = pow(1 - t, 2.0) * p0.y + 2 * t * (1 - t) * c.y + t * t * p2.y
        if ((p2.y > p0.y) == (yy < y)) lo = t else hi = t
    }
    val t = (lo + hi) / 2
    return pow(1 - t, 2.0) * p0.x + 2 * t * (1 - t) * c.x + t * t * p2.x
}

private fun ribbonPath(pts: List<Pt>, widths: List<Double>): BonsaiPath {
    val leftPts = ArrayList<Pt>()
    val rightPts = ArrayList<Pt>()
    for (i in pts.indices) {
        val prev = if (i == 0) pts[1] else pts[i - 1]
        val next = if (i == pts.size - 1) pts[i] else pts[i + 1]
        val dirA = if (i == 0) Pt(pts[1].x - pts[0].x, pts[1].y - pts[0].y)
        else Pt(pts[i].x - prev.x, pts[i].y - prev.y)
        val dirB = if (i == pts.size - 1) dirA else Pt(next.x - pts[i].x, next.y - pts[i].y)
        val avgX = (dirA.x + dirB.x) / 2
        val avgY = (dirA.y + dirB.y) / 2
        val len = maxOf(1e-6, hypot(avgX, avgY))
        val nx = -avgY / len
        val ny = avgX / len
        val w = widths[i] / 2
        leftPts.add(Pt(pts[i].x + nx * w, pts[i].y + ny * w))
        rightPts.add(Pt(pts[i].x - nx * w, pts[i].y - ny * w))
    }
    val all = ArrayList<Pt>(leftPts)
    all.addAll(rightPts.asReversed())
    val path = BonsaiPath()
    path.move(all[0])
    for (i in 1 until all.size) {
        val prev = all[i - 1]
        val cur = all[i]
        val m = Pt((prev.x + cur.x) / 2, (prev.y + cur.y) / 2)
        path.quad(to = m, control = prev)
    }
    path.close()
    return path
}

private fun trunkTraditional(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 410.0
    val heightPx = 70 + 230 * p.trunkHeight
    val tipY = baseY - heightPx
    val tipX = baseX + 12
    val baseW = 8 + 36 * p.trunkThickness
    val midW = baseW * 0.6
    val tipW = maxOf(2.4, baseW * 0.25)
    val midY = (baseY + tipY) / 2
    val midX1 = baseX - 14
    val midX2 = baseX + 18
    val bL = baseX - baseW / 2
    val bR = baseX + baseW / 2
    val m1L = midX1 - midW / 2
    val m1R = midX1 + midW / 2
    val m2L = midX2 - midW / 2
    val m2R = midX2 + midW / 2
    val tL = tipX - tipW / 2
    val tR = tipX + tipW / 2

    val path = BonsaiPath()
    path.move(bL, baseY)
    path.quad(to = Pt(m1L, midY), control = Pt(m1L - 4, (baseY + midY) / 2))
    path.quad(to = Pt(tL, tipY), control = Pt(m2L - 2, (midY + tipY) / 2))
    path.line(tR, tipY)
    path.quad(to = Pt(m2R, midY), control = Pt(m2R + 2, (midY + tipY) / 2))
    path.quad(to = Pt(bR, baseY), control = Pt(m1R + 4, (baseY + midY) / 2))
    path.close()

    // Branch reach grows with the tree (k=1 at day 365 = original geometry).
    // Branches draw from the day their foliage clusters appear, so a blob is
    // never left floating where its limb hasn't grown yet.
    val k = p.reach
    val ymid2 = (midY + tipY) / 2
    val b1Start = Pt(m1L + 2, midY + 4)
    val b1End = Pt(b1Start.x - 38 * k, b1Start.y - 26 * k)
    val b2Start = Pt(m2R - 2, ymid2 + 4)
    val b2End = Pt(b2Start.x + 38 * k, b2Start.y - 34 * k)
    // Plant branch 3 on the actual right edge of the S-curved trunk, tucked 3pt under the fill.
    val b3Anchor = Pt(bR - 2, baseY - 36)
    val b3End = Pt(b3Anchor.x + 44 * k, b3Anchor.y - 36 * k)
    val b3Start = Pt(
        quadXAtY(
            b3Anchor.y,
            Pt(m2R, midY),
            Pt(m1R + 4, (baseY + midY) / 2),
            Pt(bR, baseY),
        ) - 3,
        b3Anchor.y,
    )

    val branches = ArrayList<StrokedPath>()
    if (p.day >= 30) {
        val b1 = BonsaiPath()
        b1.move(b1Start)
        b1.quad(to = b1End, control = Pt(b1Start.x - 18 * k, b1Start.y - 10 * k))
        branches.add(StrokedPath(b1, maxOf(3.0, baseW * 0.18)))
        val b2 = BonsaiPath()
        b2.move(b2Start)
        b2.quad(to = b2End, control = Pt(b2Start.x + 20 * k, b2Start.y - 18 * k))
        branches.add(StrokedPath(b2, maxOf(2.6, baseW * 0.14)))
    }
    if (p.day >= 60) {
        val b3 = BonsaiPath()
        b3.move(b3Start)
        b3.quad(to = b3End, control = Pt(b3Start.x + 20 * k, b3Start.y - 18 * k))
        branches.add(StrokedPath(b3, maxOf(2.4, baseW * 0.12)))
    }

    val gnarl = ArrayList<GnarlPath>()
    if (p.trunkGnarl > 0) {
        val a = minOf(1.0, p.trunkGnarl)
        val op = 0.5 + 0.5 * a
        gnarl.add(GnarlPath(ellipse(midX1 + midW * 0.15, midY + 4, midW * 0.55, 3.6), 0.55 * op))
        gnarl.add(GnarlPath(ellipse(midX2 - midW * 0.15, (midY + tipY) / 2, midW * 0.45, 3.0), 0.5 * op))
        gnarl.add(GnarlPath(ellipse((bL + m1L) / 2, (baseY + midY) / 2 + 6, baseW * 0.35, 3.2), 0.45 * op))
    }

    val attach = mapOf(
        Attach.Crown to Pt(tipX, tipY - 8 * k),
        Attach.UpperLeft to b1End,
        Attach.UpperRight to b2End,
        Attach.MidLeft to Pt(m1L - 12 * k, midY - 4 * k),
        Attach.MidRight to Pt(m2R + 12 * k, ymid2 - 6 * k),
        Attach.LowerRight to b3End,
    )
    return TrunkResult(path, branches, emptyList(), gnarl, attach)
}

private fun trunkCascade(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 378.0
    val fallPx = 30 + 130 * p.trunkHeight
    // Taller riser than the JS source: the crown must clear the pot rim from
    // day 8 so the young cascade doesn't read as a lump on the pot corner.
    val upPx = 24 + 42 * p.trunkHeight
    val sideX = baseX - 80 - 60 * p.trunkHeight
    val baseW = 8 + 32 * p.trunkThickness
    val midW = baseW * 0.55
    val tipW = maxOf(2.4, baseW * 0.22)

    val p0 = Pt(baseX, baseY)
    val p1 = Pt(baseX - 16, baseY - upPx)
    val p2 = Pt(baseX - 30, baseY + 6)
    val p3 = Pt(sideX, baseY + fallPx)
    val pts = listOf(p0, p1, p2, p3)
    val widths = listOf(baseW, midW * 1.1, midW, tipW)
    val path = ribbonPath(pts, widths)

    val gnarl = ArrayList<GnarlPath>()
    if (p.trunkGnarl > 0) {
        val a = minOf(1.0, p.trunkGnarl)
        val op = 0.5 + 0.5 * a
        gnarl.add(GnarlPath(ellipse(p1.x + 4, p1.y + 2, midW * 0.55, 3.2), 0.5 * op))
        gnarl.add(GnarlPath(ellipse(p2.x - 2, p2.y + 4, midW * 0.5, 3.0), 0.5 * op))
    }

    val k = p.reach
    val midPt = Pt((p2.x + p3.x) / 2, (p2.y + p3.y) / 2)
    val b1Start = Pt(p2.x, p2.y + 6)
    val b1End = Pt(b1Start.x - 44 * k, b1Start.y + 46 * k)
    val b2End = Pt(midPt.x - 56 * k, midPt.y + 28 * k)

    val branches = ArrayList<StrokedPath>()
    if (p.day >= 30) {
        val b1 = BonsaiPath()
        b1.move(b1Start)
        b1.quad(to = b1End, control = Pt(b1Start.x - 22 * k, b1Start.y + 24 * k))
        branches.add(StrokedPath(b1, maxOf(2.6, baseW * 0.14)))
        val b2 = BonsaiPath()
        b2.move(midPt)
        b2.quad(to = b2End, control = Pt(midPt.x - 26 * k, midPt.y + 18 * k))
        branches.add(StrokedPath(b2, maxOf(2.4, baseW * 0.12)))
    }

    val attach = mapOf(
        Attach.Crown to Pt(p1.x - 2 * k, p1.y - 12 * k),
        Attach.UpperLeft to Pt(b1End.x, b1End.y - 8 * k),
        Attach.UpperRight to Pt(b2End.x, b2End.y - 8 * k),
        Attach.MidLeft to Pt(p3.x - 12 * k, p3.y - 22 * k),
        Attach.MidRight to Pt(p3.x + 14 * k, p3.y - 10 * k),
        Attach.LowerRight to Pt(p3.x - 6 * k, p3.y + 10 * k),
    )
    return TrunkResult(path, branches, emptyList(), gnarl, attach)
}

private fun trunkWindswept(p: Params): TrunkResult {
    val baseX = 300.0
    val baseY = 410.0
    val heightPx = 70 + 220 * p.trunkHeight
    val leanRad = 18.0 * PI / 180
    val tipX = baseX + sin(leanRad) * heightPx + 8
    val tipY = baseY - cos(leanRad) * heightPx
    val baseW = 8 + 34 * p.trunkThickness
    val midW = baseW * 0.55
    val tipW = maxOf(2.4, baseW * 0.22)
    val midX = (baseX + tipX) / 2 + 14
    val midY = (baseY + tipY) / 2 + 4

    val pts = listOf(Pt(baseX, baseY), Pt(midX, midY), Pt(tipX, tipY))
    val widths = listOf(baseW, midW * 1.05, tipW)
    val path = ribbonPath(pts, widths)

    val gnarl = ArrayList<GnarlPath>()
    if (p.trunkGnarl > 0) {
        val a = minOf(1.0, p.trunkGnarl)
        val op = 0.5 + 0.5 * a
        gnarl.add(GnarlPath(ellipse(midX - 2, midY + 2, midW * 0.55, 3.6), 0.55 * op))
    }

    val k = p.reach

    // Bare windward (left) branches: decorative dead wood, scaled with growth.
    val bare = ArrayList<BareBranch>()
    if (p.trunkThickness > 0.35) {
        val bareSize = maxOf(2.0, baseW * 0.12)
        val s1 = Pt((baseX + midX) / 2, (baseY + midY) / 2)
        val b1 = BonsaiPath()
        b1.move(s1)
        b1.quad(
            to = Pt(s1.x + (baseX - 44 - s1.x) * k, s1.y + (baseY - 92 - s1.y) * k),
            control = Pt(s1.x + (baseX - 18 - s1.x) * k, s1.y + (baseY - 80 - s1.y) * k),
        )
        bare.add(BareBranch(b1, bareSize, Pal.barkMid, 1.0))
        val b2 = BonsaiPath()
        b2.move(midX - 4, midY + 4)
        b2.quad(
            to = Pt(midX - 4 - 52 * k, midY + 4 - 32 * k),
            control = Pt(midX - 4 - 26 * k, midY + 4 - 22 * k),
        )
        bare.add(BareBranch(b2, bareSize * 0.85, Pal.barkDeep, 0.85))
        val b3 = BonsaiPath()
        b3.move(midX - 18, midY - 4)
        b3.quad(
            to = Pt(midX - 18 - 42 * k, midY - 4 + 2 * k),
            control = Pt(midX - 18 - 22 * k, midY - 4 - 2 * k),
        )
        bare.add(BareBranch(b3, bareSize * 0.7, Pal.barkMid, 1.0))
    }

    // Leeward (right) heavy branches into the foliage. Drawn from the day the
    // leeward clusters exist so foliage always has wood to sit on.
    val branches = ArrayList<StrokedPath>()
    if (p.day >= 30) {
        val b1 = BonsaiPath()
        b1.move(midX + 2, midY - 2)
        b1.quad(
            to = Pt(midX + 2 + 46 * k, midY - 2 - 26 * k),
            control = Pt(midX + 2 + 24 * k, midY - 2 - 12 * k),
        )
        branches.add(StrokedPath(b1, maxOf(3.0, baseW * 0.18)))
        val b2 = BonsaiPath()
        b2.move(tipX - 6, tipY + 6)
        b2.quad(
            to = Pt(tipX - 6 + 48 * k, tipY + 6 - 20 * k),
            control = Pt(tipX - 6 + 24 * k, tipY + 6 - 10 * k),
        )
        branches.add(StrokedPath(b2, maxOf(2.6, baseW * 0.14)))
    }

    val attach = mapOf(
        Attach.Crown to Pt(tipX + 24 * k, tipY - 10 * k),
        Attach.UpperLeft to Pt(tipX + 14 * k, tipY + 4 * k),
        Attach.UpperRight to Pt(tipX + 56 * k, tipY),
        Attach.MidLeft to Pt(midX + 24 * k, midY - 16 * k),
        Attach.MidRight to Pt(midX + 56 * k, midY - 12 * k),
        Attach.LowerRight to Pt(midX + 70 * k, midY + 14 * k),
    )
    return TrunkResult(path, branches, bare, gnarl, attach)
}

private fun buildTrunk(p: Params, style: BonsaiStyle): TrunkResult = when (style) {
    BonsaiStyle.Cascade -> trunkCascade(p)
    BonsaiStyle.Windswept -> trunkWindswept(p)
    BonsaiStyle.Traditional -> trunkTraditional(p)
    // Sakura/Maple/Pine each have their own self-contained render path and never
    // reach this trunk/cluster pipeline; these keep the branch exhaustive.
    BonsaiStyle.Sakura, BonsaiStyle.Maple, BonsaiStyle.Pine -> trunkTraditional(p)
}

// MARK: - Params (pure continuous function of day, matches JS paramsForDay)

private class Params(
    val day: Int,
    val trunkHeight: Double,
    val trunkThickness: Double,
    val trunkGnarl: Double,
    val leafSaturation: Double,
    val mossOnTrunk: Double,
    val exposedRoots: Double,
    /**
     * 0 to 1 canopy growth factor (1 at day 365). Scales branch lengths and
     * cluster attach offsets so foliage hugs a young trunk.
     */
    val reach: Double,
    val clusters: List<ClusterSpec>,
)

private fun lerp(a: Double, b: Double, t: Double): Double = a + (b - a) * t

private fun eased(day: Int): Double {
    if (day >= 365) return 1.0
    val t = day.toDouble() / 365
    return 1 - pow(1 - t, 1.6)
}

private fun paramsForDay(day: Int, style: BonsaiStyle): Params {
    val e = eased(day)
    // Height starts low so day 8 (first day of the trunk pipeline) reads as a
    // grown-up version of the day-7 sprout, not a sudden adult tree.
    val trunkHeight = lerp(0.10, 0.86, e)
    val trunkThickness = lerp(0.14, if (style == BonsaiStyle.Cascade) 0.82 else 0.90, e)
    val trunkGnarl = maxOf(0.0, (day - 21).toDouble() / (365 - 21).toDouble())
    val leafSaturation = if (day < 14) lerp(0.85, 0.95, day.toDouble() / 14)
    else lerp(0.95, 1.0, (day - 14).toDouble() / (365 - 14).toDouble())
    val mossOnTrunk = if (day < 60) 0.0 else minOf(1.0, (day - 60).toDouble() / (365 - 60).toDouble())
    val exposedRoots = if (day < 21) 0.0 else minOf(1.0, (day - 21).toDouble() / (180 - 21).toDouble())

    val sizeBase = lerp(14.0, 82.0, e)
    val clusters = ArrayList<ClusterSpec>()
    clusters.add(
        ClusterSpec(Attach.Crown, (sizeBase * 1.0).swiftRounded(), 1.0, if (day < 21) Tone.Fresh else Tone.Sage),
    )
    if (day >= 14) {
        clusters.add(ClusterSpec(Attach.MidLeft, (sizeBase * 0.55).swiftRounded(), 2.0, Tone.Fresh))
        clusters.add(ClusterSpec(Attach.MidRight, (sizeBase * 0.52).swiftRounded(), 3.0, Tone.Sage))
    }
    if (day >= 30) {
        clusters.add(ClusterSpec(Attach.UpperLeft, (sizeBase * 0.75).swiftRounded(), 4.0, Tone.Fresh))
        clusters.add(ClusterSpec(Attach.UpperRight, (sizeBase * 0.72).swiftRounded(), 5.0, Tone.Sage))
    }
    if (day >= 60) {
        clusters.add(ClusterSpec(Attach.LowerRight, (sizeBase * 0.5).swiftRounded(), 6.0, Tone.Sage))
    }
    // Ambient canopy fillers, anchored to trunk attach points (not fixed
    // canvas coordinates) so they stay inside the silhouette on every style.
    if (day >= 90) {
        clusters.add(
            ClusterSpec(
                Attach.Crown, (sizeBase * 0.42).swiftRounded(), 7.0, Tone.Fresh,
                offsetW = -12.0, offsetH = 32.0,
            ),
        )
    }
    if (day >= 180) {
        clusters.add(
            ClusterSpec(
                Attach.MidRight, (sizeBase * 0.28).swiftRounded(), 8.0, Tone.Autumn, sat = 0.8,
                offsetW = 16.0, offsetH = 12.0,
            ),
        )
    }
    if (day >= 270) {
        clusters.add(
            ClusterSpec(
                Attach.MidLeft, (sizeBase * 0.28).swiftRounded(), 9.0, Tone.Autumn, sat = 0.75,
                offsetW = -14.0, offsetH = -8.0,
            ),
        )
    }

    return Params(
        day = day,
        trunkHeight = trunkHeight, trunkThickness = trunkThickness, trunkGnarl = trunkGnarl,
        leafSaturation = leafSaturation, mossOnTrunk = mossOnTrunk, exposedRoots = exposedRoots,
        reach = sizeBase / 82,
        clusters = clusters,
    )
}

// MARK: - Early stages (days 0-7), bespoke per JS renderEarly

private fun drawEarly(day: Int, style: BonsaiStyle, outer: BonsaiGraphics) {
    val baseY: Double = if (style == BonsaiStyle.Cascade) 378.0 else 410.0
    val cx = 300.0
    val ctx = outer
    ctx.save()
    if (style == BonsaiStyle.Cascade) {
        // Shrink the sprout so day 7 hands off smoothly to the cascade's short
        // riser on day 8 instead of towering over it.
        ctx.translate(cx, baseY)
        ctx.scale(0.62, 0.62)
        ctx.translate(-cx, -baseY)
    }
    when (day) {
        0 -> {
            ctx.fillColor(ellipse(cx, baseY + 1, 22.0, 3.5), Pal.barkDeep.opacity(0.55))
            ctx.fillColor(ellipse(cx + 1, baseY - 2, 7.0, 4.0), Pal.barkMid)
            ctx.fillColor(ellipse(cx - 0.5, baseY - 3, 4.5, 2.6), Pal.barkLight.opacity(0.85))
            ctx.fillColor(ellipse(cx - 1.5, baseY - 3.5, 2.0, 1.2), BonsaiColor.hex(0xE0BD8E).opacity(0.7))
        }
        1 -> {
            ctx.fillColor(ellipse(cx, baseY + 1, 14.0, 2.4), Pal.barkDeep.opacity(0.5))
            val stem = BonsaiPath()
            stem.move(cx - 0.5, baseY - 1)
            stem.quad(to = Pt(cx + 0.5, baseY - 16), control = Pt(cx + 0.5, baseY - 9))
            ctx.strokeRound(stem, Pal.leafSage, 3.2)
            fillRotatedEllipse(ctx, cx + 0.5, baseY - 18, 5.0, 3.0, -12.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 0.5, baseY - 19, 3.0, 1.8, -12.0, Pal.leafLight, 0.8)
        }
        2 -> {
            ctx.fillColor(ellipse(cx, baseY + 1, 14.0, 2.4), Pal.barkDeep.opacity(0.5))
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx + 1, baseY - 20), control = Pt(cx + 1, baseY - 14))
            ctx.strokeRound(stem, Pal.leafSage, 2.8)
            fillRotatedEllipse(ctx, cx - 5, baseY - 20, 6.0, 3.4, -26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 5, baseY - 21, 6.0, 3.4, 26.0, Pal.leafFresh)
        }
        3 -> {
            val stemH = 22.0
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx, baseY - stemH), control = Pt(cx + 1, baseY - stemH * 0.5))
            ctx.strokeRound(stem, Pal.leafFresh, 2.2)
            fillRotatedEllipse(ctx, cx - 9, baseY - stemH - 1, 10.0, 5.0, -22.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 11, baseY - stemH - 3, 6.0, 3.0, -22.0, Pal.leafLight, 0.8)
            fillRotatedEllipse(ctx, cx + 9, baseY - stemH - 1, 10.0, 5.0, 22.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 11, baseY - stemH - 3, 6.0, 3.0, 22.0, Pal.leafLight, 0.8)
        }
        4 -> {
            val stemH = 32.0
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx, baseY - stemH), control = Pt(cx + 1.5, baseY - stemH * 0.5))
            ctx.strokeRound(stem, Pal.leafFresh, 2.4)
            fillRotatedEllipse(ctx, cx - 10, baseY - 16, 11.0, 5.0, -26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 10, baseY - 16, 11.0, 5.0, 26.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx - 4, baseY - stemH - 1, 5.0, 3.0, -12.0, Pal.leafLight)
            fillRotatedEllipse(ctx, cx + 5, baseY - stemH - 1, 5.0, 3.0, 12.0, Pal.leafLight)
        }
        5 -> {
            val stemH = 42.0
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx + 1, baseY - stemH), control = Pt(cx + 2, baseY - stemH * 0.5))
            ctx.strokeRound(stem, Pal.leafSage, 2.6)
            fillRotatedEllipse(ctx, cx - 10, baseY - 18, 11.0, 5.0, -30.0, Pal.leafSage, 0.9)
            fillRotatedEllipse(ctx, cx + 10, baseY - 18, 11.0, 5.0, 30.0, Pal.leafSage, 0.9)
            fillRotatedEllipse(ctx, cx - 6, baseY - stemH - 2, 7.0, 3.4, -18.0, Pal.leafFresh)
            fillRotatedEllipse(ctx, cx + 7, baseY - stemH - 1, 7.0, 3.4, 18.0, Pal.leafFresh)
            ctx.fillColor(ellipse(cx + 1, baseY - stemH - 5, 5.0, 3.0), Pal.leafLight)
        }
        6 -> {
            val stemH = 58.0
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx + 1, baseY - stemH), control = Pt(cx - 1, baseY - stemH * 0.5))
            ctx.strokeRound(stem, Pal.barkLight, 2.8)
            fillRotatedEllipse(ctx, cx - 9, baseY - 26, 10.0, 4.0, -26.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx + 10, baseY - 38, 10.0, 4.0, 26.0, Pal.leafSage)
            drawCluster(cx + 1, baseY - stemH - 3, 12.0, Tone.Fresh, 0.9, 6.0, ctx)
        }
        else -> { // 7
            val stemH = 78.0
            val stem = BonsaiPath()
            stem.move(cx, baseY)
            stem.quad(to = Pt(cx + 1, baseY - stemH * 0.7), control = Pt(cx - 2, baseY - stemH * 0.4))
            stem.quad(to = Pt(cx + 2, baseY - stemH), control = Pt(cx + 3, baseY - stemH * 0.9))
            ctx.strokeRound(stem, Pal.barkLight, 3.2)
            fillRotatedEllipse(ctx, cx - 10, baseY - 38, 10.0, 4.0, -22.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx + 11, baseY - 54, 10.0, 4.0, 22.0, Pal.leafSage)
            fillRotatedEllipse(ctx, cx - 9, baseY - 68, 9.0, 3.8, -26.0, Pal.leafFresh)
            drawCluster(cx + 2, baseY - stemH - 2, 14.0, Tone.Fresh, 0.9, 7.0, ctx)
        }
    }
    ctx.restore()
}

// MARK: - Shared canopy easing helpers (Sakura / Maple / Pine)

private fun clamp01(x: Double): Double = if (x < 0) 0.0 else (if (x > 1) 1.0 else x)

private fun smoothstepS(e0: Double, e1: Double, x: Double): Double {
    val t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)
}

private fun ramp(day: Double, start: Double, end: Double, power: Double): Double =
    pow(clamp01((day - start) / (end - start)), power)

/** Sakura and Maple share the same canopy record shape. */
private class Canopy(
    val cX: Double, val cY: Double, val rx: Double, val ry: Double,
    val forkX: Double, val forkY: Double, val g: Double, val baseW: Double,
)

private class GrowLimb(val a: Double, val r: Double, val s: Double, val seed: Double, val app: Double, val span: Double)

private fun limb(a: Number, r: Number, s: Number, seed: Number, app: Number, span: Number) =
    GrowLimb(a.toDouble(), r.toDouble(), s.toDouble(), seed.toDouble(), app.toDouble(), span.toDouble())

private class GrowTuft(
    val ang: Double, val rad: Double, val app: Double, val sz: Double, val span: Double, val seed: Double,
)

private class LimbItem(
    val limb: GrowLimb, val e: Double, val tx: Double, val ty: Double, val size: Double, val branch: Boolean,
)

private class Blossom(
    val tx: Double, val ty: Double, val size: Double, val seed: Double, val accent: Boolean, val light: Boolean,
)

// MARK: - Sakura (cherry-blossom) bonsai, native port of bonsai-sakura.js

private object SakuraPal {
    val bloomDeep = BonsaiColor.hex(0xD77FA6)
    val bloomMid = BonsaiColor.hex(0xF2B2CD)
    val bloomLight = BonsaiColor.hex(0xFBD7E6)
    val bloomHi = BonsaiColor.hex(0xFFF1F7)
    val center = BonsaiColor.hex(0xF2C773)
    val barkDeep = BonsaiColor.hex(0x4A3526)
    val barkMid = BonsaiColor.hex(0x7C5B45)
    val barkLight = BonsaiColor.hex(0xAD8C70)
    val lenticel = BonsaiColor.hex(0x5A4233)
    val potDark = BonsaiColor.hex(0x5E7E6F)
    val potMid = BonsaiColor.hex(0x8AAE9C)
    val potLight = BonsaiColor.hex(0xBDD6C7)
    val potRim = BonsaiColor.hex(0x4C6A5C)
    val potGlaze = BonsaiColor.hex(0xD6E7DC)
    val soilDark = BonsaiColor.hex(0x221710)
    val soilMid = BonsaiColor.hex(0x3A2A1C)
}

// One shared scale drives every dimension, so growth is self-similar with no morphing.
private fun sakuraScale(d: Int): Double = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun sakuraBark(d: Int): Double = smoothstepS(70.0, 400.0, d.toDouble())
private fun sakuraPetalAmt(d: Int): Double = ramp(d.toDouble(), 45.0, 365.0, 1.0)

private fun sakuraCanopy(day: Int): Canopy {
    val baseY = 410.0
    val g = sakuraScale(day)
    val forkLen = 10 + 162 * g
    val forkY = baseY - forkLen
    val forkX = 303.0
    val rx = 8 + 138 * g
    val ry = 5 + 58 * g
    val baseW = 2.5 + 44 * g
    return Canopy(forkX, forkY - ry * 0.40, rx, ry, forkX, forkY, g, baseW)
}

private val sakuraLimbs: List<GrowLimb> = listOf(
    limb(90, 0.08, 1.00, 1, 0, 1),
    limb(124, 0.48, 0.90, 2, 7, 16),
    limb(56, 0.48, 0.90, 3, 13, 16),
    limb(150, 0.70, 0.80, 4, 22, 18),
    limb(30, 0.70, 0.80, 5, 31, 18),
    limb(96, 0.56, 0.78, 6, 42, 16),
    limb(112, 0.80, 0.70, 7, 54, 18),
    limb(67, 0.80, 0.70, 8, 67, 18),
    limb(20, 0.62, 0.66, 9, 84, 20),
    limb(160, 0.62, 0.66, 10, 104, 20),
    limb(44, 0.40, 0.66, 11, 126, 20),
    limb(136, 0.40, 0.66, 12, 150, 20),
    limb(80, 0.70, 0.62, 13, 178, 22),
    limb(104, 0.68, 0.62, 14, 210, 22),
    limb(38, 0.82, 0.56, 15, 248, 24),
    limb(146, 0.82, 0.56, 16, 290, 24),
    limb(90, 0.74, 0.58, 17, 332, 24),
)

private val sakuraTufts: List<GrowTuft> = run {
    val out = ArrayList<GrowTuft>()
    val n = 38
    for (i in 0 until n) {
        val u = rand01(700.0, (i + 1).toDouble())
        val v = rand01(810.0, (i + 1).toDouble())
        out.add(
            GrowTuft(
                ang = PI * (0.07 + 0.86 * u),
                rad = 0.06 + 0.70 * sqrt(v),
                app = 2 + pow(i.toDouble() / n.toDouble(), 0.92) * 356,
                sz = 0.48 + 0.42 * rand01(920.0, (i + 1).toDouble()),
                span = 9 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
                seed = 200 + i.toDouble(),
            ),
        )
    }
    out
}

/** A soft painterly blossom cluster (shadow, mid, lit clumps, highlights). */
private fun sakuraCluster(
    ctx: BonsaiGraphics, cx: Double, cy: Double, size: Double,
    seed: Double, squashY: Double = 0.84, noise: Double = 0.28,
    clumps: Int = 4, lights: Int = 3, sat: Double = 1.0, opacity: Double = 1.0, tilt: Double = 0.0,
) {
    val shadow = SakuraPal.bloomDeep
    val mid = SakuraPal.bloomMid
    val light = SakuraPal.bloomLight
    val hi = SakuraPal.bloomHi
    fun r(n: Double) = rand01(seed, n)

    ctx.save()
    ctx.translate(cx, cy)
    ctx.setOpacity(opacity)

    val sh = blobPath(
        cx = size * 0.10, cy = size * 0.13, rBase = size * 1.02,
        seed = seed * 1.1, points = 10, squashY = squashY, noise = noise * 0.85, tiltDeg = tilt,
    )
    ctx.fillColor(sh, shadow.opacity(0.8 * sat))

    val md = blobPath(
        cx = 0.0, cy = 0.0, rBase = size * 0.92,
        seed = seed * 1.3 + 7, points = 11, squashY = squashY + 0.03, noise = noise, tiltDeg = tilt * 0.6,
    )
    ctx.fillColor(md, mid.opacity(0.96 * sat))

    for (i in 0 until clumps) {
        val a = i.toDouble() / maxOf(1, clumps).toDouble() * PI * 1.4 - PI * 0.95
        val off = size * (0.30 + r((i * 5 + 2).toDouble()) * 0.22)
        val rad = size * (0.20 + r((i * 5 + 3).toDouble()) * 0.12)
        val p = blobPath(
            cx = cos(a) * off, cy = sin(a) * off * 0.7 - size * 0.08, rBase = rad,
            seed = seed * 17 + i.toDouble() * 31, points = 8, squashY = 0.9, noise = 0.32,
        )
        ctx.fillColor(p, light.opacity(0.72 * sat))
    }

    for (i in 0 until lights) {
        val a = -PI * 0.78 + i.toDouble() / maxOf(1, lights).toDouble() * PI * 0.72
        val off = size * (0.44 + r((i * 7 + 9).toDouble()) * 0.18)
        val rad = size * (0.10 + r((i * 7 + 11).toDouble()) * 0.07)
        val p = blobPath(
            cx = cos(a) * off, cy = sin(a) * off * 0.55 - size * 0.18, rBase = rad,
            seed = seed * 23 + i.toDouble() * 41, points = 8, squashY = 0.95, noise = 0.28,
        )
        ctx.fillColor(p, hi.opacity(0.85 * sat))
    }
    ctx.restore()
}

private fun drawSakuraPot(ctx: BonsaiGraphics) {
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
    ctx.fillColor(glaze, SakuraPal.potGlaze.opacity(0.30))

    val shade = BonsaiPath()
    shade.move(300.0, 415.0)
    shade.line(416.0, 460.0)
    shade.line(430.0, 415.0)
    shade.close()
    ctx.fillColor(shade, SakuraPal.potDark.opacity(0.45))

    val rim = BonsaiPath()
    rim.move(184.0, 460.0)
    rim.line(416.0, 460.0)
    rim.line(408.0, 456.0)
    rim.line(192.0, 456.0)
    rim.close()
    ctx.fillColor(rim, SakuraPal.potRim.opacity(0.55))

    ctx.fillColor(ellipse(300.0, 413.0, 130.0, 9.0), SakuraPal.potRim)
    ctx.fillColor(ellipse(300.0, 411.0, 130.0, 8.0), SakuraPal.potMid)
    ctx.fillColor(ellipse(300.0, 410.0, 126.0, 6.5), SakuraPal.potLight.opacity(0.7))
    ctx.fillColor(ellipse(300.0, 412.0, 124.0, 6.5), SakuraPal.soilMid)
    ctx.fillColor(ellipse(300.0, 412.5, 122.0, 5.5), SakuraPal.soilDark)
    ctx.fillColor(ellipse(240.0, 412.0, 1.8, 1.8), SakuraPal.barkMid.opacity(0.5))
    ctx.fillColor(ellipse(328.0, 412.0, 1.6, 1.6), SakuraPal.barkMid.opacity(0.45))
    ctx.fillColor(ellipse(285.0, 413.0, 1.2, 1.2), SakuraPal.barkLight.opacity(0.4))
}

private fun drawSakuraTrunk(day: Int, c: Canopy, ctx: BonsaiGraphics) {
    val baseX = 300.0
    val baseY = 410.0
    val topW = maxOf(2.2, c.baseW * 0.42)
    val midY = (baseY + c.forkY) / 2
    val bend = 2 + 7 * c.g
    val bL = baseX - c.baseW / 2
    val bR = baseX + c.baseW / 2
    val mL = baseX - bend - topW * 0.55
    val mR = baseX - bend + topW * 0.55
    val tL = c.forkX - topW / 2
    val tR = c.forkX + topW / 2

    val trunk = BonsaiPath()
    trunk.move(bL, baseY)
    trunk.quad(to = Pt(mL, midY), control = Pt(bL - 2, midY + 8))
    trunk.quad(to = Pt(tL, c.forkY), control = Pt(mL + 2, (midY + c.forkY) / 2))
    trunk.line(tR, c.forkY)
    trunk.quad(to = Pt(mR, midY), control = Pt(mR + 2, (midY + c.forkY) / 2))
    trunk.quad(to = Pt(bR, baseY), control = Pt(bR + 2, midY + 8))
    trunk.close()

    val tb = trunk.boundingRect()
    ctx.fill(
        trunk,
        gradient(listOf(SakuraPal.barkLight, SakuraPal.barkMid, SakuraPal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY),
    )

    val lc = sakuraBark(day)
    val forkLen = baseY - c.forkY
    if (lc > 0.05 && c.baseW > 14) {
        val rows = (2 + 5 * lc).swiftRounded().toInt()
        for (i in 0 until rows) {
            val ty = lerp(baseY - 8, c.forkY + 6, i.toDouble() / maxOf(1, rows - 1).toDouble())
            val tw = lerp(c.baseW, topW, (baseY - ty) / maxOf(1.0, forkLen))
            val lx = baseX - tw * 0.28 - bend * ((baseY - ty) / maxOf(1.0, forkLen))
            val ll = maxOf(2.4, tw * 0.5)
            val line = BonsaiPath()
            line.move(lx, ty)
            line.line(lx + ll, ty)
            ctx.strokeRound(line, SakuraPal.lenticel.opacity(0.5 * lc), 1.8)
        }
    }
}

private fun sakuraPetal(
    ctx: BonsaiGraphics, x: Double, y: Double, s: Double,
    rotDeg: Double, color: BonsaiColor, opacity: Double,
) {
    val p = BonsaiPath()
    p.move(0.0, -s)
    p.quad(to = Pt(s * 0.5, s * 0.62), control = Pt(s, -s * 0.35))
    p.quad(to = Pt(0.0, s * 0.5), control = Pt(s * 0.18, s * 0.18))
    p.quad(to = Pt(-s * 0.5, s * 0.62), control = Pt(-s * 0.18, s * 0.18))
    p.quad(to = Pt(0.0, -s), control = Pt(-s, -s * 0.35))
    p.close()
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(rotDeg * PI / 180)
    ctx.fillColor(p, color.opacity(opacity))
    ctx.restore()
}

private fun drawSakuraPetals(day: Int, c: Canopy, ctx: BonsaiGraphics) {
    val amt = sakuraPetalAmt(day)
    if (amt < 0.02) return
    val fallN = (amt * 30).swiftRounded().toInt()
    for (i in 0 until fallN) {
        val h1 = rand01(71.0, (i + 1).toDouble())
        val h2 = rand01(89.0, (i + 3).toDouble())
        sakuraPetal(
            ctx, x = 300 + (h1 - 0.5) * 158, y = 408.5 + h2 * 5.5,
            s = 3 + rand01(53.0, i.toDouble()) * 2, rotDeg = (h1 - 0.5) * 120,
            color = if (h2 > 0.5) SakuraPal.bloomLight else SakuraPal.bloomMid, opacity = 0.92,
        )
    }
    val airN = (amt * 12).swiftRounded().toInt()
    for (i in 0 until airN) {
        val h1 = rand01(131.0, (i + 1).toDouble())
        val h2 = rand01(167.0, (i + 5).toDouble())
        val h3 = rand01(199.0, (i + 9).toDouble())
        val y0 = c.cY + c.ry * 0.5 + h2 * (430 - (c.cY + c.ry * 0.5))
        sakuraPetal(
            ctx, x = c.cX + (h1 - 0.5) * c.rx * 2.0, y = minOf(y0, 432.0),
            s = 3 + h3 * 2.4, rotDeg = (h1 - 0.5) * 150,
            color = if (h3 > 0.5) SakuraPal.bloomLight else SakuraPal.bloomMid, opacity = 0.85,
        )
    }
}

private fun growLimbItems(c: Canopy, padBase: Double, limbs: List<GrowLimb>, day: Int): List<LimbItem> {
    val items = ArrayList<LimbItem>()
    for (l in limbs) {
        val e = if (l.app == 0.0) 1.0 else smoothstepS(l.app, l.app + l.span, day.toDouble())
        if (e < 0.02) continue
        val ar = l.a * PI / 180
        val tx = c.cX + cos(ar) * c.rx * l.r * e
        val ty = c.cY - sin(ar) * c.ry * l.r * e
        items.add(LimbItem(l, e, tx, ty, padBase * l.s * (0.6 + 0.4 * e), l.app != 0.0))
    }
    return items
}

private fun growBlossoms(c: Canopy, padBase: Double, items: List<LimbItem>, tufts: List<GrowTuft>, day: Int): List<Blossom> {
    val blossoms = ArrayList<Blossom>()
    for (it in items) {
        blossoms.add(Blossom(it.tx, it.ty, it.size, it.limb.seed, it.limb.seed.toInt() % 3 == 0, false))
    }
    for (t in tufts) {
        val e = smoothstepS(t.app, t.app + t.span, day.toDouble())
        if (e < 0.02) continue
        val rr = t.rad * (0.35 + 0.65 * e)
        val tx = c.cX + cos(t.ang) * c.rx * rr
        val ty = c.cY - sin(t.ang) * c.ry * rr
        blossoms.add(Blossom(tx, ty, padBase * t.sz * (0.6 + 0.4 * e), t.seed, false, true))
    }
    return blossoms
}

fun drawSakura(rawDay: Int, ctx: BonsaiGraphics) {
    val day = maxOf(0, minOf(365, rawDay))
    val c = sakuraCanopy(day)
    val padBase = 6 + 34 * c.g
    val limbItems = growLimbItems(c, padBase, sakuraLimbs, day)

    drawSakuraPot(ctx)

    // Branches sit behind the trunk, painted back-to-front (lowest on screen first).
    for (it in limbItems.sortedByDescending { it.ty }) {
        if (!it.branch) continue
        val ar = it.limb.a * PI / 180
        val mx = (c.forkX + it.tx) / 2 - sin(ar) * 5 * c.g
        val my = (c.forkY + it.ty) / 2 - 8 * c.g * it.e
        val w = maxOf(1.8, c.baseW * 0.20 * (0.4 + 0.6 * it.e))
        val b = BonsaiPath()
        b.move(c.forkX, c.forkY)
        b.quad(to = Pt(it.tx, it.ty), control = Pt(mx, my))
        ctx.strokeRound(b, SakuraPal.barkMid, w)
    }

    drawSakuraTrunk(day, c, ctx)

    val blossoms = growBlossoms(c, padBase, limbItems, sakuraTufts, day)
    for (it in blossoms.sortedByDescending { it.ty }) {
        val clumps = if (it.light) 0 else 2
        val lights = if (it.light) 1 else 2
        sakuraCluster(
            ctx, cx = it.tx, cy = it.ty, size = it.size, seed = it.seed * 5 + 2,
            squashY = 0.86, noise = 0.30, clumps = clumps, lights = lights, sat = 1.0, opacity = 1.0,
        )
        if (c.g > 0.45 && it.accent) {
            ctx.fillColor(
                ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                SakuraPal.center.opacity(0.4),
            )
        }
    }

    drawSakuraPetals(day, c, ctx)
}

private fun contentRectFloor(rectIn: BRect): BRect {
    var rect = rectIn
    val minDim = 230.0
    if (rect.width < minDim) rect = rect.insetBy(-(minDim - rect.width) / 2, 0.0)
    if (rect.height < minDim) rect = rect.insetBy(0.0, -(minDim - rect.height) / 2)
    return rect
}

/** Tight content box for the sakura in the 600x600 design space. */
fun sakuraContentRect(day: Int): BRect {
    val d = minOf(365, maxOf(0, day))
    val c = sakuraCanopy(d)
    val padBase = 6 + 34 * c.g
    var minX = 170.0
    var maxX = 430.0
    var minY = 410.0
    val maxY = 464.0 // pot footprint always anchors the bottom
    minX = minOf(minX, c.cX - c.rx - padBase)
    maxX = maxOf(maxX, c.cX + c.rx + padBase)
    minY = minOf(minY, c.cY - c.ry - padBase * 1.3)
    return contentRectFloor(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Maple (Japanese maple) bonsai, native port of bonsai-maple.js

private object MaplePal {
    val folDeep = BonsaiColor.hex(0x8C2E22)
    val folMid = BonsaiColor.hex(0xC8472A)
    val folLight = BonsaiColor.hex(0xE87B33)
    val folHi = BonsaiColor.hex(0xF4B24B)
    val folEmber = BonsaiColor.hex(0x9E3320)
    val barkDeep = BonsaiColor.hex(0x43342B)
    val barkMid = BonsaiColor.hex(0x6E594A)
    val barkLight = BonsaiColor.hex(0x9C8676)
    val barkStripe = BonsaiColor.hex(0x574539)
    val potDark = BonsaiColor.hex(0x26282B)
    val potMid = BonsaiColor.hex(0x3C4045)
    val potLight = BonsaiColor.hex(0x565C63)
    val potRim = BonsaiColor.hex(0x1A1B1D)
    val potGlaze = BonsaiColor.hex(0x6B7178)
    val soilDark = BonsaiColor.hex(0x211712)
    val soilMid = BonsaiColor.hex(0x37281D)
}

private fun mapleScale(d: Int): Double = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun mapleBark(d: Int): Double = smoothstepS(70.0, 400.0, d.toDouble())
private fun mapleFall(d: Int): Double = ramp(d.toDouble(), 55.0, 365.0, 1.0)

private fun mapleCanopy(day: Int): Canopy {
    val baseY = 410.0
    val g = mapleScale(day)
    val forkLen = 12 + 182 * g
    val forkY = baseY - forkLen
    val forkX = 304.0
    val rx = 8 + 132 * g
    val ry = 6 + 74 * g
    val baseW = 2.4 + 38 * g
    return Canopy(forkX, forkY - ry * 0.34, rx, ry, forkX, forkY, g, baseW)
}

private val mapleLimbs: List<GrowLimb> = listOf(
    limb(90, 0.10, 1.00, 1, 0, 1),
    limb(120, 0.46, 0.88, 2, 7, 16),
    limb(60, 0.46, 0.88, 3, 13, 16),
    limb(142, 0.66, 0.78, 4, 22, 18),
    limb(38, 0.66, 0.78, 5, 31, 18),
    limb(96, 0.62, 0.80, 6, 42, 16),
    limb(108, 0.84, 0.70, 7, 54, 18),
    limb(72, 0.84, 0.70, 8, 67, 18),
    limb(26, 0.58, 0.66, 9, 84, 20),
    limb(154, 0.58, 0.66, 10, 104, 20),
    limb(50, 0.38, 0.66, 11, 126, 20),
    limb(130, 0.38, 0.66, 12, 150, 20),
    limb(84, 0.74, 0.62, 13, 178, 22),
    limb(100, 0.72, 0.62, 14, 210, 22),
    limb(44, 0.80, 0.56, 15, 248, 24),
    limb(138, 0.80, 0.56, 16, 290, 24),
    limb(90, 0.86, 0.58, 17, 332, 24),
)

private val mapleTufts: List<GrowTuft> = run {
    val out = ArrayList<GrowTuft>()
    val n = 46
    for (i in 0 until n) {
        val u = rand01(700.0, (i + 1).toDouble())
        val v = rand01(810.0, (i + 1).toDouble())
        out.add(
            GrowTuft(
                ang = PI * (0.05 + 0.90 * u),
                rad = 0.05 + 0.74 * sqrt(v),
                app = 2 + pow(i.toDouble() / n.toDouble(), 0.92) * 356,
                sz = 0.40 + 0.40 * rand01(920.0, (i + 1).toDouble()),
                span = 9 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
                seed = 200 + i.toDouble(),
            ),
        )
    }
    out
}

private fun mapleCluster(
    ctx: BonsaiGraphics, cx: Double, cy: Double, size: Double,
    seed: Double, squashY: Double = 0.84, noise: Double = 0.34,
    clumps: Int = 4, lights: Int = 3, sat: Double = 1.0, opacity: Double = 1.0, tilt: Double = 0.0,
) {
    val shadow = MaplePal.folDeep
    val mid = MaplePal.folMid
    val light = MaplePal.folLight
    val hi = MaplePal.folHi
    fun r(n: Double) = rand01(seed, n)
    ctx.save()
    ctx.translate(cx, cy)
    ctx.setOpacity(opacity)

    val sh = blobPath(
        cx = size * 0.10, cy = size * 0.13, rBase = size * 1.02,
        seed = seed * 1.1, points = 11, squashY = squashY, noise = noise * 0.9, tiltDeg = tilt,
    )
    ctx.fillColor(sh, shadow.opacity(0.82 * sat))
    val md = blobPath(
        cx = 0.0, cy = 0.0, rBase = size * 0.92,
        seed = seed * 1.3 + 7, points = 12, squashY = squashY + 0.02, noise = noise, tiltDeg = tilt * 0.6,
    )
    ctx.fillColor(md, mid.opacity(0.96 * sat))
    for (i in 0 until clumps) {
        val a = i.toDouble() / maxOf(1, clumps).toDouble() * PI * 1.4 - PI * 0.95
        val off = size * (0.30 + r((i * 5 + 2).toDouble()) * 0.24)
        val rad = size * (0.18 + r((i * 5 + 3).toDouble()) * 0.12)
        val p = blobPath(
            cx = cos(a) * off, cy = sin(a) * off * 0.7 - size * 0.08, rBase = rad,
            seed = seed * 17 + i.toDouble() * 31, points = 8, squashY = 0.9, noise = 0.4,
        )
        ctx.fillColor(p, light.opacity(0.74 * sat))
    }
    for (i in 0 until lights) {
        val a = -PI * 0.78 + i.toDouble() / maxOf(1, lights).toDouble() * PI * 0.72
        val off = size * (0.44 + r((i * 7 + 9).toDouble()) * 0.18)
        val rad = size * (0.09 + r((i * 7 + 11).toDouble()) * 0.07)
        val p = blobPath(
            cx = cos(a) * off, cy = sin(a) * off * 0.55 - size * 0.18, rBase = rad,
            seed = seed * 23 + i.toDouble() * 41, points = 7, squashY = 0.95, noise = 0.34,
        )
        ctx.fillColor(p, hi.opacity(0.85 * sat))
    }
    ctx.restore()
}

private fun drawMaplePot(ctx: BonsaiGraphics) {
    val body = BonsaiPath()
    body.move(176.0, 418.0)
    body.line(186.0, 460.0)
    body.line(414.0, 460.0)
    body.line(424.0, 418.0)
    body.close()
    ctx.fill(body, gradient(listOf(MaplePal.potMid, MaplePal.potDark), 300.0, 418.0, 300.0, 460.0))

    val glaze = BonsaiPath()
    glaze.move(186.0, 420.0)
    glaze.line(198.0, 452.0)
    glaze.line(262.0, 452.0)
    glaze.line(256.0, 420.0)
    glaze.close()
    ctx.fillColor(glaze, MaplePal.potGlaze.opacity(0.16))

    val shade = BonsaiPath()
    shade.move(300.0, 418.0)
    shade.line(414.0, 460.0)
    shade.line(424.0, 418.0)
    shade.close()
    ctx.fillColor(shade, MaplePal.potDark.opacity(0.5))

    val rim = BonsaiPath()
    rim.move(186.0, 460.0)
    rim.line(414.0, 460.0)
    rim.line(406.0, 455.0)
    rim.line(194.0, 455.0)
    rim.close()
    ctx.fillColor(rim, MaplePal.potRim.opacity(0.6))

    val lip = BonsaiPath()
    lip.move(168.0, 410.0)
    lip.line(432.0, 410.0)
    lip.line(424.0, 421.0)
    lip.line(176.0, 421.0)
    lip.close()
    ctx.fillColor(lip, MaplePal.potLight.opacity(0.9))

    val lipHi = BonsaiPath()
    lipHi.move(168.0, 410.0)
    lipHi.line(432.0, 410.0)
    lipHi.line(430.0, 414.0)
    lipHi.line(170.0, 414.0)
    lipHi.close()
    ctx.fillColor(lipHi, MaplePal.potGlaze.opacity(0.4))

    val lipShadow = BonsaiPath()
    lipShadow.move(176.0, 421.0)
    lipShadow.line(424.0, 421.0)
    lipShadow.line(421.0, 425.0)
    lipShadow.line(179.0, 425.0)
    lipShadow.close()
    ctx.fillColor(lipShadow, MaplePal.potRim.opacity(0.5))

    ctx.fillColor(ellipse(300.0, 412.0, 124.0, 6.5), MaplePal.soilMid)
    ctx.fillColor(ellipse(300.0, 412.5, 122.0, 5.5), MaplePal.soilDark)
    ctx.fillColor(ellipse(242.0, 412.0, 1.8, 1.8), MaplePal.barkMid.opacity(0.5))
    ctx.fillColor(ellipse(330.0, 412.0, 1.6, 1.6), MaplePal.barkMid.opacity(0.45))
    ctx.fillColor(ellipse(286.0, 413.0, 1.2, 1.2), MaplePal.barkLight.opacity(0.4))
}

private fun drawMapleTrunk(day: Int, c: Canopy, ctx: BonsaiGraphics) {
    val baseX = 300.0
    val baseY = 410.0
    val topW = maxOf(2.0, c.baseW * 0.40)
    val midY = (baseY + c.forkY) / 2
    val bend = 3 + 9 * c.g
    val bL = baseX - c.baseW / 2
    val bR = baseX + c.baseW / 2
    val mL = baseX - bend - topW * 0.55
    val mR = baseX - bend + topW * 0.55
    val tL = c.forkX - topW / 2
    val tR = c.forkX + topW / 2

    val trunk = BonsaiPath()
    trunk.move(bL, baseY)
    trunk.quad(to = Pt(mL, midY), control = Pt(bL - 2, midY + 8))
    trunk.quad(to = Pt(tL, c.forkY), control = Pt(mL + 2, (midY + c.forkY) / 2))
    trunk.line(tR, c.forkY)
    trunk.quad(to = Pt(mR, midY), control = Pt(mR + 2, (midY + c.forkY) / 2))
    trunk.quad(to = Pt(bR, baseY), control = Pt(bR + 2, midY + 8))
    trunk.close()

    val tb = trunk.boundingRect()
    ctx.fill(
        trunk,
        gradient(listOf(MaplePal.barkLight, MaplePal.barkMid, MaplePal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY),
    )

    val lc = mapleBark(day)
    if (lc > 0.05 && c.baseW > 12) {
        val n = (2 + 3 * lc).swiftRounded().toInt()
        for (i in 0 until n) {
            val fx = lerp(-0.3, 0.3, i.toDouble() / maxOf(1, n - 1).toDouble())
            val x0 = baseX + fx * c.baseW * 0.7
            val x1 = c.forkX + fx * topW * 0.7 - bend
            val s = BonsaiPath()
            s.move(x0, baseY - 4)
            s.quad(to = Pt(x1, c.forkY + 4), control = Pt((x0 + x1) / 2 - bend * 0.5, midY))
            ctx.strokeRound(s, MaplePal.barkStripe.opacity(0.4 * lc), 1.8)
        }
    }
}

private fun mapleLeaf(
    ctx: BonsaiGraphics, x: Double, y: Double, s: Double,
    rotDeg: Double, color: BonsaiColor, opacity: Double,
) {
    val p = BonsaiPath()
    for (i in 0 until 5) {
        val a = i.toDouble() / 5 * PI * 2 - PI / 2
        val aInner = a + PI / 5
        val outerX = cos(a) * s
        val outerY = sin(a) * s
        val innerX = cos(aInner) * s * 0.42
        val innerY = sin(aInner) * s * 0.42
        if (i == 0) p.move(outerX, outerY) else p.line(outerX, outerY)
        p.line(innerX, innerY)
    }
    p.close()
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(rotDeg * PI / 180)
    ctx.fillColor(p, color.opacity(opacity))
    ctx.restore()
}

private fun drawMapleLeaves(day: Int, c: Canopy, ctx: BonsaiGraphics) {
    val amt = mapleFall(day)
    if (amt < 0.02) return
    val fallN = (amt * 26).swiftRounded().toInt()
    for (i in 0 until fallN) {
        val h1 = rand01(71.0, (i + 1).toDouble())
        val h2 = rand01(89.0, (i + 3).toDouble())
        val h3 = rand01(53.0, i.toDouble())
        val fill = if (h3 > 0.6) MaplePal.folHi else (if (h3 > 0.3) MaplePal.folLight else MaplePal.folMid)
        mapleLeaf(
            ctx, x = 300 + (h1 - 0.5) * 160, y = 408 + h2 * 6, s = 3.2 + h3 * 2,
            rotDeg = (h1 - 0.5) * 180, color = fill, opacity = 0.92,
        )
    }
    val airN = (amt * 10).swiftRounded().toInt()
    for (i in 0 until airN) {
        val h1 = rand01(131.0, (i + 1).toDouble())
        val h2 = rand01(167.0, (i + 5).toDouble())
        val h3 = rand01(199.0, (i + 9).toDouble())
        val y0 = c.cY + c.ry * 0.5 + h2 * (430 - (c.cY + c.ry * 0.5))
        val fill = if (h3 > 0.5) MaplePal.folLight else MaplePal.folMid
        mapleLeaf(
            ctx, x = c.cX + (h1 - 0.5) * c.rx * 2.0, y = minOf(y0, 432.0), s = 3 + h3 * 2.2,
            rotDeg = (h1 - 0.5) * 200, color = fill, opacity = 0.85,
        )
    }
}

fun drawMaple(rawDay: Int, ctx: BonsaiGraphics) {
    val day = maxOf(0, minOf(365, rawDay))
    val c = mapleCanopy(day)
    val padBase = 5 + 30 * c.g
    val limbItems = growLimbItems(c, padBase, mapleLimbs, day)

    drawMaplePot(ctx)

    for (it in limbItems.sortedByDescending { it.ty }) {
        if (!it.branch) continue
        val ar = it.limb.a * PI / 180
        val mx = (c.forkX + it.tx) / 2 - sin(ar) * 5 * c.g
        val my = (c.forkY + it.ty) / 2 - 6 * c.g * it.e
        val w = maxOf(1.6, c.baseW * 0.17 * (0.4 + 0.6 * it.e))
        val b = BonsaiPath()
        b.move(c.forkX, c.forkY)
        b.quad(to = Pt(it.tx, it.ty), control = Pt(mx, my))
        ctx.strokeRound(b, MaplePal.barkMid, w)
    }

    drawMapleTrunk(day, c, ctx)

    val fol = growBlossoms(c, padBase, limbItems, mapleTufts, day)
    for (it in fol.sortedByDescending { it.ty }) {
        val clumps = if (it.light) 0 else 2
        val lights = if (it.light) 1 else 2
        mapleCluster(
            ctx, cx = it.tx, cy = it.ty, size = it.size, seed = it.seed * 5 + 2,
            squashY = 0.84, noise = 0.36, clumps = clumps, lights = lights, sat = 1.0, opacity = 1.0,
        )
        if (c.g > 0.45 && it.accent) {
            ctx.fillColor(
                ellipse(it.tx + it.size * 0.1, it.ty - it.size * 0.1, 1.2 + c.g, 1.2 + c.g),
                MaplePal.folEmber.opacity(0.4),
            )
        }
    }

    drawMapleLeaves(day, c, ctx)
}

fun mapleContentRect(day: Int): BRect {
    val d = minOf(365, maxOf(0, day))
    val c = mapleCanopy(d)
    val padBase = 5 + 30 * c.g
    var minX = 168.0
    var maxX = 432.0
    var minY = 410.0
    val maxY = 462.0
    minX = minOf(minX, c.cX - c.rx - padBase)
    maxX = maxOf(maxX, c.cX + c.rx + padBase)
    minY = minOf(minY, c.cY - c.ry - padBase * 1.3)
    return contentRectFloor(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Pine (Japanese black pine) bonsai, native port of bonsai-pine.js

private object PinePal {
    val needDeep = BonsaiColor.hex(0x1E3A30)
    val needMid = BonsaiColor.hex(0x2F6149)
    val needLight = BonsaiColor.hex(0x4C8A63)
    val needHi = BonsaiColor.hex(0x7FB583)
    val candle = BonsaiColor.hex(0xB7C68A)
    val barkDeep = BonsaiColor.hex(0x33271F)
    val barkMid = BonsaiColor.hex(0x5A4636)
    val barkLight = BonsaiColor.hex(0x897059)
    val barkPlate = BonsaiColor.hex(0x3E2F24)
    val barkMoss = BonsaiColor.hex(0x6E7A4E)
    val potDark = BonsaiColor.hex(0x5A3D2A)
    val potMid = BonsaiColor.hex(0x825939)
    val potLight = BonsaiColor.hex(0xA8794F)
    val potRim = BonsaiColor.hex(0x432C1D)
    val potSpeck = BonsaiColor.hex(0xC49A6A)
    val soilDark = BonsaiColor.hex(0x211611)
    val soilMid = BonsaiColor.hex(0x36271C)
}

private fun pineScale(d: Int): Double = ramp(d.toDouble(), 0.0, 430.0, 0.5)
private fun pineBark(d: Int): Double = smoothstepS(60.0, 380.0, d.toDouble())
private fun pineNeedle(d: Int): Double = ramp(d.toDouble(), 60.0, 365.0, 1.0)
private fun pineCandle(d: Int): Double =
    smoothstepS(20.0, 120.0, d.toDouble()) * (1 - smoothstepS(150.0, 230.0, d.toDouble()))

private fun lerpP(a: Pt, b: Pt, t: Double) = Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)

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

private class PinePad(
    val side: Double, val hFrac: Double, val reach: Double, val wFrac: Double,
    val app: Double, val span: Double, val seed: Double,
)

private fun pad(side: Number, hFrac: Number, reach: Number, wFrac: Number, app: Number, span: Number, seed: Number) =
    PinePad(
        side.toDouble(), hFrac.toDouble(), reach.toDouble(), wFrac.toDouble(),
        app.toDouble(), span.toDouble(), seed.toDouble(),
    )

private val pinePads: List<PinePad> = listOf(
    pad(0, 1.00, 0.00, 0.62, 0, 1, 1),
    pad(1, 0.62, 0.95, 0.95, 8, 20, 2),
    pad(-1, 0.46, 0.85, 0.85, 26, 22, 3),
    pad(1, 0.80, 0.62, 0.72, 70, 24, 4),
    pad(-1, 0.86, 0.40, 0.58, 150, 28, 5),
    pad(1, 0.30, 1.05, 0.70, 250, 30, 6),
)

private class PineTuft(
    val padU: Double, val fx: Double, val fy: Double, val app: Double,
    val sz: Double, val span: Double, val seed: Double,
)

private val pineTufts: List<PineTuft> = run {
    val out = ArrayList<PineTuft>()
    val n = 30
    for (i in 0 until n) {
        out.add(
            PineTuft(
                padU = rand01(610.0, (i + 1).toDouble()),
                fx = (rand01(700.0, (i + 1).toDouble()) - 0.5) * 1.7,
                fy = (rand01(810.0, (i + 1).toDouble()) - 0.5) * 0.7,
                app = 4 + pow(i.toDouble() / n.toDouble(), 0.9) * 354,
                sz = 0.30 + 0.30 * rand01(920.0, (i + 1).toDouble()),
                span = 10 + (rand01(930.0, (i + 1).toDouble()) * 6).swiftRounded(),
                seed = 300 + i.toDouble(),
            ),
        )
    }
    out
}

private fun needleCluster(
    ctx: BonsaiGraphics, cx: Double, cy: Double, w: Double, h: Double,
    seed: Double, noise: Double = 0.30, clumps: Int = 4, lights: Int = 3, sat: Double = 1.0, opacity: Double = 1.0,
) {
    val shadow = PinePal.needDeep
    val mid = PinePal.needMid
    val light = PinePal.needLight
    val hi = PinePal.needHi
    fun r(n: Double) = rand01(seed, n)
    val sq = h / w
    ctx.save()
    ctx.translate(cx, cy)
    ctx.setOpacity(opacity)

    val sh = blobPath(
        cx = 0.0, cy = h * 0.22, rBase = w * 1.02, seed = seed * 1.1, points = 12,
        squashY = sq, noise = noise * 0.85, tiltDeg = 0.0,
    )
    ctx.fillColor(sh, shadow.opacity(0.85 * sat))
    val md = blobPath(
        cx = 0.0, cy = 0.0, rBase = w * 0.94, seed = seed * 1.3 + 7, points = 13,
        squashY = sq + 0.03, noise = noise, tiltDeg = 0.0,
    )
    ctx.fillColor(md, mid.opacity(0.96 * sat))
    for (i in 0 until clumps) {
        val fx = (i.toDouble() / maxOf(1, clumps - 1).toDouble() - 0.5) * 1.7
        val off = w * fx
        val rad = w * (0.22 + r((i * 5 + 3).toDouble()) * 0.13)
        val p = blobPath(
            cx = off, cy = -h * 0.18, rBase = rad, seed = seed * 17 + i.toDouble() * 31,
            points = 8, squashY = 0.62, noise = 0.36,
        )
        ctx.fillColor(p, light.opacity(0.72 * sat))
    }
    for (i in 0 until lights) {
        val fx = (i.toDouble() / maxOf(1, lights - 1).toDouble() - 0.5) * 1.5
        val rad = w * (0.10 + r((i * 7 + 11).toDouble()) * 0.06)
        val p = blobPath(
            cx = w * fx, cy = -h * 0.34, rBase = rad, seed = seed * 23 + i.toDouble() * 41,
            points = 7, squashY = 0.7, noise = 0.3,
        )
        ctx.fillColor(p, hi.opacity(0.8 * sat))
    }
    ctx.restore()
}

private fun drawPinePot(ctx: BonsaiGraphics) {
    val body = BonsaiPath()
    body.move(188.0, 414.0)
    body.quad(to = Pt(196.0, 458.0), control = Pt(186.0, 440.0))
    body.line(404.0, 458.0)
    body.quad(to = Pt(412.0, 414.0), control = Pt(414.0, 440.0))
    body.close()
    ctx.fill(body, gradient(listOf(PinePal.potMid, PinePal.potDark), 300.0, 414.0, 300.0, 458.0))

    val shade = BonsaiPath()
    shade.move(300.0, 414.0)
    shade.quad(to = Pt(404.0, 458.0), control = Pt(412.0, 440.0))
    shade.line(300.0, 458.0)
    shade.close()
    ctx.fillColor(shade, PinePal.potDark.opacity(0.4))

    val hl = BonsaiPath()
    hl.move(196.0, 420.0)
    hl.quad(to = Pt(200.0, 450.0), control = Pt(193.0, 436.0))
    hl.line(236.0, 450.0)
    hl.quad(to = Pt(232.0, 420.0), control = Pt(230.0, 434.0))
    hl.close()
    ctx.fillColor(hl, PinePal.potLight.opacity(0.22))

    ctx.fillColor(ellipse(300.0, 414.0, 112.0, 11.0), PinePal.potRim)
    ctx.fillColor(ellipse(300.0, 412.0, 112.0, 10.0), PinePal.potMid)
    ctx.fillColor(ellipse(300.0, 411.0, 108.0, 8.5), PinePal.potLight.opacity(0.55))
    ctx.fillColor(ellipse(300.0, 412.5, 103.0, 6.5), PinePal.soilMid)
    ctx.fillColor(ellipse(300.0, 413.0, 101.0, 5.5), PinePal.soilDark)
    ctx.fillColor(ellipse(250.0, 430.0, 1.6, 1.6), PinePal.potSpeck.opacity(0.4))
    ctx.fillColor(ellipse(340.0, 440.0, 1.4, 1.4), PinePal.potSpeck.opacity(0.35))
    ctx.fillColor(ellipse(300.0, 448.0, 1.5, 1.5), PinePal.potSpeck.opacity(0.3))
    ctx.fillColor(ellipse(225.0, 412.0, 1.6, 1.6), PinePal.barkMid.opacity(0.45))
    ctx.fillColor(ellipse(352.0, 412.0, 1.4, 1.4), PinePal.barkMid.opacity(0.4))
}

private fun drawPineTrunk(day: Int, c: PineCanopy, ctx: BonsaiGraphics) {
    val baseX = c.baseX
    val baseY = c.baseY
    val topX = c.topX
    val topY = c.topY
    val baseW = c.baseW
    val topW = maxOf(2.2, baseW * 0.30)
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
    fun tangent(t: Double): Pt {
        val a = lerpP(p0, p1, t)
        val b = lerpP(p1, p2, t)
        val cc = lerpP(p2, p3, t)
        val ab = lerpP(a, b, t)
        val bc = lerpP(b, cc, t)
        return Pt(bc.x - ab.x, bc.y - ab.y)
    }
    fun widthAt(t: Double) = lerp(baseW, topW, t)
    fun side(sign: Double): List<Pt> {
        val steps = 5
        val pts = ArrayList<Pt>()
        for (i in 0..steps) {
            val t = i.toDouble() / steps.toDouble()
            val pt = bez(t)
            val tg = tangent(t)
            val len = maxOf(hypot(tg.x, tg.y), 1.0)
            val nx = -tg.y / len
            val ny = tg.x / len
            val w = widthAt(t) / 2
            pts.add(Pt(pt.x + sign * nx * w, pt.y + sign * ny * w))
        }
        return pts
    }
    val lPts = side(1.0)
    val rPts = side(-1.0).asReversed()
    val trunk = BonsaiPath()
    trunk.move(lPts[0])
    for (i in 1 until lPts.size) trunk.line(lPts[i])
    for (pt in rPts) trunk.line(pt)
    trunk.close()
    val tb = trunk.boundingRect()
    ctx.fill(
        trunk,
        gradient(listOf(PinePal.barkLight, PinePal.barkMid, PinePal.barkDeep), tb.minX, tb.midY, tb.maxX, tb.midY),
    )

    val lc = pineBark(day)
    if (lc > 0.05 && baseW > 12) {
        val n = (3 + 5 * lc).swiftRounded().toInt()
        for (i in 0 until n) {
            val t = (i.toDouble() + 0.5) / n.toDouble()
            val pt = bez(t)
            val w = widthAt(t)
            val s = BonsaiPath()
            s.move(pt.x - w * 0.3, pt.y)
            s.quad(to = Pt(pt.x + w * 0.3, pt.y), control = Pt(pt.x, pt.y + 2))
            ctx.strokeRound(s, PinePal.barkPlate.opacity(0.45 * lc), 1.8)
        }
        ctx.fillColor(ellipse(baseX - baseW * 0.25, baseY - 4, 2 + lc, 2 + lc), PinePal.barkMoss.opacity(0.4 * lc))
        ctx.fillColor(ellipse(baseX + baseW * 0.18, baseY - 2, 1.6 + lc, 1.6 + lc), PinePal.barkMoss.opacity(0.32 * lc))
    }
}

private fun pineNeedlePair(
    ctx: BonsaiGraphics, x: Double, y: Double, s: Double,
    rotDeg: Double, color: BonsaiColor, opacity: Double,
) {
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(rotDeg * PI / 180)
    val a = BonsaiPath()
    a.move(0.0, 0.0)
    a.line(-s * 0.3, s)
    val b = BonsaiPath()
    b.move(0.0, 0.0)
    b.line(s * 0.3, s)
    ctx.strokeRound(a, color.opacity(opacity), 1.5)
    ctx.strokeRound(b, color.opacity(opacity), 1.5)
    ctx.restore()
}

private class PadLive(val p: PinePad, val e: Double, val x: Double, val y: Double, val w: Double, val h: Double)

/** The pads alive on `day`, in `pinePads` order. */
private fun pineLivePads(day: Int, c: PineCanopy): List<PadLive> {
    val live = ArrayList<PadLive>()
    for (p in pinePads) {
        val e = if (p.app == 0.0) 1.0 else smoothstepS(p.app, p.app + p.span, day.toDouble())
        if (e < 0.02) continue
        val y = lerp(c.baseY, c.topY, p.hFrac)
        val leanAtH = lerp(0.0, c.topX - c.baseX, p.hFrac)
        val padW = (10 + 78 * c.g) * p.wFrac
        val x = c.baseX + leanAtH + p.side * p.reach * padW * 0.65 * e
        val w = padW * (0.5 + 0.5 * e)
        live.add(PadLive(p, e, x, y, w, w * 0.42))
    }
    return live
}

private class NItem(val x: Double, val y: Double, val w: Double, val h: Double, val seed: Double, val light: Boolean)

/**
 * Every needle blob painted on `day`: the pads themselves plus the tufts that
 * sit on top of them. drawPine paints exactly this list and pineContentRect
 * measures exactly this list.
 */
private fun pineNeedleItems(day: Int, live: List<PadLive>): List<NItem> {
    val items = ArrayList<NItem>()
    for (l in live) items.add(NItem(l.x, l.y, l.w, l.h, l.p.seed, false))
    if (live.isEmpty()) return items
    for (t in pineTufts) {
        val e = smoothstepS(t.app, t.app + t.span, day.toDouble())
        if (e < 0.02) continue
        val host = live[floor(t.padU * live.size.toDouble()).toInt() % live.size]
        val ex = 0.4 + 0.6 * e
        val x = host.x + t.fx * host.w * ex
        val y = host.y + t.fy * host.h
        val w = host.w * t.sz * (0.6 + 0.4 * e)
        items.add(NItem(x, y, w, w * 0.5, t.seed, true))
    }
    return items
}

fun drawPine(rawDay: Int, ctx: BonsaiGraphics) {
    val day = maxOf(0, minOf(365, rawDay))
    val c = pineCanopy(day)

    drawPinePot(ctx)
    drawPineTrunk(day, c, ctx)

    val live = pineLivePads(day, c)

    for (it in live.sortedByDescending { it.y }) {
        if (it.p.app == 0.0) continue
        val leanAtH = lerp(0.0, c.topX - c.baseX, it.p.hFrac)
        val sx = c.baseX + leanAtH
        val w = maxOf(1.8, c.baseW * 0.16 * (0.5 + 0.5 * it.e))
        val b = BonsaiPath()
        b.move(sx, it.y + 2)
        b.quad(to = Pt(it.x, it.y), control = Pt((sx + it.x) / 2, it.y + 4))
        ctx.strokeRound(b, PinePal.barkDeep, w)
    }

    val items = pineNeedleItems(day, live)
    for (it in items.sortedBy { it.y }) {
        val clumps = if (it.light) 0 else 4
        val lights = if (it.light) 1 else 3
        needleCluster(
            ctx, cx = it.x, cy = it.y, w = it.w, h = it.h, seed = it.seed * 5 + 2,
            noise = 0.32, clumps = clumps, lights = lights, sat = 1.0, opacity = 1.0,
        )
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
                ctx.strokeRound(s, PinePal.candle.opacity(0.6 * cand), 2.0)
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
            pineNeedlePair(
                ctx, x = 300 + (h1 - 0.5) * 140, y = 408 + h2 * 6, s = 4 + h3 * 3,
                rotDeg = (h1 - 0.5) * 160, color = fill, opacity = 0.7,
            )
        }
    }
}

fun pineContentRect(day: Int): BRect {
    val d = minOf(365, maxOf(0, day))
    val c = pineCanopy(d)
    var minX = 186.0
    var maxX = 414.0
    var minY = 410.0
    val maxY = 460.0
    // Measure every blob drawPine paints, not just the pads. blobPath jitters its
    // radius by up to `noise` (0.32 for needles), so a blob of half-width w
    // actually reaches w * 1.02 * 1.32.
    val blobSlack = 1.36
    for (it in pineNeedleItems(d, pineLivePads(d, c))) {
        minX = minOf(minX, it.x - it.w * blobSlack)
        maxX = maxOf(maxX, it.x + it.w * blobSlack)
        minY = minOf(minY, it.y - it.h * 1.6)
    }
    minY = minOf(minY, c.topY - 10)
    return contentRectFloor(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Content bounds (for fill rendering)

/**
 * Tight bounding box, in the 600x600 design space, of the drawn bonsai for a
 * given day/style. BonsaiView(fill = true) uses this to zoom onto the plant.
 */
fun bonsaiContentRect(day: Int, style: BonsaiStyle): BRect {
    if (style == BonsaiStyle.Sakura) return sakuraContentRect(day)
    if (style == BonsaiStyle.Maple) return mapleContentRect(day)
    if (style == BonsaiStyle.Pine) return pineContentRect(day)
    val d = minOf(365, maxOf(0, day))
    var minX = 1e9
    var minY = 1e9
    var maxX = -1e9
    var maxY = -1e9
    fun include(x: Double, y: Double) {
        minX = minOf(minX, x); maxX = maxOf(maxX, x)
        minY = minOf(minY, y); maxY = maxOf(maxY, y)
    }

    // Pot footprint is always part of the silhouette.
    if (style == BonsaiStyle.Cascade) {
        include(218.0, 360.0); include(382.0, 462.0)
    } else {
        include(170.0, 380.0); include(430.0, 464.0)
    }

    if (d <= 7) {
        // Sprout: a small region just above the soil. Bounded so a single
        // stem doesn't zoom to absurd magnification.
        val baseY: Double = if (style == BonsaiStyle.Cascade) 378.0 else 410.0
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

    // Floor on each dimension so young plants don't over-zoom.
    return contentRectFloor(BRect(minX, minY, maxX - minX, maxY - minY))
}

// MARK: - Public entry point (body of the Swift BonsaiView canvas, after layout)

/**
 * Draws the tree into the 600x600 design space. The caller owns layout: translate/scale
 * the graphics first (see BonsaiView). `vitality` only dims traditional/cascade/windswept
 * foliage, exactly like the Swift view.
 */
fun drawBonsai(day: Int, style: BonsaiStyle, vitality: Double, ctx: BonsaiGraphics) {
    when (style) {
        BonsaiStyle.Sakura -> { drawSakura(day, ctx); return }
        BonsaiStyle.Maple -> { drawMaple(day, ctx); return }
        BonsaiStyle.Pine -> { drawPine(day, ctx); return }
        else -> Unit
    }

    drawPot(style, ctx)

    if (day <= 7) {
        drawRootsAndMoss(paramsForDay(day, style), style, ctx)
        drawEarly(maxOf(0, day), style, ctx)
        return
    }

    val p = paramsForDay(minOf(365, day), style)
    drawRootsAndMoss(p, style, ctx)
    val tr = buildTrunk(p, style)

    for (b in tr.bareBranches) {
        ctx.strokeRound(b.path, b.color.opacity(b.opacity), b.width)
    }
    for (b in tr.branches) {
        ctx.strokeRound(b.path, Pal.barkMid, b.width)
    }
    val trunkRect = tr.path.boundingRect()
    ctx.fill(
        tr.path,
        gradient(listOf(Pal.barkLight, Pal.barkMid, Pal.barkDeep), trunkRect.minX, 300.0, trunkRect.maxX, 300.0),
    )
    for (g in tr.gnarl) {
        ctx.fillColor(g.path, Pal.barkDeep.opacity(g.opacity))
    }

    val satFactor = 0.7 + 0.3 * maxOf(0.0, minOf(1.0, vitality))
    for (c in p.clusters) {
        val base = clusterCenter(c, tr, p.reach)
        drawCluster(base.x, base.y, c.size, c.tone, p.leafSaturation * c.sat * satFactor, c.seed, ctx)
    }
}
