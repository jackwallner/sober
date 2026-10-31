package com.jackwallner.sober.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sober.model.AppClock
import com.jackwallner.sober.content.HabitWords
import kotlinx.coroutines.delay

/**
 * Bloom+ capabilities, the single source of the paywall's benefit copy. The
 * declaration order is the paywall's priority order, as on iOS.
 */
enum class BloomFeature(val icon: String) {
    PATTERNS("chart.bar.xaxis"),
    HEALTH_TIMELINE("heart.text.square.fill"),
    SAVINGS_TRACKING("chart.line.uptrend.xyaxis"),
    JOURNAL("book.closed.fill"),
    GARDEN_SPECIES("leaf.fill");

    fun title(words: HabitWords): String = when (this) {
        PATTERNS -> "Your ${words.urge} patterns"
        GARDEN_SPECIES -> "All 6 bonsai species"
        HEALTH_TIMELINE -> "Full health timeline"
        JOURNAL -> "Daily journal"
        SAVINGS_TRACKING -> "Your year ahead"
    }

    val detail: String
        get() = when (this) {
            PATTERNS -> "When they hit, what sets them off, how long yours last."
            GARDEN_SPECIES -> "Switch your tree as your streak grows."
            HEALTH_TIMELINE -> "13 recovery milestones with sources."
            JOURNAL -> "Prompts and reflections on hard days."
            SAVINGS_TRACKING -> "What you'll have kept by this time next year."
        }

    val pitchHeadline: String
        get() = when (this) {
            PATTERNS -> "Learn your own pattern."
            GARDEN_SPECIES -> "Grow every species."
            HEALTH_TIMELINE -> "See what's coming back."
            JOURNAL -> "Write through the urges."
            SAVINGS_TRACKING -> "See where this goes."
        }

    fun pitchSubheadline(words: HabitWords): String = when (this) {
        PATTERNS -> "See when your ${words.urges} hit, what sets them off, and how long yours actually last, plus the rest of Bloom+."
        GARDEN_SPECIES -> "Unlock every bonsai species and switch whenever you like, plus the rest of Bloom+."
        HEALTH_TIMELINE -> "Unlock the full 13-milestone recovery timeline, plus the rest of Bloom+."
        JOURNAL -> "Daily journal prompts when you need them most, plus the rest of Bloom+."
        SAVINGS_TRACKING -> "Project your money, calories, and tree a year out, plus the rest of Bloom+."
    }

    /** RevenueCat impression id for a pitch led by this feature. */
    val impressionId: String
        get() = when (this) {
            PATTERNS -> "sober_paywall_patterns"
            GARDEN_SPECIES -> "sober_paywall_garden"
            HEALTH_TIMELINE -> "sober_paywall_health"
            JOURNAL -> "sober_paywall_journal"
            SAVINGS_TRACKING -> "sober_paywall_savings"
        }
}

enum class PitchIntent(val raw: String) {
    POST_ONBOARDING("postOnboarding"),
    JOURNAL("journal"),
    HEALTH_TIMELINE("healthTimeline"),
    GARDEN_SPECIES("gardenSpecies"),
    PROGRESS_SHEET("progressSheet"),
    SETTINGS("settings"),
    GROWTH_CELEBRATION("growthCelebration"),
    CHECK_IN_MILESTONE("checkInMilestone"),
    CRAVING_RELIEF("cravingRelief"),
    PATTERNS("patterns");

    val focusFeature: BloomFeature?
        get() = when (this) {
            JOURNAL -> BloomFeature.JOURNAL
            HEALTH_TIMELINE -> BloomFeature.HEALTH_TIMELINE
            GARDEN_SPECIES -> BloomFeature.GARDEN_SPECIES
            PROGRESS_SHEET -> BloomFeature.SAVINGS_TRACKING
            CRAVING_RELIEF, PATTERNS -> BloomFeature.PATTERNS
            POST_ONBOARDING, SETTINGS, GROWTH_CELEBRATION, CHECK_IN_MILESTONE -> null
        }
}

enum class PitchPolicy { INITIAL, EXPLICIT_UPGRADE, SUBSEQUENT_LOCKED, SUBSEQUENT_PASSIVE }

data class PitchRequest(val intent: PitchIntent, val policy: PitchPolicy)

/**
 * Where any screen asks for a Bloom+ pitch. The tab host owns the paywall
 * sheet and resolves requests, so pitches never stack on one another.
 */
class TrialOfferCoordinator {
    var pendingRequest by mutableStateOf<PitchRequest?>(null)

    /** True while the paywall sheet is on screen. */
    var isPresentingSheet by mutableStateOf(false)

    fun request(intent: PitchIntent, policy: PitchPolicy = PitchPolicy.SUBSEQUENT_LOCKED) {
        pendingRequest = PitchRequest(intent, policy)
    }

    fun requestLockedFeature(intent: PitchIntent) = request(intent, PitchPolicy.SUBSEQUENT_LOCKED)

