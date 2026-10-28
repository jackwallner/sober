package com.jackwallner.sober.ui.bonsai

import android.content.res.Resources
import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Canvas as ComposeCanvas
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.LinearGradientShader
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.PaintingStyle
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.Shader
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntSize
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.compose.runtime.withFrameNanos
import java.util.WeakHashMap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The procedural bonsai, drawn natively (port of the Swift BonsaiView).
 *
 * `fill` zooms onto the plant's content rect and bottom-anchors it (home centerpiece);
 * otherwise the 600x600 design square is centered in the frame. The tree is recorded once per
 * (day, style, vitality, detail) and replayed every frame; `wind` supplies the sway, read in the
 * draw phase (see [rememberWindClock]). Null draws the still tree.
 */
@Composable
fun BonsaiView(
    day: Int,
    style: BonsaiStyle,
    vitality: Double,
    modifier: Modifier = Modifier,
    fill: Boolean = false,
    wind: (() -> BonsaiWind?)? = null,
) {
    val density = LocalDensity.current.density
    val vitalityKey = vitality.coerceIn(0.0, 1.0)
    val rect = remember(day, style, fill) {
        if (fill) bonsaiContentRect(day, style) else BRect(0.0, 0.0, 600.0, 600.0)
    }
    val paint = remember { Paint().apply { isAntiAlias = true } }
    var box by remember { mutableStateOf(IntSize.Zero) }
    // How much leaf and needle texture the tree needs depends on the size it is drawn at.
    val scale = if (box.width <= 0 || box.height <= 0) 0.0 else {
        val pad = if (fill) 1.04 else 1.0
        minOf(box.width / (rect.width * pad), box.height / (rect.height * pad)) / density
    }
    // The scene and its Compose paths (path booleans included) are built off the main thread; the
    // previous tree stays on screen until the next is ready.
    val scene by produceState<BonsaiScene?>(null, day, style, vitalityKey, detailFor(style, scale), scale > 0) {
        if (scale <= 0.0) return@produceState
        value = withContext(Dispatchers.Default) {
            bonsaiScene(day, style, vitalityKey, scale).also { BonsaiPainter.prepare(it) }
        }
    }
    Canvas(modifier.onSizeChanged { box = it }.semantics { contentDescription = "Bonsai, day $day" }) {
        val ready = scene ?: return@Canvas
        val width = size.width.toDouble()
        val height = size.height.toDouble()
        if (width <= 0.0 || height <= 0.0) return@Canvas
        val pad = if (fill) 1.04 else 1.0
        val fit = minOf(width / (rect.width * pad), height / (rect.height * pad))
        val drawnW = rect.width * fit
        val drawnH = rect.height * fit
        // Center horizontally; center (default) or bottom-anchor (fill) the focus rect.
        val offX = (width - drawnW) / 2 - rect.minX * fit
        val offY = if (fill) (height - drawnH) - rect.minY * fit
        else (height - drawnH) / 2 - rect.minY * fit
        val pose = wind?.invoke()
        drawIntoCanvas { canvas ->
            canvas.save()
            canvas.clipRect(0f, 0f, size.width, size.height)
            canvas.translate(offX.toFloat(), offY.toFloat())
            canvas.scale(fit.toFloat(), fit.toFloat())
            BonsaiPainter.paint(ready, pose, canvas, paint)
            canvas.restore()
        }
    }
}

/**
 * A wind clock for the garden. Returns a reader to hand to [BonsaiView]: it gives null for the still
 * tree (reduce motion) and the current pose otherwise. It runs only while the screen is resumed
 * and continues from where it paused, so the tree never jumps.
 */
@Composable
fun rememberWindClock(): () -> BonsaiWind? {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val ms = remember { mutableDoubleStateOf(0.0) }
    LaunchedEffect(reduceMotion, lifecycle) {
        if (reduceMotion) return@LaunchedEffect
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            val resumedAt = ms.doubleValue
            var origin = -1L
            while (true) {
                withFrameNanos { now ->
                    if (origin < 0) origin = now
                    ms.doubleValue = resumedAt + (now - origin) / 1_000_000.0
                }
            }
        }
    }
    return { if (reduceMotion) null else BonsaiWind(ms.doubleValue) }
}

