package com.jackwallner.sober.ui.screens

import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.model.InsightCopy
import com.jackwallner.sober.model.CravingInsights
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.PrimaryCapsule
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.Instant
import kotlinx.coroutines.delay

private enum class CravingStep { BREATHING, REFLECT, DONE }

/**
 * The ride-it-out tool. No gate, no questions on the way in, nothing scored:
 * intensity and trigger are asked on the way out, when they are worth more.
 */
@Composable
fun CravingModeScreen(onFinish: (CravingOutcome) -> Unit, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val words = graph.content.words
    val isPro = graph.subscriptions.isPro
    val view = LocalView.current
    val context = LocalContext.current

    var step by rememberSaveable { mutableStateOf(CravingStep.BREATHING) }
    val startedAt = rememberSaveable { graph.clock.now().toEpochMilli() }
    var elapsed by rememberSaveable { mutableIntStateOf(0) }
    var target by rememberSaveable { mutableIntStateOf(words.typicalUrgeSeconds) }
    var intensity by rememberSaveable { mutableStateOf<Int?>(null) }
    var trigger by rememberSaveable { mutableStateOf<String?>(null) }
    var finished by rememberSaveable { mutableStateOf(false) }
    var rodeOutTotal by rememberSaveable { mutableIntStateOf(0) }
    val coachLine = remember { if (isPro) InsightCopy.coachLine(store.state.cravings) else null }
    val reduceMotion = remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }

    DisposableEffect(view) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
    LaunchedEffect(step) {
        while (step == CravingStep.BREATHING) {
            delay(1_000)
            elapsed += 1
            if (elapsed >= target) step = CravingStep.REFLECT
        }
    }

    fun finish(outcome: CravingOutcome) {
        if (finished) return
        finished = true
        val saved = store.recordCraving(Instant.ofEpochMilli(startedAt), elapsed, outcome, intensity, trigger)
        onFinish(outcome)
        // A failed save must not end on "Logged." with a count that includes the unsaved row.
        if (outcome != CravingOutcome.RODE_IT_OUT || !saved) {
            onClose()
            return
        }
        rodeOutTotal = store.rodeOutCount()
        step = CravingStep.DONE
    }

    BackHandler {
        when (step) {
            CravingStep.DONE -> onClose()
            else -> finish(CravingOutcome.UNRESOLVED)
        }
    }

    Box(Modifier.fillMaxSize().background(SoberColors.background)) {
        AnimatedContent(step, transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) }, label = "craving") { current ->
            when (current) {
                CravingStep.BREATHING -> Breathing(
                    elapsed = elapsed,
                    target = target,
                    coachLine = coachLine,
                    coach = graph.content.coach(elapsed, target),
                    reduceMotion = reduceMotion,
                    canExtend = target < words.maxUrgeSeconds,
                    onClose = { finish(CravingOutcome.UNRESOLVED) },
                    onThrough = { step = CravingStep.REFLECT },
                    onExtend = { target = minOf(words.maxUrgeSeconds, target + 60) },
                )
                CravingStep.REFLECT -> Reflect(
                    elapsed = elapsed,
                    intensity = intensity,
                    trigger = trigger,
                    triggers = words.triggers,
                    onIntensity = { intensity = it },
                    onTrigger = { trigger = it },
                    onFinish = ::finish,
                )
                CravingStep.DONE -> Done(
                    rodeOutTotal = rodeOutTotal,
                    urge = words.urge,
                    urges = words.urges,
                    doneLine = if (isPro) CravingInsights.rideOutRate(store.state.cravings)?.let { "${it.rode} of your last ${it.resolved} ended this way." } else null,
                    onClose = onClose,
                )
            }
        }
    }
}