    fun clear() {
        pendingRequest = null
    }
}

/** The escalating passive-nudge cooldown: 48h, 72h, 5d, 7d, then 14d. */
class TrialNudgeGate(private val defaults: KeyValueStore, private val clock: AppClock) {
    private val shownCount: Int get() = defaults.getInt(COUNT)

    fun canShow(): Boolean {
        if (!defaults.contains(LAST)) return true
        val index = minOf(maxOf(shownCount, 1), SCHEDULE_HOURS.size) - 1
        return clock.now().toEpochMilli() - defaults.getLong(LAST) >= SCHEDULE_HOURS[index] * 3_600_000L
    }

    fun markShown() {
        defaults.putLong(LAST, clock.now().toEpochMilli())
        defaults.putInt(COUNT, shownCount + 1)
    }

    private companion object {
        val SCHEDULE_HOURS = listOf(48L, 72L, 120L, 168L, 336L)
        const val LAST = "lastTrialNudgeAt"
        const val COUNT = "trialNudgeCount"
    }
}

class TrialSubsequentPitchGate(private val defaults: KeyValueStore, private val nudges: TrialNudgeGate) {
    private val sessionCounts = mutableMapOf<String, Int>()

    fun actionCount(intent: PitchIntent): Int = defaults.getInt(actionKey(intent))

    fun recordAction(intent: PitchIntent): Int {
        val next = actionCount(intent) + 1
        defaults.putInt(actionKey(intent), next)
        return next
    }

    fun canPresentTrialPitch(intent: PitchIntent): Boolean = (sessionCounts[intent.raw] ?: 0) < MAX_PER_INTENT_PER_SESSION

    fun markTrialPitchPresented(intent: PitchIntent) {
        sessionCounts[intent.raw] = (sessionCounts[intent.raw] ?: 0) + 1
        nudges.markShown()
    }

    fun incrementPersistedCount(key: String): Int {
        val next = defaults.getInt(key) + 1
        defaults.putInt(key, next)
        return next
    }

    private fun actionKey(intent: PitchIntent) = "bloomActionCount_${intent.raw}"

    companion object {
        const val LOCKED_FEATURE_THRESHOLD = 2
        const val PASSIVE_USAGE_THRESHOLD = 2
        const val MAX_PER_INTENT_PER_SESSION = 2

        const val POST_ONBOARDING_PAYWALL_KEY = "postOnboardingPaywallPending"
        const val JOURNAL_TAB_VISIT_COUNT_KEY = "journalTabVisitCount"
        const val CHECK_IN_COMPLETED_COUNT_KEY = "checkInCompletedCount"
        const val GROWTH_CELEBRATION_COUNT_KEY = "growthCelebrationCount"
        const val CRAVING_RODE_OUT_COUNT_KEY = "cravingRodeOutCount"
    }
}

/**
 * `presentPassiveTrialNudge` and `evaluateUsageBasedTrialPitch` from
 * BloomFeature.swift, with the same guards before and after the delay.
 */
class PitchScheduler(
    private val subscriptions: SubscriptionService,
    private val coordinator: TrialOfferCoordinator,
    private val nudges: TrialNudgeGate,
    private val gate: TrialSubsequentPitchGate,
) {
    suspend fun passiveNudge(intent: PitchIntent, delaySeconds: Double = 4.0) {
        if (subscriptions.isPro || subscriptions.hasClaimedTrial || !subscriptions.hasTrialOfferAvailable ||
            coordinator.pendingRequest != null || !nudges.canShow()
        ) return
        delay((delaySeconds * 1000).toLong())
        // Checked again after the wait: a paywall shown and closed inside it
        // restarted the cooldown, and this one would follow it straight away.
        if (!passiveNudgeStillAllowed(subscriptions.isPro, coordinator.pendingRequest != null, nudges.canShow())) return
        coordinator.request(intent, PitchPolicy.SUBSEQUENT_PASSIVE)
    }

    suspend fun usageBased(
        intent: PitchIntent,
        usageCount: Int,
        threshold: Int = TrialSubsequentPitchGate.PASSIVE_USAGE_THRESHOLD,
        delaySeconds: Double = 1.5,
    ) {
        fun allowed() = !subscriptions.isPro && coordinator.pendingRequest == null && nudges.canShow() && gate.canPresentTrialPitch(intent)
        if (!allowed() || subscriptions.hasClaimedTrial || !subscriptions.hasTrialOfferAvailable || usageCount < threshold) return
        delay((delaySeconds * 1000).toLong())
        if (!allowed()) return
        coordinator.request(intent, PitchPolicy.SUBSEQUENT_PASSIVE)
    }
}

/** The guard `PitchScheduler.passiveNudge` re-runs once its delay has passed. */
internal fun passiveNudgeStillAllowed(isPro: Boolean, hasPendingRequest: Boolean, cooldownElapsed: Boolean): Boolean =
    !isPro && !hasPendingRequest && cooldownElapsed
