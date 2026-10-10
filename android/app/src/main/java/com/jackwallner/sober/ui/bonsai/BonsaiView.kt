package com.jackwallner.sober.ui.bonsai

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Canvas as ComposeCanvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.LinearGradientShader
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.PaintingStyle
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shader
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

/**
 * The procedural bonsai, drawn natively (port of the Swift BonsaiView).
 *
 * `fill` zooms onto the plant's content rect and bottom-anchors it (home centerpiece);
 * otherwise the 600x600 design square is centered in the frame. The command list is
 * cached per (day, style, vitality), so small collection tiles stay cheap.
 */
@Composable
fun BonsaiView(
    day: Int,
    style: BonsaiStyle,
    vitality: Double,
    modifier: Modifier = Modifier,
    fill: Boolean = false,
) {
    // Vitality only changes the three trunk-pipeline styles; keep the others on one cache key.
    val vitalityKey = if (style.usesVitality) vitality.coerceIn(0.0, 1.0) else 1.0
    val scene = remember(day, style, vitalityKey) { BonsaiScene.build(day, style, vitalityKey) }
    val rect = remember(day, style, fill) {
        if (fill) bonsaiContentRect(day, style) else BRect(0.0, 0.0, 600.0, 600.0)
    }
    val paint = remember { Paint().apply { isAntiAlias = true } }
    Canvas(modifier.semantics { contentDescription = "Bonsai, day $day" }) {
        val width = size.width.toDouble()
        val height = size.height.toDouble()
        if (width <= 0.0 || height <= 0.0) return@Canvas
        val pad = if (fill) 1.04 else 1.0
        val scale = minOf(width / (rect.width * pad), height / (rect.height * pad))
        val drawnW = rect.width * scale
        val drawnH = rect.height * scale
        // Center horizontally; center (default) or bottom-anchor (fill) the focus rect.
        val offX = (width - drawnW) / 2 - rect.minX * scale
        val offY = if (fill) (height - drawnH) - rect.minY * scale
        else (height - drawnH) / 2 - rect.minY * scale
        drawIntoCanvas { canvas ->
            canvas.save()
            canvas.clipRect(0f, 0f, size.width, size.height)
            canvas.translate(offX.toFloat(), offY.toFloat())
            canvas.scale(scale.toFloat(), scale.toFloat())
            scene.draw(canvas, paint)
            canvas.restore()
        }
    }
}

private val BonsaiStyle.usesVitality: Boolean
    get() = this == BonsaiStyle.Traditional || this == BonsaiStyle.Cascade || this == BonsaiStyle.Windswept

/** Pre-resolved platform draw calls for one tree, in the 600x600 design space. */
internal class BonsaiScene private constructor(private val ops: List<Op>) {
    private class Op(
        val path: Path,
        val matrix: Matrix,
        val color: Color,
        val shader: Shader?,
        val strokeWidth: Float,
        val cap: StrokeCap,
        val isStroke: Boolean,
    )

    fun draw(canvas: ComposeCanvas, paint: Paint) {
        paint.strokeMiterLimit = 10f
        paint.strokeJoin = StrokeJoin.Miter
        for (op in ops) {
            canvas.save()
            canvas.concat(op.matrix)
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
            canvas.restore()
        }
        paint.shader = null
    }

    companion object {
        fun build(day: Int, style: BonsaiStyle, vitality: Double): BonsaiScene {
            val recorder = BonsaiRecorder()
            drawBonsai(day, style, vitality, recorder)
            return BonsaiScene(recorder.commands.map(::toOp))
        }

        private fun toOp(c: BonsaiCommand): Op {
            val paint = c.paint
            val color = when (paint) {
                is BonsaiPaint.Solid -> composeColor(paint.color, c.opacity)
                is BonsaiPaint.LinearGradient -> Color.Unspecified
            }
            val shader = (paint as? BonsaiPaint.LinearGradient)?.let {
                LinearGradientShader(
                    from = Offset(it.start.x.toFloat(), it.start.y.toFloat()),
                    to = Offset(it.end.x.toFloat(), it.end.y.toFloat()),
                    colors = it.colors.map { stop -> composeColor(stop, c.opacity) },
                    colorStops = null,
                    tileMode = TileMode.Clamp,
                )
            }
            val cap = when (c.cap) {
                BonsaiCap.Butt -> StrokeCap.Butt
                BonsaiCap.Round -> StrokeCap.Round
                BonsaiCap.Square -> StrokeCap.Square
            }
            return Op(toPath(c.path), toMatrix(c.transform), color, shader, c.strokeWidth.toFloat(), cap, c.isStroke)
        }

        private fun composeColor(color: BonsaiColor, opacity: Double) = Color(
            red = color.red.toFloat(),
            green = color.green.toFloat(),
            blue = color.blue.toFloat(),
            alpha = (color.alpha * opacity).toFloat(),
        )

        /** Affine [a, b, c, d, tx, ty] to Compose's column-major 4x4. */
        private fun toMatrix(t: DoubleArray): Matrix = Matrix(
            floatArrayOf(
                t[0].toFloat(), t[1].toFloat(), 0f, 0f,
                t[2].toFloat(), t[3].toFloat(), 0f, 0f,
                0f, 0f, 1f, 0f,
                t[4].toFloat(), t[5].toFloat(), 0f, 1f,
            ),
        )

        // Non-zero winding is Compose's default fill type, matching SwiftUI's FillStyle().
        private fun toPath(source: BonsaiPath): Path {
            val path = Path()
            source.forEachOp { op, a, b, c, d ->
                when (op) {
                    BonsaiPath.OP_MOVE.toInt() -> path.moveTo(a.toFloat(), b.toFloat())
                    BonsaiPath.OP_LINE.toInt() -> path.lineTo(a.toFloat(), b.toFloat())
                    BonsaiPath.OP_QUAD.toInt() -> path.quadraticTo(a.toFloat(), b.toFloat(), c.toFloat(), d.toFloat())
                    BonsaiPath.OP_CLOSE.toInt() -> path.close()
                    BonsaiPath.OP_ELLIPSE.toInt() ->
                        path.addOval(androidx.compose.ui.geometry.Rect(a.toFloat(), b.toFloat(), (a + c).toFloat(), (b + d).toFloat()))
                }
            }
            return path
        }
    }
}
