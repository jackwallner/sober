package com.jackwallner.sober.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.DebugLaunchOptions
import com.jackwallner.sober.data.ConversionEvent
import com.jackwallner.sober.data.OnboardingTrialResolution
import com.jackwallner.sober.data.PitchPolicy
import com.jackwallner.sober.data.PurchaseException
import com.jackwallner.sober.data.PurchaseOutcome
import com.jackwallner.sober.data.StoreLinks
import com.jackwallner.sober.data.SubscriptionService
import com.jackwallner.sober.data.TrialSubsequentPitchGate
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.model.SpendScale
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.findActivity
import com.jackwallner.sober.ui.openUrl
import com.jackwallner.sober.ui.theme.ProgressSpinner
import com.jackwallner.sober.ui.theme.SoberAlert
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberSlider
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.Space
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.testTagCompat
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val White88 = Color.White.copy(alpha = 0.88f)

/** Phones shorter than an iPhone SE get the compact hero: smaller glyph and type. */
@Composable
private fun compactHeight(): Boolean = androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp < 700

/** `OnboardingView`: promise, start date, savings, the offer, then reminders. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen() {
    val graph = LocalGraph.current
    val store = graph.store
    val subscriptions = graph.subscriptions
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var step by rememberSaveable { mutableIntStateOf(0) }
    var startDay by rememberSaveable { mutableStateOf(graph.clock.today().toString()) }
    val spendScale = remember { SpendScale.current() }
    var costPerDay by rememberSaveable { mutableFloatStateOf(spendScale.defaultDaily.toFloat()) }
    var caloriesPerDay by rememberSaveable { mutableFloatStateOf(600f) }
    var trialInFlight by remember { mutableStateOf(false) }
    var resolutionInFlight by remember { mutableStateOf(false) }
    var resolutionError by remember { mutableStateOf<String?>(null) }
    var trialError by remember { mutableStateOf<String?>(null) }
    var restoreInFlight by remember { mutableStateOf(false) }
    var didShowTrial by rememberSaveable { mutableStateOf(false) }
    var reminderInFlight by remember { mutableStateOf(false) }
    var remindersOptIn by rememberSaveable { mutableStateOf(false) }
    var offerIncludesTrial by rememberSaveable { mutableStateOf(true) }
    var showSkipConfirm by remember { mutableStateOf(false) }

    val startDate = LocalDate.parse(startDay)
    fun startInstant(): Instant =
        minOf(startDate.atTime(LocalTime.now(graph.clock.zone())).atZone(graph.clock.zone()).toInstant(), graph.clock.now())

    fun persistSetup() = store.persistSetup(startInstant(), (costPerDay * 100).toInt(), caloriesPerDay.toInt(), remindersOptIn, SpendScale.currentCode())

    fun finishOnboarding() {
        if (step == 4) return
        persistSetup()
        step = 4
    }

    fun completeOnboarding() {
        persistSetup()
        store.completeOnboarding()
        graph.diagnostics.record(ConversionEvent.ONBOARDING_COMPLETED)
        if (!didShowTrial) graph.defaults.putBoolean(TrialSubsequentPitchGate.POST_ONBOARDING_PAYWALL_KEY, true)
        graph.refreshWidgets()
    }

    LaunchedEffect(Unit) {
        graph.diagnostics.record(ConversionEvent.ONBOARDING_REACHED)
        if (subscriptions.isConfigured && subscriptions.plans.isEmpty()) subscriptions.fetchProducts()
        DebugLaunchOptions.onboardingStep?.let {
            offerIncludesTrial = subscriptions.directTrialPlan != null
            step = it
        }
    }

    fun resolveTrialAndContinue() {
        if (resolutionInFlight) return
        persistSetup()
        resolutionError = null
        resolutionInFlight = true
        scope.launch {
            try {
                if (!subscriptions.isConfigured) {
                    resolutionError = "Bloom+ plans are temporarily unavailable. You can retry or start free."
                    return@launch
                }
                var resolution = subscriptions.resolveOnboardingTrial()
                if (resolution == OnboardingTrialResolution.FAILED || resolution == OnboardingTrialResolution.UNAVAILABLE) {
                    delay(1_200)
                    resolution = subscriptions.resolveOnboardingTrial()
                }
                when (resolution) {
                    OnboardingTrialResolution.ELIGIBLE -> {
                        offerIncludesTrial = true
                        step = 3
                    }
                    OnboardingTrialResolution.INELIGIBLE -> {
                        if (subscriptions.isPro || subscriptions.directOfferPlan == null) finishOnboarding()
                        else {
                            offerIncludesTrial = false
                            step = 3
                        }
                    }
                    else -> resolutionError = "Bloom+ plans are temporarily unavailable. You can retry or start free."
                }
            } finally {
                resolutionInFlight = false
            }
        }
    }

    fun startOnboardingTrial() {
        val plan = subscriptions.directOfferPlan
        if (plan == null) {
            trialError = if (offerIncludesTrial) "Couldn't load the trial plan. Please try again." else "Couldn't load the Bloom+ plan. Please try again."
            return
        }
        val activity = context.findActivity() ?: return
        graph.diagnostics.record(ConversionEvent.TRIAL_CTA_TAPPED)
        trialError = null
        trialInFlight = true
        scope.launch {
            try {
                when (subscriptions.purchase(activity, plan)) {
                    PurchaseOutcome.PURCHASED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_SUCCEEDED)
                        finishOnboarding()
                    }
                    PurchaseOutcome.PENDING -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_PENDING)
                        finishOnboarding()
                    }
                    PurchaseOutcome.CANCELLED -> graph.diagnostics.record(ConversionEvent.PURCHASE_CANCELLED)
                }
            } catch (_: PurchaseException) {
                graph.diagnostics.record(ConversionEvent.PURCHASE_FAILED)
                trialError = "Couldn't start your trial. Please try again."
            } finally {
                trialInFlight = false
            }
        }
    }

    fun restore() {
        if (restoreInFlight) return
        restoreInFlight = true
        scope.launch {
            subscriptions.restorePurchases()
            restoreInFlight = false
            if (subscriptions.isPro) finishOnboarding()
        }
    }

    fun enableRemindersAndFinish() {
        if (reminderInFlight) return
        reminderInFlight = true
        scope.launch {
            val granted = graph.notifications.ensureAuthorized()
            reminderInFlight = false
            remindersOptIn = granted
            graph.diagnostics.record(if (granted) ConversionEvent.REMINDERS_GRANTED else ConversionEvent.REMINDERS_DECLINED)
            if (granted) {
                val settings = store.settings
                val streak = JourneyDays.since(startInstant(), graph.clock.now(), graph.clock.zone())
                graph.notifications.scheduleDailyReminder(settings.dailyReminderHour, settings.madeCommitment, streak)
            }
            completeOnboarding()
        }
    }

    val legal: @Composable () -> Unit = {
        LegalFooter(restoreInFlight, onRestore = ::restore)
    }

    Box(Modifier.fillMaxSize().background(SoberBrushes.brand)) {
        AnimatedContent(step, transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) }, label = "step") { current ->
            Column(
                Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = Space.l, vertical = Space.l),
            ) {
                when (current) {
                    1 -> StartDateStep(startDate, graph.clock.today(), onPick = { startDay = it.toString() }) { step = 2 }
                    2 -> SavingsStep(
                        costPerDay, caloriesPerDay, spendScale,
                        onCost = { costPerDay = it }, onCalories = { caloriesPerDay = it },
                        inFlight = resolutionInFlight, error = resolutionError,
                        onStartFree = ::finishOnboarding, onContinue = ::resolveTrialAndContinue,
                    )
                    3 -> TrialStep(
                        subscriptions = subscriptions,
                        offerIncludesTrial = offerIncludesTrial,
                        costPerDay = costPerDay,
                        trialInFlight = trialInFlight,
                        trialError = trialError,
                        habitNoun = graph.content.words.habitGerund,
                        legal = legal,
                        onAppear = {
                            didShowTrial = true
                            graph.diagnostics.record(ConversionEvent.TRIAL_OFFER_REACHED)
                            subscriptions.trackPaywallImpression(
                                if (offerIncludesTrial) "sober_onboarding_trial_1_2_2" else "sober_onboarding_offer_no_trial",
                                oncePerSession = true,
                            )
                            graph.nudges.markShown()
                        },
                        onSkip = { showSkipConfirm = true },
                        onStart = ::startOnboardingTrial,
                    )
                    4 -> RemindersStep(
                        inFlight = reminderInFlight,
                        onAppear = { graph.diagnostics.record(ConversionEvent.REMINDERS_STEP_REACHED) },
                        onSkip = ::completeOnboarding,
                        onEnable = ::enableRemindersAndFinish,
                    )
                    else -> PromiseStep { step = 1 }
                }
            }
        }
    }

    if (showSkipConfirm) {
        SoberAlert(
            title = "Keep the free version?",
            message = "You'll keep the day counter, the calendar, and your tree. Your year-ahead projection, the full health timeline, the journal, and the other species stay locked.",
            confirmTitle = if (offerIncludesTrial) "Keep my free trial" else "Back",
            dismissTitle = "Get started",
            onConfirm = { showSkipConfirm = false },
            onDismiss = {
                showSkipConfirm = false
                graph.diagnostics.record(ConversionEvent.FREE_VERSION_CHOSEN)
                finishOnboarding()
            },
        )
    }
}

/** Scrolls when a short phone can't fit the hero, centred when it can. */
@Composable
private fun ColumnScope.Hero(content: @Composable ColumnScope.() -> Unit) {
    val gap = if (compactHeight()) Space.m else Space.xl
    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
        val viewport = maxHeight
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
            verticalArrangement = Arrangement.spacedBy(gap, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
            content = content,
        )
    }
}