/** Replays a recorded scene onto a Compose canvas, already in design space. */
internal object BonsaiPainter {
    class Op(
        val path: Path,
        val color: Color,
        val shader: Shader?,
        val strokeWidth: Float,
        val cap: StrokeCap,
        val isStroke: Boolean,
        val clip: Int,
        val motion: Int,
    )

    class Prepared(val ops: List<Op>, val clips: List<List<Pair<Path, Boolean>>>)

    private val prepared = WeakHashMap<BonsaiScene, Prepared>()

    @Synchronized
    fun prepare(scene: BonsaiScene): Prepared = prepared.getOrPut(scene) {
        val paths = HashMap<BonsaiPath, Path>()
        fun path(p: BonsaiPath) = paths.getOrPut(p) { toPath(p) }
        val ops = scene.layers.map { l ->
            val ink = l.ink
            val color = when (ink) {
                is BonsaiInk.Color -> composeColor(ink.color)
                // A shader paints opaque black through its stops; each stop carries its own alpha.
                is BonsaiInk.Linear -> Color.Black
            }
            val shader = (ink as? BonsaiInk.Linear)?.let {
                LinearGradientShader(
                    from = Offset(it.start.x.toFloat(), it.start.y.toFloat()),
                    to = Offset(it.end.x.toFloat(), it.end.y.toFloat()),
                    colors = it.colors.map(::composeColor),
                    colorStops = null,
                    tileMode = TileMode.Clamp,
                )
            }
            val cap = when (l.cap) {
                BonsaiCap.Butt -> StrokeCap.Butt
                BonsaiCap.Round -> StrokeCap.Round
                BonsaiCap.Square -> StrokeCap.Square
            }
            Op(path(l.path), color, shader, l.strokeWidth.toFloat(), cap, l.isStroke, l.clip, l.motion)
        }
        val clips = scene.clips.map { chain -> chain.map { path(it.path) to it.inverse } }
        Prepared(ops, clips)
    }

    fun paint(scene: BonsaiScene, wind: BonsaiWind?, canvas: ComposeCanvas, paint: Paint) {
        val prep = prepare(scene)
        val bend = scene.bendAffine(wind)
        paint.strokeMiterLimit = 10f
        paint.strokeJoin = StrokeJoin.Miter
        var runClip = -1
        var runMotion = -1
        var open = false
        for (op in prep.ops) {
            if (op.clip != runClip || op.motion != runMotion) {
                if (open) canvas.restore()
                runClip = op.clip
                runMotion = op.motion
                canvas.save()
                open = true
                val placed = scene.placement(scene.motions[op.motion], wind, bend)
                if (!placed.isIdentity) canvas.concat(toMatrix(placed))
                for ((clip, inverse) in prep.clips[op.clip]) {
                    canvas.clipPath(clip, if (inverse) ClipOp.Difference else ClipOp.Intersect)
                }
            }
            paint.shader = op.shader
            paint.color = op.color
            if (op.isStroke) {
                paint.style = PaintingStyle.Stroke
                paint.strokeWidth = op.strokeWidth
                paint.strokeCap = op.cap
            } else {
                paint.style = PaintingStyle.Fill
            }
            canvas.drawPath(op.path, paint)
        }
        if (open) canvas.restore()
        paint.shader = null
        paint.style = PaintingStyle.Fill

        scene.air?.invoke(
            BonsaiAirCanvas { path, color ->
                paint.color = composeColor(color)
                paint.style = PaintingStyle.Fill
                canvas.drawPath(toPath(path), paint)
            },
            wind,
        )
    }

    private fun composeColor(color: BonsaiColor) = Color(
        red = color.red.toFloat(),
        green = color.green.toFloat(),
        blue = color.blue.toFloat(),
        alpha = color.alpha.toFloat(),
    )

