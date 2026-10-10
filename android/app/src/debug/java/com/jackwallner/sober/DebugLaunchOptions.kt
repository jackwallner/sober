package com.jackwallner.sober

import android.content.Intent
import com.jackwallner.sober.data.PackageKind
import com.jackwallner.sober.data.PeriodUnit
import com.jackwallner.sober.data.Plan
import com.jackwallner.sober.data.PlanPeriod
import com.jackwallner.sober.model.JournalEntry
import com.jackwallner.sober.model.JournalKind
import com.jackwallner.sober.model.SoberEngine
import com.jackwallner.sober.model.SoberState

/**
 * Debug-only launch extras, the Android side of the iOS launch arguments.
 * None of this is compiled into a release or QA build.
 *
 *     adb shell am start -n com.jackwallner.sober/.MainActivity \
 *         --ez resetAll true --ez seedDemo true --ei seedDays 127 --ez demoPro true --ei tab 4
 */
object DebugLaunchOptions {
    var launchTab: Int? = null
        private set
    var showProgress: Boolean = false
        private set
    var onboardingStep: Int? = null
        private set
    var gallery: Boolean = false
        private set

    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("uiTest")) graph.review.isAutomationRun = true
        if (extras.getBoolean("resetAll")) {
            graph.store.update { SoberState() }
            graph.defaults.keys().forEach(graph.defaults::remove)
        }
        if (extras.getBoolean("demoPro")) graph.subscriptions.forceProForDebug()
        if (extras.getBoolean("previewStore")) {
            val trialDays = extras.getInt("previewTrialDays", 7)
            graph.subscriptions.loadPreviewPlans(previewPlans(trialDays), history = extras.getBoolean("previewTrialUsed"))
        }
        if (extras.getBoolean("seedDemo") && !graph.store.hasCompletedOnboarding) seed(graph, extras.getInt("seedDays", 24))
        if (extras.getBoolean("seedCravings")) seedCravings(graph)
        // Rewind the growth watermark so Home replays a celebration (`--ei watermark 10`).
        if (extras.containsKey("watermark")) {
            val mark = extras.getInt("watermark")
            graph.store.update { it.copy(garden = it.garden.copy(watermark = mark)) }
        }
        if (extras.containsKey("testReminderIn")) {
            graph.notifications.scheduleForTesting(extras.getString("testReminderId") ?: "sober.lapse-nudge", extras.getInt("testReminderIn"))
        }
        if (extras.containsKey("tab")) launchTab = extras.getInt("tab")
        showProgress = extras.getBoolean("showProgress")
        gallery = extras.getBoolean("gallery")
        if (extras.containsKey("onboardingStep")) onboardingStep = extras.getInt("onboardingStep")
    }

    /** `-seedDemo -seedDays N`: one number drives counter, calendar, health, and savings. */
    private fun seed(graph: AppGraph, days: Int) {
        val clock = graph.clock
        val start = clock.today().minusDays(days.toLong()).atStartOfDay(clock.zone()).toInstant()
        graph.store.update { old ->
            var next = SoberEngine.startJourney(old, start, clock)
            next = SoberEngine.fillJourney(next, clock.today(), clock)
            next = next.copy(settings = next.settings.copy(
                costPerDayCents = 2000,
                caloriesPerDay = 600,
                madeCommitment = true,
                hasCompletedOnboarding = true,
            ))
            val entries = listOf(
                Triple(1L, "Went to Dan's birthday and stayed with soda water the whole night. Nobody cared. I drove myself home and woke up clear.", "good"),
                Triple(6L, "Rough day at work and the old reflex showed up around 6pm. Went for a walk instead. It passed in about twenty minutes.", "neutral"),
                Triple(13L, "Slept a full eight hours for the first time in years. That alone is worth it.", "excellent"),
            ).filter { it.first <= days }.map { (daysAgo, text, feeling) ->
                JournalEntry(createdAt = clock.now().minusSeconds(daysAgo * 86_400), kind = JournalKind.DAILY, text = text, feeling = feeling)
            }
            next.copy(journal = entries)
        }
    }

    private fun seedCravings(graph: AppGraph) {
        val clock = graph.clock
        val triggers = listOf("After work", "Stress", "After work", "Social event", "After work", "Boredom")
        graph.store.update { old ->
            triggers.foldIndexed(old) { index, state, trigger ->
                val started = clock.today().minusDays((index * 2 + 1).toLong()).atTime(18 + index % 3, 10).atZone(clock.zone()).toInstant()
                state.copy(cravings = state.cravings + com.jackwallner.sober.model.CravingEpisode(
                    startedAt = started,
                    endedAt = started.plusSeconds(200L + index * 20),
                    intensity = 2 + index % 3,
                    outcome = if (index == 3) com.jackwallner.sober.model.CravingOutcome.GAVE_IN else com.jackwallner.sober.model.CravingOutcome.RODE_IT_OUT,
                    trigger = trigger,
                    secondsElapsed = 200 + index * 20,
                ))
            }
        }
    }

    /** `PaywallPreviewStore`: the Android US ladder, so the real paywall renders without a store. */
    private fun previewPlans(trialDays: Int): List<Plan> {
        val trial = if (trialDays % 7 == 0) PlanPeriod(trialDays / 7, PeriodUnit.WEEK) else PlanPeriod(maxOf(1, trialDays), PeriodUnit.DAY)
        return listOf(
            Plan("\$rc_annual", "com.jackwallner.sober.pro.yearly", PackageKind.YEARLY, 24_990_000, "$24.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), trial, "Bloom+ Yearly"),
            Plan("\$rc_monthly", "com.jackwallner.sober.pro.monthly", PackageKind.MONTHLY, 7_990_000, "$7.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), trial, "Bloom+ Monthly"),
            Plan("\$rc_lifetime", "com.jackwallner.sober.pro.lifetime", PackageKind.LIFETIME, 54_990_000, "$54.99", "USD", null, null, "Bloom+ Lifetime"),
        )
    }
}
