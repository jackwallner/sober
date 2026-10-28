package com.jackwallner.sober.ui.bonsai

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// Platform-neutral geometry for the bonsai renderer. The renderer, the recorded scene and
// the parity tests only use these types, so they run on the plain JVM. BonsaiView.kt turns
// them into Compose paths (booleans via PathOperation) once per scene.

data class Pt(val x: Double, val y: Double) {
    companion object { val Zero = Pt(0.0, 0.0) }
}

/** Mirror of CGRect for the pieces the renderer uses. */
data class BRect(val x: Double, val y: Double, val width: Double, val height: Double) {
    val minX: Double get() = x
    val minY: Double get() = y
    val maxX: Double get() = x + width
    val maxY: Double get() = y + height
    val midX: Double get() = x + width / 2
    val midY: Double get() = y + height / 2

    /** CGRect.insetBy: a negative inset grows the rect. */
    fun insetBy(dx: Double, dy: Double) = BRect(x + dx, y + dy, width - 2 * dx, height - 2 * dy)
}

data class BonsaiColor(val red: Double, val green: Double, val blue: Double, val alpha: Double = 1.0) {
    fun opacity(amount: Double) = copy(alpha = alpha * amount)

    companion object {
        /** Color(hex:) from the Swift renderer. */
        fun hex(value: Int) = BonsaiColor(
            ((value shr 16) and 0xFF).toDouble() / 255,
            ((value shr 8) and 0xFF).toDouble() / 255,
            (value and 0xFF).toDouble() / 255,
        )
    }
}

enum class BonsaiCap { Butt, Round, Square }

/** CGAffineTransform: x' = a x + c y + tx, y' = b x + d y + ty. */
class Affine(
    val a: Double = 1.0, val b: Double = 0.0, val c: Double = 0.0,
    val d: Double = 1.0, val tx: Double = 0.0, val ty: Double = 0.0,
) {
    val isIdentity: Boolean get() = a == 1.0 && b == 0.0 && c == 0.0 && d == 1.0 && tx == 0.0 && ty == 0.0

    fun translatedBy(x: Double, y: Double) = Affine(a, b, c, d, tx + a * x + c * y, ty + b * x + d * y)
    fun scaledBy(x: Double, y: Double) = Affine(a * x, b * x, c * y, d * y, tx, ty)
    fun rotated(radians: Double): Affine {
        val s = StrictMath.sin(radians)
        val co = StrictMath.cos(radians)
        return Affine(co * a + s * c, co * b + s * d, -s * a + co * c, -s * b + co * d, tx, ty)
    }

    /** `self.concatenating(other)`: self first, then other (CGAffineTransformConcat). */
    fun concatenating(o: Affine) = Affine(
        a * o.a + b * o.c, a * o.b + b * o.d,
        c * o.a + d * o.c, c * o.b + d * o.d,
        tx * o.a + ty * o.c + o.tx, tx * o.b + ty * o.d + o.ty,
    )

    fun apply(p: Pt) = Pt(a * p.x + c * p.y + tx, b * p.x + d * p.y + ty)

    /** Uniform scale factor of the linear part, for stroke widths. */
    val scaleFactor: Double get() = StrictMath.sqrt(abs(a * d - b * c))

    val isAxisAligned: Boolean get() = b == 0.0 && c == 0.0 && a > 0 && d > 0

    companion object { val identity = Affine() }
}

/** How two paths combine (SwiftUI Path.union, intersection, subtracting). */
enum class BoolOp { Union, Intersect, Difference }

/**
 * A path as a flat opcode stream, or (after union/intersection/subtracting) a lazy boolean of
 * two paths. The boolean is only evaluated where it has to be: Compose combines the two
 * operands once per scene, and the parity tests ask [contains] per point.
 *
 * Leaf opcodes: 0 move(x,y), 1 line(x,y), 2 quad(cx,cy,x,y), 3 close, 4 ellipse(x,y,w,h),
 * 5 cubic(c1x,c1y,c2x,c2y,x,y).
 */
class BonsaiPath {
    private var data = DoubleArray(24)
    var size = 0
        private set

    var boolOp: BoolOp? = null
        private set
    var boolA: BonsaiPath? = null
        private set
    var boolB: BonsaiPath? = null
        private set

    val isComposite: Boolean get() = boolOp != null
    val values: DoubleArray get() = data.copyOf(size)

