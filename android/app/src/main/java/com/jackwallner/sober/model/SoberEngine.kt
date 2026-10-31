package com.jackwallner.sober.model

import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit

object SoberEngine {
    fun startJourney(state: SoberState, start: Instant, clock: AppClock): SoberState {
        val now = clock.now()
        val active = JourneyDays.active(state)
        val ended = state.journeys.map { if (it.id == active?.id) it.copy(end = now) else it }
        return state.copy(journeys = ended + Journey(start = minOf(start, now)))
    }

    fun changeStart(state: SoberState, start: Instant, clock: AppClock): SoberState {
        val active = JourneyDays.active(state) ?: return state
        return state.copy(journeys = state.journeys.map {
            if (it.id == active.id) it.copy(start = minOf(start, clock.now())) else it
        })
    }

    fun resetCounter(state: SoberState, clock: AppClock): SoberState {
        val restarted = startJourney(state, clock.now(), clock)
        return restarted.copy(garden = state.garden.copy(
            carryoverDays = 0,
            carryoverBeforeSlip = 0,
            watermark = 0,
            groveCountAtJourneyStart = state.garden.completedTreeStyles.size,
            vitality = 1.0,
            lastWateredAt = null,
        ))
    }

    fun checkIn(
        state: SoberState,
        day: LocalDate,
        wasSober: Boolean = true,
        mood: Int? = null,
        note: String? = null,
        logged: Boolean = true,
    ): SoberState {
        val old = state.checkIns.firstOrNull { it.day == day }
        val entry = CheckIn(
            day = day,
            wasSober = wasSober,
            mood = mood?.coerceIn(1, 5) ?: old?.mood,
            note = note ?: old?.note,
            wasLogged = logged || old?.wasLogged == true,
        )
        return state.copy(checkIns = (state.checkIns.filterNot { it.day == day } + entry).sortedBy { it.day })
    }

    /** The mood and note saved for a day, so the note sheet opens on what is already there. */
    fun detail(state: SoberState, day: LocalDate): Pair<Int?, String?> =
        state.checkIns.firstOrNull { it.day == day }?.let { it.mood to it.note } ?: (null to null)

    /**
     * Saves the note sheet's edit exactly as written: a cleared note clears and
     * the day's sober or slip answer is left alone. [checkIn] keeps an old note
     * for a null one and marks the day sober, which is right for a tap and wrong
     * for an edit.
     */
    fun saveDetail(state: SoberState, day: LocalDate, mood: Int?, note: String?): SoberState {
        val text = note?.trim()?.ifEmpty { null }
        val old = state.checkIns.firstOrNull { it.day == day }
        if (old == null && mood == null && text == null) return state
        val entry = (old ?: CheckIn(day)).copy(mood = mood?.coerceIn(1, 5), note = text, wasLogged = true)
        return state.copy(checkIns = (state.checkIns.filterNot { it.day == day } + entry).sortedBy { it.day })
    }

    fun fillJourney(state: SoberState, through: LocalDate, clock: AppClock): SoberState {
        val start = JourneyDays.active(state)?.start?.atZone(clock.zone())?.toLocalDate() ?: return state
        if (start > through) return state
        val existing = state.checkIns.associateBy { it.day }.toMutableMap()
        var day = start
        while (day <= through) {
            if (day !in existing) existing[day] = CheckIn(day, wasLogged = false)
            day = day.plusDays(1)
        }
        return state.copy(checkIns = existing.values.sortedBy { it.day })
    }

    fun backfillSoberDays(state: SoberState, through: LocalDate): SoberState {
        val last = state.checkIns.filter { it.wasLogged }.maxByOrNull { it.day }?.day
        var day = last?.plusDays(1) ?: through
        val entries = state.checkIns.associateBy { it.day }.toMutableMap()
        while (day <= through) {
            val old = entries[day]
            if (old == null) entries[day] = CheckIn(day)
            else if (old.wasSober) entries[day] = old.copy(wasLogged = true)
            day = day.plusDays(1)
        }
        return state.copy(checkIns = entries.values.sortedBy { it.day })
    }

