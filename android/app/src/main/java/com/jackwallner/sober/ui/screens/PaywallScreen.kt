package com.jackwallner.sober.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.sober.BuildConfig
import com.jackwallner.sober.data.BloomFeature
import com.jackwallner.sober.data.ConversionEvent
import com.jackwallner.sober.data.PackageKind
import com.jackwallner.sober.data.Plan
import com.jackwallner.sober.data.PurchaseException
import com.jackwallner.sober.data.PurchaseOutcome
import com.jackwallner.sober.data.StoreLinks
import com.jackwallner.sober.data.capitalizeWords
import com.jackwallner.sober.ui.Format
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.findActivity
import com.jackwallner.sober.ui.openUrl
import com.jackwallner.sober.ui.theme.ProgressSpinner
import com.jackwallner.sober.ui.theme.SoberBrushes
import com.jackwallner.sober.ui.theme.SoberColors
import com.jackwallner.sober.ui.theme.SoberFonts
import com.jackwallner.sober.ui.theme.SoberType
import com.jackwallner.sober.ui.theme.SymbolIcon
import com.jackwallner.sober.ui.theme.card
import com.jackwallner.sober.ui.theme.pressable
import com.jackwallner.sober.ui.theme.softShadow
import com.jackwallner.sober.ui.theme.testTagCompat
import kotlinx.coroutines.launch

