package com.jackwallner.sober.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.animation.core.VectorConverter
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.content.Species
import com.jackwallner.sober.model.BonsaiStage
import com.jackwallner.sober.model.DayMark
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.model.GardenState
import com.jackwallner.sober.model.GrowthEvent
import com.jackwallner.sober.model.TendedDay
import com.jackwallner.sober.model.TendedWeek
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.bonsai.BonsaiStyle
import com.jackwallner.sober.ui.bonsai.BonsaiView
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import kotlinx.coroutines.launch

/** `GardenSceneView.styleEnum(for:)`. */
fun bonsaiStyleFor(id: String): BonsaiStyle = when (id) {
    "cascade-bonsai", "cascade" -> BonsaiStyle.Cascade
    "windswept-bonsai", "windswept" -> BonsaiStyle.Windswept
    "sakura-bonsai", "sakura" -> BonsaiStyle.Sakura
    "maple-bonsai", "maple" -> BonsaiStyle.Maple
    "pine-bonsai", "pine" -> BonsaiStyle.Pine
    else -> BonsaiStyle.Traditional
}

/** Free users get the one starter tree; Bloom+ unlocks every species. */
fun canUseSpecies(id: String, isPro: Boolean) = isPro || id == GardenState.FREE_SPECIES

private val translucentChip = Color.White.copy(alpha = 0.72f)

/**
 * The garden scene: one bonsai that grows daily, the grove of completed trees
 * behind it, and the species switcher.
 */
