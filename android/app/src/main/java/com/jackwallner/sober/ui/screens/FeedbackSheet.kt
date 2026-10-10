package com.jackwallner.sober.ui.screens

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jackwallner.sober.data.StoreLinks
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.theme.PlainTextField
import com.jackwallner.sober.ui.theme.PrimaryCapsule
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.card

/**
 * The feedback step of the iOS review prompt, on its own: Google forbids a
 * sentiment question before the Play review card, so feedback is a row.
 */
@Composable
fun FeedbackSheet(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val context = LocalContext.current
    var text by remember { mutableStateOf("") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    Column(Modifier.fillMaxSize()) {
        SheetBar("Help us improve", leading = { TextAction("Not now", onClick = onClose) })
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("What would make Sober work better for you?", style = SoberType.subhead(), color = SoberColors.textSecondary)
            PlainTextField(
                text, { text = it }, "",
                minLines = 6, maxLines = 12,
                modifier = Modifier.fillMaxWidth().heightIn(min = 140.dp).card(SoberColors.cardSurface, 12.dp, null).padding(10.dp).focusRequester(focus),
            )
            Text("Opens your mail app with a draft to the developer. No analytics, just your words.", style = SoberType.caption(), color = SoberColors.textSecondary)
            PrimaryCapsule("Send feedback", enabled = text.isNotBlank(), tag = "feedback.send") {
                val trimmed = text.trim()
                if (trimmed.isEmpty()) return@PrimaryCapsule
                graph.review.markFeedbackSubmitted()
                runCatching { context.startActivity(Intent(Intent.ACTION_SENDTO, StoreLinks.feedbackMail(trimmed)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                onClose()
            }
        }
    }
}