@Composable
private fun PromiseStep(onNext: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Hero {
            HeroGlyph("leaf.fill", 76)
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Text("Your sober days, growing.", style = SoberType.display(if (compactHeight()) 32.sp else 40.sp), color = Color.White, textAlign = TextAlign.Center)
                Text(
                    "Count every day, grow a private bonsai, and see what your body and wallet get back.",
                    style = SoberType.body(), color = White88, textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = Space.s),
                )
            }
            Column(Modifier.padding(horizontal = Space.m), verticalArrangement = Arrangement.spacedBy(Space.m)) {
                PromiseRow("calendar", "A clear sobriety counter and calendar")
                PromiseRow("tree.fill", "A garden that changes with your streak")
                PromiseRow("lock.fill", "Private on your device, no account")
            }
        }
        Dock(primaryTitle = "Start my counter", tag = "onboarding.start", onPrimary = onNext)
    }
}

@Composable
private fun HeroGlyph(name: String, size: Int) {
    val compact = compactHeight()
    Box(Modifier.size(if (compact) 96.dp else 150.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
        SymbolIcon(name, Color.White, if (compact) (size * 0.62f).dp else size.dp)
    }
}

@Composable
private fun PromiseRow(icon: String, text: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        SymbolIcon(icon, Color.White, 22.dp, Modifier.width(24.dp))
        Spacer(Modifier.width(Space.m))
        Text(text, style = SoberType.body(), color = Color.White)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StartDateStep(selected: LocalDate, today: LocalDate, onPick: (LocalDate) -> Unit, onNext: () -> Unit) {
    val todayMillis = today.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    val state = rememberDatePickerState(
        initialSelectedDateMillis = selected.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= todayMillis
            override fun isSelectableYear(year: Int) = year <= today.year
        },
    )
    LaunchedEffect(state.selectedDateMillis) {
        state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
    }
    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            val pickerWidth = maxOf(maxWidth, 360.dp)
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("When did your sober journey begin?", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
                Text("Today is fine. You can change this later.", style = SoberType.subhead(), color = Color.White.copy(alpha = 0.8f))
                androidx.compose.runtime.CompositionLocalProvider(androidx.compose.material3.LocalContentColor provides Color.White) { DatePicker(
                    state = state,
                    title = null,
                    headline = null,
                    showModeToggle = false,
                    colors = DatePickerDefaults.colors(
                        containerColor = Color.Transparent,
                        weekdayContentColor = Color.White.copy(alpha = 0.6f),
                        subheadContentColor = Color.White,
                        navigationContentColor = Color.White,
                        yearContentColor = Color.White,
                        currentYearContentColor = Color.White,
                        selectedYearContentColor = SoberColors.brandPrimary,
                        selectedYearContainerColor = Color.White,
                        dayContentColor = Color.White,
                        disabledDayContentColor = Color.White.copy(alpha = 0.3f),
                        selectedDayContentColor = SoberColors.brandPrimary,
                        selectedDayContainerColor = Color.White,
                        todayContentColor = Color.White,
                        todayDateBorderColor = Color.White,
                    ),
                    // Material's calendar needs 360dp; on a 360dp phone let it use the step's side padding.
                    modifier = Modifier.testTagCompat("onboarding.datePicker").requiredWidth(pickerWidth),
                ) }
            }
        }
        Dock(primaryTitle = "Continue", tag = "onboarding.continue", onPrimary = onNext)
    }
}