@Composable
fun GardenScene(
    days: Int,
    vitality: Double,
    activeStyleId: String,
    isPro: Boolean,
    completedTreeStyles: List<String>,
    modifier: Modifier = Modifier,
    onSwapBonsai: (() -> Unit)? = null,
) {
    val species = LocalGraph.current.content.species
    val cycle = GardenGrowth.cycle(days)
    val stage = GardenGrowth.stage(days)
    val style = bonsaiStyleFor(activeStyleId)
    val groveTotal = maxOf(cycle.completed, completedTreeStyles.size)
    val groveStyles = completedTreeStyles + List(maxOf(0, groveTotal - completedTreeStyles.size)) { activeStyleId }
    val premiumCount = species.count { it.id != GardenState.FREE_SPECIES }
    val activeName = species.firstOrNull { it.id == activeStyleId }?.name ?: style.displayName

    BoxWithConstraints(modifier.clip(RoundedCornerShape(24.dp)).background(SoberBrushes.sky)) {
        val w = maxWidth
        val h = maxHeight
        val groundY = h - 22.dp
        // Ground band.
        Box(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(24.dp)
                .background(Brush.verticalGradient(listOf(Color(0xFF8C6B47), Color(0xFF735233)))),
        )
        // Grove, filled outside-in so trees flank the centerpiece.
        val slots = listOf(0.10f, 0.90f, 0.23f, 0.77f, 0.36f, 0.64f)
        val baseW = minOf(w * 0.16f, 58.dp)
        groveStyles.take(slots.size).forEachIndexed { index, styleId ->
            val size = baseW * (1f - (index / 2) * 0.12f)
            BonsaiView(
                day = 365,
                style = bonsaiStyleFor(styleId),
                vitality = 1.0,
                fill = true,
                modifier = Modifier
                    .size(size)
                    .offset(x = w * slots[index] - size / 2, y = groundY - size)
                    .alpha(0.78f - (index / 2) * 0.08f),
            )
        }
        // Centerpiece, zoomed onto the plant and resting on the dirt line.
        val centerW = w * (if (stage == BonsaiStage.SEED) 0.55f else 1f)
        val topInset = h * (if (stage == BonsaiStage.SEED) 0.40f else 0.05f)
        val centerH = groundY - topInset
        BonsaiView(
            day = cycle.dayInCycle,
            style = style,
            vitality = vitality,
            fill = true,
            modifier = Modifier
                .size(centerW, centerH)
                .offset(x = (w - centerW) / 2, y = topInset)
                .then(if (onSwapBonsai != null) Modifier.pressable(onClick = onSwapBonsai) else Modifier),
        )
        // Overlays: stage and grove badges top-right, the species switcher bottom-left.
        Column(Modifier.align(Alignment.TopEnd).padding(12.dp), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Chip(
                icon = "leaf.fill",
                text = if (cycle.completed > 0) "Year ${cycle.completed + 1} · ${stage.title}" else stage.title,
                description = "${stage.title} stage",
            )
            if (groveTotal > 0) {
                Chip(
                    icon = "tree.fill",
                    text = if (groveTotal == 1) "1 tree grown" else "$groveTotal trees grown",
                    description = "$groveTotal ${if (groveTotal == 1) "tree" else "trees"} grown in your grove",
                )
            }
        }
        Row(
            Modifier.align(Alignment.BottomStart).padding(12.dp)
                .clip(CircleShape)
                .then(if (isPro) Modifier.background(translucentChip) else Modifier.background(SoberBrushes.brand))
                .semantics {
                    contentDescription = if (isPro) "Switch bonsai species, currently $activeName" else "Unlock more bonsai species with Bloom+"
                }
                .testTagCompat("garden.speciesSwitcher")
                .pressable { onSwapBonsai?.invoke() }
                .padding(horizontal = 10.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val tint = if (isPro) SoberColors.textPrimary else Color.White
            SymbolIcon(if (isPro) "arrow.triangle.2.circlepath" else "crown.fill", tint, 13.dp)
            Spacer(Modifier.width(5.dp))
            Text(if (isPro) "Switch" else "Unlock $premiumCount trees", style = SoberType.caption(FontWeight.SemiBold), color = tint, maxLines = 1)
        }
    }
}

@Composable
private fun Chip(icon: String, text: String, description: String) {
    Row(
        Modifier.clip(CircleShape).background(translucentChip).semantics { contentDescription = description }.padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SymbolIcon(icon, SoberColors.textPrimary, 12.dp)
        Spacer(Modifier.width(4.dp))
        Text(text, style = SoberType.caption(FontWeight.Bold), color = SoberColors.textPrimary)
    }
}

/**
 * Hosts the scene so it can be pinch-zoomed and dragged. Panning only unlocks
 * once zoomed in, so a one-finger drag at rest is left to the page, and a
 * reset button appears while zoomed.
 */
@Composable
fun PannableGarden(
    days: Int,
    vitality: Double,
    activeStyleId: String,
    isPro: Boolean,
    completedTreeStyles: List<String>,
    modifier: Modifier = Modifier,
    onSwapBonsai: () -> Unit,
) {
    var viewport by remember { mutableStateOf(IntSize.Zero) }
    val scale = remember { Animatable(1f) }
    val offset = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    val scope = rememberCoroutineScope()

    fun clamp(o: Offset, s: Float): Offset {
        val maxX = maxOf(0f, (viewport.width * s - viewport.width) / 2)
        val maxY = maxOf(0f, (viewport.height * s - viewport.height) / 2)
        return Offset(o.x.coerceIn(-maxX, maxX), o.y.coerceIn(-maxY, maxY))
    }

    Box(
        modifier
            .clip(RoundedCornerShape(24.dp))
            .onSizeChanged { viewport = it }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    do {
                        val event = awaitPointerEvent()
                        val multiTouch = event.changes.count { it.pressed } > 1
                        if (multiTouch || scale.value > 1f) {
                            val next = (scale.value * event.calculateZoom()).coerceIn(1f, 3f)
                            val moved = clamp(offset.value + event.calculatePan(), next)
                            scope.launch {
                                scale.snapTo(next)
                                offset.snapTo(moved)
                            }
                            event.changes.forEach { if (it.positionChanged()) it.consume() }
                        }
                    } while (event.changes.any { it.pressed })
                }
            },
    ) {
        GardenScene(
            days, vitality, activeStyleId, isPro, completedTreeStyles,
            modifier = Modifier.fillMaxSize().graphicsLayer {
                scaleX = scale.value
                scaleY = scale.value
                translationX = offset.value.x
                translationY = offset.value.y
            },
            onSwapBonsai = onSwapBonsai,
        )
        AnimatedVisibility(
            scale.value > 1f || offset.value != Offset.Zero,
            enter = fadeIn(), exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomEnd).padding(12.dp),
        ) {
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(translucentChip)
                    .semantics { contentDescription = "Reset zoom" }
                    .pressable {
                        scope.launch { scale.animateTo(1f, spring(dampingRatio = 0.8f, stiffness = 300f)) }
                        scope.launch { offset.animateTo(Offset.Zero, spring(dampingRatio = 0.8f, stiffness = 300f)) }
                    },
                contentAlignment = Alignment.Center,
            ) {
                SymbolIcon("arrow.up.left.and.down.right.magnifyingglass", SoberColors.textPrimary, 20.dp)
            }
        }
    }
}

/** Seven dots: what the last week actually looked like. */
@Composable
fun WeekStrip(days: List<TendedDay>, dotSize: androidx.compose.ui.unit.Dp = 10.dp) {
    Row(Modifier.semantics { contentDescription = TendedWeek.summary(days) }, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        days.forEach { day ->
            val base = Modifier.size(dotSize).clip(CircleShape)
            when (day.mark) {
                DayMark.TENDED -> Box(base.background(SoberColors.brandPrimary))
                DayMark.ASSUMED -> Box(base.border(1.5.dp, SoberColors.brandPrimary.copy(alpha = 0.45f), CircleShape))
                DayMark.SLIP -> Box(base.background(SoberColors.danger.copy(alpha = 0.75f)))
                DayMark.BLANK -> Box(base.background(SoberColors.ringTrack))
            }
        }
    }
}

