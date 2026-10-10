package com.jackwallner.sober.model

import java.time.Instant
import java.time.ZoneId
import kotlin.math.floor

object CravingInsights {
    const val MINIMUM_FOR_RATE = 3
    const val MINIMUM_FOR_TIMING = 4
    const val MINIMUM_FOR_TRIGGER = 3
    const val MINIMUM_FOR_WEEKLY = 4
    const val MINIMUM_SLIPS_FOR_MOOD = 2

    data class Rate(val rode: Int, val resolved: Int)
    data class Window(val startHour: Int, val count: Int)
    data class Trigger(val name: String, val count: Int)
    data class Weekday(val sundayBasedDay: Int, val count: Int)
    data class WeeklyChange(val thisWeek: Int, val lastWeek: Int)

    fun resolved(facts: List<CravingEpisode>): List<CravingEpisode> =
        facts.filter { it.outcome != CravingOutcome.UNRESOLVED }

    fun rideOutRate(facts: List<CravingEpisode>): Rate? {
        val answered = resolved(facts)
        if (answered.size < MINIMUM_FOR_RATE) return null
        return Rate(answered.count { it.outcome == CravingOutcome.RODE_IT_OUT }, answered.size)
    }

    fun medianRideOutSeconds(facts: List<CravingEpisode>): Int? {
        val lengths = facts.filter { it.outcome == CravingOutcome.RODE_IT_OUT }.map { it.secondsElapsed }.sorted()
        if (lengths.size < MINIMUM_FOR_RATE) return null
        val middle = lengths.size / 2
        return if (lengths.size % 2 == 0) (lengths[middle - 1] + lengths[middle]) / 2 else lengths[middle]
    }

    fun peakWindow(facts: List<CravingEpisode>, zone: ZoneId): Window? {
        if (facts.size < MINIMUM_FOR_TIMING) return null
        val counts = IntArray(24)
        facts.forEach { counts[it.startedAt.atZone(zone).hour]++ }
        var best = Window(0, -1)
        for (start in 0..23) {
            val count = (0..2).sumOf { counts[(start + it) % 24] }
            if (count > best.count) best = Window(start, count)
        }
        return best.takeIf { it.count >= 2 && it.count < facts.size }
    }

    fun topTrigger(facts: List<CravingEpisode>): Trigger? {
        val tagged = facts.mapNotNull { it.trigger }
        if (tagged.size < MINIMUM_FOR_TRIGGER) return null
        val best = tagged.groupingBy { it }.eachCount().entries.sortedWith(
            compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key },
        ).firstOrNull() ?: return null
        return Trigger(best.key, best.value).takeIf { it.count >= 2 }
    }

    fun hardestWeekday(facts: List<CravingEpisode>, zone: ZoneId): Weekday? {
        if (facts.size < MINIMUM_FOR_TIMING) return null
        val best = facts.groupingBy { it.startedAt.atZone(zone).dayOfWeek.value % 7 + 1 }.eachCount()
            .entries.sortedWith(compareByDescending<Map.Entry<Int, Int>> { it.value }.thenBy { it.key }).firstOrNull()
            ?: return null
        return Weekday(best.key, best.value).takeIf { it.count >= 2 }
    }

    fun weeklyChange(facts: List<CravingEpisode>, now: Instant, zone: ZoneId): WeeklyChange? {
        val weekAgo = now.atZone(zone).minusDays(7).toInstant()
        val twoWeeksAgo = now.atZone(zone).minusDays(14).toInstant()
        val current = facts.count { it.startedAt > weekAgo && it.startedAt <= now }
        val previous = facts.count { it.startedAt > twoWeeksAgo && it.startedAt <= weekAgo }
        return WeeklyChange(current, previous).takeIf { current + previous >= MINIMUM_FOR_WEEKLY }
    }

    fun moodDipBeforeSlips(checkIns: List<CheckIn>): Double? {
        val slipDays = checkIns.filter { !it.wasSober }.map { it.day }
        if (slipDays.size < MINIMUM_SLIPS_FOR_MOOD) return null
        val runUp = slipDays.flatMap { listOf(it.minusDays(1), it.minusDays(2)) }.toSet()
        val before = checkIns.filter { it.day in runUp }.mapNotNull { it.mood }
        val rest = checkIns.filter { it.wasSober && it.day !in runUp }.mapNotNull { it.mood }
        if (before.size < 3 || rest.size < 3) return null
        return (rest.average() - before.average()).takeIf { it >= 0.5 }
    }

    fun nextUnlock(facts: List<CravingEpisode>, shownCount: Int = 0, urge: String = "craving", urges: String = "cravings"): String? {
        val needed = maxOf(MINIMUM_FOR_RATE, MINIMUM_FOR_TIMING)
        val usable = resolved(facts).size
        if (usable >= needed) return null
        val remaining = needed - usable
        val verb = if (shownCount > 0) "keep filling in" else "start filling in"
        return if (remaining == 1) "One more logged $urge and your patterns $verb."
        else "$remaining more logged $urges and your patterns $verb."
    }

    fun spokenDuration(seconds: Int): String {
        if (seconds < 90) return "about a minute"
        return "about ${floor(seconds / 60.0 + 0.5).toInt()} minutes"
    }
}

object CravingCoach {
    fun line(elapsed: Int, target: Int, lines: List<String>): String {
        require(lines.size == 5)
        val progress = if (target > 0) elapsed.toDouble() / target else 1.0
        val index = when {
            progress < 0.15 -> 0
            progress < 0.35 -> 1
            progress < 0.6 -> 2
            progress < 0.85 -> 3
            else -> 4
        }
        return lines[index]
    }
}
