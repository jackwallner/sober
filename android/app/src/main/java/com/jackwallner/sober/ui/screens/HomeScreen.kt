package com.jackwallner.sober.ui.screens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.jackwallner.sober.DebugLaunchOptions
import com.jackwallner.sober.data.PitchIntent
import com.jackwallner.sober.data.PitchPolicy
import com.jackwallner.sober.data.TrialSubsequentPitchGate
import com.jackwallner.sober.model.BonsaiStage
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.model.GardenGrowth
import com.jackwallner.sober.model.GrowthEvent
import com.jackwallner.sober.model.TendedWeek
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.launchPlayReview
import com.jackwallner.sober.ui.theme.BarIcon
import com.jackwallner.sober.ui.theme.BorderedButton
import com.jackwallner.sober.ui.theme.InsetSection
import com.jackwallner.sober.ui.theme.PlainTextField
import com.jackwallner.sober.ui.theme.SheetBar
import com.jackwallner.sober.ui.theme.TextAction
import com.jackwallner.sober.ui.theme.SheetHeight
import com.jackwallner.sober.ui.theme.SoberAlert
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberGeo
import com.jackwallner.sober.ui.theme.SoberSheet
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.capsule
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.softShadow
import com.jackwallner.sober.ui.theme.testTagCompat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Home: the garden is the home. The day counter, check-in, and the craving
 * button sit around the bonsai; everything longer-horizon is one tap away.
 */