    /** Affine to Compose's column-major 4x4. */
    private fun toMatrix(t: Affine): Matrix = Matrix(
        floatArrayOf(
            t.a.toFloat(), t.b.toFloat(), 0f, 0f,
            t.c.toFloat(), t.d.toFloat(), 0f, 0f,
            0f, 0f, 1f, 0f,
            t.tx.toFloat(), t.ty.toFloat(), 0f, 1f,
        ),
    )

    /** Booleans are combined once here; non-zero winding is Compose's default fill, as in SwiftUI. */
    private fun toPath(source: BonsaiPath): Path {
        if (source.isComposite) {
            val op = when (source.boolOp!!) {
                BoolOp.Union -> PathOperation.Union
                BoolOp.Intersect -> PathOperation.Intersect
                BoolOp.Difference -> PathOperation.Difference
            }
            val out = Path()
            out.op(toPath(source.boolA!!), toPath(source.boolB!!), op)
            return out
        }
        val path = Path()
        source.forEachOp { op, v, i ->
            when (op) {
                BonsaiPath.OP_MOVE.toInt() -> path.moveTo(v[i].toFloat(), v[i + 1].toFloat())
                BonsaiPath.OP_LINE.toInt() -> path.lineTo(v[i].toFloat(), v[i + 1].toFloat())
                BonsaiPath.OP_QUAD.toInt() ->
                    path.quadraticTo(v[i].toFloat(), v[i + 1].toFloat(), v[i + 2].toFloat(), v[i + 3].toFloat())
                BonsaiPath.OP_CUBIC.toInt() -> path.cubicTo(
                    v[i].toFloat(), v[i + 1].toFloat(), v[i + 2].toFloat(), v[i + 3].toFloat(),
                    v[i + 4].toFloat(), v[i + 5].toFloat(),
                )
                BonsaiPath.OP_CLOSE.toInt() -> path.close()
                BonsaiPath.OP_ELLIPSE.toInt() -> path.addOval(
                    androidx.compose.ui.geometry.Rect(
                        v[i].toFloat(), v[i + 1].toFloat(), (v[i] + v[i + 2]).toFloat(), (v[i + 1] + v[i + 3]).toFloat(),
                    ),
                )
            }
        }
        return path
    }
}

/** The same drawing into an offscreen bitmap, for the home-screen widget (the still tree). */
fun renderBonsaiBitmap(
    day: Int,
    style: BonsaiStyle,
    vitality: Double,
    widthPx: Int,
    heightPx: Int,
    fill: Boolean,
    wind: BonsaiWind? = null,
): android.graphics.Bitmap {
    val image = androidx.compose.ui.graphics.ImageBitmap(widthPx, heightPx)
    val canvas = ComposeCanvas(image)
    val rect = if (fill) bonsaiContentRect(day, style) else BRect(0.0, 0.0, 600.0, 600.0)
    val pad = if (fill) 1.04 else 1.0
    val width = widthPx.toDouble()
    val height = heightPx.toDouble()
    val scale = minOf(width / (rect.width * pad), height / (rect.height * pad))
    val offX = (width - rect.width * scale) / 2 - rect.minX * scale
    val offY = if (fill) (height - rect.height * scale) - rect.minY * scale else (height - rect.height * scale) / 2 - rect.minY * scale
    val density = Resources.getSystem().displayMetrics.density
    val scene = bonsaiScene(day, style, vitality.coerceIn(0.0, 1.0), scale / density)
    canvas.translate(offX.toFloat(), offY.toFloat())
    canvas.scale(scale.toFloat(), scale.toFloat())
    BonsaiPainter.paint(scene, wind, canvas, Paint().apply { isAntiAlias = true })
    return image.asAndroidBitmap()
}

/** The scene's level of detail for a drawn size in dp per design unit (see bonsaiScene). */
private fun detailFor(style: BonsaiStyle, scale: Double): Int =
    if (style != BonsaiStyle.Maple && style != BonsaiStyle.Pine) 0 else if (scale < 0.2) 0 else if (scale < 0.5) 1 else 2