    private fun ensure(extra: Int) {
        check(boolOp == null) { "Composite path is read-only" }
        if (size + extra > data.size) data = data.copyOf(max(data.size * 2, size + extra))
    }

    fun move(p: Pt) = move(p.x, p.y)
    fun line(p: Pt) = line(p.x, p.y)

    fun move(x: Double, y: Double) {
        ensure(3); data[size++] = OP_MOVE; data[size++] = x; data[size++] = y
    }

    fun line(x: Double, y: Double) {
        ensure(3); data[size++] = OP_LINE; data[size++] = x; data[size++] = y
    }

    /** Swift's addQuadCurve(to:control:). */
    fun quad(to: Pt, control: Pt) {
        ensure(5)
        data[size++] = OP_QUAD
        data[size++] = control.x; data[size++] = control.y
        data[size++] = to.x; data[size++] = to.y
    }

    fun cubic(to: Pt, c1: Pt, c2: Pt) {
        ensure(7)
        data[size++] = OP_CUBIC
        data[size++] = c1.x; data[size++] = c1.y
        data[size++] = c2.x; data[size++] = c2.y
        data[size++] = to.x; data[size++] = to.y
    }

    fun close() {
        ensure(1); data[size++] = OP_CLOSE
    }

    /** addEllipse(in: CGRect(x, y, width, height)). */
    fun ellipse(x: Double, y: Double, width: Double, height: Double) {
        ensure(5)
        data[size++] = OP_ELLIPSE
        data[size++] = x; data[size++] = y; data[size++] = width; data[size++] = height
    }

    fun addLines(pts: List<Pt>) {
        if (pts.isEmpty()) return
        move(pts[0])
        for (i in 1 until pts.size) line(pts[i])
    }

    /** Path.addPath: another leaf path's segments, appended. */
    fun addPath(other: BonsaiPath) {
        check(!other.isComposite) { "Cannot append a composite path" }
        ensure(other.size)
        System.arraycopy(other.data, 0, data, size, other.size)
        size += other.size
    }

    fun union(other: BonsaiPath) = combine(BoolOp.Union, other)
    fun intersection(other: BonsaiPath) = combine(BoolOp.Intersect, other)
    fun subtracting(other: BonsaiPath) = combine(BoolOp.Difference, other)

    private fun combine(op: BoolOp, other: BonsaiPath) = BonsaiPath().also {
        it.boolOp = op; it.boolA = this; it.boolB = other
    }

    /** Visit every leaf segment; unused arguments are 0. */
    inline fun forEachOp(visit: (op: Int, v: DoubleArray, i: Int) -> Unit) {
        val v = values
        var i = 0
        while (i < v.size) {
            val op = v[i].toInt()
            visit(op, v, i + 1)
            i += when (op) {
                OP_MOVE.toInt(), OP_LINE.toInt() -> 3
                OP_QUAD.toInt(), OP_ELLIPSE.toInt() -> 5
                OP_CUBIC.toInt() -> 7
                OP_CLOSE.toInt() -> 1
                else -> error("Unsupported path op $op")
            }
        }
    }

    fun applying(t: Affine): BonsaiPath {
        if (t.isIdentity) return this
        val out = BonsaiPath()
        if (isComposite) {
            out.boolOp = boolOp
            out.boolA = boolA!!.applying(t)
            out.boolB = boolB!!.applying(t)
            return out
        }
        var curX = 0.0
        var curY = 0.0
        forEachOp { op, v, i ->
            when (op) {
                OP_MOVE.toInt() -> { out.move(t.apply(Pt(v[i], v[i + 1]))); curX = v[i]; curY = v[i + 1] }
                OP_LINE.toInt() -> { out.line(t.apply(Pt(v[i], v[i + 1]))); curX = v[i]; curY = v[i + 1] }
                OP_QUAD.toInt() -> {
                    out.quad(t.apply(Pt(v[i + 2], v[i + 3])), t.apply(Pt(v[i], v[i + 1])))
                    curX = v[i + 2]; curY = v[i + 3]
                }
                OP_CUBIC.toInt() -> {
                    out.cubic(t.apply(Pt(v[i + 4], v[i + 5])), t.apply(Pt(v[i], v[i + 1])), t.apply(Pt(v[i + 2], v[i + 3])))
                    curX = v[i + 4]; curY = v[i + 5]
                }
                OP_CLOSE.toInt() -> out.close()
                OP_ELLIPSE.toInt() -> {
                    if (t.isAxisAligned) {
                        val p0 = t.apply(Pt(v[i], v[i + 1]))
                        val p1 = t.apply(Pt(v[i] + v[i + 2], v[i + 1] + v[i + 3]))
                        out.ellipse(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y)
                    } else {
                        ellipseCubics(v[i], v[i + 1], v[i + 2], v[i + 3]).forEach { seg ->
                            if (seg.size == 2) out.move(t.apply(Pt(seg[0], seg[1])))
                            else out.cubic(t.apply(Pt(seg[4], seg[5])), t.apply(Pt(seg[0], seg[1])), t.apply(Pt(seg[2], seg[3])))
                        }
                        out.close()
                    }
                }
            }
        }
        return out
    }