@Composable
private fun SavingsStep(
    cost: Float,
    calories: Float,
    spendScale: SpendScale,
    onCost: (Float) -> Unit,
    onCalories: (Float) -> Unit,
    inFlight: Boolean,
    error: String?,
    onStartFree: () -> Unit,
    onContinue: () -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("See what drinking used to cost", style = SoberType.display(if (compactHeight()) 28.sp else 34.sp), color = Color.White, textAlign = TextAlign.Center)
                Text(
                    "Optional. Use zero if you only want the day counter and garden.",
                    style = SoberType.subhead(), color = Color.White.copy(alpha = 0.8f), textAlign = TextAlign.Center,
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    Text("Typical daily spend", style = SoberType.subhead(), color = Color.White.copy(alpha = 0.82f))
                    Text("${Format.currency(cost.toDouble())} / day", style = SoberType.rounded(if (compactHeight()) 34.sp else 44.sp, FontWeight.Bold), color = Color.White)
                    SoberSlider(cost, onCost, 0f..spendScale.maxDaily.toFloat(), spendScale.step.toFloat(), Color.White, Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.testTagCompat("onboarding.costSlider").semantics { contentDescription = "Typical daily spend" })
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    Text("Typical calories", style = SoberType.subhead(), color = Color.White.copy(alpha = 0.82f))
                    Text("${calories.toInt()} / day", style = SoberType.rounded(if (compactHeight()) 26.sp else 32.sp, FontWeight.Bold), color = Color.White)
                    SoberSlider(calories, onCalories, 0f..3000f, 50f, Color.White, Color.White.copy(alpha = 0.3f),
                        modifier = Modifier.semantics { contentDescription = "Typical calories" })
                }
                Projection(cost.toInt() * 365, calories.toInt() * 365)
            }
        }
        Dock(
            primaryTitle = if (inFlight) "Checking trial availability…" else "Continue",
            busy = inFlight,
            tag = "onboarding.savingsContinue",
            above = {
                if (error != null) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                        Text(error, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.onBrandError, textAlign = TextAlign.Center)
                        Text("Get started", style = SoberType.subhead(FontWeight.SemiBold), color = Color.White,
                            modifier = Modifier.pressable(onClick = onStartFree).padding(4.dp))
                    }
                }
            },
            onPrimary = onContinue,
        )
    }
}