private fun rounded(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
    TextStyle(fontFamily = SoberFonts.rounded, fontWeight = weight, fontSize = size, lineHeight = size * 1.18f)

/**
 * The native Bloom+ paywall: savings hero, what Bloom+ unlocks, the plan
 * stack (the real price on every card), and a pinned purchase dock with the
 * renewal terms, trust line, and legal links.
 */
@Composable
fun PaywallScreen(
    focus: BloomFeature?,
    impressionId: String,
    displayCloseButton: Boolean,
    showsLifetime: Boolean,
    onClose: () -> Unit,
) {
    val graph = LocalGraph.current
    val subscriptions = graph.subscriptions
    val store = graph.store
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var isPurchasing by remember { mutableStateOf(false) }
    var isRestoring by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var restoreMessage by remember { mutableStateOf<String?>(null) }
    val remindersDenied = remember { graph.notifications.isDenied }

    val order = mapOf(PackageKind.YEARLY to 0, PackageKind.MONTHLY to 1, PackageKind.LIFETIME to 2)
    val plans = subscriptions.plans.filter { showsLifetime || it.kind != PackageKind.LIFETIME }.sortedBy { order[it.kind] ?: 9 }
    val monthly = subscriptions.plans.firstOrNull { it.kind == PackageKind.MONTHLY }
    val selected = plans.firstOrNull { it.packageId == selectedId }

    LaunchedEffect(Unit) {
        graph.diagnostics.record(ConversionEvent.TRIAL_OFFER_REACHED)
        subscriptions.trackPaywallImpression(impressionId)
        if (subscriptions.isConfigured && subscriptions.plans.isEmpty()) subscriptions.fetchProducts()
    }
    LaunchedEffect(plans.size) {
        if (selectedId == null && plans.isNotEmpty()) {
            selectedId = (plans.firstOrNull { it.kind == PackageKind.YEARLY } ?: plans.firstOrNull { it.kind == PackageKind.MONTHLY } ?: plans.first()).packageId
        }
    }
    LaunchedEffect(subscriptions.isPro) {
        // Only a sheet closes itself; the Bloom+ tab swaps to the subscriber hub.
        if (subscriptions.isPro && displayCloseButton) onClose()
    }

    val state = store.state
    val days = store.days
    val heroDays = maxOf(store.lifetimeSoberDays, days)
    val cents = state.settings.costPerDayCents

    fun purchase() {
        val plan = selected ?: return
        val activity = context.findActivity() ?: return
        graph.diagnostics.record(ConversionEvent.TRIAL_CTA_TAPPED)
        errorMessage = null
        restoreMessage = null
        isPurchasing = true
        scope.launch {
            try {
                when (subscriptions.purchase(activity, plan)) {
                    PurchaseOutcome.PURCHASED -> graph.diagnostics.record(ConversionEvent.PURCHASE_SUCCEEDED)
                    PurchaseOutcome.PENDING -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_PENDING)
                        restoreMessage = "Your purchase is awaiting approval. Bloom+ unlocks as soon as it's confirmed."
                    }
                    PurchaseOutcome.CANCELLED -> {
                        graph.diagnostics.record(ConversionEvent.PURCHASE_CANCELLED)
                        errorMessage = "Purchase cancelled. Tap again to continue."
                    }
                }
            } catch (_: PurchaseException) {
                graph.diagnostics.record(ConversionEvent.PURCHASE_FAILED)
                errorMessage = "Couldn't complete the purchase. Please try again."
            } finally {
                isPurchasing = false
            }
        }
    }

    fun restore() {
        errorMessage = null
        restoreMessage = null
        isRestoring = true
        scope.launch {
            subscriptions.restorePurchases()
            isRestoring = false
            if (!subscriptions.isPro) restoreMessage = subscriptions.lastError ?: "No active Bloom+ purchase found for this Google Play account."
        }
    }

    val footer: @Composable (PaywallMetrics) -> Unit = { m ->
        FooterLinks(m, isRestoring || isPurchasing, isRestoring, ::restore)
    }

    Box(Modifier.fillMaxSize().background(SoberColors.background)) {
        when {
            !subscriptions.isConfigured -> if (BuildConfig.DEBUG) {
                DevPlaceholder(focus, heroDays, cents, displayCloseButton) {
                    subscriptions.setLocalOverride(true)
                    if (displayCloseButton) onClose()
                }
            } else {
                EmptyState(subscriptions.lastError, displayCloseButton, footer) { scope.launch { subscriptions.fetchProducts() } }
            }
            subscriptions.isLoadingProducts && plans.isEmpty() -> LoadingState(displayCloseButton, footer)
            plans.isEmpty() -> EmptyState(subscriptions.lastError, displayCloseButton, footer) { scope.launch { subscriptions.fetchProducts() } }
            else -> BoxWithConstraints(Modifier.fillMaxSize()) {
                val anyTrial = plans.any(subscriptions::isEligibleForIntroOffer)
                val premium = if (showsLifetime) 0f else 35f
                val relief = if (anyTrial) 0f else 85f
                val m = PaywallMetrics(maxHeight.value - premium + relief)
                Column(Modifier.fillMaxSize()) {
                    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
                        val top = m.stackTopPadding(displayCloseButton)
                        val fit = maxHeight - top - 2.dp
                        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                            val anyTrialBlock = anyTrial
                            PaywallPageLayout(
                                pageHeight = fit,
                                minGap = m.blockGap,
                                maxGap = m.maxBlockGap,
                                modifier = Modifier.padding(horizontal = m.horizontalGutter).padding(top = top, bottom = 2.dp),
                                blocks = listOfNotNull(
                                    PageBlock { _ ->
                                        Column {
                                            SavingsHeader(m, focus, heroDays, cents, days)
                                            if (!showsLifetime) {
                                                selected?.habitComparisonSentence(cents, graph.content.words.habitGerund)?.let {
                                                    HabitLine(m, it, Modifier.padding(top = m.lerp(8f, 12f).dp))
                                                }
                                            }
                                        }
                                    },
                                    PageBlock(1.3f) { bounded ->
                                        BenefitShowcase(m, focus, limit = if (!anyTrial && m.showsExpandedBenefits) 4 else 3, bounded = bounded)
                                    },
                                    PageBlock(1f) { bounded ->
                                        Column(if (bounded) Modifier.fillMaxSize() else Modifier, verticalArrangement = Arrangement.spacedBy(m.planSpacing)) {
                                            plans.forEach { plan ->
                                                PlanCard(
                                                    plan = plan,
                                                    selected = plan.packageId == selectedId,
                                                    showsTrialBadge = subscriptions.isEligibleForIntroOffer(plan),
                                                    monthly = monthly,
                                                    m = m,
                                                    modifier = if (bounded) Modifier.weight(1f, fill = true) else Modifier,
                                                ) { selectedId = plan.packageId }
                                            }
                                        }
                                    },
                                    if (anyTrialBlock) PageBlock { _ ->
                                        val trialDays = selected?.takeIf(subscriptions::isEligibleForIntroOffer)?.trial?.days
                                        val longest = plans.filter(subscriptions::isEligibleForIntroOffer).mapNotNull { it.trial?.days }.maxOrNull() ?: 0
                                        val shows by animateFloatAsState(if (trialDays != null) 1f else 0f, tween(200), label = "timeline")
                                        Box(contentAlignment = Alignment.Center) {
                                            Box(Modifier.alpha(shows)) { TrialTimelineCard(m, trialDays ?: longest, !remindersDenied) }
                                            Box(Modifier.alpha(1f - shows)) { LifetimeNoteCard(m) }
                                        }
                                    } else null,
                                ),
                            )
                        }
                    }
                    PurchaseDock(
                        m = m,
                        plans = plans,
                        selected = selected,
                        isPurchasing = isPurchasing,
                        errorMessage = errorMessage,
                        restoreMessage = restoreMessage,
                        footer = footer,
                        onPurchase = ::purchase,
                    )
                }
            }
        }
        if (displayCloseButton) {
            Box(
                Modifier.align(Alignment.TopEnd).padding(8.dp).size(44.dp)
                    .semantics { contentDescription = "Close" }
                    .testTagCompat("paywall.close")
                    .pressable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) { SymbolIcon("xmark.circle.fill", SoberColors.textTertiary, 28.dp) }
        }
    }
}