    fun hasCheckedIn(state: SoberState, day: LocalDate): Boolean = state.checkIns.any { it.day == day && it.wasLogged }

    fun loggedSlip(state: SoberState, day: LocalDate): Boolean =
        state.checkIns.any { it.day == day && it.wasLogged && !it.wasSober }

    fun lifetimeSoberDays(state: SoberState): Int = state.checkIns.count { it.wasSober }

    fun daysSinceLastCheckIn(state: SoberState, clock: AppClock): Int {
        val last = state.checkIns.filter { it.wasLogged }.maxByOrNull { it.day }?.day ?: return 0
        return maxOf(0, ChronoUnit.DAYS.between(last, clock.today()).toInt())
    }

    fun water(state: SoberState, clock: AppClock): SoberState = state.copy(garden = state.garden.copy(
        vitality = minOf(1.0, state.garden.vitality + 0.25), lastWateredAt = clock.now(), vitalityDecayDays = 0,
    ))

    fun decayVitality(state: SoberState, clock: AppClock): SoberState {
        val last = state.garden.lastWateredAt ?: return state
        val missed = ChronoUnit.DAYS.between(last.atZone(clock.zone()).toLocalDate(), clock.today()).toInt()
        val uncharged = missed - state.garden.vitalityDecayDays
        if (uncharged <= 0) return state
        return state.copy(garden = state.garden.copy(
            vitality = maxOf(0.3, state.garden.vitality - uncharged * 0.1),
            vitalityDecayDays = missed,
        ))
    }

    fun recordSlip(
        state: SoberState,
        requestedDay: LocalDate,
        clock: AppClock,
        mood: Int? = null,
        note: String? = null,
    ): SoberState {
        val day = minOf(requestedDay, clock.today())
        if (loggedSlip(state, day)) return checkIn(state, day, wasSober = false, mood = mood, note = note)
        val previousStreak = JourneyDays.at(state, day, clock.zone())
        var next = checkIn(state, day, wasSober = false, mood = mood, note = note)
        val latestSlip = next.checkIns.filter { it.wasLogged && !it.wasSober }.maxOf { it.day }
        val restartDay = maxOf(day, latestSlip).plusDays(1)
        val active = JourneyDays.active(next)
        val alreadyRestarted = active != null && active.start.atZone(clock.zone()).toLocalDate() >= restartDay
        if (!alreadyRestarted) {
            val endingOn = minOf(day.atStartOfDay(clock.zone()).toInstant(), clock.now())
            val journeys = next.journeys.map {
                if (it.id == active?.id) it.copy(end = maxOf(it.start, endingOn), resetReason = "slip") else it
            }
            val start = minOf(restartDay.atStartOfDay(clock.zone()).toInstant(), clock.now())
            next = next.copy(journeys = journeys + Journey(start = start))
        }
        // An older slip leaves the live run, and so the live tree, as it was.
        if (alreadyRestarted) return next
        val had = GardenGrowth.treeDays(previousStreak, state.garden.carryoverDays)
        return next.copy(garden = state.garden.copy(
            carryoverBeforeSlip = state.garden.carryoverDays,
            carryoverDays = minOf(364, (had * 0.5).toInt()),
            watermark = 0,
            groveCountAtJourneyStart = state.garden.completedTreeStyles.size,
            vitality = maxOf(0.3, state.garden.vitality - 0.3),
            lastWateredAt = null,
        ))
    }

    private fun reversibleJourney(state: SoberState, day: LocalDate, clock: AppClock): Journey? {
        if (!loggedSlip(state, day)) return null
        val active = JourneyDays.active(state) ?: return null
        val gap = ChronoUnit.DAYS.between(day, active.start.atZone(clock.zone()).toLocalDate())
        if (gap !in 0..1) return null
        return state.journeys.filter {
            it.id != active.id && it.end?.atZone(clock.zone())?.toLocalDate() == day
        }.maxByOrNull { it.start }
    }

