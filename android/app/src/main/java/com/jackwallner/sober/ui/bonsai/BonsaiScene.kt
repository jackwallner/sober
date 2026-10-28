package com.jackwallner.sober.ui.bonsai

// Port of Shared/Bonsai/BonsaiScene.swift. A tree's geometry is a pure function of its style
// and day, so it is recorded once into a BonsaiScene and replayed on every animation frame.
// The painters write into BonsaiLayers; only the wind (bend, drift, limb stretch) is worked
// out per frame, by BonsaiView.

/** How a recorded piece moves in the wind. */
sealed interface BonsaiMotion {
    /** Pot, soil, fallen petals. */
    data object Still : BonsaiMotion

    /** The plant's shear about its soil line. */
    data object Bent : BonsaiMotion

    /** Bent, then carried by the drift at this point. */
    data class Drift(val at: Pt) : BonsaiMotion

    /** Bent, then a limb stretched from `from` (fixed in the wood) to `to` (carried by the drift there). */
    data class Limb(val from: Pt, val to: Pt) : BonsaiMotion
}

/** A fill colour or bark gradient, kept in design space so a recorded transform can move a gradient along. */
sealed interface BonsaiInk {
    data class Color(val color: BonsaiColor) : BonsaiInk

    /** Evenly spaced stops from `start` to `end`. */
    class Linear(val colors: List<BonsaiColor>, val start: Pt, val end: Pt) : BonsaiInk

    fun applying(t: Affine): BonsaiInk = when (this) {
        is Color -> this
        is Linear -> Linear(colors, t.apply(start), t.apply(end))
    }
}

class BonsaiLayer(
    val path: BonsaiPath,
    val ink: BonsaiInk,
    /** Negative for fills; the stroked centre line otherwise. */
    val strokeWidth: Double,
    val cap: BonsaiCap,
    val clip: Int,
    val motion: Int,
) {
    val isStroke: Boolean get() = strokeWidth >= 0
}

class BonsaiClip(val path: BonsaiPath, val inverse: Boolean)

/**
 * Records fills for a [BonsaiScene]. A [copy] keeps its own transform, clip and motion but writes
 * into the same list, just as a SwiftUI GraphicsContext copy draws into the same canvas.
 */
class BonsaiLayers private constructor(private val store: Store) {
    class Store {
        val layers = ArrayList<BonsaiLayer>()
        val clips = arrayListOf(emptyList<BonsaiClip>())
        val motions = arrayListOf<BonsaiMotion>(BonsaiMotion.Still)
    }

    constructor() : this(Store())

    private var transform = Affine.identity
    private var clip = 0
    private var motion = 0

    val layers: List<BonsaiLayer> get() = store.layers
    val clips: List<List<BonsaiClip>> get() = store.clips
    val motions: List<BonsaiMotion> get() = store.motions

    fun copy(): BonsaiLayers = BonsaiLayers(store).also {
        it.transform = transform; it.clip = clip; it.motion = motion
    }

    /** Everything recorded after this moves with `m`. */
    fun move(m: BonsaiMotion) {
        store.motions.add(m)
        motion = store.motions.size - 1
    }

    fun fill(path: BonsaiPath, ink: BonsaiInk) {
        store.layers.add(BonsaiLayer(path.applying(transform), ink.applying(transform), -1.0, BonsaiCap.Butt, clip, motion))
    }

    fun fill(path: BonsaiPath, color: BonsaiColor) = fill(path, BonsaiInk.Color(color))

    fun stroke(path: BonsaiPath, color: BonsaiColor, width: Double, cap: BonsaiCap) {
        store.layers.add(
            BonsaiLayer(path.applying(transform), BonsaiInk.Color(color), width * transform.scaleFactor, cap, clip, motion),
        )
    }

    fun clip(to: BonsaiPath, inverse: Boolean = false) {
        store.clips.add(store.clips[clip] + BonsaiClip(to.applying(transform), inverse))
        clip = store.clips.size - 1
    }

