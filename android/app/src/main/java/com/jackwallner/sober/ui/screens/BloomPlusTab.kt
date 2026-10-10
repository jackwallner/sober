package com.jackwallner.sober.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberSheet
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat

/** The always-present Bloom+ tab: the paywall for free users, a dashboard for subscribers. */
@Composable
fun BloomPlusTab() {
    val graph = LocalGraph.current
    if (graph.subscriptions.isPro) {
        BloomPlusHub()
    } else {
        Box(Modifier.fillMaxSize().statusBarsPadding()) {
            PaywallScreen(focus = null, impressionId = "sober_bloom_tab", displayCloseButton = false, showsLifetime = true, onClose = {})
        }
    }
}

@Composable
private fun BloomPlusHub() {
    var showPatterns by rememberSaveable { mutableStateOf(false) }
    var showProgress by rememberSaveable { mutableStateOf(false) }
    Box(Modifier.fillMaxSize().background(SoberColors.background).statusBarsPadding()) {
        AnimatedContent(
            showPatterns,
            transitionSpec = {
                if (targetState) slideInHorizontally(tween(280)) { it } togetherWith slideOutHorizontally(tween(280)) { -it / 3 }
                else slideInHorizontally(tween(280)) { -it / 3 } togetherWith slideOutHorizontally(tween(280)) { it }
            },
            label = "hub",
        ) { patterns ->
            if (patterns) {
                BackHandler { showPatterns = false }
                PatternsScreen(backLabel = "Bloom+", onBack = { showPatterns = false })
            } else {
                HubContent(onPatterns = { showPatterns = true }, onProgress = { showProgress = true })
            }
        }
    }
    SoberSheet(showProgress, onDismiss = { showProgress = false }) {
        ProgressSheet(onClose = { showProgress = false })
    }
}

@Composable
private fun HubContent(onPatterns: () -> Unit, onProgress: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val state = store.state
    val content = graph.content
    val cents = state.settings.costPerDayCents
    val calories = state.settings.caloriesPerDay
    val days = store.days
    val heroDays = maxOf(store.lifetimeSoberDays, days)
    val money = heroDays * cents / 100.0
    val lifetimeCalories = heroDays * calories
    val yearly = cents * 365 / 100.0
    val rodeOut = state.cravings.count { it.outcome == CravingOutcome.RODE_IT_OUT }

    Column(Modifier.fillMaxSize()) {
        SheetBar("Bloom+")
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Space.l), verticalArrangement = Arrangement.spacedBy(Space.l)) {
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(SoberColors.brandPrimary.copy(alpha = 0.06f)).padding(vertical = Space.l),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SymbolIcon("sparkles", SoberColors.brandPrimary, 13.dp)
                    Text("BLOOM+ ACTIVE", style = SoberType.caption(FontWeight.Bold).copy(letterSpacing = 1.4.sp), color = SoberColors.brandPrimary)
                }
                Text(Format.currency(money), style = SoberType.rounded(54.sp, FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
                Text("kept in your pocket across $heroDays sober day${if (heroDays == 1) "" else "s"}", style = SoberType.caption(),
                    color = SoberColors.textSecondary, textAlign = TextAlign.Center)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                StatTile("flame.fill", Format.number(lifetimeCalories), "calories avoided", Modifier.weight(1f))
                StatTile("scalemass.fill", "${Format.oneDecimal(lifetimeCalories / 3500.0)} lb", "of body fat", Modifier.weight(1f))
            }
            if (yearly > 0) {
                Row(
                    Modifier.fillMaxWidth().card(SoberColors.cardSurface, 16.dp, null).padding(Space.m),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    SymbolIcon("chart.line.uptrend.xyaxis", SoberColors.brandPrimary, 22.dp, Modifier.width(32.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("On track to save", style = SoberType.caption(), color = SoberColors.textSecondary)
                        Text("${Format.currency(yearly)} a year", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
                    }
                }
            }
            Row(
                Modifier.fillMaxWidth().card(SoberColors.cardSurface, 16.dp, null).testTagCompat("hub.patterns").pressable(onClick = onPatterns).padding(Space.m),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Space.m),
            ) {
                Box(Modifier.size(38.dp).clip(CircleShape).background(SoberBrushes.brand), contentAlignment = Alignment.Center) {
                    SymbolIcon("chart.bar.xaxis", Color.White, 20.dp)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text("Your patterns", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
                    Text(
                        when (rodeOut) {
                            0 -> "When your ${content.words.urges} hit and what sets them off"
                            1 -> "1 ${content.words.urge} ridden out so far"
                            else -> "$rodeOut ${content.words.urges} ridden out so far"
                        },
                        style = SoberType.caption(), color = SoberColors.textSecondary,
                    )
                }
                SymbolIcon("chevron.right", SoberColors.textTertiary, 16.dp)
            }
            val next = content.achievements.firstOrNull { it.kind == "timeMilestone" && days < it.dayThreshold }
            val hours = maxOf(0, days - 1) * 24.0
            val benefit = content.health.firstOrNull { hours < it.hoursRequired }
            Column(Modifier.fillMaxWidth().card(SoberColors.cardSurface, 16.dp, null)) {
                MilestoneRow("flag.fill", next?.title ?: "Year One", next?.let { "in ${maxOf(1, it.dayThreshold - days)} days" } ?: "Crushed it")
                HorizontalDivider(Modifier.padding(start = 48.dp), color = SoberColors.ringTrack)
                MilestoneRow("heart.fill", benefit?.title ?: "All benefits unlocked", benefit?.let { "at ${it.displayWait}" } ?: "")
                HorizontalDivider(Modifier.padding(start = 48.dp), color = SoberColors.ringTrack)
                MilestoneRow("checkmark.seal.fill", "Achievements earned", "${state.earnedAchievementIds.size}")
            }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(SoberColors.brandPrimary.copy(alpha = 0.08f))
                    .testTagCompat("hub.progress").pressable(onClick = onProgress).padding(Space.m),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SymbolIcon("chart.bar.fill", SoberColors.brandPrimary, 20.dp)
                Spacer(Modifier.width(8.dp))
                Text("See full progress", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.brandPrimary, modifier = Modifier.weight(1f))
                SymbolIcon("chevron.right", SoberColors.brandPrimary, 14.dp)
            }
        }
    }
}

@Composable
private fun StatTile(icon: String, value: String, label: String, modifier: Modifier) {
    Column(
        modifier.card(SoberColors.cardSurface, 16.dp, null).padding(vertical = Space.m),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SymbolIcon(icon, SoberColors.brandPrimary, 22.dp)
        Text(value, style = SoberType.heading(weight = FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
        Text(label, style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.Center)
    }
}

@Composable
private fun MilestoneRow(icon: String, title: String, trailing: String) {
    Row(Modifier.fillMaxWidth().padding(Space.m), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(32.dp))
        Text(title, style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
        Text(trailing, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
    }
}
