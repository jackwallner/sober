package com.jackwallner.sober

import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.data.ConversionDiagnostics
import com.jackwallner.sober.data.InMemoryStore
import com.jackwallner.sober.data.NotificationService
import com.jackwallner.sober.data.PackageKind
import com.jackwallner.sober.data.PeriodUnit
import com.jackwallner.sober.data.Plan
import com.jackwallner.sober.data.PlanPeriod
import com.jackwallner.sober.data.ReminderPlatform
import com.jackwallner.sober.data.ReminderSpec
import com.jackwallner.sober.data.ReviewPromptTracker
import com.jackwallner.sober.data.SoberStore
import com.jackwallner.sober.data.StateFile
import com.jackwallner.sober.data.SubscriptionService
import com.jackwallner.sober.data.TrialLifecycle
import com.jackwallner.sober.data.TrialNudgeGate
import com.jackwallner.sober.model.CravingEpisode
import com.jackwallner.sober.model.CravingOutcome
import com.jackwallner.sober.model.DailyGrowth
import com.jackwallner.sober.model.HabitPriceComparison
import com.jackwallner.sober.model.InsightCopy
import com.jackwallner.sober.model.JourneyDays
import java.io.IOException
import java.time.Duration
import com.jackwallner.sober.ui.screens.displayWait
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Android-side ports of iOS helpers, pinned to the iOS strings and rules. */
class PortParityTest {
    private val clock = TestClock()

    private fun plan(kind: PackageKind, micros: Long, formatted: String, period: PlanPeriod?, trial: PlanPeriod? = null) =
        Plan(kind.name, "id.${kind.name}", kind, micros, formatted, "USD", period, trial)

    private val monthly = plan(PackageKind.MONTHLY, 9_990_000, "$9.99", PlanPeriod(1, PeriodUnit.MONTH), PlanPeriod(1, PeriodUnit.WEEK))
    private val yearly = plan(PackageKind.YEARLY, 29_990_000, "$29.99", PlanPeriod(1, PeriodUnit.YEAR), PlanPeriod(1, PeriodUnit.WEEK))
    private val lifetime = plan(PackageKind.LIFETIME, 69_990_000, "$69.99", null)

    @Test fun planLabelsMatchTheSwiftPackageExtensions() {
        Locale.setDefault(Locale.US)
        assertEquals("$9.99 / month", monthly.priceLabel)
        assertEquals("$29.99 / year", yearly.priceLabel)
        assertEquals("$69.99", lifetime.priceLabel)
        assertEquals("$2.50 / mo", yearly.perMonthLabel)
        assertNull(monthly.perMonthLabel)
        assertEquals(75, yearly.savingsPercent(monthly))
        assertEquals("$119.88", yearly.anchorPriceLabel(monthly))
        assertEquals("7-day free trial", yearly.introOfferLabel)
        assertEquals("14-day free trial", plan(PackageKind.YEARLY, 1, "", null, PlanPeriod(14, PeriodUnit.DAY)).introOfferLabel)
        assertEquals("1-month free trial", plan(PackageKind.YEARLY, 1, "", null, PlanPeriod(1, PeriodUnit.MONTH)).introOfferLabel)
        assertNull(lifetime.introOfferLabel)
    }

    @Test fun yearlyLeadsTheOneTapOffer() {
        assertEquals(PackageKind.YEARLY, SubscriptionService.preferredTrialPlan(listOf(monthly, yearly, lifetime))?.kind)
        assertEquals(PackageKind.MONTHLY, SubscriptionService.preferredTrialPlan(listOf(lifetime, monthly))?.kind)
        assertNull(SubscriptionService.preferredTrialPlan(emptyList()))
    }

    @Test fun habitComparisonNeverQuotesAnAmount() {
        assertEquals("A year of Bloom+ costs about a day and a half of drinking.", yearly.habitComparisonSentence(2000, "drinking"))
        assertNull(yearly.habitComparisonSentence(0, "drinking"))
        assertNull(lifetime.habitComparisonSentence(500, "drinking"))
        assertEquals("less than a day", HabitPriceComparison.dayCount(0.5))
        assertEquals("about a day", HabitPriceComparison.dayCount(1.0))
        assertEquals("about 2 days", HabitPriceComparison.dayCount(2.2))
        assertEquals("about 2 and a half days", HabitPriceComparison.dayCount(2.5))
    }

