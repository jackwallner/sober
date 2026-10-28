package com.jackwallner.sober.ui.bonsai

import kotlin.math.floor

// Math helpers shared by the bonsai files. sin/cos/pow go through StrictMath so the JVM tests
// and Android agree bit for bit; the renderer's noise is a high-gain sine hash.

internal fun sin(x: Double) = StrictMath.sin(x)
internal fun cos(x: Double) = StrictMath.cos(x)
internal fun atan2(y: Double, x: Double) = StrictMath.atan2(y, x)
internal fun pow(x: Double, y: Double) = StrictMath.pow(x, y)
internal fun hypot(x: Double, y: Double) = StrictMath.hypot(x, y)
internal fun sqrt(x: Double) = StrictMath.sqrt(x)

/** Swift's Double.rounded(): nearest, ties away from zero. */
internal fun Double.swiftRounded(): Double {
    if (isNaN() || isInfinite()) return this
    val f = floor(this)
    val diff = this - f
    return if (this >= 0) (if (diff >= 0.5) f + 1 else f) else (if (diff > 0.5) f + 1 else f)
}

/** Swift's `remainder(dividingBy:)`: IEEE remainder, quotient rounded to nearest even. */
internal fun Double.ieeeRemainder(d: Double): Double = Math.IEEEremainder(this, d)

/** Deterministic noise in 0..<1 (the renderer's `rand01`). */
internal fun bonsaiNoise(seed: Double, n: Double): Double {
    val v = sin(seed * 12.9898 + n * 78.233) * 43758.5453
    return v - floor(v)
}

internal const val TAU = 2 * Math.PI