@Composable
fun HomeScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current
    var dayRefresh by remember { mutableIntStateOf(0) }
    var hasRefreshed by remember { mutableStateOf(false) }
    val state = store.state
    val isPro = subscriptions.isPro

    var showResetAlert by remember { mutableStateOf(false) }
    var showSlip by rememberSaveable { mutableStateOf(false) }
    var showCraving by rememberSaveable { mutableStateOf(false) }
    var pendingCravingOutcome by remember { mutableStateOf<CravingOutcome?>(null) }
    var showSettings by rememberSaveable { mutableStateOf(false) }
    var showCustomize by rememberSaveable { mutableStateOf(false) }
    var showProgress by rememberSaveable { mutableStateOf(DebugLaunchOptions.showProgress) }
    var growthEvent by remember { mutableStateOf<GrowthEvent?>(null) }
    var showCheckInDetail by remember { mutableStateOf(false) }
    var menuOpen by remember { mutableStateOf(false) }
    var reviewShownThisSession by remember { mutableStateOf(false) }
    var postOnboardingScheduled by remember { mutableStateOf(false) }
    var showTrialRecap by remember { mutableStateOf(false) }

    val days = store.days
    val treeDays = store.treeDays
    val dayInCycle = GardenGrowth.cycle(treeDays).dayInCycle
    val stage = GardenGrowth.stage(treeDays)
    val checkedInToday = store.hasCheckedIn()
    val todayHasNote = !store.todayDetail().second.isNullOrEmpty()
    val todayWasSlip = store.loggedSlip()
    val daysMissed = store.daysSinceLastCheckIn()
    val week = TendedWeek.days(store.today, state.checkIns)
    val showGrowth = growthEvent != null
    val isTimeMilestoneDay = days > 0 && graph.content.achievements.any { it.kind == "timeMilestone" && it.dayThreshold == days }

    fun scheduleReviewAfterPositiveMoment() {
        if (!graph.review.shouldShowAfterPositiveMoment(store.hasCompletedOnboarding) || reviewShownThisSession || showGrowth || showCheckInDetail) return
        scope.launch {
            delay(3_500)
            if (growthEvent != null || showCheckInDetail || graph.coordinator.isPresentingSheet || graph.coordinator.pendingRequest != null) return@launch
            if (!graph.review.shouldShowAfterPositiveMoment(store.hasCompletedOnboarding)) return@launch
            reviewShownThisSession = true
            graph.review.markShown()
            context.launchPlayReview()
        }
    }

    fun recordPositiveMoment(isMilestone: Boolean = false) {
        graph.review.recordPositiveMoment(isMilestone)
        scheduleReviewAfterPositiveMoment()
    }

    fun scheduleRetentionNudges() {
        val settings = store.settings
        if (!settings.dailyReminderEnabled) return
        graph.notifications.scheduleLapseNudge(store.days)
        val next = graph.content.achievements.firstOrNull { it.kind == "timeMilestone" && store.days < it.dayThreshold }
        if (next != null) graph.notifications.scheduleMilestoneEve(store.days, next.dayThreshold, next.title, settings.dailyReminderHour)
        else graph.notifications.cancelMilestoneEve()
    }

    fun recordCheckInForTrialPitch() {
        if (subscriptions.isPro) return
        val count = graph.pitchGate.incrementPersistedCount(TrialSubsequentPitchGate.CHECK_IN_COMPLETED_COUNT_KEY)
        scope.launch { graph.pitches.usageBased(PitchIntent.CHECK_IN_MILESTONE, count, threshold = 3, delaySeconds = 2.5) }
    }

    fun presentPostOnboardingPaywallIfNeeded() {
        if (!graph.defaults.getBoolean(TrialSubsequentPitchGate.POST_ONBOARDING_PAYWALL_KEY)) return
        if (subscriptions.isPro) {
            graph.defaults.putBoolean(TrialSubsequentPitchGate.POST_ONBOARDING_PAYWALL_KEY, false)
            return
        }
        if (growthEvent != null || postOnboardingScheduled) return
        postOnboardingScheduled = true
        scope.launch {
            delay(700)
            postOnboardingScheduled = false
            if (growthEvent != null) return@launch
            graph.defaults.putBoolean(TrialSubsequentPitchGate.POST_ONBOARDING_PAYWALL_KEY, false)
            graph.nudges.markShown()
            graph.coordinator.request(PitchIntent.POST_ONBOARDING, PitchPolicy.INITIAL)
        }
    }

    fun handleCravingFinished(outcome: CravingOutcome) {
        graph.refreshWidgets()
        if (outcome == CravingOutcome.GAVE_IN && !store.loggedSlip()) showSlip = true
        if (outcome != CravingOutcome.RODE_IT_OUT) return
        recordPositiveMoment()
        if (subscriptions.isPro) return
        val count = graph.pitchGate.incrementPersistedCount(TrialSubsequentPitchGate.CRAVING_RODE_OUT_COUNT_KEY)
        scope.launch { graph.pitches.usageBased(PitchIntent.CRAVING_RELIEF, count, threshold = 2, delaySeconds = 3.0) }
    }

    DisposableEffect(context, lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) dayRefresh++
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                dayRefresh++
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            context.unregisterReceiver(receiver)
        }
    }
    LaunchedEffect(dayRefresh) {
        store.refresh(applyDecay = !hasRefreshed)
        hasRefreshed = true
        store.processGrowth()?.let { growthEvent = it }
        val settings = store.settings
        if (settings.dailyReminderEnabled) graph.notifications.refreshDailyReminder(settings.dailyReminderHour, settings.madeCommitment, store.days)
        scheduleRetentionNudges()
        val cents = settings.costPerDayCents
        val parts = mutableListOf("${store.days} sober ${if (store.days == 1) "day" else "days"}")
        if (cents > 0) parts += "${Format.currency(store.days * cents / 100.0)} saved"
        graph.trial.recapSummary = parts.joinToString(" and ") + " so far."
        showTrialRecap = graph.trial.shouldShowRecap()
        graph.refreshWidgets()
    }
    LaunchedEffect(Unit) { presentPostOnboardingPaywallIfNeeded() }
    LaunchedEffect(Unit) { graph.pitches.passiveNudge(PitchIntent.POST_ONBOARDING, delaySeconds = 6.0) }

    Box(Modifier.fillMaxSize().background(SoberColors.background)) {
        if (!showGrowth) {
            Column(Modifier.fillMaxSize()) {
                // Inline bar: Progress on the leading edge, the More menu trailing.
                Row(
                    Modifier.fillMaxWidth().statusBarsPadding().height(48.dp).padding(horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    BarIcon("chart.line.uptrend.xyaxis", "Progress", tag = "home.progress") { showProgress = true }
                    Spacer(Modifier.weight(1f))
                    Box {
                        BarIcon("ellipsis.circle", "More", tag = "home.more") { menuOpen = true }
                        HomeMenu(
                            expanded = menuOpen,
                            onDismiss = { menuOpen = false },
                            onCustomize = { showCustomize = true },
                            onSettings = { showSettings = true },
                            onSlip = { showSlip = true },
                            onReset = { showResetAlert = true },
                        )
                    }
                }
                BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                    var gardenMin = (246 + (if (stage == BonsaiStage.SEED) 0 else 60) + minOf(120, state.garden.completedTreeStyles.size * 16)).dp
                    // Home does not scroll on iOS. A short phone gives the garden what is left (down to a
                    // 150dp floor) and only scrolls when even that would clip the controls.
                    val reserved = 305.dp + (if (showTrialRecap) 90.dp else 0.dp)
                    val roomy = maxHeight >= gardenMin + reserved
                    val fits = maxHeight >= 150.dp + reserved
                    if (!roomy && fits) gardenMin = 150.dp
                    val column = if (fits) Modifier.fillMaxSize() else Modifier.fillMaxWidth().verticalScroll(rememberScrollState())
                    Column(
                        column.padding(horizontal = Space.l).padding(top = Space.s, bottom = Space.m),
                        verticalArrangement = Arrangement.spacedBy(Space.l),
                    ) {
                        if (showTrialRecap) {
                            TrialRecapBanner(graph.trial.daysRemaining() ?: 1, graph.trial.recapSummary) {
                                graph.trial.dismissRecap()
                                showTrialRecap = false
                            }
                        }
                        CounterHeader(days, store.longestStreakDays, store.lifetimeSoberDays)
                        val gardenModifier = if (fits) Modifier.weight(1f).heightIn(min = gardenMin) else Modifier.height(gardenMin)
                        PannableGarden(
                            days = treeDays,
                            vitality = state.garden.vitality,
                            activeStyleId = state.garden.speciesId,
                            isPro = isPro,
                            completedTreeStyles = state.garden.completedTreeStyles,
                            modifier = gardenModifier.fillMaxWidth()
                                .softShadow(Color.Black.copy(alpha = 0.06f), 12.dp, 4.dp, SoberGeo.cardRadius)
                                .card(Color.Transparent, SoberGeo.cardRadius),
                            onSwapBonsai = { showCustomize = true },
                        )
                        CheckInControl(
                            checkedInToday = checkedInToday,
                            todayHasNote = todayHasNote,
                            todayWasSlip = todayWasSlip,
                            daysMissed = daysMissed,
                            week = week,
                            onStillSober = {
                                store.backfillAndWater()
                                recordPositiveMoment(isTimeMilestoneDay)
                                scheduleRetentionNudges()
                                recordCheckInForTrialPitch()
                            },
                            onSlipped = { showSlip = true },
                            onAddNote = { showCheckInDetail = true },
                            onCheckIn = {
                                store.checkInToday()
                                recordPositiveMoment(isTimeMilestoneDay)
                                scheduleRetentionNudges()
                                recordCheckInForTrialPitch()
                                showCheckInDetail = true
                            },
                        )
                        CravingControl(graph.content.words.urge) { showCraving = true }
                    }
                }
            }
        }
        AnimatedVisibility(showGrowth, enter = fadeIn(), exit = fadeOut()) {
            growthEvent?.let { event ->
                GrowthCelebration(
                    event = event,
                    style = bonsaiStyleFor(state.garden.speciesId),
                    dayInCycle = dayInCycle,
                    stageMessage = { graph.content.stageMessages[it] ?: "" },
                ) {
                    growthEvent = null
                    graph.refreshWidgets()
                    recordPositiveMoment(isMilestone = true)
                    presentPostOnboardingPaywallIfNeeded()
                    if (!subscriptions.isPro) {
                        val count = graph.pitchGate.incrementPersistedCount(TrialSubsequentPitchGate.GROWTH_CELEBRATION_COUNT_KEY)
                        scope.launch { graph.pitches.usageBased(PitchIntent.GROWTH_CELEBRATION, count, delaySeconds = 1.5) }
                    }
                }
            }
        }
    }

    if (showResetAlert) {
        SoberAlert(
            title = "Reset sobriety counter?",
            message = "Your day counter will restart at day 1. Your history is kept.",
            confirmTitle = "Reset",
            dismissTitle = "Cancel",
            destructive = true,
            onConfirm = {
                showResetAlert = false
                store.resetCounter()
            },
            onDismiss = { showResetAlert = false },
        )
    }

    SoberSheet(showCheckInDetail, onDismiss = { showCheckInDetail = false }, height = SheetHeight.COMPACT) {
        CheckInDetailSheet(onClose = { showCheckInDetail = false })
    }
    SoberSheet(showSettings, onDismiss = { showSettings = false }) {
        SettingsScreen(onClose = { showSettings = false })
    }
    SoberSheet(showSlip, onDismiss = { showSlip = false }) {
        SlipSheet(currentStreakDays = days, onClose = { showSlip = false })
    }
    SoberSheet(
        showCraving,
        onDismiss = { showCraving = false },
        height = SheetHeight.FULL,
        dismissible = false,
    ) {
        CravingModeScreen(
            onFinish = { pendingCravingOutcome = it },
            onClose = {
                showCraving = false
                pendingCravingOutcome?.let {
                    pendingCravingOutcome = null
                    scope.launch {
                        // Present follow-ups after the cover has gone, as iOS does on dismiss.
                        delay(350)
                        handleCravingFinished(it)
                    }
                }
            },
        )
    }
    SoberSheet(showCustomize, onDismiss = { showCustomize = false }) {
        GardenCustomizationSheet(onClose = { showCustomize = false })
    }
    SoberSheet(showProgress, onDismiss = { showProgress = false }) {
        ProgressSheet(onClose = { showProgress = false })
    }
}