    @Test fun dailyGrowthPhrasesFollowTheCycleDay() {
        assertEquals("the seed is settling in", DailyGrowth.note(0))
        assertEquals("the trunk gained a hair of girth", DailyGrowth.note(25))
        assertEquals("the tree is complete, and the next cycle begins", DailyGrowth.note(365))
    }

    private class FakePlatform(var allowed: Boolean = true) : ReminderPlatform {
        val scheduled = mutableMapOf<String, ReminderSpec>()
        override fun canNotify() = allowed
        override fun schedule(spec: ReminderSpec) { scheduled[spec.id] = spec }
        override fun cancel(id: String) { scheduled.remove(id) }
    }

    @Test fun remindersUseTheIosCopyAndTiming() {
        val platform = FakePlatform()
        val now = clock.now().toEpochMilli()
        val service = NotificationService(platform, InMemoryStore(), { now }, { clock.zone() })
        service.scheduleDailyReminder(hour = 9, committed = true, streakDays = 12)
        val daily = platform.scheduled.getValue(NotificationService.DAILY_ID)
        assertEquals("Day 13 is waiting", daily.title)
        assertEquals("You're 12 days in. Log today and water your bonsai.", daily.body)
        assertTrue(daily.repeatsDaily && daily.fireAtMillis > now)

        service.scheduleMilestoneEve(currentDays = 5, milestoneDays = 7, milestoneTitle = "Strong Foundation", hour = 9)
        val eve = platform.scheduled.getValue(NotificationService.MILESTONE_EVE_ID)
        assertEquals("Tomorrow is day 7", eve.title)
        assertEquals(clock.today().plusDays(1), java.time.Instant.ofEpochMilli(eve.fireAtMillis).atZone(clock.zone()).toLocalDate())

        val ends = now + Duration.ofDays(7).toMillis()
        assertEquals(ends - Duration.ofDays(2).toMillis(), service.trialReminderFireDate(ends))
        assertEquals(now + Duration.ofHours(5).toMillis(), service.trialReminderFireDate(now + Duration.ofHours(10).toMillis()))
        assertNull(service.trialReminderFireDate(now + 1_000))

        service.markDelivered(NotificationService.DAILY_ID)
        assertTrue(platform.scheduled.getValue(NotificationService.DAILY_ID).fireAtMillis > daily.fireAtMillis)

        service.cancelDailyReminder()
        service.refreshDailyReminder(9, true, 3)
        assertFalse(NotificationService.DAILY_ID in platform.scheduled)
    }

    @Test fun nothingIsScheduledWithoutPermission() {
        val platform = FakePlatform(allowed = false)
        val service = NotificationService(platform, InMemoryStore())
        service.scheduleDailyReminder(9)
        service.scheduleLapseNudge(4)
        assertTrue(platform.scheduled.isEmpty())
    }

    @Test fun reviewPromptKeepsTheIosGates() {
        val defaults = InMemoryStore()
        val tracker = ReviewPromptTracker(defaults, clock)
        tracker.recordAppLaunch()
        tracker.recordPositiveMoment()
        assertFalse(tracker.shouldShowAfterPositiveMoment(true))
        tracker.recordAppLaunch()
        tracker.recordPositiveMoment(isMilestone = true)
        assertTrue(tracker.shouldShowAfterPositiveMoment(true))
        assertFalse(tracker.shouldShowAfterPositiveMoment(false))
        tracker.markShown()
        tracker.recordPositiveMoment(isMilestone = true)
        assertFalse(tracker.shouldShowAfterPositiveMoment(true))
        clock.instant = clock.instant.plus(Duration.ofDays(121))
        assertTrue(tracker.shouldShowAfterPositiveMoment(true))
    }

    @Test fun passiveNudgesBackOffOnTheIosSchedule() {
        val gate = TrialNudgeGate(InMemoryStore(), clock)
        assertTrue(gate.canShow())
        gate.markShown()
        clock.instant = clock.instant.plus(Duration.ofHours(47))
        assertFalse(gate.canShow())
        clock.instant = clock.instant.plus(Duration.ofHours(2))
        assertTrue(gate.canShow())
        gate.markShown()
        clock.instant = clock.instant.plus(Duration.ofHours(49))
        assertFalse(gate.canShow())
    }