    fun offsetBy(dx: Double, dy: Double) = applying(Affine(tx = dx, ty = dy))

    /**
     * Bounds with control points excluded, like SwiftUI's Path.boundingRect. A boolean takes
     * the bounds of its operands (the intersection of a path with a rect is clipped exactly).
     */
    fun boundingRect(): BRect {
        if (isComposite) {
            val a = boolA!!.boundingRect()
            val b = boolB!!.boundingRect()
            return when (boolOp!!) {
                BoolOp.Union -> unionRect(a, b)
                BoolOp.Difference -> a
                BoolOp.Intersect -> clippedBounds(boolA!!, boolB!!, a, b)
            }
        }
        var minX = Double.POSITIVE_INFINITY
        var minY = Double.POSITIVE_INFINITY
        var maxX = Double.NEGATIVE_INFINITY
        var maxY = Double.NEGATIVE_INFINITY
        var curX = 0.0
        var curY = 0.0
        fun include(x: Double, y: Double) {
            if (x < minX) minX = x
            if (x > maxX) maxX = x
            if (y < minY) minY = y
            if (y > maxY) maxY = y
        }
        fun extremum(p0: Double, c: Double, p2: Double): Double? {
            val denom = p0 - 2 * c + p2
            if (denom == 0.0) return null
            val t = (p0 - c) / denom
            if (t <= 0.0 || t >= 1.0) return null
            val u = 1 - t
            return u * u * p0 + 2 * u * t * c + t * t * p2
        }
        forEachOp { op, v, i ->
            when (op) {
                OP_MOVE.toInt(), OP_LINE.toInt() -> { include(v[i], v[i + 1]); curX = v[i]; curY = v[i + 1] }
                OP_QUAD.toInt() -> {
                    include(v[i + 2], v[i + 3])
                    extremum(curX, v[i], v[i + 2])?.let { x -> include(x, curY) }
                    extremum(curY, v[i + 1], v[i + 3])?.let { y -> include(curX, y) }
                    curX = v[i + 2]; curY = v[i + 3]
                }
                OP_CUBIC.toInt() -> {
                    // Sample the curve; tight enough for the zoom boxes that use bounds.
                    for (k in 0..16) {
                        val t = k / 16.0
                        val u = 1 - t
                        include(
                            u * u * u * curX + 3 * u * u * t * v[i] + 3 * u * t * t * v[i + 2] + t * t * t * v[i + 4],
                            u * u * u * curY + 3 * u * u * t * v[i + 1] + 3 * u * t * t * v[i + 3] + t * t * t * v[i + 5],
                        )
                    }
                    curX = v[i + 4]; curY = v[i + 5]
                }
                OP_ELLIPSE.toInt() -> { include(v[i], v[i + 1]); include(v[i] + v[i + 2], v[i + 1] + v[i + 3]) }
            }
        }
        if (minX == Double.POSITIVE_INFINITY) return BRect(0.0, 0.0, 0.0, 0.0)
        return BRect(minX, minY, maxX - minX, maxY - minY)
    }

    // MARK: Point queries (parity tests, bounds of clipped paths)

    private var cachedPolys: List<DoubleArray>? = null

