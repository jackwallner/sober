package com.jackwallner.sober.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

interface AppClock {
    fun now(): Instant
    fun zone(): ZoneId
    fun today(): LocalDate = now().atZone(zone()).toLocalDate()
}

class SystemAppClock : AppClock {
    override fun now(): Instant = Instant.now()
    override fun zone(): ZoneId = ZoneId.systemDefault()
}

data class Journey(
    val id: String = UUID.randomUUID().toString(),
    val start: Instant,
    val end: Instant? = null,
    val resetReason: String? = null,
)

data class CheckIn(
    val day: LocalDate,
    val wasSober: Boolean = true,
    val mood: Int? = null,
    val note: String? = null,
    val wasLogged: Boolean = true,
)

enum class JournalKind(val key: String) { DAILY("daily"), CHALLENGE("challenge"), FREEFORM("freeform") }

data class JournalEntry(
    val id: String = UUID.randomUUID().toString(),
    val createdAt: Instant,
    val promptId: String? = null,
    val kind: JournalKind = JournalKind.DAILY,
    val text: String,
    val feeling: String? = null,
)

enum class CravingOutcome(val key: String, val label: String) {
    RODE_IT_OUT("rodeItOut", "It passed"),
    UNRESOLVED("unresolved", "Not sure"),
    GAVE_IN("gaveIn", "I gave in"),
}

data class CravingEpisode(
    val id: String = UUID.randomUUID().toString(),
    val startedAt: Instant,
    val endedAt: Instant,
    val intensity: Int = 0,
    val outcome: CravingOutcome = CravingOutcome.UNRESOLVED,
    val trigger: String? = null,
    val secondsElapsed: Int = 0,
)

data class GardenState(
    val vitality: Double = 1.0,
    val lastWateredAt: Instant? = null,
    val speciesId: String = FREE_SPECIES,
    val themeId: String = "zen",
    val watermark: Int = 0,
    val completedTreeStyles: List<String> = emptyList(),
    val groveCountAtJourneyStart: Int = 0,
    val carryoverDays: Int = 0,
    val carryoverBeforeSlip: Int = 0,
    /** Missed days since [lastWateredAt] already taken off [vitality], so each is charged once. */
    val vitalityDecayDays: Int = 0,
) {
    companion object { const val FREE_SPECIES = "traditional-bonsai" }
}

data class UserSettings(
    val costPerDayCents: Int = 2000,
    val currencyCode: String = "USD",
    val caloriesPerDay: Int = 600,
    val dailyReminderEnabled: Boolean = false,
    val dailyReminderHour: Int = 9,
    val hasCompletedOnboarding: Boolean = false,
    val madeCommitment: Boolean = true,
)

data class SoberState(
    val schemaVersion: Int = 1,
    val settings: UserSettings = UserSettings(),
    val journeys: List<Journey> = emptyList(),
    val checkIns: List<CheckIn> = emptyList(),
    val journal: List<JournalEntry> = emptyList(),
    val cravings: List<CravingEpisode> = emptyList(),
    val garden: GardenState = GardenState(),
    val earnedAchievementIds: Set<String> = emptySet(),
)

enum class BonsaiStage(val title: String, val threshold: Int) {
    SEED("Seed", 0), SPROUT("Sprout", 3), SEEDLING("Seedling", 7), YOUNG("Young Bonsai", 14),
    ADOLESCENT("Adolescent", 30), MATURE("Mature", 60), REFINED("Refined", 90), ANCIENT("Ancient", 180),
    LEGENDARY("Legendary", 365),
}

data class CycleProgress(val dayInCycle: Int, val completed: Int)

sealed interface GrowthEvent {
    data class NewStage(val stage: BonsaiStage) : GrowthEvent
    data class TreeCompleted(val total: Int) : GrowthEvent
}

object GardenGrowth {
    fun cycle(days: Int): CycleProgress {
        if (days <= 0) return CycleProgress(0, 0)
        val completed = (days - 1) / 365
        return CycleProgress(days - completed * 365, completed)
    }

    fun stage(days: Int): BonsaiStage {
        val inCycle = cycle(days).dayInCycle
        return BonsaiStage.entries.lastOrNull { inCycle >= it.threshold } ?: BonsaiStage.SEED
    }

    fun treeDays(streakDays: Int, carryover: Int): Int {
        if (carryover <= 0 || streakDays <= 0 || streakDays >= 365) return streakDays
        return minOf(364, streakDays + carryover)
    }

    fun event(previousDays: Int, currentDays: Int): GrowthEvent? {
        if (previousDays <= 0 || currentDays <= previousDays) return null
        val previous = cycle(previousDays)
        val current = cycle(currentDays)
        if (current.completed > previous.completed) return GrowthEvent.TreeCompleted(current.completed)
        val oldStage = stage(previousDays)
        val newStage = stage(currentDays)
        return if (newStage > oldStage) GrowthEvent.NewStage(newStage) else null
    }
}

object JourneyDays {
    fun since(start: Instant, asOf: Instant, zone: ZoneId): Int =
        maxOf(0, ChronoUnit.DAYS.between(start.atZone(zone).toLocalDate(), asOf.atZone(zone).toLocalDate()).toInt()) + 1

    fun active(state: SoberState): Journey? = state.journeys.filter { it.end == null }.maxByOrNull { it.start }

    fun current(state: SoberState, clock: AppClock): Int = active(state)?.let { since(it.start, clock.now(), clock.zone()) } ?: 0

    fun at(state: SoberState, day: LocalDate, zone: ZoneId): Int {
        val covering = state.journeys.sortedBy { it.start }.firstOrNull { journey ->
            day >= journey.start.atZone(zone).toLocalDate() &&
                (journey.end == null || day <= journey.end.atZone(zone).toLocalDate())
        } ?: return 0
        return maxOf(0, ChronoUnit.DAYS.between(covering.start.atZone(zone).toLocalDate(), day).toInt()) + 1
    }

    fun longest(state: SoberState, clock: AppClock): Int =
        state.journeys.maxOfOrNull { since(it.start, it.end ?: clock.now(), clock.zone()) } ?: 0
}

enum class DayMark { TENDED, ASSUMED, SLIP, BLANK }
data class TendedDay(val day: LocalDate, val mark: DayMark, val mood: Int?)

object TendedWeek {
    val moodLabels = listOf("rough", "low", "okay", "good", "great")

    fun days(end: LocalDate, facts: List<CheckIn>): List<TendedDay> {
        val byDay = facts.associateBy { it.day }
        return (6 downTo 0).map { offset ->
            val day = end.minusDays(offset.toLong())
            val fact = byDay[day]
            val mark = when {
                fact == null -> DayMark.BLANK
                !fact.wasSober -> DayMark.SLIP
                fact.wasLogged -> DayMark.TENDED
                else -> DayMark.ASSUMED
            }
            TendedDay(day, mark, fact?.mood)
        }
    }

    fun tendedCount(days: List<TendedDay>): Int = days.count { it.mark == DayMark.TENDED }

    fun moodSummary(days: List<TendedDay>): String? {
        val moods = days.mapNotNull { it.mood }.filter { it in 1..5 }
        if (moods.isEmpty()) return null
        val rounded = kotlin.math.floor(moods.average() + 0.5).toInt()
        return "mostly ${moodLabels[(rounded - 1).coerceIn(0, 4)]}"
    }

    fun summary(days: List<TendedDay>): String = when (val count = tendedCount(days)) {
        0 -> "Tend a day to start your week"
        7 -> "All 7 days tended"
        else -> "$count of 7 days tended"
    }
}
