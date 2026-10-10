package com.jackwallner.sober.ui.screens

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.jackwallner.sober.BuildConfig
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.data.PitchPolicy
import com.jackwallner.sober.data.StoreLinks
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.openUrl
import com.jackwallner.sober.ui.theme.BorderedButton
import com.jackwallner.sober.ui.theme.DateRow
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.SheetHeight
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberSheet
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.StepperRow
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.ToggleRow
import com.jackwallner.sober.ui.theme.navBarPadding
import com.jackwallner.sober.ui.theme.testTagCompat
import kotlinx.coroutines.launch

/** `SettingsView`, plus the Play rows Android needs (manage, rate, feedback). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SettingsScreen(onClose: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val notifications = graph.notifications
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val settings = store.settings
    val isPro = subscriptions.isPro
    var restoreMessage by remember { mutableStateOf<String?>(null) }
    var isRestoring by remember { mutableStateOf(false) }
    var denied by remember { mutableStateOf(notifications.isDenied) }
    var showFeedback by remember { mutableStateOf(false) }
    var showReviewCode by remember { mutableStateOf(false) }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        // Re-check on return from system settings so the warning clears once allowed.
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) denied = notifications.isDenied }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    fun rescheduleReminder() {
        val s = store.settings
        val streak = store.days
        scope.launch {
            if (s.dailyReminderEnabled) {
                notifications.ensureAuthorized()
                denied = notifications.isDenied
                notifications.scheduleDailyReminder(s.dailyReminderHour, s.madeCommitment, streak)
                graph.content.achievements.firstOrNull { it.kind == "timeMilestone" && streak < it.dayThreshold }?.let {
                    notifications.scheduleMilestoneEve(streak, it.dayThreshold, it.title, s.dailyReminderHour)
                }
                notifications.scheduleLapseNudge(streak)
            } else {
                notifications.cancelDailyReminder()
                notifications.cancelRetentionNudges()
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        SheetBar("Settings", trailing = { TextAction("Done", style = SoberType.body(FontWeight.SemiBold), onClick = onClose) })
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(navBarPadding(8.dp)).padding(top = 8.dp)) {
            InsetSection("Bloom+") {
                Item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        SymbolIcon("crown.fill", if (isPro) SoberColors.brandPrimary else SoberColors.textSecondary, 20.dp)
                        Spacer(Modifier.width(8.dp))
                        Text(if (isPro) "Bloom+ active" else "Bloom+", style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
                        if (!isPro) {
                            BorderedButton("Upgrade", small = true, modifier = Modifier.testTagCompat("settings.upgrade")) {
                                graph.coordinator.request(PitchIntent.SETTINGS, PitchPolicy.EXPLICIT_UPGRADE)
                            }
                        }
                    }
                }
                Item(onClick = if (isRestoring) null else ({
                    restoreMessage = null
                    isRestoring = true
                    scope.launch {
                        subscriptions.restorePurchases()
                        isRestoring = false
                        if (!subscriptions.isPro) restoreMessage = subscriptions.lastError ?: "No active Bloom+ purchase found for this Google Play account."
                    }
                })) {
                    Text(if (isRestoring) "Restoring…" else "Restore Purchases", style = SoberType.body(), color = SoberColors.brandPrimary)
                }
                subscriptions.activeProductId?.let { productId ->
                    Item(onClick = { context.openUrl(StoreLinks.manageSubscriptionURL(productId)) }) {
                        Text("Manage subscription", style = SoberType.body(), color = SoberColors.brandPrimary)
                    }
                }
                restoreMessage?.let { message ->
                    Item { Text(message, style = SoberType.caption(), color = SoberColors.textSecondary) }
                }
            }
            store.activeStart?.let { start ->
                val zone = graph.clock.zone()
                InsetSection("Sobriety Start", footer = "Adjust the date your journey began.") {
                    Item {
                        DateRow("Start", start.atZone(zone).toLocalDate(), java.time.LocalDate.of(1970, 1, 1)..store.today, tag = "settings.start") { picked ->
                            val time = start.atZone(zone).toLocalTime()
                            store.changeStart(picked.atTime(time).atZone(zone).toInstant())
                        }
                    }
                }
            }
            InsetSection(
                "Your pledge",
                footer = if (settings.madeCommitment) "Reminders are framed around your pledge." else "Reminders stay neutral and pressure-free.",
            ) {
                Item {
                    ToggleRow("I'm committing to this", settings.madeCommitment) { value ->
                        store.updateSettings { it.copy(madeCommitment = value) }
                        rescheduleReminder()
                    }
                }
            }
            InsetSection(
                "Daily Reminder",
                footer = if (settings.dailyReminderEnabled && denied) {
                    "Notifications are turned off for Sober, so the reminder can't be delivered. Tap above to enable them in Android settings."
                } else null,
            ) {
                Item {
                    ToggleRow("Enabled", settings.dailyReminderEnabled, tag = "settings.reminderToggle") { value ->
                        store.updateSettings { it.copy(dailyReminderEnabled = value) }
                        rescheduleReminder()
                    }
                }
                Item {
                    StepperRow(
                        label = { Text("Hour: ${settings.dailyReminderHour}:00", style = SoberType.body(), color = SoberColors.textPrimary) },
                        canDecrement = settings.dailyReminderHour > 0,
                        canIncrement = settings.dailyReminderHour < 23,
                        onDecrement = {
                            store.updateSettings { it.copy(dailyReminderHour = it.dailyReminderHour - 1) }
                            rescheduleReminder()
                        },
                        onIncrement = {
                            store.updateSettings { it.copy(dailyReminderHour = it.dailyReminderHour + 1) }
                            rescheduleReminder()
                        },
                        decrementLabel = "Earlier hour",
                        incrementLabel = "Later hour",
                    )
                }
                if (settings.dailyReminderEnabled && denied) {
                    Item(onClick = {
                        context.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                        )
                    }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            SymbolIcon("bell.slash.fill", SoberColors.brandPrimary, 18.dp)
                            Spacer(Modifier.width(8.dp))
                            Text("Allow notifications in Settings", style = SoberType.body(), color = SoberColors.brandPrimary)
                        }
                    }
                }
            }
            InsetSection("Cost & Calories", footer = "Used to estimate money and calories saved while you stay sober.") {
                Item {
                    StepperRow(
                        label = {
                            Text("Cost per day", style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
                            Text(Format.currencyFromCents(settings.costPerDayCents), style = SoberType.body(), color = SoberColors.textSecondary)
                        },
                        canDecrement = settings.costPerDayCents > 0,
                        canIncrement = settings.costPerDayCents < 20_000,
                        onDecrement = { store.updateSettings { it.copy(costPerDayCents = maxOf(0, it.costPerDayCents - 100)) } },
                        onIncrement = { store.updateSettings { it.copy(costPerDayCents = minOf(20_000, it.costPerDayCents + 100)) } },
                        decrementLabel = "Lower cost per day",
                        incrementLabel = "Raise cost per day",
                    )
                }
                Item {
                    StepperRow(
                        label = {
                            Text("Calories per day", style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
                            Text("${settings.caloriesPerDay} cal", style = SoberType.body(), color = SoberColors.textSecondary)
                        },
                        canDecrement = settings.caloriesPerDay > 0,
                        canIncrement = settings.caloriesPerDay < 3_000,
                        onDecrement = { store.updateSettings { it.copy(caloriesPerDay = maxOf(0, it.caloriesPerDay - 50)) } },
                        onIncrement = { store.updateSettings { it.copy(caloriesPerDay = minOf(3_000, it.caloriesPerDay + 50)) } },
                        decrementLabel = "Fewer calories per day",
                        incrementLabel = "More calories per day",
                    )
                }
            }
            InsetSection(
                "If you need support",
                footer = "Free, confidential help is available any time. Reaching out is a strength, not a setback.",
            ) {
                Item(onClick = { context.openUrl("tel:988") }) { ResourceRow("phone.fill", "988 Suicide & Crisis Lifeline", "Call or text 988 · 24/7 · US") }
                Item(onClick = { context.openUrl("tel:18006624357") }) { ResourceRow("cross.case.fill", "SAMHSA National Helpline", "1-800-662-HELP · Free, confidential, 24/7") }
                Item(onClick = { context.openUrl("https://findtreatment.gov") }) { ResourceRow("magnifyingglass", "Find Treatment", "findtreatment.gov") }
            }
            InsetSection("Help") {
                Item(onClick = { context.openUrl("mailto:${StoreLinks.SUPPORT_EMAIL}") }) {
                    ResourceRow("envelope.fill", "Contact Support", "Questions or trouble? Reach out.")
                }
                Item(onClick = {
                    graph.review.markOpenedWriteReview()
                    runCatching {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(StoreLinks.PLAY_MARKET_URI)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }.onFailure { context.openUrl(StoreLinks.PLAY_LISTING_URL) }
                }) {
                    Text("Rate on Google Play", style = SoberType.body(), color = SoberColors.brandPrimary)
                }
                Item(onClick = { showFeedback = true }) {
                    Text("Send Feedback", style = SoberType.body(), color = SoberColors.brandPrimary)
                }
            }
            InsetSection("Legal") {
                Item(onClick = { context.openUrl(StoreLinks.PRIVACY_URL) }) { Text("Privacy Policy", style = SoberType.body(), color = SoberColors.brandPrimary) }
                Item(onClick = { context.openUrl(StoreLinks.TERMS_URL) }) { Text("Terms of Use", style = SoberType.body(), color = SoberColors.brandPrimary) }
            }
            InsetSection("About") {
                Item {
                    Row(
                        Modifier.fillMaxWidth()
                            .testTagCompat("settings.version")
                            // Play reviewers reach Bloom+ here without paying (private code in the review notes).
                            .combinedClickable(onClick = {}, onLongClick = { showReviewCode = true }),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Version", style = SoberType.body(), color = SoberColors.textPrimary, modifier = Modifier.weight(1f))
                        Text(BuildConfig.VERSION_NAME, style = SoberType.body(), color = SoberColors.textSecondary)
                    }
                }
            }
            if (BuildConfig.DEBUG) {
                InsetSection("Developer") {
                    Item(onClick = { subscriptions.setLocalOverride(!subscriptions.isPro) }) {
                        Text(if (isPro) "Disable Bloom+ override" else "Enable Bloom+ override", style = SoberType.body(), color = SoberColors.brandPrimary)
                    }
                }
            }
        }
    }

    SoberSheet(showFeedback, onDismiss = { showFeedback = false }, height = SheetHeight.LARGE) {
        FeedbackSheet(onClose = { showFeedback = false })
    }
    if (showReviewCode) ReviewCodeDialog(onClose = { showReviewCode = false })
}

@Composable
private fun ResourceRow(icon: String, title: String, subtitle: String) {
    Row(
        Modifier.semantics(mergeDescendants = true) { contentDescription = "$title. $subtitle" },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SymbolIcon(icon, SoberColors.brandPrimary, 20.dp, Modifier.width(26.dp))
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, style = SoberType.body(), color = SoberColors.textPrimary)
            Text(subtitle, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
    }
}

/** A wrong code never grants anything; a right one persists like a purchase. */
@Composable
private fun ReviewCodeDialog(onClose: () -> Unit) {
    val subscriptions = LocalGraph.current.subscriptions
    var code by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onClose,
        containerColor = SoberColors.cardSurface,
        title = { Text("Reviewer access", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary) },
        text = {
            OutlinedTextField(
                value = code,
                onValueChange = {
                    code = it
                    failed = false
                },
                singleLine = true,
                label = { Text(if (failed) "That code didn't work" else "Code", style = SoberType.caption()) },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                isError = failed,
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = SoberColors.brandPrimary, cursorColor = SoberColors.brandPrimary),
                modifier = Modifier.testTagCompat("settings.reviewCode"),
            )
        },
        confirmButton = {
            TextButton(onClick = { if (subscriptions.activateReviewAccess(code)) onClose() else failed = true }) {
                Text("Unlock", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.brandPrimary)
            }
        },
        dismissButton = { TextButton(onClick = onClose) { Text("Cancel", style = SoberType.body(), color = SoberColors.brandPrimary) } },
    )
}