/**
 * Full-screen celebration for a new growth stage or a completed tree, with
 * the tree as it looks right now (or fully grown for a completed cycle).
 */
@Composable
fun GrowthCelebration(event: GrowthEvent, style: BonsaiStyle, dayInCycle: Int, stageMessage: (BonsaiStage) -> String, onDismiss: () -> Unit) {
    val renderDay = if (event is GrowthEvent.TreeCompleted) 365 else dayInCycle
    val headline = if (event is GrowthEvent.TreeCompleted) "A Full Year" else "New Growth"
    val brandLine = when (event) {
        is GrowthEvent.NewStage -> event.stage.title
        is GrowthEvent.TreeCompleted -> "Your tree joins the grove"
    }
    val message = when (event) {
        is GrowthEvent.NewStage -> stageMessage(event.stage)
        is GrowthEvent.TreeCompleted -> if (event.total <= 1) {
            "365 days of growth, complete. Your tree now stands in your grove, and a fresh sapling begins beside it."
        } else {
            "365 days of growth, complete. That's ${event.total} trees in your grove, and a fresh sapling begins."
        }
    }
    val appear = remember { Animatable(0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = 120f)) }
    val sparkle = rememberInfiniteTransition(label = "sparkle")
    val turn by sparkle.animateFloat(0f, 360f, infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Restart), label = "turn")
    val pulse by sparkle.animateFloat(0.95f, 1.05f, infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Reverse), label = "pulse")

    Box(
        Modifier.fillMaxSize().background(SoberColors.background)
            .pressable(label = "Dismiss", onClick = onDismiss),
    ) {
        Column(Modifier.fillMaxSize().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(320.dp), contentAlignment = Alignment.Center) {
                Box(
                    Modifier.size(320.dp).scale(pulse).background(
                        Brush.radialGradient(listOf(SoberColors.accent.copy(alpha = 0.28f), SoberColors.accent.copy(alpha = 0f))),
                        CircleShape,
                    ),
                )
                SymbolIcon("sparkle", SoberColors.accent, 40.dp, Modifier.offset(y = (-120).dp).rotate(turn).scale(0.8f + 0.4f * (turn / 360f)))
                BonsaiView(
                    day = renderDay, style = style, vitality = 1.0, fill = true,
                    modifier = Modifier.size(200.dp).graphicsLayer {
                        val s = 0.4f + 0.6f * appear.value
                        scaleX = s
                        scaleY = s
                        alpha = appear.value.coerceIn(0f, 1f)
                    },
                )
            }
            Spacer(Modifier.height(24.dp))
            Column(
                Modifier.padding(horizontal = 24.dp).fillMaxWidth()
                    .graphicsLayer {
                        alpha = appear.value.coerceIn(0f, 1f)
                        translationY = (1 - appear.value) * 20.dp.toPx()
                    }
                    .card(SoberColors.cardSurface, 20.dp)
                    .padding(vertical = 20.dp, horizontal = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(headline, style = SoberType.title(), color = SoberColors.textPrimary)
                Text(brandLine, style = SoberType.title(), color = SoberColors.brandPrimary, textAlign = TextAlign.Center)
                Text(message, style = SoberType.subhead(), color = SoberColors.textSecondary, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 24.dp))
            }
            Spacer(Modifier.weight(1f))
            Box(
                Modifier.padding(horizontal = 40.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SoberColors.brandPrimary)
                    .testTagCompat("growth.continue")
                    .pressable(onClick = onDismiss).padding(16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("Continue", style = SoberType.body(FontWeight.SemiBold), color = Color.White)
            }
        }
    }
}

/** A species thumbnail on the sky wash, blurred and locked when out of reach. */
@Composable
fun SpeciesThumb(species: Species, day: Int, usable: Boolean, modifier: Modifier = Modifier, corner: androidx.compose.ui.unit.Dp = 10.dp, lockSize: androidx.compose.ui.unit.Dp = 12.dp) {
    Box(modifier.clip(RoundedCornerShape(corner)).background(SoberBrushes.sky), contentAlignment = Alignment.Center) {
        BonsaiView(
            day = day, style = bonsaiStyleFor(species.id), vitality = 1.0, fill = true,
            modifier = Modifier.fillMaxSize().padding(4.dp).then(if (usable) Modifier else Modifier.blur(4.dp)),
        )
        if (!usable) {
            Box(Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.35f)).padding(6.dp)) {
                SymbolIcon("lock.fill", Color.White, lockSize)
            }
        }
    }
}
