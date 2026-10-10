package com.jackwallner.sober.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.content.Achievement
import com.jackwallner.sober.content.HealthMilestone
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.model.TendedWeek
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.InsetScope
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.navBarPadding
import com.jackwallner.sober.ui.theme.testTagCompat

/** `HealthBenefit.displayWait`: "6h", "3d", "2w", "4mo", "1y". */
val HealthMilestone.displayWait: String
    get() {
        if (hoursRequired < 24) return "${hoursRequired.toInt()}h"
        val days = (hoursRequired / 24).toInt()
        return when {
            days < 7 -> "${days}d"
            days < 30 -> "${days / 7}w"
            days < 365 -> "${days / 30}mo"
            else -> "${days / 365}y"
        }
    }

/**
 * The pull-up sheet for the longer horizon: what's next, this week, patterns,
 * money kept, the year ahead, the species, and every badge.
 */
@Composable
fun ProgressSheet(onClose: () -> Unit) {
    var showPatterns by rememberSaveable { mutableStateOf(false) }
    AnimatedContent(
        showPatterns,
        transitionSpec = {
            if (targetState) slideInHorizontally(tween(280)) { it } togetherWith slideOutHorizontally(tween(280)) { -it / 3 }
            else slideInHorizontally(tween(280)) { -it / 3 } togetherWith slideOutHorizontally(tween(280)) { it }
        },
        label = "progress",
    ) { patterns ->
        if (patterns) {
            BackHandler { showPatterns = false }
            PatternsScreen(backLabel = "Your progress", onBack = { showPatterns = false })
        } else {
            ProgressList(onClose, onPatterns = { showPatterns = true })
        }
    }
}

@Composable
private fun ProgressList(onClose: () -> Unit, onPatterns: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val coordinator = graph.coordinator
    val content = graph.content
    val state = store.state
    val settings = state.settings
    val isPro = subscriptions.isPro
    val days = store.days
    val week = TendedWeek.days(store.today, state.checkIns)
    val summary = TendedWeek.summary(week)
    val mood = TendedWeek.moodSummary(week)
    val weekLine = if (TendedWeek.tendedCount(week) > 0 && mood != null) "$summary · felt $mood" else summary
    val lifetime = store.lifetimeSoberDays
    val cents = settings.costPerDayCents
    val calories = settings.caloriesPerDay
    val hasSpendData = cents > 0 || calories > 0
    val showTrialNudge = days >= 7 && !isPro && !subscriptions.hasClaimedTrial && subscriptions.hasTrialOfferAvailable
    val lifetimeMoney = Format.currency(lifetime * cents / 100.0)

    Column(Modifier.fillMaxSize()) {
        SheetBar("Your progress", trailing = { TextAction("Done", style = SoberType.body(FontWeight.SemiBold), onClick = onClose) })
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(navBarPadding(8.dp)).padding(top = 8.dp)) {
            if (showTrialNudge) {
                InsetSection {
                    Item(onClick = { coordinator.requestLockedFeature(PitchIntent.PROGRESS_SHEET) }) {
                        LeadingRow("gift.fill", "You've kept $lifetimeMoney so far", "See what a year of this looks like", trailingIcon = "chevron.right", emphasized = true)
                    }
                }
            }
            InsetSection("Next up") {
                val next = content.achievements.firstOrNull { it.kind == "timeMilestone" && days < it.dayThreshold }
                Item { LeadingRow("flag.fill", next?.title ?: "Year One", next?.let { "in ${maxOf(1, it.dayThreshold - days)} days" } ?: "Crushed it") }
                val hours = maxOf(0, days - 1) * 24.0
                val benefit = content.health.firstOrNull { hours < it.hoursRequired }
                Item { LeadingRow("heart.fill", benefit?.title ?: "All unlocked", benefit?.let { "at ${it.displayWait}" } ?: "") }
            }
            InsetSection("This week", footer = "A filled dot is a day you checked in. A hollow one is a sober day the app filled in for you.") {
                Item {
                    Column(verticalArrangement = Arrangement.spacedBy(Space.s), modifier = Modifier.padding(vertical = Space.xs)) {
                        WeekStrip(week, 14.dp)
                        Text(weekLine, style = SoberType.caption(), color = SoberColors.textSecondary)
                    }
                }
            }
            InsetSection {
                if (isPro) {
                    Item(onClick = onPatterns, modifier = Modifier.testTagCompat("progress.patterns")) {
                        LeadingRow("chart.bar.xaxis", "Your patterns", "When your ${content.words.urges} hit and what sets them off", trailingIcon = "chevron.right")
                    }
                } else {
                    Item(onClick = { coordinator.requestLockedFeature(PitchIntent.PATTERNS) }, modifier = Modifier.testTagCompat("progress.patternsLocked")) {
                        LeadingRow(
                            "chart.bar.xaxis", "Learn your own pattern",
                            "Bloom+ reads your logged ${content.words.urges} back to you: when they hit, what sets them off, how long yours last",
                            trailingIcon = "lock.fill",
                        )
                    }
                }
            }
            if (hasSpendData) {
                InsetSection(
                    "Kept so far",
                    footer = "Streak counts your current run. Lifetime counts every sober day on your record, including days the app filled in for you, so past progress isn't lost on a reset.",
                ) {
                    Item { SavedRow("Money", Format.currency(days * cents / 100.0), lifetimeMoney, "${Format.currencyFromCents(cents)} / day", "dollarsign.circle.fill") }
                    Item { SavedRow("Calories", Format.number(days * calories), Format.number(lifetime * calories), "$calories / day", "flame.fill") }
                    Item { SavedRow("Body fat", Format.poundsOfFat(days * calories), Format.poundsOfFat(lifetime * calories), "~3,500 cal per lb", "scalemass.fill") }
                }
                InsetSection(
                    "Your year ahead",
                    footer = "A projection from your current daily figures, not a promise. Change them any time in Settings.",
                ) {
                    if (isPro) {
                        Item { YearRow("Money", Format.currency(cents * 365 / 100.0), "if you keep going for 12 months", "dollarsign.circle.fill") }
                        Item { YearRow("Calories", Format.number(calories * 365), "not drunk over 12 months", "flame.fill") }
                        Item { YearRow("Body fat", Format.poundsOfFat(calories * 365), "~3,500 cal per lb", "scalemass.fill") }
                    } else {
                        Item(onClick = { coordinator.requestLockedFeature(PitchIntent.PROGRESS_SHEET) }) {
                            LeadingRow("chart.line.uptrend.xyaxis", "See where this goes", "Bloom+ projects your money, calories, and tree a year out", trailingIcon = "lock.fill")
                        }
                    }
                }
            }
            Text(
                "BONSAI SPECIES",
                style = SoberType.rounded(androidx.compose.ui.unit.TextUnit(13f, androidx.compose.ui.unit.TextUnitType.Sp)),
                color = SoberColors.textSecondary,
                modifier = Modifier.padding(start = 32.dp, bottom = 7.dp),
            )
            GardenCollection(activeStyleId = state.garden.speciesId, isPro = isPro, modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 22.dp))
            InsetSection("Time milestones") {
                content.achievements.filter { it.kind == "timeMilestone" }.forEach { AchievementRow(it, days, isPro) }
            }
            InsetSection("Streaks") {
                content.achievements.filter { it.kind == "streak" }.forEach { AchievementRow(it, days, isPro) }
            }
        }
    }
}

