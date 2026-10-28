package com.jackwallner.sober.ui.bonsai

import kotlin.math.hypot
import kotlin.math.min

// Port of Shared/Bonsai/BonsaiWind.swift: idle life for the bonsai in the 600x600 design space.
// The plant leans a degree or so around its soil line, the foliage trails the lean, and the
// petals or leaves the sakura and maple hold in mid-air fall and drift. `t` is a clock in ms.
// A null wind draws the still tree (widgets, thumbnails and reduced motion).

class BonsaiWind(val t: Double) {
    /** The same wind, later in its cycle, so grove trees don't sway in step. */
    fun offset(byMs: Double) = BonsaiWind(t + byMs)

    /**
     * Shear factor of the bend about the soil line: x' = x + y * tan(deg). The trunk's base stays
     * planted and the top travels furthest. A sprout bends more than a tree.
     */
    fun bendShear(sprout: Boolean): Double {
        val amp = if (sprout) 2.4 else 1.3
        val deg = amp * (0.72 * wave(5600.0, 0.0) + 0.28 * wave(8900.0, 0.31))
        return StrictMath.tan(deg * Math.PI / 180)
    }

    /** Foliage offset at (x, y): the lean's wave, delayed by distance from the pivot, plus a small rustle. */
    fun drift(x: Double, y: Double, pivot: Pt): Pt {
        val reach = min(1.2, hypot(x - pivot.x, y - pivot.y) / 220)
        val lag = -0.07 * reach
        val rustle = 0.35 * wave(2300.0, 0.004 * x + 0.003 * y)
        return Pt(
            2.4 * reach * (0.8 * wave(5600.0, lag) + rustle),
            0.6 * reach * wave(5600.0, lag + 0.25),
        )
    }

    class Fall(val x: Double, val y: Double, val rotDeg: Double, val opacity: Double)

    /**
     * An airborne petal or leaf: it falls from `top` to `bottom` on its own loop (`seed` and `pace`
     * in 0..1 pick phase and speed), swinging side to side like a pendulum as it drifts downwind.
     */
    fun fall(seed: Double, pace: Double, x: Double, top: Double, bottom: Double, rotDeg: Double): Fall {
        val period = 5200 + 2800 * pace
        var p = (t / period + seed) % 1.0
        if (p < 0) p += 1
        val swing = 0.75 * wave(1500 + 500 * pace, seed * 3) + 0.25 * wave(2300.0, seed * 7)
        val width = 7 + 6 * seed
        val sink = top + (bottom - top) * p - 3 * kotlin.math.abs(swing)
        return Fall(
            x = x + 14 * p + width * swing * (1 - p * 0.6),
            y = min(bottom, sink),
            rotDeg = rotDeg + 40 * swing,
            opacity = min(1.0, p / 0.12) * min(1.0, (1 - p) / 0.08),
        )
    }

    private fun wave(period: Double, phase: Double) = StrictMath.sin((t / period + phase) * Math.PI * 2)
}
