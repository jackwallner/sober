package com.jackwallner.sober.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.model.DailyGrowth
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.bonsai.BonsaiView
import com.jackwallner.sober.ui.theme.Hairline
import com.jackwallner.sober.ui.theme.InsetScope
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.LargeTitle
import com.jackwallner.sober.ui.theme.PlainTextField
import com.jackwallner.sober.ui.theme.SoberAlert
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale

/**
 * Timeline: the calendar doubles as a date picker; the selected day shows the
 * tree as it looked then, with a day-over-day note and that day's check-in.
 */
@Composable
fun TimelineScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val state = store.state
    val zone = graph.clock.zone()
    val today = store.today
    var monthAnchor by rememberSaveable { mutableStateOf(today.withDayOfMonth(1).toString()) }
    var selectedDay by rememberSaveable { mutableStateOf(today.toString()) }
    var draftMood by rememberSaveable { mutableStateOf<Int?>(null) }
    var draftNote by rememberSaveable { mutableStateOf("") }
    var pendingSlipDay by rememberSaveable { mutableStateOf<String?>(null) }
    val month = LocalDate.parse(monthAnchor)
    val selected = LocalDate.parse(selectedDay)
    val byDay = state.checkIns.associateBy { it.day }
    val earliestStart = state.journeys.minByOrNull { it.start }?.start?.atZone(zone)?.toLocalDate()
    val activeStart = JourneyDays.active(state)?.start?.atZone(zone)?.toLocalDate()

    LaunchedEffect(Unit) { graph.pitches.passiveNudge(PitchIntent.PROGRESS_SHEET) }
    LaunchedEffect(selectedDay) {
        val checkIn = byDay[selected]
        draftMood = checkIn?.mood
        draftNote = checkIn?.note ?: ""
    }

    fun soberDays(date: LocalDate): Int = JourneyDays.at(state, date, zone)
    fun treeDays(date: LocalDate): Int {
        val count = soberDays(date)
        if (activeStart == null || date < activeStart) return count
        return GardenGrowth.treeDays(count, state.garden.carryoverDays)
    }

    Column(Modifier.fillMaxSize().background(SoberColors.background).statusBarsPadding()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 16.dp)) {
            LargeTitle("Timeline", Modifier.padding(top = 8.dp))
            InsetSection {
                Item(padding = androidx.compose.foundation.layout.PaddingValues(horizontal = Space.l, vertical = Space.m)) {
                    val totalSober = state.checkIns.count { it.wasSober }
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        StatCell("${store.days}", "Current", Modifier.weight(1f))
                        Box(Modifier.width(0.5.dp).height(40.dp).background(Color(0x33000000)))
                        StatCell("${store.longestStreakDays}", "Longest", Modifier.weight(1f))
                        Box(Modifier.width(0.5.dp).height(40.dp).background(Color(0x33000000)))
                        StatCell("$totalSober", "Total", Modifier.weight(1f))
                    }
                }
            }
            InsetSection {
                Item {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        MonthArrow("chevron.left", "Previous month") { monthAnchor = month.minusMonths(1).toString() }
                        Text(Format.monthTitle(month), style = SoberType.heading(), color = SoberColors.textPrimary,
                            modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                        MonthArrow("chevron.right", "Next month") { monthAnchor = month.plusMonths(1).toString() }
                    }
                }
                Item(padding = androidx.compose.foundation.layout.PaddingValues(start = Space.s, end = Space.s, bottom = Space.s), divider = false) {
                    MonthGrid(month, selected, today, earliestStart, byDay) { selectedDay = it.toString() }
                }
            }
            InsetSection("Selected day") {
                Item(padding = androidx.compose.foundation.layout.PaddingValues(start = Space.l, end = Space.l, top = Space.s, bottom = Space.m)) {
                    TreeRow(selected, today, soberDays(selected), treeDays(selected), bonsaiStyleFor(state.garden.speciesId))
                }
            }
            if (selected <= today) {
                InsetSection("Check-in") {
                    CheckInEditor(
                        day = selected,
                        draftMood = draftMood,
                        draftNote = draftNote,
                        onMood = { draftMood = it },
                        onNote = { draftNote = it },
                        onRequestSlip = { pendingSlipDay = selected.toString() },
                    )
                }
            }
        }
    }

    pendingSlipDay?.let { raw ->
        SoberAlert(
            title = "Log a slip?",
            message = "Your day counter restarts after the slip. Your tree carries some growth forward, and your calendar history and completed trees stay. Your longest streak reflects the corrected dates.",
            confirmTitle = "Log slip",
            dismissTitle = "Cancel",
            onConfirm = {
                store.recordSlip(LocalDate.parse(raw), draftMood, draftNote.trim().ifEmpty { null })
                pendingSlipDay = null
            },
            onDismiss = { pendingSlipDay = null },
        )
    }
}