@Composable
private fun Eyebrow(text: String, size: TextUnit) {
    Text(text, style = rounded(size, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = SoberColors.brandPrimary.copy(alpha = 0.9f))
}

@Composable
private fun SavingsHeader(m: PaywallMetrics, focus: BloomFeature?, heroDays: Int, cents: Int, days: Int) {
    val words = LocalGraph.current.content.words
    val hasSavings = heroDays > 0 && cents > 0
    val saved = Format.currency(heroDays * cents / 100.0)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(m.heroLineSpacing)) {
        when {
            focus != null -> {
                Text(focus.pitchHeadline, style = rounded(m.heroHeadlineSize, FontWeight.Bold), color = SoberColors.textPrimary)
                Text(
                    if (hasSavings) "You've already saved $saved staying sober. Treat yourself to the tools that keep it growing." else focus.pitchSubheadline(words),
                    style = rounded(m.heroSubheadSize), color = SoberColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
            }
            hasSavings -> {
                Eyebrow("YOU'VE SAVED SO FAR", m.heroEyebrowSize)
                Text(saved, style = rounded(m.heroAmountSize, FontWeight.ExtraBold), color = SoberColors.brandPrimary, maxLines = 1)
                Text("Across $heroDays sober day${if (heroDays == 1) "" else "s"}. Put a fraction toward keeping it.",
                    style = rounded(m.heroSubheadSize), color = SoberColors.textSecondary, maxLines = 2)
            }
            cents > 0 -> {
                Eyebrow("YOUR MONEY, KEPT", m.heroEyebrowSize)
                Text("Up to ${Format.currency(Math.round(cents * 365 / 100.0).toDouble())}/yr", style = rounded(m.heroAmountSize, FontWeight.ExtraBold), color = SoberColors.brandPrimary, maxLines = 1)
                Text("Stays in your pocket, not on ${words.substance}. Bloom+ keeps the streak that gets you there.",
                    style = rounded(m.heroSubheadSize), color = SoberColors.textSecondary, maxLines = 2)
            }
            else -> {
                Eyebrow("BLOOM+", m.heroEyebrowSize)
                Text("Unlock the full toolkit", style = rounded((m.heroHeadlineSize.value + 2).sp, FontWeight.Bold), color = SoberColors.textPrimary)
                Text("Your garden, journal, health timeline, and savings. Everything that keeps you sober.",
                    style = rounded(m.heroSubheadSize), color = SoberColors.textSecondary, maxLines = 2)
            }
        }
    }
}

@Composable
private fun HabitLine(m: PaywallMetrics, sentence: String, modifier: Modifier) {
    Row(
        modifier.fillMaxWidth().clip(RoundedCornerShape(m.lerp(12f, 15f).dp)).background(SoberColors.brandPrimary.copy(alpha = 0.08f))
            .padding(horizontal = m.lerp(13f, 15f).dp, vertical = m.lerp(10f, 13f).dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(m.lerp(7f, 9f).dp),
    ) {
        SymbolIcon("arrow.left.arrow.right", SoberColors.brandPrimary.copy(alpha = 0.85f), m.lerp(12f, 14f).dp)
        Text(sentence, style = rounded(m.benefitTitleSize, FontWeight.SemiBold), color = SoberColors.textPrimary)
    }
}

@Composable
private fun BenefitShowcase(m: PaywallMetrics, focus: BloomFeature?, limit: Int, modifier: Modifier = Modifier, bounded: Boolean = false) {
    val words = LocalGraph.current.content.words
    val all = BloomFeature.entries
    val kept = mutableListOf<BloomFeature>().apply {
        focus?.let(::add)
        for (feature in all) if (size < limit && feature !in this) add(feature)
    }
    val visible = all.filter { it in kept }
    Column(if (bounded) modifier.fillMaxSize() else modifier, verticalArrangement = Arrangement.spacedBy(m.lerp(5f, 9f).dp)) {
        if (m.showsExpandedBenefits) Box(Modifier.padding(start = 2.dp)) { Eyebrow("WHAT BLOOM+ UNLOCKS", m.sectionLabelSize) }
        Column(
            Modifier.fillMaxWidth().then(if (bounded) Modifier.weight(1f) else Modifier)
                .softShadow(Color.Black.copy(alpha = 0.05f), 10.dp, 4.dp, m.cardRadius)
                .card(SoberColors.cardSurface, m.cardRadius, SoberColors.ringTrack.copy(alpha = 0.6f))
                .padding(horizontal = m.benefitCardPaddingH, vertical = m.benefitCardPaddingV),
            verticalArrangement = Arrangement.spacedBy(m.benefitRowSpacing, Alignment.CenterVertically),
        ) {
            visible.forEach { feature ->
                val highlighted = feature == focus
                Row(
                    Modifier.fillMaxWidth().heightIn(min = m.benefitIconSize)
                        .then(if (highlighted) Modifier.clip(RoundedCornerShape(12.dp)).background(SoberColors.brandPrimary.copy(alpha = 0.08f)).padding(horizontal = 8.dp, vertical = m.lerp(2f, 5f).dp) else Modifier),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(m.lerp(12f, 14f).dp),
                ) {
                    Box(Modifier.size(m.benefitIconSize).clip(CircleShape).background(SoberBrushes.brand), contentAlignment = Alignment.Center) {
                        SymbolIcon(feature.icon, Color.White, m.benefitGlyphSize)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        Text(feature.title(words), style = rounded(m.benefitTitleSize, FontWeight.SemiBold), color = SoberColors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (m.showsExpandedBenefits) Text(feature.detail, style = rounded(m.benefitDetailSize), color = SoberColors.textSecondary, maxLines = 2)
                    }
                    SymbolIcon("checkmark", SoberColors.brandPrimary.copy(alpha = if (highlighted) 1f else 0.55f), m.lerp(13f, 15f).dp)
                }
            }
        }
    }
}

@Composable
private fun PlanCard(
    plan: Plan,
    selected: Boolean,
    showsTrialBadge: Boolean,
    monthly: Plan?,
    m: PaywallMetrics,
    modifier: Modifier,
    onTap: () -> Unit,
) {
    val savings = if (plan.kind == PackageKind.YEARLY) plan.savingsPercent(monthly) else null
    val anchor = if (plan.kind == PackageKind.YEARLY) plan.anchorPriceLabel(monthly) else null
    val subtitle = when (plan.kind) {
        PackageKind.YEARLY -> plan.perMonthLabel?.let { perMonth ->
            val trial = plan.introOfferLabel
            if (showsTrialBadge && trial != null) "${trial.replace(" free trial", "", ignoreCase = true)} free · $perMonth" else perMonth
        }
        PackageKind.LIFETIME -> "One-time · no subscription"
        else -> null
    }
    val badge = when {
        plan.kind == PackageKind.YEARLY && savings != null -> "RECOMMENDED · SAVE $savings%"
        showsTrialBadge && plan.kind == PackageKind.MONTHLY -> plan.introOfferLabel?.uppercase() ?: "FREE TRIAL"
        else -> null
    }
    val shortBadge = when {
        plan.kind == PackageKind.YEARLY && savings != null -> "SAVE $savings%"
        showsTrialBadge && plan.kind == PackageKind.MONTHLY -> "FREE TRIAL"
        else -> null
    }
    val badgeFill = if (plan.kind == PackageKind.LIFETIME) SoberColors.accent else SoberColors.brandPrimary
    Row(
        modifier.fillMaxWidth().heightIn(min = m.planMinHeight)
            .clip(RoundedCornerShape(m.planRadius))
            .background(if (selected) SoberColors.brandPrimary.copy(alpha = 0.08f) else SoberColors.cardSurface)
            .border(if (selected) 2.dp else 1.dp, if (selected) SoberColors.brandPrimary else SoberColors.ringTrack.copy(alpha = 0.6f), RoundedCornerShape(m.planRadius))
            .semantics(mergeDescendants = true) {
                contentDescription = "${plan.displayName}, ${plan.priceLabel}" + (subtitle?.let { ", $it" } ?: "") + (badge?.let { ", $it" } ?: "")
                this.selected = selected
            }
            .testTagCompat("plan.${plan.kind.name.lowercase()}")
            .pressable(role = Role.RadioButton, onClick = onTap)
            .padding(horizontal = m.planPaddingH, vertical = m.planPaddingV),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(m.lerp(14f, 16f).dp),
    ) {
        Box(
            Modifier.size(m.planRadioSize).border(2.dp, if (selected) SoberColors.brandPrimary else SoberColors.ringTrack, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) Box(Modifier.size(m.planRadioSize * 0.55f).clip(CircleShape).background(SoberColors.brandPrimary))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(m.lerp(3f, 4f).dp)) {
            TitleWithBadge(
                title = { Text(plan.displayName, style = rounded(m.planTitleSize, FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1) },
                full = badge?.let { { Badge(it, badgeFill, m) } },
                short = (shortBadge ?: badge)?.let { { Badge(it, badgeFill, m) } },
                spacing = m.lerp(6f, 8f).dp,
            )
            if (subtitle != null) Text(subtitle, style = rounded(m.planSubtitleSize, FontWeight.SemiBold), color = SoberColors.textSecondary, maxLines = 1)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(plan.priceLabel, style = rounded(m.planPriceSize, FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
            if (anchor != null) {
                Text(anchor, style = rounded(m.planAnchorSize).copy(textDecoration = TextDecoration.LineThrough), color = SoberColors.textTertiary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun Badge(text: String, fill: Color, m: PaywallMetrics) {
    Text(
        text,
        style = rounded(m.planBadgeSize, FontWeight.ExtraBold),
        color = Color.White,
        maxLines = 1,
        modifier = Modifier.clip(CircleShape).background(fill).padding(horizontal = m.lerp(7f, 9f).dp, vertical = m.lerp(3f, 4f).dp),
    )
}

/** The full badge beside the title when it fits, the short one when it doesn't, as `ViewThatFits`. */
@Composable
private fun TitleWithBadge(title: @Composable () -> Unit, full: (@Composable () -> Unit)?, short: (@Composable () -> Unit)?, spacing: androidx.compose.ui.unit.Dp) {
    androidx.compose.ui.layout.Layout(
        content = {
            title()
            full?.invoke() ?: Box(Modifier)
            short?.invoke() ?: Box(Modifier)
        },
    ) { measurables, constraints ->
        val gap = spacing.roundToPx()
        val loose = constraints.copy(minWidth = 0, minHeight = 0)
        val titleP = measurables[0].measure(loose)
        val room = (constraints.maxWidth - titleP.width - gap).coerceAtLeast(0)
        val fullP = measurables[1].measure(loose.copy(maxWidth = androidx.compose.ui.unit.Constraints.Infinity))
        val useFull = fullP.width <= room
        val shortP = measurables[2].measure(loose.copy(maxWidth = room))
        val badgeP = if (useFull) fullP else shortP
        val height = maxOf(titleP.height, badgeP.height)
        layout(minOf(constraints.maxWidth, titleP.width + (if (badgeP.width > 0) gap + badgeP.width else 0)), height) {
            titleP.placeRelative(0, (height - titleP.height) / 2)
            if (badgeP.width > 0) badgeP.placeRelative(titleP.width + gap, (height - badgeP.height) / 2)
        }
    }
}

@Composable
private fun TrialTimelineCard(m: PaywallMetrics, trialDays: Int, remindersEnabled: Boolean) {
    Box(
        Modifier.fillMaxWidth().card(SoberColors.cardSurface, m.cardRadius, SoberColors.ringTrack.copy(alpha = 0.6f))
            .padding(horizontal = m.timelinePaddingH, vertical = m.timelinePaddingV),
    ) {
        TrialTimeline(trialDays, remindersEnabled, m)
    }
}

/** "How your free trial works", three columns joined by a rule behind the markers. */
@Composable
fun TrialTimeline(trialDays: Int, remindersEnabled: Boolean, m: PaywallMetrics) {
    val reminderDay = maxOf(1, trialDays - 2)
    val steps = listOf(
        Triple("lock.open.fill", "Today", "Everything unlocks, $0 due now."),
        Triple("bell.fill", "Day $reminderDay", if (remindersEnabled) "We remind you before it ends." else "A heads-up in the app first."),
        Triple("flag.checkered", "Day $trialDays", "Billing starts. Cancel by then."),
    )
    val rule = SoberColors.brandPrimary.copy(alpha = 0.25f)
    val marker = m.timelineMarkerSize
    Column(verticalArrangement = Arrangement.spacedBy(m.timelineRowGap), horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            Modifier.fillMaxWidth().drawBehind {
                val y = marker.toPx() / 2
                drawLine(rule, androidx.compose.ui.geometry.Offset(size.width / 6, y), androidx.compose.ui.geometry.Offset(size.width * 5 / 6, y), strokeWidth = 2.dp.toPx())
            },
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            steps.forEachIndexed { index, (icon, title, detail) ->
                val highlight = index == 0
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(m.timelineColumnGap)) {
                    Box(
                        Modifier.size(marker).clip(CircleShape).background(SoberColors.cardSurface)
                            .background(if (highlight) SoberColors.brandPrimary else SoberColors.brandPrimary.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        SymbolIcon(icon, if (highlight) Color.White else SoberColors.brandPrimary, m.timelineGlyphSize)
                    }
                    Text(title, style = rounded(m.timelineTitleSize, FontWeight.Bold), color = SoberColors.textPrimary, maxLines = 1)
                    Text(detail, style = rounded(m.timelineDetailSize), color = SoberColors.textSecondary, textAlign = TextAlign.Center)
                }
            }
        }
        if (remindersEnabled) {
            Text("Reminder needs notifications turned on.", style = rounded(m.timelineDetailSize), color = SoberColors.textSecondary.copy(alpha = 0.75f), textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun LifetimeNoteCard(m: PaywallMetrics) {
    Row(
        Modifier.fillMaxWidth().card(SoberColors.cardSurface, m.cardRadius, SoberColors.ringTrack.copy(alpha = 0.6f))
            .padding(horizontal = m.timelinePaddingH + 2.dp, vertical = m.timelinePaddingV + 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(m.lerp(11f, 14f).dp),
    ) {
        Box(Modifier.size(m.timelineMarkerSize).clip(CircleShape).background(SoberColors.brandPrimary), contentAlignment = Alignment.Center) {
            SymbolIcon("infinity", Color.White, m.timelineGlyphSize + 2.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("One-time purchase", style = rounded(m.benefitTitleSize, FontWeight.SemiBold), color = SoberColors.textPrimary)
            Text("No trial, no renewal. Bloom+ stays unlocked.", style = rounded(m.timelineDetailSize), color = SoberColors.textSecondary)
        }
    }
}

@Composable
private fun PurchaseDock(
    m: PaywallMetrics,
    plans: List<Plan>,
    selected: Plan?,
    isPurchasing: Boolean,
    errorMessage: String?,
    restoreMessage: String?,
    footer: @Composable (PaywallMetrics) -> Unit,
    onPurchase: () -> Unit,
) {
    val subscriptions = LocalGraph.current.subscriptions
    val cta = when {
        selected == null -> "Continue"
        selected.kind == PackageKind.LIFETIME -> "Unlock Lifetime"
        subscriptions.isEligibleForIntroOffer(selected) && selected.introOfferLabel != null ->
            "Start ${selected.introOfferLabel!!.replace(" free trial", "", ignoreCase = true).capitalizeWords()} Free Trial"
        else -> "Continue with Bloom+"
    }
    val trialTrust = selected?.let(subscriptions::isEligibleForIntroOffer) ?: false
    Column(
        Modifier.fillMaxWidth()
            .background(Brush.verticalGradient(0f to SoberColors.background.copy(alpha = 0f), 0.06f to SoberColors.background))
            .navigationBarsPadding()
            .padding(horizontal = m.horizontalGutter)
            .padding(top = 10.dp + m.lerp(6f, 10f).dp, bottom = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(m.dockSpacing),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(m.dockInnerSpacing)) {
            Box(
                Modifier.fillMaxWidth().height(m.ctaHeight)
                    .softShadow(SoberColors.brandPrimary.copy(alpha = 0.3f), 12.dp, 6.dp, m.ctaRadius)
                    .clip(RoundedCornerShape(m.ctaRadius))
                    .background(SoberBrushes.brand, RoundedCornerShape(m.ctaRadius))
                    .graphicsLayer { alpha = if (selected == null) 0.6f else 1f }
                    .semantics { contentDescription = cta }
                    .testTagCompat("paywall.cta")
                    .pressable(enabled = !isPurchasing && selected != null, onClick = onPurchase),
                contentAlignment = Alignment.Center,
            ) {
                Text(cta, style = rounded(m.ctaTitleSize, FontWeight.Bold), color = Color.White, maxLines = 1, modifier = Modifier.alpha(if (isPurchasing) 0f else 1f))
                if (isPurchasing) ProgressSpinner(Color.White)
            }
            // Every plan's terms laid out at once, all but the selected hidden, so the CTA never moves.
            Box(contentAlignment = Alignment.TopCenter) {
                plans.forEach { plan ->
                    Text(
                        disclosure(plan, subscriptions.isEligibleForIntroOffer(plan)),
                        style = rounded(m.disclosureSize),
                        color = SoberColors.textSecondary,
                        textAlign = TextAlign.Center,
                        maxLines = 4,
                        modifier = Modifier.alpha(if (plan.packageId == selected?.packageId) 1f else 0f),
                    )
                }
            }
            if (errorMessage != null) {
                Text(errorMessage, style = rounded(m.disclosureSize), color = SoberColors.danger, textAlign = TextAlign.Center)
            } else if (restoreMessage != null) {
                Text(restoreMessage, style = rounded(m.disclosureSize), color = SoberColors.textSecondary, textAlign = TextAlign.Center)
            }
        }
        Box(Modifier.padding(horizontal = 4.dp), contentAlignment = Alignment.Center) {
            TrustLine(m, "bell.fill", "No payment now · Cancel any time · Data stays on-device", Modifier.alpha(if (trialTrust) 1f else 0f))
            TrustLine(m, "lock.fill", "Your data stays on this device", Modifier.alpha(if (trialTrust) 0f else 1f))
        }
        footer(m)
    }
}

private fun disclosure(plan: Plan, eligible: Boolean): String {
    if (plan.kind == PackageKind.LIFETIME) return "${plan.priceLabel}. One-time purchase. Lifetime access, no subscription."
    val renew = "Auto-renews until cancelled. Cancel any time in Google Play › Payments & subscriptions."
    val trial = plan.introOfferLabel
    return if (eligible && trial != null) "${trial.capitalizeWords()}, then ${plan.priceLabel}. $renew" else "${plan.priceLabel}. $renew"
}

@Composable
private fun TrustLine(m: PaywallMetrics, icon: String, text: String, modifier: Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        SymbolIcon(icon, SoberColors.brandPrimary.copy(alpha = 0.8f), m.lerp(12f, 13f).dp)
        Text(text, style = rounded(m.trustSize), color = SoberColors.textSecondary, textAlign = TextAlign.Center, maxLines = 2)
    }
}

@Composable
private fun FooterLinks(m: PaywallMetrics, disabled: Boolean, restoring: Boolean, onRestore: () -> Unit) {
    val context = LocalContext.current
    val style = rounded(m.footerSize)
    Row(horizontalArrangement = Arrangement.spacedBy(m.lerp(12f, 16f).dp), verticalAlignment = Alignment.CenterVertically) {
        Text(if (restoring) "Restoring…" else "Restore Purchases", style = style, color = SoberColors.textTertiary,
            modifier = Modifier.testTagCompat("paywall.restore").pressable(enabled = !disabled, onClick = onRestore).padding(vertical = 8.dp))
        Text("·", style = style, color = SoberColors.textTertiary)
        Text("Terms", style = style, color = SoberColors.textTertiary, modifier = Modifier.pressable { context.openUrl(StoreLinks.TERMS_URL) }.padding(vertical = 8.dp))
        Text("·", style = style, color = SoberColors.textTertiary)
        Text("Privacy Policy", style = style, color = SoberColors.textTertiary, modifier = Modifier.pressable { context.openUrl(StoreLinks.PRIVACY_URL) }.padding(vertical = 8.dp))
    }
}

@Composable
private fun LoadingState(close: Boolean, footer: @Composable (PaywallMetrics) -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 22.dp).padding(top = if (close) 52.dp else 20.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.weight(1f))
        ProgressSpinner()
        Text("Loading plans…", style = SoberType.caption(), color = SoberColors.textSecondary)
        Spacer(Modifier.weight(1f))
        footer(PaywallMetrics.compact)
    }
}

@Composable
private fun EmptyState(error: String?, close: Boolean, footer: @Composable (PaywallMetrics) -> Unit, onRetry: () -> Unit) {
    Column(
        Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 22.dp).padding(top = if (close) 52.dp else 20.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Spacer(Modifier.weight(1f))
        SymbolIcon("wifi.exclamationmark", SoberColors.textTertiary, 40.dp)
        Text("Couldn't Load Plans", style = SoberType.body(FontWeight.SemiBold), color = SoberColors.textPrimary)
        Text(error ?: "Check your connection and try again.", style = SoberType.subhead(), color = SoberColors.textSecondary,
            textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 32.dp))
        Text("Try Again", style = SoberType.subhead(FontWeight.SemiBold), color = SoberColors.brandPrimary,
            modifier = Modifier.pressable(onClick = onRetry).padding(8.dp))
        Spacer(Modifier.weight(1f))
        footer(PaywallMetrics.compact)
    }
}

/** Debug only: no store key in this build, so a local unlock stands in. */
@Composable
private fun DevPlaceholder(focus: BloomFeature?, heroDays: Int, cents: Int, close: Boolean, onContinue: () -> Unit) {
    val m = PaywallMetrics.compact
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp).padding(top = if (close) 56.dp else 24.dp, bottom = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SavingsHeader(m, focus, heroDays, cents, heroDays)
        BenefitShowcase(m, focus, 3)
        Text("Prices come from Google Play and aren't available in this build.", style = SoberType.caption(FontWeight.SemiBold),
            color = SoberColors.textSecondary, textAlign = TextAlign.Center)
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(SoberBrushes.brand).pressable(onClick = onContinue).padding(vertical = 16.dp),
            contentAlignment = Alignment.Center,
        ) { Text("Continue (dev)", style = SoberType.body(FontWeight.Bold), color = Color.White) }
    }
}