@Composable
private fun Projection(yearlyDollars: Int, yearlyCalories: Int) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.15f))
            .padding(vertical = Space.m, horizontal = Space.m),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text("One alcohol-free year keeps", style = SoberType.subhead(), color = Color.White.copy(alpha = 0.78f))
        if (yearlyDollars > 0) Text(Format.currency(yearlyDollars.toDouble()), style = SoberType.rounded(if (compactHeight()) 34.sp else 44.sp, FontWeight.Bold), color = Color.White)
        if (yearlyCalories > 0) {
            Text("and ${Format.number(yearlyCalories)} calories out of your routine", style = SoberType.caption(),
                color = Color.White.copy(alpha = 0.78f), textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun TrialStep(
    subscriptions: SubscriptionService,
    offerIncludesTrial: Boolean,
    costPerDay: Float,
    trialInFlight: Boolean,
    trialError: String?,
    habitNoun: String,
    legal: @Composable () -> Unit,
    onAppear: () -> Unit,
    onSkip: () -> Unit,
    onStart: () -> Unit,
) {
    LaunchedEffect(Unit) { onAppear() }
    val trialDays = subscriptions.trialOfferDayCount
    val headline = when {
        !offerIncludesTrial -> "Unlock Bloom+"
        trialDays == null -> "Bloom+, free to try"
        else -> "$trialDays days of Bloom+ free"
    }
    val subhead = when {
        !offerIncludesTrial -> "Every tool that keeps the streak visible, unlocked today."
        trialDays == null -> "Every tool that keeps the streak visible. Nothing is charged today."
        else -> "Every tool that keeps the streak visible. Nothing is charged for $trialDays days."
    }
    val cta = when {
        !offerIncludesTrial -> "Unlock Bloom+"
        trialDays == null -> "Start my free trial"
        else -> "Start my $trialDays-day free trial"
    }
    val yearly = costPerDay.toInt() * 365
    val savingsText = if (yearly > 0) "Project the ${Format.currency(yearly.toDouble())} you'd keep over the next year"
    else "Project the year ahead, not just the days behind"
    val chargeLine = if (offerIncludesTrial && trialDays != null) {
        "Free until ${Format.monthDay(LocalDate.now().plusDays(trialDays.toLong()))}. We'll remind you before it ends. Reminder needs notifications turned on."
    } else null
    val habitLine = subscriptions.directOfferPlan?.habitComparisonSentence((costPerDay * 100).toInt(), habitNoun)

    Column(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val viewport = maxHeight
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = viewport),
                verticalArrangement = Arrangement.spacedBy(Space.l, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                SymbolIcon("sparkles", Color.White, if (compactHeight()) 40.dp else 60.dp)
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                    Text(headline, style = SoberType.display(if (compactHeight()) 30.sp else 40.sp, FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, maxLines = 2)
                    Text(subhead, style = SoberType.body(), color = White88, textAlign = TextAlign.Center)
                }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White.copy(alpha = 0.13f)).padding(Space.m),
                    verticalArrangement = Arrangement.spacedBy(Space.m),
                ) {
                    TrialBenefit("tree.fill", "Grow and switch every bonsai species")
                    TrialBenefit("heart.text.square.fill", "Follow 13 sourced recovery milestones")
                    TrialBenefit("chart.line.uptrend.xyaxis", savingsText)
                    TrialBenefit("book.closed.fill", "Journal privately through difficult moments")
                }
            }
        }
        Dock(
            primaryTitle = cta,
            busy = trialInFlight,
            tag = "onboarding.trialCTA",
            showLegal = true,
            legal = legal,
            above = {
                Column(verticalArrangement = Arrangement.spacedBy(Space.s), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (habitLine != null) {
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.16f))
                                .padding(horizontal = 13.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            SymbolIcon("arrow.left.arrow.right", Color.White, 13.dp)
                            Spacer(Modifier.width(7.dp))
                            Text(habitLine, style = SoberType.subhead(FontWeight.SemiBold), color = Color.White)
                        }
                    }
                    subscriptions.directTrialPriceHeadline?.let {
                        Text(it, style = SoberType.body(FontWeight.Bold), color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    }
                    StatusSlot(chargeLine, trialError)
                    Text(
                        "Get started",
                        style = SoberType.caption(FontWeight.SemiBold),
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.testTagCompat("onboarding.skipTrial").pressable(enabled = !trialInFlight, onClick = onSkip).padding(vertical = 6.dp, horizontal = 12.dp),
                    )
                }
            },
            below = {
                subscriptions.directTrialRenewalDisclosure?.let { DisclosureLine(it) }
            },
            onPrimary = onStart,
        )
    }
}