    /** Closed polygons (x0,y0,x1,y1,...) approximating a leaf path; curves are flattened. */
    fun polygons(): List<DoubleArray> {
        cachedPolys?.let { return it }
        check(!isComposite)
        val polys = ArrayList<DoubleArray>()
        var cur = ArrayList<Double>()
        var curX = 0.0
        var curY = 0.0
        fun flush() {
            if (cur.size >= 6) polys.add(cur.toDoubleArray())
            cur = ArrayList()
        }
        forEachOp { op, v, i ->
            when (op) {
                OP_MOVE.toInt() -> { flush(); cur.add(v[i]); cur.add(v[i + 1]); curX = v[i]; curY = v[i + 1] }
                OP_LINE.toInt() -> { cur.add(v[i]); cur.add(v[i + 1]); curX = v[i]; curY = v[i + 1] }
                OP_QUAD.toInt() -> {
                    for (k in 1..FLATTEN) {
                        val t = k.toDouble() / FLATTEN
                        val u = 1 - t
                        cur.add(u * u * curX + 2 * u * t * v[i] + t * t * v[i + 2])
                        cur.add(u * u * curY + 2 * u * t * v[i + 1] + t * t * v[i + 3])
                    }
                    curX = v[i + 2]; curY = v[i + 3]
                }
                OP_CUBIC.toInt() -> {
                    for (k in 1..FLATTEN) {
                        val t = k.toDouble() / FLATTEN
                        val u = 1 - t
                        cur.add(u * u * u * curX + 3 * u * u * t * v[i] + 3 * u * t * t * v[i + 2] + t * t * t * v[i + 4])
                        cur.add(u * u * u * curY + 3 * u * u * t * v[i + 1] + 3 * u * t * t * v[i + 3] + t * t * t * v[i + 5])
                    }
                    curX = v[i + 4]; curY = v[i + 5]
                }
                OP_CLOSE.toInt() -> flush()
                OP_ELLIPSE.toInt() -> {
                    flush()
                    val cx = v[i] + v[i + 2] / 2
                    val cy = v[i + 1] + v[i + 3] / 2
                    for (k in 0 until ELLIPSE_STEPS) {
                        val a = 2 * Math.PI * k / ELLIPSE_STEPS
                        cur.add(cx + StrictMath.cos(a) * v[i + 2] / 2)
                        cur.add(cy + StrictMath.sin(a) * v[i + 3] / 2)
                    }
                    flush()
                }
            }
        }
        flush()
        cachedPolys = polys
        return polys
    }

    /** Non-zero winding fill test, with booleans evaluated per point. */
    fun contains(x: Double, y: Double): Boolean {
        if (isComposite) {
            return when (boolOp!!) {
                BoolOp.Union -> boolA!!.contains(x, y) || boolB!!.contains(x, y)
                BoolOp.Intersect -> boolA!!.contains(x, y) && boolB!!.contains(x, y)
                BoolOp.Difference -> boolA!!.contains(x, y) && !boolB!!.contains(x, y)
            }
        }
        var winding = 0
        for (poly in polygons()) {
            val n = poly.size / 2
            var j = n - 1
            for (k in 0 until n) {
                val x0 = poly[2 * j]; val y0 = poly[2 * j + 1]
                val x1 = poly[2 * k]; val y1 = poly[2 * k + 1]
                if (y0 <= y) {
                    if (y1 > y && (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0) > 0) winding++
                } else if (y1 <= y && (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0) < 0) winding--
                j = k
            }
        }
        return winding != 0
    }

