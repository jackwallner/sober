package com.jackwallner.sober.ui

import android.text.format.DateFormat
import java.math.RoundingMode
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

/** The few formatters the iOS views share. */
object Format {
    /** `NumberFormatter(.currency, maximumFractionDigits: 0)` in the device locale. */
    fun currency(amount: Double): String = NumberFormat.getCurrencyInstance().apply {
        maximumFractionDigits = 0
        roundingMode = RoundingMode.HALF_EVEN
    }.format(amount)

    fun currencyFromCents(cents: Int): String = currency(cents / 100.0)

    /** `Int.formatted()`: grouped digits. */
    fun number(value: Int): String = NumberFormat.getIntegerInstance().format(value)

    /** "4.3 lb" below ten pounds, "12 lb" above, at ~3,500 kcal per lb. */
    fun poundsOfFat(calories: Int): String {
        val lbs = calories / 3500.0
        val format = NumberFormat.getNumberInstance().apply {
            val digits = if (lbs < 10) 1 else 0
            minimumFractionDigits = digits
            maximumFractionDigits = digits
            roundingMode = RoundingMode.HALF_EVEN
        }
        return "${format.format(lbs)} lb"
    }

    fun oneDecimal(value: Double): String = NumberFormat.getNumberInstance().apply {
        minimumFractionDigits = 1
        maximumFractionDigits = 1
    }.format(value)

    private fun pattern(skeleton: String): DateTimeFormatter =
        DateTimeFormatter.ofPattern(DateFormat.getBestDateTimePattern(Locale.getDefault(), skeleton), Locale.getDefault())

    /** `DateHelpers.mediumDate`: "Oct 3". */
    fun mediumDate(date: LocalDate): String = pattern("MMMd").format(date)

    /** The month header: "October 2026". */
    fun monthTitle(date: LocalDate): String = pattern("MMMMy").format(date)

    /** "Sep 5" for the onboarding trial's free-until line. */
    fun monthDay(date: LocalDate): String = pattern("MMMd").format(date)

    /** One-letter weekday headers starting on the locale's first weekday. */
    fun weekdaySymbols(firstDayOfWeek: java.time.DayOfWeek): List<String> =
        (0 until 7).map { firstDayOfWeek.plus(it.toLong()).getDisplayName(TextStyle.NARROW_STANDALONE, Locale.getDefault()) }

    fun capitalized(text: String): String = text.split(" ").joinToString(" ") { it.replaceFirstChar(Char::uppercaseChar) }
}
