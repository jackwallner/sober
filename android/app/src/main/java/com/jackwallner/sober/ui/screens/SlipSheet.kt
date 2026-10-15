package com.jackwallner.sober.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.data.SlipOutcome
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.DateRow
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.PlainTextField
import com.jackwallner.sober.ui.theme.PrimaryCapsule
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.navBarPadding
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.LocalDate

/**
 * What happens the morning after: the same bookkeeping as a reset, with what
 * survives (most of the tree, past streaks, every counted day) shown before
 * the user commits.
 */
@Composable
fun SlipSheet(currentStreakDays: Int, onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val today = store.today
    var day by rememberSaveable { mutableStateOf(today.toString()) }
    var note by rememberSaveable { mutableStateOf("") }
    var recorded by remember { mutableStateOf<SlipOutcome?>(null) }
    val selected = LocalDate.parse(day)
    val earliest = today.minusDays(maxOf(0, currentStreakDays - 1).toLong())

    recorded?.let { outcome ->
        Confirmation(outcome, onClose)
        return
    }

    val carryover = store.previewCarryover(selected)
    Column(Modifier.fillMaxSize()) {
        SheetBar("Log a slip", leading = { TextAction("Cancel", onClick = onClose) })
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(navBarPadding(8.dp)).padding(top = 8.dp)) {
            InsetSection {
                Item {
                    Text(
                        "It's okay. A slip is part of a lot of journeys, and logging it keeps the rest of your record honest.",
                        style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.padding(vertical = Space.xs),
                    )
                }
            }
            InsetSection("When") {
                Item { DateRow("Day", selected, earliest..today, tag = "slip.day") { day = it.toString() } }
            }
            InsetSection("Anything you want to remember") {
                Item { PlainTextField(note, { note = it }, "What was going on?") }
            }
            InsetSection(
                "What you keep",
                footer = "Your counter restarts after the slip. A slip today starts day 1; for a past slip, the days since then are counted. Your longest streak reflects the corrected dates.",
            ) {
                Item { KeepRow("leaf.fill", "Your tree keeps $carryover day${if (carryover == 1) "" else "s"} of growth") }
                Item { KeepRow("flag.fill", "Your past streaks stay on your record") }
                Item { KeepRow("calendar", "Every sober day you've counted still counts") }
            }
            InsetSection {
                Item(onClick = {
                    recorded = store.recordSlip(selected, note = note.trim().ifEmpty { null })
                }, modifier = Modifier.testTagCompat("slip.log")) {
                    Text(
                        "Log it and keep going",
                        style = SoberType.body(FontWeight.SemiBold),
                        color = SoberColors.brandPrimary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun KeepRow(icon: String, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(28.dp))
        Text(text, style = SoberType.subhead(), color = SoberColors.textPrimary)
    }
}

@Composable
private fun Confirmation(outcome: SlipOutcome, onClose: () -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(Space.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Space.l),
    ) {
        Spacer(Modifier.weight(1f))
        SymbolIcon("leaf.fill", SoberColors.brandPrimary, 44.dp)
        Text("Logged. You're still on the journey.", style = SoberType.title(), color = SoberColors.textPrimary, textAlign = TextAlign.Center)
        Text(
            if (outcome.carryoverDays > 0) {
                "Your counter starts again, but your tree kept ${outcome.carryoverDays} day${if (outcome.carryoverDays == 1) "" else "s"} of growth from the ${outcome.previousStreakDays}-day run behind it."
            } else {
                "Your counter starts again. Everything you've logged is still counted."
            },
            style = SoberType.body(), color = SoberColors.textSecondary, textAlign = TextAlign.Center,
        )
        Spacer(Modifier.weight(1f))
        Box(Modifier.fillMaxWidth()) { PrimaryCapsule("Done", tag = "slip.done", onClick = onClose) }
    }
}