@Composable
private fun Breathing(
    elapsed: Int,
    target: Int,
    coachLine: String?,
    coach: String,
    reduceMotion: Boolean,
    canExtend: Boolean,
    onClose: () -> Unit,
    onThrough: () -> Unit,
    onExtend: () -> Unit,
) {
    // Box breathing, 4 counts a side.
    val phase = (elapsed / 4) % 4
    val label = when (phase) {
        0 -> "Breathe in"
        2 -> "Breathe out"
        else -> "Hold"
    }
    val scale = remember { Animatable(0.72f) }
    LaunchedEffect(phase) {
        val goal = if (phase == 0 || phase == 1) 1f else 0.72f
        if (reduceMotion) scale.snapTo(goal) else scale.animateTo(goal, tween(4_000, easing = FastOutSlowInEasing))
    }
    val left = maxOf(0, target - elapsed)
    Column(Modifier.fillMaxSize().padding(top = Space.s), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).semantics { contentDescription = "Close" }.testTagCompat("craving.close").pressable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { SymbolIcon("xmark", SoberColors.textTertiary, 20.dp) }
            Spacer(Modifier.weight(1f))
            Text("%d:%02d".format(left / 60, left % 60), style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textSecondary,
                modifier = Modifier.padding(end = Space.m))
        }
        Spacer(Modifier.weight(1f))
        Box(Modifier.size(260.dp).semantics { contentDescription = label }, contentAlignment = Alignment.Center) {
            Box(Modifier.size(260.dp).border(1.dp, SoberColors.ringTrack, CircleShape))
            Box(Modifier.size(260.dp).scale(scale.value).clip(CircleShape).background(SoberColors.brandPrimary.copy(alpha = 0.14f)))
            Box(Modifier.size(260.dp).scale(scale.value).border(2.dp, SoberColors.brandPrimary.copy(alpha = 0.5f), CircleShape))
            Text(label, style = SoberType.heading(), color = SoberColors.brandPrimary)
        }
        Spacer(Modifier.size(Space.xl))
        Column(Modifier.widthIn(max = 320.dp).padding(horizontal = Space.l), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.s)) {
            AnimatedContent(coach, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "coach") {
                Text(it, style = SoberType.body(), color = SoberColors.textPrimary, textAlign = TextAlign.Center)
            }
            AnimatedVisibility(coachLine != null && elapsed >= target / 3, enter = fadeIn(), exit = fadeOut()) {
                Text(coachLine.orEmpty(), style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.brandPrimary, textAlign = TextAlign.Center)
            }
        }
        Spacer(Modifier.weight(1f))
        Column(
            Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = Space.xl).padding(bottom = Space.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.m),
        ) {
            PrimaryCapsule("I'm through it", tag = "craving.through", onClick = onThrough)
            Text(
                "Give me another minute",
                style = SoberType.subhead(FontWeight.SemiBold),
                color = SoberColors.brandPrimary,
                modifier = Modifier.alpha(if (canExtend) 1f else 0f).pressable(enabled = canExtend, onClick = onExtend).padding(8.dp),
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Reflect(
    elapsed: Int,
    intensity: Int?,
    trigger: String?,
    triggers: List<String>,
    onIntensity: (Int?) -> Unit,
    onTrigger: (String?) -> Unit,
    onFinish: (CravingOutcome) -> Unit,
) {
    val spoken = when {
        elapsed < 60 -> "${maxOf(1, elapsed)} seconds"
        elapsed % 60 == 0 -> if (elapsed / 60 == 1) "a minute" else "${elapsed / 60} minutes"
        else -> "${elapsed / 60}m ${elapsed % 60}s"
    }
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(Space.xl),
        verticalArrangement = Arrangement.spacedBy(Space.xl),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            Text("You stayed with it for $spoken.", style = SoberType.title(), color = SoberColors.textPrimary)
            Text("Two quick questions while it's fresh. Both optional.", style = SoberType.subhead(), color = SoberColors.textSecondary)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
            Text("How strong was it?", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
            Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                (1..5).forEach { value ->
                    val active = intensity == value
                    Box(
                        Modifier.weight(1f).clip(RoundedCornerShape(12.dp))
                            .background(if (active) SoberColors.brandPrimary else SoberColors.cardSurface)
                            .semantics {
                                contentDescription = "Intensity $value of 5"
                                selected = active
                            }
                            .testTagCompat("craving.intensity.$value")
                            .pressable { onIntensity(if (active) null else value) }
                            .padding(vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("$value", style = SoberType.body(FontWeight.SemiBold), color = if (active) Color.White else SoberColors.textSecondary)
                    }
                }
            }
            Row {
                Text("Mild", style = SoberType.caption(), color = SoberColors.textTertiary)
                Spacer(Modifier.weight(1f))
                Text("Overwhelming", style = SoberType.caption(), color = SoberColors.textTertiary)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
            Text("What set it off?", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(Space.s), verticalArrangement = Arrangement.spacedBy(Space.s)) {
                triggers.forEach { tag ->
                    val active = trigger == tag
                    Text(
                        tag,
                        style = SoberType.subhead(FontWeight.SemiBold),
                        color = if (active) Color.White else SoberColors.textSecondary,
                        modifier = Modifier.clip(CircleShape)
                            .background(if (active) SoberColors.brandPrimary else SoberColors.cardSurface)
                            .then(if (active) Modifier else Modifier.border(1.dp, SoberColors.ringTrack, CircleShape))
                            .semantics { selected = active }
                            .pressable { onTrigger(if (active) null else tag) }
                            .padding(horizontal = 14.dp, vertical = 8.dp),
                    )
                }
            }
        }
        Column(Modifier.padding(top = Space.s), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.m)) {
            PrimaryCapsule("It passed", tag = "craving.passed") { onFinish(CravingOutcome.RODE_IT_OUT) }
            Text("Not sure yet. Close session", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textSecondary,
                modifier = Modifier.testTagCompat("craving.unsure").pressable { onFinish(CravingOutcome.UNRESOLVED) }.padding(8.dp))
            Text("I gave in", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textSecondary,
                modifier = Modifier.testTagCompat("craving.gaveIn").pressable { onFinish(CravingOutcome.GAVE_IN) }.padding(8.dp))
        }
    }
}

@Composable
private fun Done(rodeOutTotal: Int, urge: String, urges: String, doneLine: String?, onClose: () -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(Space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.l),
    ) {
        Spacer(Modifier.weight(1f))
        SymbolIcon("wind", SoberColors.brandPrimary, 48.dp)
        Text("Logged.", style = SoberType.title(), color = SoberColors.textPrimary)
        if (rodeOutTotal > 0) {
            Text(
                if (rodeOutTotal == 1) "That's one $urge you've ridden out." else "That's $rodeOutTotal $urges you've ridden out.",
                style = SoberType.body(), color = SoberColors.textSecondary, textAlign = TextAlign.Center,
            )
        }
        if (doneLine != null) Text(doneLine, style = SoberType.subhead(), color = SoberColors.textTertiary, textAlign = TextAlign.Center)
        Spacer(Modifier.weight(1f))
        Box(Modifier.padding(horizontal = Space.xl)) { PrimaryCapsule("Back to the garden", tag = "craving.back", onClick = onClose) }
    }
}