@Composable
private fun InsetScope.AchievementRow(achievement: Achievement, days: Int, isPro: Boolean) {
    val graph = LocalGraph.current
    val unlocked = achievement.id in graph.store.state.earnedAchievementIds || days >= achievement.dayThreshold
    Item(onClick = if (!unlocked && !isPro) ({ graph.coordinator.requestLockedFeature(PitchIntent.PROGRESS_SHEET) }) else null) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
            SymbolIcon(achievement.icon, if (unlocked) SoberColors.brandPrimary else SoberColors.textTertiary, 22.dp, Modifier.width(32.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(achievement.title, style = SoberType.body(), color = if (unlocked) SoberColors.textPrimary else SoberColors.textSecondary)
                Text(achievement.description, style = SoberType.caption(), color = SoberColors.textSecondary)
            }
            if (unlocked) SymbolIcon("checkmark.seal.fill", SoberColors.brandPrimary, 22.dp)
            else if (!isPro) SymbolIcon("lock.fill", SoberColors.textTertiary, 18.dp)
        }
    }
}

/** Leading glyph, title, and caption: the List row most of these sheets use. */
@Composable
fun LeadingRow(icon: String, title: String, detail: String, trailingIcon: String? = null, emphasized: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, if (emphasized) 24.dp else 20.dp, Modifier.width(32.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = if (emphasized) SoberType.subhead(FontWeight.SemiBold) else SoberType.body(), color = SoberColors.textPrimary)
            if (detail.isNotEmpty()) Text(detail, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        if (trailingIcon != null) SymbolIcon(trailingIcon, SoberColors.textTertiary, 16.dp)
    }
}

@Composable
private fun SavedRow(label: String, streak: String, lifetime: String, sub: String, icon: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(32.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, style = SoberType.body(), color = SoberColors.textPrimary)
            Text(sub, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(streak, style = SoberType.heading(), color = SoberColors.brandPrimary)
            Text("$lifetime lifetime", style = SoberType.caption(), color = SoberColors.textSecondary, textAlign = TextAlign.End)
        }
    }
}

@Composable
private fun YearRow(label: String, value: String, sub: String, icon: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(32.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, style = SoberType.body(), color = SoberColors.textPrimary)
            Text(sub, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        Text(value, style = SoberType.heading(), color = SoberColors.brandPrimary)
    }
}
