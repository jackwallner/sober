package com.jackwallner.sober.ui.bonsai

// Platform-neutral drawing vocabulary for the bonsai renderer. The renderer only talks to
// these types, so the same code runs in JVM unit tests (recording, compared against the
// Swift output) and on Android (replayed onto a Compose canvas).

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

sealed interface BonsaiPaint {
    data class Solid(val color: BonsaiColor) : BonsaiPaint

    /** Evenly spaced stops, start and end in the user space current at draw time. */
    class LinearGradient(val colors: List<BonsaiColor>, val start: Pt, val end: Pt) : BonsaiPaint
}

enum class BonsaiCap { Butt, Round, Square }

/**
 * Path as a flat opcode stream (same encoding the Swift recorder uses):
 * 0 move(x,y), 1 line(x,y), 2 quad(cx,cy,x,y), 3 close, 4 ellipse(x,y,w,h).
 */
class BonsaiPath {
    private var data = DoubleArray(24)
    var size = 0
        private set

    val values: DoubleArray get() = data.copyOf(size)

    private fun ensure(extra: Int) {
        if (size + extra > data.size) data = data.copyOf(maxOf(data.size * 2, size + extra))
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

    fun close() {
        ensure(1); data[size++] = OP_CLOSE
    }

    fun ellipse(x: Double, y: Double, width: Double, height: Double) {
        ensure(5)
        data[size++] = OP_ELLIPSE
        data[size++] = x; data[size++] = y; data[size++] = width; data[size++] = height
    }

    /** Visit every segment; unused arguments are 0. */
    inline fun forEachOp(visit: (op: Int, a: Double, b: Double, c: Double, d: Double) -> Unit) {
        val v = values
        var i = 0
        while (i < v.size) {
            when (val op = v[i].toInt()) {
                OP_MOVE.toInt(), OP_LINE.toInt() -> { visit(op, v[i + 1], v[i + 2], 0.0, 0.0); i += 3 }
                OP_QUAD.toInt() -> { visit(op, v[i + 1], v[i + 2], v[i + 3], v[i + 4]); i += 5 }
                OP_CLOSE.toInt() -> { visit(op, 0.0, 0.0, 0.0, 0.0); i += 1 }
                OP_ELLIPSE.toInt() -> { visit(op, v[i + 1], v[i + 2], v[i + 3], v[i + 4]); i += 5 }
                else -> error("Unsupported path op $op")
            }
        }
    }

    /**
     * Tight bounds (control points excluded), like SwiftUI's Path.boundingRect.
     * Quadratic extrema are solved exactly.
     */
    fun boundingRect(): BRect {
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
        fun quadExtremum(p0: Double, c: Double, p2: Double): Double? {
            val denom = p0 - 2 * c + p2
            if (denom == 0.0) return null
            val t = (p0 - c) / denom
            if (t <= 0.0 || t >= 1.0) return null
            val u = 1 - t
            return u * u * p0 + 2 * u * t * c + t * t * p2
        }
        forEachOp { op, a, b, c, d ->
            when (op) {
                OP_MOVE.toInt(), OP_LINE.toInt() -> { include(a, b); curX = a; curY = b }
                OP_QUAD.toInt() -> {
                    include(c, d)
                    quadExtremum(curX, a, c)?.let { x -> include(x, curY) }
                    quadExtremum(curY, b, d)?.let { y -> include(curX, y) }
                    curX = c; curY = d
                }
                OP_ELLIPSE.toInt() -> { include(a, b); include(a + c, b + d) }
            }
        }
        if (minX == Double.POSITIVE_INFINITY) return BRect(0.0, 0.0, 0.0, 0.0)
        return BRect(minX, minY, maxX - minX, maxY - minY)
    }

    companion object {
        const val OP_MOVE = 0.0
        const val OP_LINE = 1.0
        const val OP_QUAD = 2.0
        const val OP_CLOSE = 3.0
        const val OP_ELLIPSE = 4.0
    }
}

/**
 * Drawing target. `save`/`restore` model Swift's value-type `var g = ctx` copies: any
 * transform or opacity change made after `save` is dropped by the matching `restore`.
 */
interface BonsaiGraphics {
    fun save()
    fun restore()
    fun translate(x: Double, y: Double)
    fun scale(x: Double, y: Double)
    fun rotate(radians: Double)

    /** Replaces the context opacity (GraphicsContext.opacity = ...), it does not multiply. */
    fun setOpacity(value: Double)

    fun fill(path: BonsaiPath, paint: BonsaiPaint)
    fun stroke(path: BonsaiPath, paint: BonsaiPaint, width: Double, cap: BonsaiCap)
}

inline fun BonsaiGraphics.scoped(block: BonsaiGraphics.() -> Unit) {
    save()
    try { block() } finally { restore() }
}

/** One resolved draw call: absolute transform [a, b, c, d, tx, ty], opacity, paint. */
class BonsaiCommand(
    val path: BonsaiPath,
    val transform: DoubleArray,
    val opacity: Double,
    val paint: BonsaiPaint,
    /** Negative for fills. */
    val strokeWidth: Double,
    val cap: BonsaiCap,
) {
    val isStroke: Boolean get() = strokeWidth >= 0
}

/**
 * Resolves the renderer's calls into a flat command list with absolute transforms
 * (CGAffineTransform concatenation order). The Android view caches and replays this.
 */
class BonsaiRecorder : BonsaiGraphics {
    val commands = ArrayList<BonsaiCommand>()
    // Matrices are never mutated in place, so save can keep the reference.
    private val stack = ArrayList<DoubleArray>()
    private val opacityStack = ArrayList<Double>()
    private var m = doubleArrayOf(1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    private var opacity = 1.0

    override fun save() {
        stack.add(m)
        opacityStack.add(opacity)
    }

    override fun restore() {
        m = stack.removeAt(stack.size - 1)
        opacity = opacityStack.removeAt(opacityStack.size - 1)
    }

    override fun translate(x: Double, y: Double) {
        m = doubleArrayOf(m[0], m[1], m[2], m[3], m[4] + m[0] * x + m[2] * y, m[5] + m[1] * x + m[3] * y)
    }

    override fun scale(x: Double, y: Double) {
        m = doubleArrayOf(m[0] * x, m[1] * x, m[2] * y, m[3] * y, m[4], m[5])
    }

    override fun rotate(radians: Double) {
        val s = Math.sin(radians)
        val c = Math.cos(radians)
        m = doubleArrayOf(
            c * m[0] + s * m[2], c * m[1] + s * m[3],
            -s * m[0] + c * m[2], -s * m[1] + c * m[3],
            m[4], m[5],
        )
    }

    override fun setOpacity(value: Double) { opacity = value }

    override fun fill(path: BonsaiPath, paint: BonsaiPaint) {
        commands.add(BonsaiCommand(path, m, opacity, paint, -1.0, BonsaiCap.Butt))
    }

    override fun stroke(path: BonsaiPath, paint: BonsaiPaint, width: Double, cap: BonsaiCap) {
        commands.add(BonsaiCommand(path, m, opacity, paint, width, cap))
    }
}
