package com.jackwallner.sober

import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.data.SoberStore
import com.jackwallner.sober.data.StateFile
import com.jackwallner.sober.model.AppClock
import com.jackwallner.sober.model.GardenState
import com.jackwallner.sober.model.JourneyDays
import com.jackwallner.sober.model.SoberEngine
import com.jackwallner.sober.model.SoberState
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS c81b3e5 (the 2026-10-30 overnight bug hunt), on the Android engine and store. */
class OvernightRegressionTest {
    private class MovableClock(var instant: Instant, var timeZone: ZoneId) : AppClock {
        override fun now(): Instant = instant
        override fun zone(): ZoneId = timeZone
    }

    private class MemoryFile : StateFile {
        override fun read(): String? = null
        override fun write(text: String) {}
        override fun keepUnreadable(text: String, stamp: Long) {}
    }

    private val clock = TestClock()
    private fun day(daysAgo: Long): LocalDate = clock.today().minusDays(daysAgo)
    private fun journey(daysAgo: Long): SoberState = SoberEngine.startJourney(SoberState(), day(daysAgo).atStartOfDay(clock.zone()).toInstant(), clock)
    private fun store(on: AppClock = clock) = SoberStore(MemoryFile(), on, SoberContent.shared)

    // F01: DST and skipped midnights. Check-in days are LocalDates here, never instants.

    private val dstCases = listOf(
        "America/Los_Angeles" to LocalDate.of(2026, 3, 8),
        "America/Los_Angeles" to LocalDate.of(2026, 11, 1),
        "America/Santiago" to LocalDate.of(2026, 9, 6),
        "America/Havana" to LocalDate.of(2026, 3, 8),
        "Africa/Cairo" to LocalDate.of(2026, 4, 24),
    )

    @Test fun fillingNeverTouchesALoggedDayAcrossDaylightSaving() {
        for ((id, change) in dstCases) {
            val zone = ZoneId.of(id)
            val now = change.plusDays(7).atTime(12, 0).atZone(zone).toInstant()
            val dst = MovableClock(now, zone)
            val today = dst.today()
            var state = SoberEngine.startJourney(SoberState(), today.minusDays(14).atStartOfDay(zone).toInstant(), dst)
            state = SoberEngine.checkIn(state, today.minusDays(10), mood = 4, note = "good day")
            state = SoberEngine.checkIn(state, change, wasSober = false, note = "slipped at the party")

            val filled = SoberEngine.fillJourney(state, today.minusDays(1), dst)

            assertEquals(id, 14, filled.checkIns.size)
            assertEquals(id, (1L..14L).map { today.minusDays(it) }.sorted(), filled.checkIns.map { it.day })
            val good = filled.checkIns.first { it.day == today.minusDays(10) }
            assertTrue(id, good.wasLogged)
            assertEquals(id, 4, good.mood)
            assertEquals(id, "good day", good.note)
            val slip = filled.checkIns.first { it.day == change }
            assertFalse(id, slip.wasSober)
            assertEquals(id, "slipped at the party", slip.note)
            assertEquals(id, filled, SoberEngine.fillJourney(filled, today.minusDays(1), dst))
        }
    }

    // F02: a westward or far-eastward zone change must not duplicate or lose history.

    @Test fun travellingDoesNotDuplicateHistory() {
        for (target in listOf("Pacific/Honolulu", "Pacific/Auckland", "Asia/Tokyo", "Europe/London")) {
            val home = MovableClock(Instant.parse("2026-10-30T20:00:00Z"), ZoneId.of("America/Los_Angeles"))
            val store = store(home)
            store.persistSetup(home.today().minusDays(20).atStartOfDay(home.zone()).toInstant(), 2000, 600, false)
            store.refresh()
            store.checkInToday()
            store.addTodayDetail(4, "before the trip")
            val lifetimeBefore = store.lifetimeSoberDays

            home.timeZone = ZoneId.of(target)
            store.refresh()

            val days = store.state.checkIns.map { it.day }
            assertEquals(target, days.distinct().size, days.size)
            assertTrue(target, store.lifetimeSoberDays - lifetimeBefore in 0..1)
            assertEquals(target, "before the trip", store.state.checkIns.first { it.note != null }.note)
        }
    }

    // F05: the note sheet saves an edit, it never turns a slip day sober.

    @Test fun aNoteOnASlipDayLeavesTheSlip() {
        val store = store()
        store.persistSetup(day(3).atStartOfDay(clock.zone()).toInstant(), 100, 200, false)
        store.logCheckIn(store.today, wasSober = false, mood = null, note = null)

        store.addTodayDetail(2, "Tomorrow is day one")

        assertTrue(store.loggedSlip())
        assertEquals("Tomorrow is day one", store.checkIn(store.today)?.note)
    }

    // F08: an older slip entered after a newer one leaves the live tree and the undo snapshot alone.

    @Test fun anOlderSlipLeavesTheLiveTree() {
        val first = SoberEngine.recordSlip(journey(26), day(10), clock)
        val second = SoberEngine.recordSlip(first, day(20), clock)

        assertEquals(10, JourneyDays.current(second, clock))
        assertEquals(first.garden.carryoverDays, second.garden.carryoverDays)
        assertEquals(first.garden.carryoverBeforeSlip, second.garden.carryoverBeforeSlip)
        assertEquals(first.garden.groveCountAtJourneyStart, second.garden.groveCountAtJourneyStart)
        assertEquals(first.garden.vitality, second.garden.vitality, 0.0)
    }

    // F09: Home appearing three times on one day costs one day's fade.

    @Test fun vitalityFadesOncePerMissedDay() {
        val watered = SoberState(garden = GardenState(vitality = 1.0, lastWateredAt = clock.now().minusSeconds(2 * 86_400L)))
        val once = SoberEngine.decayVitality(watered, clock)
        val thrice = SoberEngine.decayVitality(SoberEngine.decayVitality(once, clock), clock)

        assertEquals(0.8, once.garden.vitality, 0.0001)
        assertEquals(once.garden.vitality, thrice.garden.vitality, 0.0)
    }

    @Test fun aLaterMissedDayIsChargedAndWateringStartsOver() {
        val watered = SoberState(garden = GardenState(vitality = 1.0, lastWateredAt = clock.now().minusSeconds(2 * 86_400L)))
        val twoDays = SoberEngine.decayVitality(watered, clock)
        clock.instant = clock.instant.plusSeconds(86_400L)
        val threeDays = SoberEngine.decayVitality(twoDays, clock)
        assertEquals(0.7, threeDays.garden.vitality, 0.0001)

        val rewatered = SoberEngine.water(threeDays, clock)
        assertEquals(0, rewatered.garden.vitalityDecayDays)
        clock.instant = clock.instant.plusSeconds(86_400L)
        assertEquals(rewatered.garden.vitality - 0.1, SoberEngine.decayVitality(rewatered, clock).garden.vitality, 0.0001)
    }

    // F10: streak badges say "check-ins", so assumed days do not earn them.

    @Test fun checkInBadgesNeedCheckIns() {
        val store = store()
        store.persistSetup(day(120).atStartOfDay(clock.zone()).toInstant(), 100, 200, false)
        store.refresh(applyDecay = false)

        val ids = store.state.earnedAchievementIds
        assertFalse(ids.contains("perfect-week"))
        assertFalse(ids.contains("consistency-champion"))
        assertFalse(ids.contains("diamond-discipline"))
        assertTrue(ids.contains("quarter-master"))
    }
}
