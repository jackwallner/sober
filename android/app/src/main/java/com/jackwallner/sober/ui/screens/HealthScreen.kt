package com.jackwallner.sober.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.content.HealthMilestone
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.openUrl
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.LargeTitle
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.Duration

/** Free users see the first five benefits; the rest of the timeline is Bloom+. */
private const val FREE_REVEAL_COUNT = 5

@Composable
fun HealthScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val isPro = graph.subscriptions.isPro
    val coordinator = graph.coordinator
    val benefits = graph.content.health
    val hours = store.activeStart?.let { maxOf(0.0, Duration.between(it, graph.clock.now()).toMinutes() / 60.0) } ?: 0.0
    val unlockedCount = benefits.count { hours >= it.hoursRequired }
    val next = benefits.firstOrNull { hours < it.hoursRequired }

    LaunchedEffect(Unit) { graph.pitches.passiveNudge(PitchIntent.HEALTH_TIMELINE) }

    Column(Modifier.fillMaxSize().background(SoberColors.background).statusBarsPadding()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 16.dp)) {
            LargeTitle("Health", Modifier.padding(top = 8.dp))
            InsetSection {
                Item {
                    Column(Modifier.padding(vertical = Space.xs), verticalArrangement = Arrangement.spacedBy(Space.s)) {
                        Row(verticalAlignment = Alignment.Bottom) {
                            Text("$unlockedCount", style = SoberType.rounded(44.sp, FontWeight.SemiBold), color = SoberColors.brandPrimary)
                            Spacer(Modifier.width(6.dp))
                            Text("/ ${benefits.size} benefits", style = SoberType.subhead(), color = SoberColors.textSecondary, modifier = Modifier.padding(bottom = 8.dp))
                        }
                        LinearProgressIndicator(
                            progress = { if (benefits.isEmpty()) 0f else unlockedCount.toFloat() / benefits.size },
                            color = SoberColors.brandPrimary,
                            trackColor = SoberColors.ringTrack,
                            drawStopIndicator = {},
                            modifier = Modifier.fillMaxWidth().height(4.dp).clip(CircleShape),
                        )
                    }
                }
                if (next != null) {
                    if (isPro) {
                        Item {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                                SymbolIcon("hourglass", SoberColors.textTertiary, 20.dp, Modifier.width(32.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text("Next up", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
                                    Text(next.title, style = SoberType.body(), color = SoberColors.textPrimary, maxLines = 2)
                                }
                                Text("in ${next.displayWait}", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
                            }
                        }
                    } else {
                        Item(onClick = { coordinator.requestLockedFeature(PitchIntent.HEALTH_TIMELINE) }, modifier = Modifier.testTagCompat("health.nextLocked")) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                                SymbolIcon("crown.fill", SoberColors.brandPrimary, 20.dp, Modifier.width(32.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text("Next up", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
                                    Text("Unlock what's coming with Bloom+", style = SoberType.body(), color = SoberColors.textPrimary)
                                }
                                SymbolIcon("chevron.right", SoberColors.textTertiary, 16.dp)
                            }
                        }
                    }
                }
            }
            InsetSection(
                "Benefits",
                footer = "General wellness information, not medical advice. Timelines vary from person to person. For medical concerns, talk to a healthcare professional.",
            ) {
                benefits.forEachIndexed { index, benefit ->
                    val inFreeWindow = isPro || index < FREE_REVEAL_COUNT
                    val visible = hours >= benefit.hoursRequired && inFreeWindow
                    val gated = !visible && !inFreeWindow
                    Item(
                        onClick = if (!isPro && index >= FREE_REVEAL_COUNT) ({ coordinator.requestLockedFeature(PitchIntent.HEALTH_TIMELINE) }) else null,
                        modifier = Modifier.testTagCompat("benefit.${benefit.id}"),
                    ) { BenefitRow(benefit, visible, gated) }
                }
            }
        }
    }
}

@Composable
private fun BenefitRow(benefit: HealthMilestone, unlocked: Boolean, gated: Boolean) {
    val context = LocalContext.current
    Row(Modifier.padding(vertical = Space.xs), horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        val (icon, tint) = when {
            unlocked -> "checkmark.circle.fill" to SoberColors.brandPrimary
            gated -> "crown.fill" to SoberColors.brandPrimary
            else -> "hourglass" to SoberColors.textTertiary
        }
        SymbolIcon(icon, tint, 22.dp, Modifier.width(32.dp).padding(top = 2.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                Text(if (gated) "A future milestone" else benefit.title, style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
                when {
                    unlocked -> Unit
                    gated -> Text("Bloom+", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.brandPrimary)
                    else -> Text("in ${benefit.displayWait}", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textTertiary)
                }
            }
            if (!gated) Text(benefit.summary, style = SoberType.caption(), color = SoberColors.textSecondary)
            if (unlocked) {
                Text(benefit.detail, style = SoberType.caption(), color = SoberColors.textSecondary, modifier = Modifier.padding(top = 2.dp))
                benefit.sourceUrl?.let { url ->
                    Row(
                        Modifier.padding(top = 2.dp).pressable { context.openUrl(url) },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        SymbolIcon("link", SoberColors.brandPrimary, 12.dp)
                        Text(benefit.sourceLabel, style = SoberType.caption(), color = SoberColors.brandPrimary)
                    }
                }
            } else if (gated) {
                Row(Modifier.padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Unlock with Bloom+", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.brandPrimary)
                    SymbolIcon("chevron.right", SoberColors.brandPrimary, 12.dp)
                }
            }
        }
    }
}
