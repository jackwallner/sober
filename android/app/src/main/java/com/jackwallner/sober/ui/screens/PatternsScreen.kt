package com.jackwallner.sober.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.model.CravingInsight
import com.jackwallner.sober.model.CravingInsights
import com.jackwallner.sober.model.InsightCopy
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.BackChevron
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.navBarPadding

/** The Bloom+ headline: the user's own logged urges, read back to them. */
@Composable
fun PatternsScreen(backLabel: String, onBack: () -> Unit) {
    val graph = LocalGraph.current
    val state = graph.store.state
    val words = graph.content.words
    val zone = graph.clock.zone()
    val cravings = state.cravings
    val insights = InsightCopy.insights(cravings, state.checkIns, graph.clock.now(), zone, words.urge, words.urges, words.habitInstance)

    Column(Modifier.fillMaxSize().background(SoberColors.background)) {
        SheetBar("Your patterns", leading = { BackChevron(backLabel, onBack) })
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Space.l).padding(navBarPadding(0.dp)),
            verticalArrangement = Arrangement.spacedBy(Space.l),
        ) {
            if (cravings.isEmpty()) {
                Column(
                    Modifier.fillMaxWidth().padding(vertical = Space.xxl),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    SymbolIcon("chart.bar.xaxis", SoberColors.brandPrimary, 40.dp)
                    Text("Nothing to read yet", style = SoberType.title(), color = SoberColors.textPrimary)
                    Text(
                        "Every time you ride out a ${words.urge}, this page learns something about yours: when they hit, what sets them off, and how long they actually last.",
                        style = SoberType.body(), color = SoberColors.textSecondary, textAlign = TextAlign.Center,
                    )
                }
            } else {
                val answered = CravingInsights.resolved(cravings)
                val rodeOut = answered.count { it.outcome == com.jackwallner.sober.model.CravingOutcome.RODE_IT_OUT }
                val openEnded = cravings.size - answered.size
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(SoberColors.brandPrimary.copy(alpha = 0.06f)).padding(vertical = Space.l),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text("$rodeOut", style = SoberType.bigNumber(56.sp), color = SoberColors.brandPrimary)
                    Text(
                        (if (rodeOut == 1) "${words.urge} ridden out" else "${words.urges} ridden out").uppercase(),
                        style = SoberType.caption(FontWeight.SemiBold).copy(letterSpacing = 1.2.sp), color = SoberColors.textSecondary,
                    )
                    Text(
                        if (openEnded > 0) "out of ${answered.size} you saw through · $openEnded left open" else "out of ${answered.size} logged",
                        style = SoberType.caption(), color = SoberColors.textTertiary, textAlign = TextAlign.Center,
                    )
                }
                if (cravings.size >= CravingInsights.MINIMUM_FOR_TIMING) HourChart(cravings.map { it.startedAt.atZone(zone).hour }, words.urges)
                insights.forEach { InsightCard(it) }
                CravingInsights.nextUnlock(cravings, insights.size, words.urge, words.urges)?.let {
                    Text(it, style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(Space.m))
                }
            }
        }
    }
}

@Composable
private fun HourChart(hours: List<Int>, urges: String) {
    val counts = IntArray(24).also { array -> hours.forEach { array[it]++ } }
    val peak = maxOf(1, counts.maxOrNull() ?: 1)
    Column(
        Modifier.fillMaxWidth().card(SoberColors.cardSurface, 18.dp, null).padding(Space.l)
            .semantics(mergeDescendants = true) { contentDescription = "${urges.replaceFirstChar(Char::uppercaseChar)} by time of day" },
        verticalArrangement = Arrangement.spacedBy(Space.s),
    ) {
        Text("By time of day", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
        Row(Modifier.fillMaxWidth().height(56.dp), horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.Bottom) {
            counts.forEach { count ->
                Box(
                    Modifier.weight(1f).height(maxOf(3f, 56f * count / peak).dp).clip(RoundedCornerShape(2.dp))
                        .background(SoberColors.brandPrimary.copy(alpha = if (count == 0) 0.12f else 0.85f)),
                )
            }
        }
        Row {
            Text(InsightCopy.hourLabel(0), style = SoberType.caption(), color = SoberColors.textTertiary)
            Spacer(Modifier.weight(1f))
            Text(InsightCopy.hourLabel(12), style = SoberType.caption(), color = SoberColors.textTertiary)
            Spacer(Modifier.weight(1f))
            Text(InsightCopy.hourLabel(23), style = SoberType.caption(), color = SoberColors.textTertiary)
        }
    }
}

@Composable
private fun InsightCard(insight: CravingInsight) {
    Row(Modifier.fillMaxWidth().card(SoberColors.cardSurface, 18.dp, null).padding(Space.l), horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        Box(Modifier.size(34.dp).clip(CircleShape).background(SoberBrushes.brand), contentAlignment = Alignment.Center) {
            SymbolIcon(insight.icon, Color.White, 18.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(insight.headline, style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
            Text(insight.detail, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
    }
}