    @Test fun trialRecapShowsOnlyInTheFinalStretch() {
        val platform = FakePlatform()
        val defaults = InMemoryStore()
        val trial = TrialLifecycle(defaults, clock, NotificationService(platform, defaults, { clock.now().toEpochMilli() }, { clock.zone() }))
        trial.sync(isTrialing = true, endsAt = clock.now().plus(Duration.ofDays(7)).toEpochMilli())
        assertFalse(trial.shouldShowRecap())
        assertTrue(NotificationService.TRIAL_ENDING_ID in platform.scheduled)
        clock.instant = clock.instant.plus(Duration.ofDays(5))
        assertTrue(trial.shouldShowRecap())
        trial.dismissRecap()
        assertFalse(trial.shouldShowRecap())
        trial.sync(isTrialing = false, endsAt = null)
        assertFalse(NotificationService.TRIAL_ENDING_ID in platform.scheduled)
    }

    @Test fun funnelAttributesUseTheFleetKeys() {
        val diagnostics = ConversionDiagnostics(InMemoryStore(), clock)
        assertTrue(diagnostics.subscriberAttributes.isEmpty())
        diagnostics.recordAppOpen()
        diagnostics.recordPitchView("sober_bloom_tab")
        diagnostics.recordConversion("com.jackwallner.sober.pro.yearly", startedTrial = true, offeringId = "android")
        val attributes = diagnostics.subscriberAttributes
        assertEquals("1", attributes["pitch_views_bloom_tab"])
        assertEquals("bloom_tab", attributes["converted_surface"])
        assertEquals("true", attributes["converted_with_trial"])
    }

    @Test fun insightsReadTheUsersOwnLog() {
        val zone = clock.zone()
        val episodes = (0 until 5).map { index ->
            val start = clock.today().minusDays(index.toLong() + 1).atTime(19, 0).atZone(zone).toInstant()
            CravingEpisode(startedAt = start, endedAt = start.plusSeconds(240), outcome = CravingOutcome.RODE_IT_OUT, trigger = "Stress", secondsElapsed = 240)
        } + CravingEpisode(startedAt = clock.today().atTime(8, 0).atZone(zone).toInstant(), endedAt = clock.now(), outcome = CravingOutcome.GAVE_IN, secondsElapsed = 60)
        val insights = InsightCopy.insights(episodes, emptyList(), clock.now(), zone, "craving", "cravings", "a drink", Locale.US)
        assertEquals("5 of 6 ridden out", insights.first { it.id == "rate" }.headline)
        assertEquals("Hardest between 5 PM and 8 PM", insights.first { it.id == "window" }.headline)
        assertEquals("Yours usually pass in about 4 minutes", insights.first { it.id == "length" }.headline)
        assertEquals("Stress comes up most", insights.first { it.id == "trigger" }.headline)
        assertEquals("Fridays", InsightCopy.weekdayLabel(6, Locale.US))
    }

    private class MemoryFile(var text: String? = null, var failWrites: Boolean = false) : StateFile {
        override fun read(): String? = text
        override fun write(text: String) { if (failWrites) throw IOException("full") else this.text = text }
        override fun keepUnreadable(text: String, stamp: Long) = Unit
    }

    @Test fun storeFlowsMatchTheIosServices() {
        val file = MemoryFile()
        val store = SoberStore(file, clock, SoberContent.shared)
        store.persistSetup(clock.today().minusDays(9).atStartOfDay(clock.zone()).toInstant(), 2000, 600, false)
        store.persistSetup(clock.today().minusDays(9).atStartOfDay(clock.zone()).toInstant(), 2000, 600, false)
        assertEquals(1, store.state.journeys.size)
        assertEquals(10, store.days)
        store.refresh()
        assertEquals(9, store.state.checkIns.size)
        store.checkInToday()
        assertTrue(store.hasCheckedIn())
        val outcome = store.recordSlip(clock.today())
        assertEquals(10, outcome.previousStreakDays)
        assertEquals(5, outcome.carryoverDays)
        assertTrue(store.loggedSlip())
        assertTrue(store.undoSlip(clock.today()))
        assertEquals(10, JourneyDays.current(store.state, clock))

        file.failWrites = true
        assertFalse(store.resetCounter())
        assertEquals(SoberStore.SAVE_FAILED, store.message)
        assertEquals(10, store.days)
    }

    @Test fun unreadableRecordsAreKeptAndBlockWrites() {
        val store = SoberStore(MemoryFile("{not json"), clock, SoberContent.shared)
        assertTrue(store.message!!.contains("saved record"))
        assertFalse(store.update { it.copy(settings = it.settings.copy(caloriesPerDay = 1)) })
    }

    @Test fun healthWaitLabelsMatchSwift() {
        val labels = SoberContent.shared.health.map { it.displayWait }
        assertEquals("6h", labels.first())
        assertEquals("1y", labels.last())
    }
}