@Composable
private fun HomeMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    onCustomize: () -> Unit,
    onSettings: () -> Unit,
    onSlip: () -> Unit,
    onReset: () -> Unit,
) {
    DropdownMenu(expanded, onDismissRequest = onDismiss, containerColor = SoberColors.cardSurface) {
        @Composable
        fun item(title: String, icon: String, tag: String, color: Color = SoberColors.textPrimary, action: () -> Unit) {
            DropdownMenuItem(
                text = { Text(title, style = SoberType.body(), color = color) },
                trailingIcon = { SymbolIcon(icon, color, 20.dp) },
                modifier = Modifier.testTagCompat(tag),
                onClick = {
                    onDismiss()
                    action()
                },
            )
        }
        item("Customize garden", "paintbrush.pointed", "menu.customize", action = onCustomize)
        item("Settings", "gearshape", "menu.settings", action = onSettings)
        HorizontalDivider(color = SoberColors.ringTrack)
        // A slip is an ordinary entry; the destructive item is for a counter set up wrong.
        item("I slipped", "arrow.uturn.backward", "menu.slip", action = onSlip)
        item("Reset counter", "arrow.counterclockwise", "menu.reset", SoberColors.danger, onReset)
    }
}

@Composable
private fun CounterHeader(days: Int, bestStreak: Int, lifetimeSoberDays: Int) {
    val history = if (bestStreak > days || lifetimeSoberDays > days) {
        listOfNotNull(
            "Best $bestStreak".takeIf { bestStreak > days },
            "$lifetimeSoberDays days sober".takeIf { lifetimeSoberDays > days },
        ).joinToString(" · ")
    } else null
    Column(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {
            contentDescription = "$days ${if (days == 1) "day" else "days"} sober" + (history?.let { ". $it" } ?: "")
        },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("$days", style = SoberType.bigNumber(80.sp), color = SoberColors.brandPrimary, maxLines = 1, modifier = Modifier.testTagCompat("home.dayCount"))
        Text(
            (if (days == 1) "Day Sober" else "Days Sober").uppercase(),
            style = SoberType.serif(13.sp, FontWeight.SemiBold).copy(letterSpacing = 2.sp),
            color = SoberColors.textSecondary,
        )
        if (history != null) {
            Text(history, style = SoberType.caption(), color = SoberColors.textTertiary, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
private fun TrialRecapBanner(remaining: Int, summary: String?, onDismiss: () -> Unit) {
    val detail = summary?.let { "$it Cancel any time in Google Play." }
        ?: "Keep your full garden, journal, and savings, or cancel any time in Google Play."
    Row(
        Modifier.fillMaxWidth().card(SoberColors.cardSurface, 16.dp, SoberColors.brandPrimary.copy(alpha = 0.28f)).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        SymbolIcon("sparkles", SoberColors.brandPrimary, 24.dp, Modifier.width(28.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                when (remaining) {
                    0 -> "Your Bloom+ trial ends today"
                    1 -> "Your Bloom+ trial ends tomorrow"
                    else -> "Your Bloom+ trial ends in $remaining days"
                },
                style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary,
            )
            Text(detail, style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        BorderedButton("Got it", small = true, onClick = onDismiss)
    }
}

@Composable
private fun CheckInControl(
    checkedInToday: Boolean,
    todayHasNote: Boolean,
    todayWasSlip: Boolean,
    daysMissed: Int,
    week: List<com.jackwallner.sober.model.TendedDay>,
    onStillSober: () -> Unit,
    onSlipped: () -> Unit,
    onAddNote: () -> Unit,
    onCheckIn: () -> Unit,
) {
    when {
        !checkedInToday && daysMissed > 1 -> Column(
            Modifier.fillMaxWidth().card(SoberColors.cardSurface, 18.dp).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "Welcome back. You haven't checked in for $daysMissed days. Still going strong?",
                style = SoberType.subhead(), color = SoberColors.textPrimary, textAlign = TextAlign.Center,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(
                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(SoberColors.brandPrimary)
                        .testTagCompat("home.stillSober").pressable(onClick = onStillSober).padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SymbolIcon("checkmark.circle.fill", Color.White, 18.dp)
                    Spacer(Modifier.width(6.dp))
                    Text("Still sober", style = SoberType.body(FontWeight.SemiBold), color = Color.White)
                }
                BorderedButton("I slipped", tint = SoberColors.brandPrimary, onClick = onSlipped)
            }
        }
        todayWasSlip -> Row(
            Modifier.fillMaxWidth().card(SoberColors.cardSurface, 18.dp).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SymbolIcon("leaf.fill", SoberColors.brandPrimary, 26.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Today is logged as a slip", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary)
                Text("Your tree kept its growth. Day one starts now.", style = SoberType.caption(), color = SoberColors.textSecondary)
            }
        }
        checkedInToday -> Row(
            Modifier.fillMaxWidth().card(SoberColors.checkInDoneFill, 18.dp, SoberColors.brandPrimary.copy(alpha = 0.28f)).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SymbolIcon("checkmark.circle.fill", SoberColors.brandPrimary, 26.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("Today is logged", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary, modifier = Modifier.testTagCompat("home.loggedToday"))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Space.s)) {
                    WeekStrip(week)
                    Text("${TendedWeek.tendedCount(week)}/7 tended", style = SoberType.caption(), color = SoberColors.textSecondary, maxLines = 1)
                }
            }
            BorderedButton(if (todayHasNote) "Edit note" else "Add note", small = true, onClick = onAddNote)
        }
        else -> Column(
            Modifier.fillMaxWidth()
                .capsule(SoberColors.brandPrimary, Color.White.copy(alpha = 0.18f))
                .testTagCompat("home.checkIn")
                .semantics(mergeDescendants = true) { contentDescription = "Check in for today. Log today sober and water your bonsai" }
                .pressable(onClick = onCheckIn)
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SymbolIcon("drop.fill", Color.White, 18.dp)
                Text("Check in for today", style = SoberType.body(FontWeight.SemiBold), color = Color.White)
            }
            Text("Log today sober and water your bonsai", style = SoberType.caption(), color = Color.White.copy(alpha = 0.85f))
        }
    }
}

@Composable
private fun CravingControl(urge: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .capsule(SoberColors.cardSurface, SoberColors.ringTrack)
            .testTagCompat("home.craving")
            .semantics(mergeDescendants = true) { contentDescription = "I'm having a $urge" }
            .pressable(onClick = onClick)
            .padding(horizontal = Space.l, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Space.m),
    ) {
        SymbolIcon("wind", SoberColors.brandPrimary, 20.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text("I'm having a $urge", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.textPrimary)
            Text("Ride it out with a few minutes of breathing", style = SoberType.caption(), color = SoberColors.textSecondary)
        }
        SymbolIcon("chevron.right", SoberColors.textTertiary, 16.dp)
    }
}

/**
 * Optional reflection after the one-tap check-in. The day is already logged
 * and the garden watered; this only adds mood and a note.
 */
@Composable
private fun CheckInDetailSheet(onClose: () -> Unit) {
    val store = LocalGraph.current.store
    // Opens on what today already holds: an empty field here used to replace the note saved earlier in the day.
    val saved = remember { store.todayDetail() }
    var mood by remember { mutableStateOf(saved.first) }
    var note by remember { mutableStateOf(saved.second.orEmpty()) }
    Column(Modifier.fillMaxWidth()) {
        SheetBar(
            "Checked in",
            leading = { TextAction("Skip", onClick = onClose) },
            trailing = {
                TextAction("Save", style = SoberType.body(FontWeight.SemiBold)) {
                    store.addTodayDetail(mood, note)
                    onClose()
                }
            },
        )
        InsetSection("Mood") {
            Item { MoodPicker(mood, iconSize = 26) { mood = it } }
        }
        InsetSection("Note") {
            Item { PlainTextField(note, { note = it }, "Anything you want to remember about today?") }
        }
    }
}

private val moodSymbols = listOf("cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles")
private val moodLabels = listOf("Rough", "Low", "OK", "Good", "Great")

/** The 1...5 mood scale. Tapping the active mood clears it. */
@Composable
fun MoodPicker(selected: Int?, iconSize: Int = 22, onSelect: (Int?) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = Space.xs), horizontalArrangement = Arrangement.spacedBy(Space.m)) {
        (1..5).forEach { value ->
            val active = selected == value
            val tint = if (active) SoberColors.brandPrimary else SoberColors.textTertiary
            Column(
                Modifier.weight(1f)
                    .semantics(mergeDescendants = true) { contentDescription = "Mood ${moodLabels[value - 1]}" + if (active) ", selected" else "" }
                    .testTagCompat("mood.$value")
                    .pressable { onSelect(if (active) null else value) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                SymbolIcon(moodSymbols[value - 1], tint, iconSize.dp)
                Text(moodLabels[value - 1], style = SoberType.caption(FontWeight.SemiBold), color = tint)
            }
        }
    }
}