@Composable
private fun StatCell(value: String, label: String, modifier: Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, style = SoberType.title(), color = SoberColors.brandPrimary)
        Text(label.uppercase(), style = SoberType.caption(FontWeight.SemiBold).copy(letterSpacing = androidx.compose.ui.unit.TextUnit(0.6f, androidx.compose.ui.unit.TextUnitType.Sp)), color = SoberColors.textSecondary)
    }
}

@Composable
private fun MonthArrow(icon: String, label: String, onClick: () -> Unit) {
    Box(Modifier.size(32.dp).semantics { contentDescription = label }.pressable(onClick = onClick), contentAlignment = Alignment.Center) {
        SymbolIcon(icon, SoberColors.brandPrimary, 22.dp)
    }
}

@Composable
private fun MonthGrid(
    month: LocalDate,
    selected: LocalDate,
    today: LocalDate,
    earliestStart: LocalDate?,
    byDay: Map<LocalDate, com.jackwallner.sober.model.CheckIn>,
    onSelect: (LocalDate) -> Unit,
) {
    val firstDay = WeekFields.of(Locale.getDefault()).firstDayOfWeek
    val leading = ((month.dayOfWeek.value - firstDay.value) + 7) % 7
    val cells: List<LocalDate?> = List(leading) { null } + (1..month.lengthOfMonth()).map { month.withDayOfMonth(it) }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Format.weekdaySymbols(firstDay).forEach {
                Text(it, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary,
                    modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
        cells.chunked(7).forEach { week ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                week.forEach { date ->
                    Box(Modifier.weight(1f).height(36.dp)) {
                        if (date != null) DayCell(date, byDay[date], date == selected, date > today, earliestStart?.let { date < it } ?: false) { onSelect(date) }
                    }
                }
                repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun DayCell(
    date: LocalDate,
    checkIn: com.jackwallner.sober.model.CheckIn?,
    isSelected: Boolean,
    inFuture: Boolean,
    beforeStart: Boolean,
    onTap: () -> Unit,
) {
    // A tended day reads solid; a day the app filled in reads faint.
    val bg = when {
        inFuture || beforeStart -> Color.Transparent
        checkIn?.wasSober == false -> SoberColors.danger.copy(alpha = 0.75f)
        checkIn?.wasSober == true -> SoberColors.success.copy(alpha = if (checkIn.wasLogged) 0.85f else 0.3f)
        else -> SoberColors.cardSurface
    }
    val filled = checkIn?.wasSober == false || checkIn?.wasLogged == true
    val shape = RoundedCornerShape(8.dp)
    Box(
        Modifier.fillMaxSize()
            .alpha(if (inFuture || beforeStart) 0.5f else 1f)
            .clip(shape)
            .background(bg, shape)
            .border(2.dp, if (isSelected) SoberColors.brandPrimary else Color.Transparent, shape)
            .testTagCompat("day.${date}")
            .semantics { contentDescription = Format.mediumDate(date) }
            .pressable(enabled = !inFuture && !beforeStart, onClick = onTap),
        contentAlignment = Alignment.Center,
    ) {
        Text("${date.dayOfMonth}", style = SoberType.caption(FontWeight.Bold), color = if (filled) Color.White else SoberColors.textPrimary)
    }
}

@Composable
private fun TreeRow(selected: LocalDate, today: LocalDate, dayCount: Int, drawnDays: Int, style: com.jackwallner.sober.ui.bonsai.BonsaiStyle) {
    val cycle = GardenGrowth.cycle(drawnDays)
    val stage = GardenGrowth.stage(drawnDays)
    Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(if (selected == today) "Today" else Format.mediumDate(selected), style = SoberType.body(), color = SoberColors.textPrimary)
            Text("Day $dayCount · ${stage.title}", style = SoberType.subhead(), color = SoberColors.textSecondary)
        }
        Box(Modifier.fillMaxWidth().height(200.dp).clip(RoundedCornerShape(14.dp)).background(SoberBrushes.sky)) {
            AnimatedContent(cycle.dayInCycle, transitionSpec = { fadeIn(tween(350)) togetherWith fadeOut(tween(350)) }, label = "tree") { day ->
                BonsaiView(day = day, style = style, vitality = 1.0, modifier = Modifier.fillMaxSize().padding(8.dp))
            }
        }
        val previous = GardenGrowth.stage(maxOf(0, drawnDays - 1))
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (drawnDays <= 1) {
                GrowthLine("sparkle", "The seed is settling in. Your journey starts here.")
            } else {
                GrowthLine("arrow.up.forward", "vs. yesterday: ${DailyGrowth.note(cycle.dayInCycle)}")
                if (stage != previous) GrowthLine("leaf.fill", "Stage advanced: ${previous.title} → ${stage.title}")
            }
        }
    }
}

@Composable
private fun GrowthLine(icon: String, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 13.dp)
        Text(text, style = SoberType.caption(), color = SoberColors.textSecondary)
    }
}