    fun translateBy(x: Double, y: Double) { transform = transform.translatedBy(x, y) }
    fun scaleBy(x: Double, y: Double) { transform = transform.scaledBy(x, y) }
    fun rotate(degrees: Double) { transform = transform.rotated(degrees * Math.PI / 180) }
}

/** Where airborne petals and leaves are painted each frame (the still context, no bend). */
fun interface BonsaiAirCanvas {
    fun fill(path: BonsaiPath, color: BonsaiColor)
}

/** A recorded tree, ready to paint at any moment of the sway. */
class BonsaiScene(
    rec: BonsaiLayers,
    val pivot: Pt,
    val sprout: Boolean = false,
    /** What moves on its own path every frame (falling petals and leaves). */
    val air: ((BonsaiAirCanvas, BonsaiWind?) -> Unit)? = null,
) {
    val layers: List<BonsaiLayer> = rec.layers.toList()
    val clips: List<List<BonsaiClip>> = rec.clips.toList()
    val motions: List<BonsaiMotion> = rec.motions.toList()
}

// MARK: - Cache

/** The scenes and zoom boxes of the last few trees drawn. */
object BonsaiSceneCache {
    data class Key(val style: BonsaiStyle, val day: Int, val detail: Int, val vitality: Double)
    data class RectKey(val style: BonsaiStyle, val day: Int)

    private class Recent<K, V>(val limit: Int) : LinkedHashMap<K, V>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<K, V>?) = size > limit
    }

    private val scenes = Recent<Key, BonsaiScene>(16)
    private val rects = Recent<RectKey, BRect>(64)

    @Synchronized
    fun scene(key: Key, build: () -> BonsaiScene): BonsaiScene {
        scenes[key]?.let { return it }
        val s = build()
        scenes[key] = s
        return s
    }

    @Synchronized
    fun rect(key: RectKey, build: () -> BRect): BRect {
        rects[key]?.let { return it }
        val r = build()
        rects[key] = r
        return r
    }
}

/**
 * The affine map that holds `a` and carries `b` by (dx, dy), moving each point by that offset times
 * how far along a to b it lies. A limb drawn as a quadratic whose tip moves by the offset and
 * control by half of it moves the same way, so this is the recorded limb bending with its foliage.
 */
fun limbStretch(a: Pt, b: Pt, dx: Double, dy: Double): Affine {
    val cx = b.x - a.x
    val cy = b.y - a.y
    val l2 = cx * cx + cy * cy
    if (l2 <= 1) return Affine(tx = dx, ty = dy)
    val kx = dx / l2
    val ky = dy / l2
    val along = cx * a.x + cy * a.y
    return Affine(1 + kx * cx, ky * cx, kx * cy, 1 + ky * cy, -kx * along, -ky * along)
}

/** The motion's transform in design space on top of the bend, for one wind pose (null is still). */
fun BonsaiScene.placement(m: BonsaiMotion, wind: BonsaiWind?, bend: Affine): Affine = when (m) {
    BonsaiMotion.Still -> Affine.identity
    BonsaiMotion.Bent -> bend
    is BonsaiMotion.Drift -> {
        if (wind == null) bend else {
            val d = wind.drift(m.at.x, m.at.y, pivot)
            Affine(tx = d.x, ty = d.y).concatenating(bend)
        }
    }
    is BonsaiMotion.Limb -> {
        if (wind == null) bend else {
            val d = wind.drift(m.to.x, m.to.y, pivot)
            limbStretch(m.from, m.to, d.x, d.y).concatenating(bend)
        }
    }
}

/** The plant's shear about its soil line: x' = x + k (y - pivot.y). */
fun BonsaiScene.bendAffine(wind: BonsaiWind?): Affine {
    if (wind == null) return Affine.identity
    val k = wind.bendShear(sprout)
    return Affine(1.0, 0.0, k, 1.0, -k * pivot.y, 0.0)
}
