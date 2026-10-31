package com.jackwallner.sober

import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.data.SoberStore
import com.jackwallner.sober.data.StateFile
import com.jackwallner.sober.data.TrialLifecycle
import com.jackwallner.sober.data.passiveNudgeStillAllowed
import com.jackwallner.sober.model.SpendScale
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS c81b3e5 pieces that needed new Android API: trial count, spend scale, note sheet, nudge guard. */
class OvernightNewApiTest {
    private val zone = ZoneId.of("America/Los_Angeles")
    private fun at(day: Int, hour: Int): Instant = ZonedDateTime.of(2026, 9, day, hour, 0, 0, 0, zone).toInstant()
    private fun left(until: Instant, now: Instant): Int? = TrialLifecycle.daysRemaining(until, now, zone)

    // F03

    @Test fun theLastDayReadsToday() = assertEquals(0, left(at(9, 21), at(9, 9)))

    @Test fun theEveningBeforeReadsTomorrow() {
        assertEquals(1, left(at(9, 21), at(8, 21)))
        assertEquals(1, left(at(9, 9), at(8, 22)))
    }

    @Test fun twoCalendarDaysOutReadsTwo() = assertEquals(2, left(at(9, 9), at(7, 23)))

    @Test fun anEndedTrialHasNoCount() = assertNull(left(at(9, 9), at(9, 10)))

    @Test fun theCountSurvivesTheFallBackNight() {
        val ends = ZonedDateTime.of(2026, 11, 2, 8, 0, 0, 0, zone).toInstant()
        val now = ZonedDateTime.of(2026, 10, 31, 23, 0, 0, 0, zone).toInstant()
        assertEquals(2, left(ends, now))
        assertEquals(0, left(ends, ZonedDateTime.of(2026, 11, 2, 0, 30, 0, 0, zone).toInstant()))
    }

    // F04

    private class Case(val code: String, val perDollar: Double)

    @Test fun theRangeReachesARealDailySpend() {
        val cases = listOf(
            Case("VND", 25_000.0), Case("INR", 84.0), Case("RUB", 90.0), Case("CLP", 950.0),
            Case("UAH", 41.0), Case("USD", 1.0), Case("EUR", 0.92),
        )
        for (c in cases) {
            val scale = SpendScale(c.code)
            assertTrue(c.code, scale.maxDaily / c.perDollar >= 50)
            assertTrue(c.code, scale.defaultDaily * 365 / c.perDollar >= 100)
            assertTrue("${c.code} default overstates the habit", scale.defaultDaily / c.perDollar <= 60)
            assertEquals(c.code, 0, scale.maxDaily % scale.step)
        }
    }

    @Test fun anUnknownCurrencyKeepsTheDollarShape() {
        val scale = SpendScale(null)
        assertEquals(20, scale.defaultDaily)
        assertEquals(5, scale.step)
        assertEquals(200, scale.maxDaily)
    }

    // F05

    private fun store() = SoberStore(object : StateFile {
        override fun read(): String? = null
        override fun write(text: String) {}
        override fun keepUnreadable(text: String, stamp: Long) {}
    }, TestClock(), SoberContent.shared)

    private fun checkedIn(): SoberStore = store().also {
        it.persistSetup(it.clock.now().minusSeconds(3 * 86_400L), 100, 200, false)
        it.checkInToday()
    }

    @Test fun theSheetOpensOnTheSavedNote() {
        val store = checkedIn()
        store.addTodayDetail(4, "Craving at lunch, walked it off")
        assertEquals(4 to "Craving at lunch, walked it off", store.todayDetail())
    }

    @Test fun anEditKeepsWhatTheUserLeftInTheField() {
        val store = checkedIn()
        store.addTodayDetail(4, "Craving at lunch, walked it off")
        val opened = store.todayDetail().second.orEmpty()
        store.addTodayDetail(4, opened + "\nEvening was fine")
        assertEquals("Craving at lunch, walked it off\nEvening was fine", store.todayDetail().second)
    }

    @Test fun clearingTheFieldClearsTheNote() {
        val store = checkedIn()
        store.addTodayDetail(null, "draft")
        store.addTodayDetail(null, "   ")
        assertNull(store.todayDetail().second)
        assertTrue(store.hasCheckedIn())
    }

    @Test fun emptySaveOnAnUntouchedDayWritesNothing() {
        val store = store()
        store.persistSetup(store.clock.now().minusSeconds(3 * 86_400L), 100, 200, false)
        store.addTodayDetail(null, "")
        assertFalse(store.hasCheckedIn())
        assertEquals(null to null, store.todayDetail())
    }

    // F19

    @Test fun theNudgeRechecksItsCooldownAfterTheWait() {
        assertTrue(passiveNudgeStillAllowed(isPro = false, hasPendingRequest = false, cooldownElapsed = true))
        assertFalse(passiveNudgeStillAllowed(isPro = false, hasPendingRequest = false, cooldownElapsed = false))
        assertFalse(passiveNudgeStillAllowed(isPro = false, hasPendingRequest = true, cooldownElapsed = true))
        assertFalse(passiveNudgeStillAllowed(isPro = true, hasPendingRequest = false, cooldownElapsed = true))
    }
}