@Composable
private fun InsetScope.CheckInEditor(
    day: LocalDate,
    draftMood: Int?,
    draftNote: String,
    onMood: (Int?) -> Unit,
    onNote: (String) -> Unit,
    onRequestSlip: () -> Unit,
) {
    val store = LocalGraph.current.store
    val existing = store.checkIn(day)
    if (existing != null && existing.wasLogged) {
        Item {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
                SymbolIcon(
                    if (existing.wasSober) "checkmark.circle.fill" else "exclamationmark.triangle.fill",
                    if (existing.wasSober) SoberColors.success else SoberColors.danger, 20.dp, Modifier.width(28.dp),
                )
                Text(if (existing.wasSober) "Logged sober" else "Logged a slip", style = SoberType.body(), color = SoberColors.textPrimary)
            }
        }
    } else if (existing != null) {
        Item { Text("Counted toward your journey. Not checked in yet.", style = SoberType.body(), color = SoberColors.textSecondary) }
    }
    Item {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Mood", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
            MoodPicker(draftMood, iconSize = 22) { mood ->
                onMood(mood)
                if (existing != null) store.editCheckIn(day, mood, existing.note)
            }
        }
    }
    Item {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Note", style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
            PlainTextField(draftNote, { value ->
                onNote(value)
                if (existing != null) store.editCheckIn(day, store.checkIn(day)?.mood, value.ifEmpty { null })
            }, "How did the day go?")
        }
    }
    if (existing != null && existing.wasLogged) {
        if (existing.wasSober) {
            Item(onClick = onRequestSlip) { ActionLabel("arrow.left.arrow.right", "Change to slip", SoberColors.danger) }
            Item(onClick = { store.deleteCheckIn(day) }) { ActionLabel("trash", "Delete log", SoberColors.danger) }
        } else if (store.canUndoSlip(day)) {
            Item(onClick = { store.undoSlip(day, draftMood, draftNote.trim().ifEmpty { null }) }) {
                ActionLabel("arrow.uturn.backward", "Change to sober", SoberColors.brandPrimary)
            }
            Item { Text("Puts your counter and your tree back the way they were before this slip.", style = SoberType.caption(), color = SoberColors.textSecondary) }
        } else {
            Item { Text("A slip can only be taken back while it's the most recent one on your record.", style = SoberType.caption(), color = SoberColors.textSecondary) }
        }
    } else {
        Item(onClick = { store.logCheckIn(day, true, draftMood, draftNote.trim().ifEmpty { null }) }, modifier = Modifier.testTagCompat("timeline.logSober")) {
            ActionLabel("checkmark.circle", "Log as sober", SoberColors.brandPrimary)
        }
        Item(onClick = onRequestSlip, modifier = Modifier.testTagCompat("timeline.logSlip")) {
            ActionLabel("exclamationmark.triangle", "Log a slip", SoberColors.danger)
        }
    }
}

@Composable
private fun ActionLabel(icon: String, text: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        SymbolIcon(icon, color, 20.dp)
        Text(text, style = SoberType.body(), color = color)
    }
}

@Suppress("unused")
private fun daysBetween(a: LocalDate, b: LocalDate) = ChronoUnit.DAYS.between(a, b)

@Suppress("unused")
private val divider: @Composable () -> Unit = { Hairline(Modifier.fillMaxHeight()) }