    companion object {
        const val OP_MOVE = 0.0
        const val OP_LINE = 1.0
        const val OP_QUAD = 2.0
        const val OP_CLOSE = 3.0
        const val OP_ELLIPSE = 4.0
        const val OP_CUBIC = 5.0
        private const val FLATTEN = 12
        private const val ELLIPSE_STEPS = 72

        /** Path(CGRect). */
        fun rect(x: Double, y: Double, width: Double, height: Double) = BonsaiPath().apply {
            move(x, y); line(x + width, y); line(x + width, y + height); line(x, y + height); close()
        }

        /** Path(ellipseIn: CGRect). */
        fun ellipseIn(x: Double, y: Double, width: Double, height: Double) =
            BonsaiPath().apply { ellipse(x, y, width, height) }

        /** Path(roundedRect:cornerRadius:), circular corners. */
        fun roundedRect(x: Double, y: Double, width: Double, height: Double, radius: Double): BonsaiPath {
            val r = min(radius, min(width, height) / 2)
            val k = r * (1 - 0.5522847498)
            return BonsaiPath().apply {
                move(x + r, y)
                line(x + width - r, y)
                cubic(Pt(x + width, y + r), Pt(x + width - k, y), Pt(x + width, y + k))
                line(x + width, y + height - r)
                cubic(Pt(x + width - r, y + height), Pt(x + width, y + height - k), Pt(x + width - k, y + height))
                line(x + r, y + height)
                cubic(Pt(x, y + height - r), Pt(x + k, y + height), Pt(x, y + height - k))
                line(x, y + r)
                cubic(Pt(x + r, y), Pt(x, y + k), Pt(x + k, y))
                close()
            }
        }

        /** An ellipse as a move followed by four cubics: [x, y] then [c1x, c1y, c2x, c2y, x, y]. */
        fun ellipseCubics(x: Double, y: Double, w: Double, h: Double): List<DoubleArray> {
            val kappa = 0.5522847498
            val cx = x + w / 2
            val cy = y + h / 2
            val rx = w / 2
            val ry = h / 2
            return listOf(
                doubleArrayOf(cx + rx, cy),
                doubleArrayOf(cx + rx, cy + ry * kappa, cx + rx * kappa, cy + ry, cx, cy + ry),
                doubleArrayOf(cx - rx * kappa, cy + ry, cx - rx, cy + ry * kappa, cx - rx, cy),
                doubleArrayOf(cx - rx, cy - ry * kappa, cx - rx * kappa, cy - ry, cx, cy - ry),
                doubleArrayOf(cx + rx * kappa, cy - ry, cx + rx, cy - ry * kappa, cx + rx, cy),
            )
        }

        private fun unionRect(a: BRect, b: BRect): BRect {
            val x0 = min(a.minX, b.minX)
            val y0 = min(a.minY, b.minY)
            return BRect(x0, y0, max(a.maxX, b.maxX) - x0, max(a.maxY, b.maxY) - y0)
        }

        /** Bounds of `a ∩ b` when `b` is a rectangle: Sutherland-Hodgman on the flattened `a`. */
        private fun clippedBounds(a: BonsaiPath, b: BonsaiPath, ra: BRect, rb: BRect): BRect {
            val x0 = max(ra.minX, rb.minX)
            val y0 = max(ra.minY, rb.minY)
            val x1 = min(ra.maxX, rb.maxX)
            val y1 = min(ra.maxY, rb.maxY)
            val rough = BRect(x0, y0, max(0.0, x1 - x0), max(0.0, y1 - y0))
            if (a.isComposite || b.isComposite) return rough
            val polys = b.polygons()
            val isRect = polys.size == 1 && polys[0].size == 8 &&
                (polys[0][0] == polys[0][2] || polys[0][1] == polys[0][3])
            if (!isRect) return rough
            var minX = Double.POSITIVE_INFINITY
            var minY = Double.POSITIVE_INFINITY
            var maxX = Double.NEGATIVE_INFINITY
            var maxY = Double.NEGATIVE_INFINITY
            for (poly in a.polygons()) {
                var pts = (0 until poly.size / 2).map { Pt(poly[2 * it], poly[2 * it + 1]) }
                pts = clipHalf(pts, { it.x - rb.minX }) ; pts = clipHalf(pts, { rb.maxX - it.x })
                pts = clipHalf(pts, { it.y - rb.minY }) ; pts = clipHalf(pts, { rb.maxY - it.y })
                for (p in pts) {
                    minX = min(minX, p.x); maxX = max(maxX, p.x)
                    minY = min(minY, p.y); maxY = max(maxY, p.y)
                }
            }
            if (minX == Double.POSITIVE_INFINITY) return BRect(0.0, 0.0, 0.0, 0.0)
            return BRect(minX, minY, maxX - minX, maxY - minY)
        }

        /** Keeps the part of the polygon where `side(p) >= 0`. */
        private fun clipHalf(pts: List<Pt>, side: (Pt) -> Double): List<Pt> {
            if (pts.isEmpty()) return pts
            val out = ArrayList<Pt>()
            var prev = pts.last()
            var prevSide = side(prev)
            for (p in pts) {
                val s = side(p)
                if ((s >= 0) != (prevSide >= 0)) {
                    val t = prevSide / (prevSide - s)
                    out.add(Pt(prev.x + (p.x - prev.x) * t, prev.y + (p.y - prev.y) * t))
                }
                if (s >= 0) out.add(p)
                prev = p; prevSide = s
            }
            return out
        }
    }
}
