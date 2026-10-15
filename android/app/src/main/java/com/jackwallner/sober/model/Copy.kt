package com.jackwallner.sober.model

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.chrono.IsoChronology
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.floor

/**
 * Expresses a Bloom+ price in the user's own habit spend. Names no amount:
 * the real localized price is always shown separately.
 */
object HabitPriceComparison {
    const val MAX_DAYS = 10.0

    fun daysOfHabit(price: Double, costPerDay: Double): Double? {
        if (price <= 0 || costPerDay <= 0) return null
        val days = price / costPerDay
        return days.takeIf { it <= MAX_DAYS }
    }

    fun phrase(price: Double, costPerDay: Double, habitNoun: String = "drinking"): String? {
        val days = daysOfHabit(price, costPerDay) ?: return null
        return "${dayCount(days)} of $habitNoun"
    }

    fun dayCount(days: Double): String {
        if (days < 0.75) return "less than a day"
        if (days < 1.25) return "about a day"
        if (days < 1.75) return "about a day and a half"
        val halves = swiftRound(days * 2)
        val whole = (halves / 2).toInt()
        return if (halves % 2 == 0.0) "about $whole days" else "about $whole and a half days"
    }
}

/** Swift's `.rounded()`: half away from zero. */
fun swiftRound(value: Double): Double = if (value >= 0) floor(value + 0.5) else -floor(-value + 0.5)

/** Deterministic "today's growth" phrasing keyed off the day in the cycle. */
object DailyGrowth {
    private val phrases = listOf(
        "a new leaf unfurled",
        "the trunk gained a hair of girth",
        "a fresh shoot pushed out",
        "the canopy filled in a touch",
        "bark hardened another shade",
        "a tiny bud appeared",
        "roots spread a fingerwidth",
        "the silhouette sharpened",
        "moss crept a little further",
        "needles deepened in color",
        "a branch tip lengthened",
        "the crown stretched higher",
    )

    fun note(dayInCycle: Int): String {
        if (dayInCycle <= 0) return "the seed is settling in"
        if (dayInCycle >= 365) return "the tree is complete, and the next cycle begins"
        return phrases[kotlin.math.abs(dayInCycle) % phrases.size]
    }
}

data class CravingInsight(val id: String, val icon: String, val headline: String, val detail: String)

/** The presentation half of `CravingInsights.swift`. */
object InsightCopy {
    fun insights(
        cravings: List<CravingEpisode>,
        checkIns: List<CheckIn>,
        now: Instant,
        zone: ZoneId,
        urge: String,
        urges: String,
        habitInstance: String,
        locale: Locale = Locale.getDefault(),
    ): List<CravingInsight> {
        val result = mutableListOf<CravingInsight>()
        CravingInsights.rideOutRate(cravings)?.let {
            result += CravingInsight("rate", "wind", "${it.rode} of ${it.resolved} ridden out",
                "Every one of those was a $urge that ended without $habitInstance.")
        }
        CravingInsights.peakWindow(cravings, zone)?.let {
            result += CravingInsight("window", "clock.fill",
                "Hardest between ${hourLabel(it.startHour, locale)} and ${hourLabel(it.startHour + 3, locale)}",
                "${it.count} of your ${cravings.size} logged $urges land in that stretch.")
        }
        CravingInsights.medianRideOutSeconds(cravings)?.let {
            result += CravingInsight("length", "hourglass", "Yours usually pass in ${CravingInsights.spokenDuration(it)}",
                "Measured from the sessions you stayed with, not an average of everyone.")
        }
        CravingInsights.topTrigger(cravings)?.let {
            result += CravingInsight("trigger", "tag.fill", "${it.name} comes up most", "You've tagged it ${it.count} times.")
        }
        CravingInsights.hardestWeekday(cravings, zone)?.let {
            result += CravingInsight("weekday", "calendar", "${weekdayLabel(it.sundayBasedDay, locale)} is your heaviest day",
                "${it.count} logged so far.")
        }
        CravingInsights.weeklyChange(cravings, now, zone)?.let {
            val headline = when {
                it.thisWeek < it.lastWeek -> "Fewer this week than last"
                it.thisWeek > it.lastWeek -> "More this week than last"
                else -> "Level with last week"
            }
            result += CravingInsight("weekly", "chart.line.uptrend.xyaxis", headline,
                "${it.thisWeek} in the last seven days, ${it.lastWeek} the week before.")
        }
        if (CravingInsights.moodDipBeforeSlips(checkIns) != null) {
            result += CravingInsight("mood", "cloud.sun.fill", "Your mood tends to dip before a slip",
                "The days leading up to one read lower than your usual. Worth noticing early.")
        }
        return result
    }

    /** The one personal line the ride-it-out screen shows mid-session. */
    fun coachLine(cravings: List<CravingEpisode>): String? =
        CravingInsights.medianRideOutSeconds(cravings)?.let { "Yours usually pass in ${CravingInsights.spokenDuration(it)}." }

    /** The locale's hour-only format, iOS's "j" template: "9 PM" or "21". */
    fun hourLabel(hour: Int, locale: Locale = Locale.getDefault()): String {
        val pattern = DateTimeFormatterBuilder.getLocalizedDateTimePattern(null, FormatStyle.SHORT, IsoChronology.INSTANCE, locale)
            .replace(Regex("[:.]\\s*mm"), "").replace("mm", "").trim()
        return DateTimeFormatter.ofPattern(pattern, locale).format(LocalTime.of(hour % 24, 0))
    }

    /** "Fridays" from a Sunday-based 1...7 weekday. */
    fun weekdayLabel(sundayBased: Int, locale: Locale = Locale.getDefault()): String {
        if (sundayBased !in 1..7) return ""
        val day = DayOfWeek.SUNDAY.plus((sundayBased - 1).toLong())
        return day.getDisplayName(TextStyle.FULL_STANDALONE, locale).replaceFirstChar { it.titlecase(locale) } + "s"
    }
}