/** Reassurance and a real purchase error share one slot sized to the taller. */
@Composable
private fun StatusSlot(reassurance: String?, error: String?) {
    if (reassurance != null) {
        Box {
            Box(Modifier.alpha(0f)) { ReassuranceLine(reassurance) }
            Box(Modifier.alpha(0f)) { ErrorLine("Couldn't load the Bloom+ plan. Please try again.") }
            if (error != null) ErrorLine(error) else ReassuranceLine(reassurance)
        }
    } else if (error != null) {
        ErrorLine(error)
    }
}

@Composable
private fun ReassuranceLine(text: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
        SymbolIcon("bell.badge.fill", Color.White.copy(alpha = 0.72f), 11.dp, Modifier.padding(top = 3.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, style = SoberType.caption(), color = Color.White.copy(alpha = 0.72f))
    }
}

@Composable
private fun ErrorLine(text: String) {
    Text(text, style = SoberType.caption(FontWeight.SemiBold), color = SoberColors.onBrandError, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun DisclosureLine(text: String) {
    Text(text, style = SoberType.caption(), color = Color.White.copy(alpha = 0.7f), textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = Space.s))
}

@Composable
private fun TrialBenefit(icon: String, text: String) {
    Row(Modifier.fillMaxWidth()) {
        SymbolIcon(icon, Color.White, 20.dp, Modifier.width(24.dp).padding(top = 2.dp))
        Spacer(Modifier.width(Space.m))
        Text(text, style = SoberType.body(), color = Color.White)
    }
}

@Composable
private fun RemindersStep(inFlight: Boolean, onAppear: () -> Unit, onSkip: () -> Unit, onEnable: () -> Unit) {
    LaunchedEffect(Unit) { onAppear() }
    Column(Modifier.fillMaxSize()) {
        Hero {
            HeroGlyph("bell.badge.fill", 68)
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.m)) {
                Text("One nudge a day, if you want it.", style = SoberType.display(if (compactHeight()) 30.sp else 38.sp), color = Color.White, textAlign = TextAlign.Center)
                Text(
                    "A reminder to log the day and water your bonsai, a note when a milestone is a day out, and a heads-up before a free trial converts. Nothing else, and you can turn it all off in Settings.",
                    style = SoberType.body(), color = White88, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = Space.s),
                )
            }
        }
        Dock(
            primaryTitle = "Turn on reminders",
            busy = inFlight,
            tag = "onboarding.enableReminders",
            above = {
                Text(
                    "Not now",
                    style = SoberType.caption(FontWeight.SemiBold),
                    color = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.testTagCompat("onboarding.remindersNotNow").pressable(enabled = !inFlight, onClick = onSkip).padding(vertical = 6.dp, horizontal = 12.dp),
                )
            },
            onPrimary = onEnable,
        )
    }
}