    fun canUndoSlip(state: SoberState, day: LocalDate, clock: AppClock): Boolean = reversibleJourney(state, day, clock) != null

    fun undoSlip(state: SoberState, day: LocalDate, clock: AppClock): SoberState {
        val closed = reversibleJourney(state, day, clock) ?: return state
        val active = JourneyDays.active(state) ?: return state
        val journeys = state.journeys.filterNot { it.id == active.id }.map {
            if (it.id == closed.id) it.copy(end = null, resetReason = null) else it
        }
        val restored = state.copy(journeys = journeys)
        val streak = JourneyDays.current(restored, clock)
        val carryover = state.garden.carryoverBeforeSlip
        return checkIn(restored, day, wasSober = true).copy(garden = state.garden.copy(
            carryoverDays = carryover,
            carryoverBeforeSlip = 0,
            watermark = maxOf(state.garden.watermark, GardenGrowth.treeDays(streak, carryover)),
            vitality = minOf(1.0, state.garden.vitality + 0.3),
        ))
    }

    fun completeCycles(state: SoberState, days: Int): SoberState {
        val expected = state.garden.groveCountAtJourneyStart + GardenGrowth.cycle(days).completed
        val missing = expected - state.garden.completedTreeStyles.size
        if (missing <= 0) return state
        return state.copy(garden = state.garden.copy(
            completedTreeStyles = state.garden.completedTreeStyles + List(missing) { state.garden.speciesId },
        ))
    }

    fun growthEvent(state: SoberState, days: Int): GrowthEvent? = GardenGrowth.event(state.garden.watermark, days)

    fun markGrowthSeen(state: SoberState, days: Int): SoberState =
        state.copy(garden = state.garden.copy(watermark = maxOf(state.garden.watermark, days)))

    fun selectSpecies(state: SoberState, speciesId: String, allowedIds: Set<String>, isPro: Boolean): SoberState {
        if (speciesId !in allowedIds || (!isPro && speciesId != GardenState.FREE_SPECIES)) return state
        return state.copy(garden = state.garden.copy(speciesId = speciesId))
    }

    /** Streak badges say "check-ins", so a day the app only assumed is sober does not count. */
    fun longestSoberStreak(state: SoberState): Int {
        val days = state.checkIns.filter { it.wasSober && it.wasLogged }.map { it.day }.distinct().sorted()
        if (days.isEmpty()) return 0
        var longest = 1
        var current = 1
        for (index in 1 until days.size) {
            current = if (ChronoUnit.DAYS.between(days[index - 1], days[index]) == 1L) current + 1 else 1
            longest = maxOf(longest, current)
        }
        return longest
    }

    fun addCraving(
        state: SoberState,
        startedAt: Instant,
        seconds: Int,
        outcome: CravingOutcome,
        intensity: Int?,
        trigger: String?,
        clock: AppClock,
    ): SoberState = state.copy(cravings = state.cravings + CravingEpisode(
        startedAt = startedAt,
        endedAt = clock.now(),
        intensity = intensity?.coerceIn(1, 5) ?: 0,
        outcome = outcome,
        trigger = trigger,
        secondsElapsed = maxOf(0, seconds),
    ))

    fun putJournalEntry(state: SoberState, entry: JournalEntry, isPro: Boolean): SoberState {
        val editingExisting = state.journal.any { it.id == entry.id }
        if (entry.text.isBlank() || (!isPro && state.journal.isNotEmpty() && !editingExisting)) return state
        return state.copy(journal = (state.journal.filterNot { it.id == entry.id } + entry.copy(text = entry.text.trim()))
            .sortedByDescending { it.createdAt })
    }

    fun deleteJournalEntry(state: SoberState, id: String): SoberState = state.copy(journal = state.journal.filterNot { it.id == id })
}
