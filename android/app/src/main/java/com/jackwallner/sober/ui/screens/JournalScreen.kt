package com.jackwallner.sober.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.content.JournalPrompt
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.data.TrialSubsequentPitchGate
import com.jackwallner.sober.model.JournalEntry
import com.jackwallner.sober.model.JournalKind
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.BarIcon
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.LargeTitle
import com.jackwallner.sober.ui.theme.PlainTextField
import com.jackwallner.sober.ui.theme.SegmentedPicker
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SheetHeight
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberSheet
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.ToggleRow
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.navBarPadding
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.ZoneId
import kotlinx.coroutines.launch

/** Free users get one real entry before the gate. */
@Composable
fun JournalScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val isPro = graph.subscriptions.isPro
    val entries = store.state.journal.sortedByDescending { it.createdAt }
    val canCompose = isPro || entries.isEmpty()
    var showCompose by rememberSaveable { mutableStateOf(false) }
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val prompt = graph.content.promptOfDay(store.today)

    fun compose() {
        if (canCompose) showCompose = true else graph.coordinator.requestLockedFeature(PitchIntent.JOURNAL)
    }

    LaunchedEffect(Unit) {
        if (graph.subscriptions.isPro) return@LaunchedEffect
        val visits = graph.pitchGate.incrementPersistedCount(TrialSubsequentPitchGate.JOURNAL_TAB_VISIT_COUNT_KEY)
        graph.pitches.usageBased(PitchIntent.JOURNAL, visits, delaySeconds = 2.0)
    }

    Column(Modifier.fillMaxSize().background(SoberColors.background).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            BarIcon("square.and.pencil", "New entry", tag = "journal.new", onClick = ::compose)
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 16.dp)) {
            LargeTitle("Journal")
            InsetSection("Prompt of the day") {
                Item {
                    Column(Modifier.padding(vertical = Space.xs), verticalArrangement = Arrangement.spacedBy(Space.s)) {
                        Text(prompt.text, style = SoberType.body(), color = SoberColors.textPrimary)
                        Row(
                            Modifier.padding(top = 2.dp).testTagCompat("journal.write").pressable(onClick = ::compose),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            SymbolIcon("square.and.pencil", SoberColors.brandPrimary, 18.dp)
                            Text("Write entry", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.brandPrimary)
                        }
                    }
                }
            }
            InsetSection("Entries") {
                if (entries.isEmpty()) {
                    Item {
                        Text(
                            if (isPro) "No entries yet. Use the pencil to write your first."
                            else "No entries yet. Your first entry is free. Use the pencil to write it.",
                            style = SoberType.subhead(), color = SoberColors.textSecondary, modifier = Modifier.padding(vertical = Space.s),
                        )
                    }
                } else {
                    entries.forEach { entry ->
                        Item(padding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                            SwipeToDelete(onDelete = { store.deleteJournalEntry(entry.id) }) {
                                EntryRow(entry, Modifier.pressable { selectedId = entry.id }.padding(horizontal = 16.dp, vertical = 11.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    SoberSheet(showCompose, onDismiss = { showCompose = false }) {
        ComposeEntrySheet(onClose = { showCompose = false })
    }
    SoberSheet(selectedId != null, onDismiss = { selectedId = null }, height = SheetHeight.MEDIUM) {
        val entry = store.state.journal.firstOrNull { it.id == selectedId }
        if (entry != null) EntryDetailSheet(entry, onClose = { selectedId = null })
    }
}

@Composable
private fun SwipeToDelete(onDelete: () -> Unit, content: @Composable () -> Unit) {
    val scope = rememberCoroutineScope()
    val state = rememberSwipeToDismissBoxState()
    LaunchedEffect(state.currentValue) {
        if (state.currentValue == SwipeToDismissBoxValue.EndToStart) {
            onDelete()
            scope.launch { state.reset() }
        }
    }
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(Modifier.fillMaxSize().background(SoberColors.danger).padding(horizontal = 20.dp), contentAlignment = Alignment.CenterEnd) {
                Text("Delete", style = SoberType.body(FontWeight.SemiBold), color = Color.White)
            }
        },
    ) {
        Box(Modifier.background(Color.White)) { content() }
    }
}

@Composable
private fun EntryRow(entry: JournalEntry, modifier: Modifier) {
    Column(modifier.fillMaxWidth().padding(vertical = Space.xs), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row {
            Text(Format.mediumDate(entry.createdAt.atZone(ZoneId.systemDefault()).toLocalDate()), style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
            Spacer(Modifier.weight(1f))
            entry.feeling?.let { Text(Format.capitalized(it), style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.brandPrimary) }
        }
        Text(entry.text, style = SoberType.body(), color = SoberColors.textPrimary, maxLines = 4, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun EntryDetailSheet(entry: JournalEntry, onClose: () -> Unit) {
    val graph = LocalGraph.current
    var editing by remember { mutableStateOf(false) }
    var edited by remember { mutableStateOf(entry.text) }
    val prompt = entry.promptId?.let { id -> graph.content.prompts.firstOrNull { it.id == id }?.text }
    Column(Modifier.fillMaxSize()) {
        SheetBar(
            if (entry.kind == JournalKind.FREEFORM) "Free Write" else "Entry",
            leading = {
                BarIcon("trash", "Delete entry", tint = SoberColors.danger) {
                    graph.store.deleteJournalEntry(entry.id)
                    onClose()
                }
                if (!editing) BarIcon("pencil", "Edit entry") {
                    edited = entry.text
                    editing = true
                }
            },
            trailing = {
                if (editing) {
                    TextAction("Save", style = SoberType.body(FontWeight.SemiBold)) {
                        val trimmed = edited.trim()
                        if (trimmed.isNotEmpty()) graph.store.putJournalEntry(entry.copy(text = trimmed), graph.subscriptions.isPro)
                        editing = false
                    }
                } else {
                    TextAction("Done", onClick = onClose)
                }
            },
        )
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Space.l), verticalArrangement = Arrangement.spacedBy(Space.m)) {
            Row {
                Text(Format.mediumDate(entry.createdAt.atZone(ZoneId.systemDefault()).toLocalDate()), style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.textSecondary)
                Spacer(Modifier.weight(1f))
                entry.feeling?.let { Text(Format.capitalized(it), style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.brandPrimary) }
            }
            prompt?.let { Text(it, style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textSecondary) }
            if (editing) {
                PlainTextField(
                    edited, { edited = it }, "", minLines = 8, maxLines = 30,
                    modifier = Modifier.heightIn(min = 200.dp).card(SoberColors.cardSurface, 12.dp, null).padding(8.dp),
                )
            } else {
                Text(entry.text, style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}

private val feelings = listOf("excellent", "good", "neutral", "tough", "rough")

@Composable
private fun ComposeEntrySheet(onClose: () -> Unit) {
    val graph = LocalGraph.current
    var text by rememberSaveable { mutableStateOf("") }
    var feeling by rememberSaveable { mutableStateOf("good") }
    var freeWrite by rememberSaveable { mutableStateOf(false) }
    var promptId by rememberSaveable { mutableStateOf(graph.content.promptOfDay(graph.store.today).id) }
    val prompt: JournalPrompt = graph.content.prompts.first { it.id == promptId }
    Column(Modifier.fillMaxSize()) {
        SheetBar(
            "New Entry",
            leading = { TextAction("Cancel", onClick = onClose) },
            trailing = {
                TextAction("Save", style = SoberType.body(FontWeight.SemiBold), enabled = text.isNotBlank()) {
                    val entry = if (freeWrite) {
                        JournalEntry(createdAt = graph.clock.now(), promptId = null, kind = JournalKind.FREEFORM, text = text, feeling = feeling)
                    } else {
                        JournalEntry(createdAt = graph.clock.now(), promptId = prompt.id, kind = prompt.kind, text = text, feeling = feeling)
                    }
                    graph.store.putJournalEntry(entry, graph.subscriptions.isPro)
                    onClose()
                }
            },
        )
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(navBarPadding(8.dp)).padding(top = 8.dp)) {
            InsetSection {
                Item { ToggleRow("Free write", freeWrite) { freeWrite = it } }
                if (!freeWrite) {
                    Item(onClick = {
                        // Avoid landing on the same prompt twice in a row.
                        promptId = graph.content.prompts.filter { it.id != promptId }.randomOrNull()?.id ?: promptId
                    }) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SymbolIcon("shuffle", SoberColors.brandPrimary, 18.dp)
                            Text("Shuffle prompt", style = SoberType.body(), color = SoberColors.brandPrimary)
                        }
                    }
                }
            }
            InsetSection(if (freeWrite) "Your entry" else prompt.text) {
                Item {
                    PlainTextField(text, { text = it }, "", minLines = 7, maxLines = 30, modifier = Modifier.heightIn(min = 180.dp).testTagCompat("journal.text"))
                }
            }
            InsetSection("Feeling") {
                Item { SegmentedPicker(feelings, feeling, label = Format::capitalized) { feeling = it } }
            }
        }
    }
}

@Suppress("unused")
private val spacer = Modifier.width(0.dp)