@Composable
private fun LegalFooter(restoreInFlight: Boolean, onRestore: () -> Unit) {
    val context = LocalContext.current
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        val style = SoberType.caption()
        val color = Color.White.copy(alpha = 0.75f)
        Text(if (restoreInFlight) "Restoring…" else "Restore", style = style, color = color,
            modifier = Modifier.pressable(enabled = !restoreInFlight, onClick = onRestore).padding(vertical = 6.dp))
        Text("·", style = style, color = color)
        Text("Terms", style = style, color = color, modifier = Modifier.pressable { context.openUrl(StoreLinks.TERMS_URL) }.padding(vertical = 6.dp))
        Text("·", style = style, color = color)
        Text("Privacy", style = style, color = color, modifier = Modifier.pressable { context.openUrl(StoreLinks.PRIVACY_URL) }.padding(vertical = 6.dp))
    }
}

/**
 * Every step docks its primary button on the same pixel: the slot under it
 * always reserves the offer step's disclosure and legal footer, invisibly.
 */
@Composable
private fun Dock(
    primaryTitle: String,
    busy: Boolean = false,
    tag: String,
    showLegal: Boolean = false,
    legal: (@Composable () -> Unit)? = null,
    above: @Composable () -> Unit = {},
    below: @Composable () -> Unit = {},
    onPrimary: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(top = Space.s), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
        above()
        Box(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(Color.White.copy(alpha = 0.25f))
                .testTagCompat(tag)
                .semantics { contentDescription = primaryTitle }
                .pressable(enabled = !busy, onClick = onPrimary)
                .padding(vertical = Space.l),
            contentAlignment = Alignment.Center,
        ) {
            Text(primaryTitle, style = SoberType.body(FontWeight.SemiBold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.alpha(if (busy) 0f else 1f))
            if (busy) ProgressSpinner(Color.White)
        }
        Box(contentAlignment = Alignment.TopCenter) {
            // The reserve: what the offer step puts under its button, laid out hidden on every step.
            Column(Modifier.alpha(0f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                DisclosureLine(SubscriptionService.AUTO_RENEW_DISCLOSURE)
                LegalFooter(false) {}
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Space.s)) {
                below()
                if (showLegal) legal?.invoke()
            }
        }
    }
}
