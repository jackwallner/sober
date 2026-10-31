package com.jackwallner.sober.model

import java.util.Currency
import java.util.Locale

/**
 * Sizes the daily spend controls to the user's currency.
 *
 * The slider and stepper were fixed at 0 to 200 units, which is a real range
 * in dollars or euros and nothing at all in dong or rupees: 200 VND is about a
 * cent, so every money figure in Vietnam and India read near zero. [unit] is a
 * round number of local currency worth roughly one US dollar; the controls
 * keep their dollar shape (default 20, step 5, up to 200) times that unit.
 * Rough on purpose: it sizes a slider, it never converts a price.
 */
class SpendScale(currencyCode: String?) {
    val unit: Int = UNITS[currencyCode?.uppercase().orEmpty()] ?: 1
    val defaultDaily: Int get() = 20 * unit
    val step: Int get() = 5 * unit
    val maxDaily: Int get() = 200 * unit

    companion object {
        /** The device locale's currency, the one the controls are labelled in. */
        fun currentCode(locale: Locale = Locale.getDefault()): String =
            runCatching { Currency.getInstance(locale).currencyCode }.getOrDefault("USD")

        fun current(locale: Locale = Locale.getDefault()): SpendScale = SpendScale(currentCode(locale))

        /** Local units per US dollar, rounded to 1, 2 or 5 times a power of ten. */
        private val UNITS = mapOf(
            "ARS" to 1000, "BGN" to 2, "BRL" to 5, "CLP" to 1000, "CNY" to 5, "COP" to 5000,
            "CZK" to 20, "DKK" to 5, "EGP" to 50, "GEL" to 2, "HKD" to 10, "HUF" to 500,
            "IDR" to 20000, "ILS" to 5, "INR" to 100, "ISK" to 100, "JPY" to 200, "KRW" to 1000,
            "KZT" to 500, "MXN" to 20, "MYR" to 5, "NGN" to 2000, "NOK" to 10, "PEN" to 5,
            "PHP" to 50, "PKR" to 200, "PLN" to 5, "RON" to 5, "RSD" to 100, "RUB" to 100,
            "SAR" to 5, "AED" to 5, "SEK" to 10, "THB" to 50, "TRY" to 50, "TWD" to 50,
            "UAH" to 50, "VND" to 20000, "ZAR" to 20,
        )
    }
}
