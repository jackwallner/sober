package com.jackwallner.sober.data

import android.net.Uri
import com.jackwallner.sober.model.AppClock
import java.time.Instant

object StoreLinks {
    const val PACKAGE = "com.jackwallner.sober"
    const val PLAY_LISTING_URL = "https://play.google.com/store/apps/details?id=$PACKAGE"
    const val PLAY_MARKET_URI = "market://details?id=$PACKAGE"
    const val SUPPORT_EMAIL = "jackwallner+st@gmail.com"
    const val FEEDBACK_EMAIL = "jackwallner@gmail.com"
    const val PRIVACY_URL = "https://jackwallner.github.io/sober/android-privacy.html"
    const val TERMS_URL = "https://jackwallner.github.io/sober/android-terms.html"

    fun manageSubscriptionURL(productId: String?): String =
        if (productId == null) "https://play.google.com/store/account/subscriptions"
        else "https://play.google.com/store/account/subscriptions?sku=$productId&package=$PACKAGE"

    /** `ReviewPromptSheet.feedbackMailURL`, same address and subject. */
    fun feedbackMail(body: String): Uri = Uri.parse(
        "mailto:$FEEDBACK_EMAIL?subject=${Uri.encode("Sober feedback")}&body=${Uri.encode(body)}",
    )
}

/**
 * The review funnel's memory, with the iOS keys and gates. Google forbids an
 * enjoyment question before the Play card, so a positive moment that passes
 * these gates goes straight to `launchReviewFlow`; feedback is its own row.
 */
class ReviewPromptTracker(private val defaults: KeyValueStore, private val clock: AppClock) {
    /** Tests and screenshot runs never trigger the store card. */
    var isAutomationRun = false

    val appLaunchCount: Int get() = maxOf(defaults.getInt(LAUNCH_COUNT), 0)
    val positiveMomentCount: Int get() = maxOf(defaults.getInt(POSITIVE_MOMENTS), 0)
    val outcome: String? get() = defaults.getString(OUTCOME)
    private val hasPendingPositiveMoment: Boolean get() = defaults.getBoolean(PENDING)
    private val hasPendingMilestoneMoment: Boolean get() = defaults.getBoolean(PENDING_MILESTONE)

    fun recordAppLaunch() {
        if (!defaults.contains(FIRST_OPEN)) defaults.putLong(FIRST_OPEN, clock.now().toEpochMilli())
        defaults.putInt(LAUNCH_COUNT, appLaunchCount + 1)
    }

    fun recordPositiveMoment(isMilestone: Boolean = false) {
        defaults.putInt(POSITIVE_MOMENTS, positiveMomentCount + 1)
        defaults.putBoolean(PENDING, true)
        if (isMilestone) defaults.putBoolean(PENDING_MILESTONE, true)
    }

    fun consumePendingPositiveMoment() {
        defaults.putBoolean(PENDING, false)
        defaults.putBoolean(PENDING_MILESTONE, false)
    }

    private fun passivePromptAllowed(): Boolean {
        if (outcome != null) return false
        if (!defaults.contains(LAST_SHOWN)) return true
        return clock.now().toEpochMilli() - defaults.getLong(LAST_SHOWN) >= COOLDOWN_DAYS * DAY_MS
    }

    fun canPresent(hasCompletedSetup: Boolean, isMilestone: Boolean): Boolean {
        if (isAutomationRun || !hasCompletedSetup || !passivePromptAllowed()) return false
        if (isMilestone) return appLaunchCount >= MINIMUM_LAUNCH_COUNT_FOR_MILESTONE
        if (appLaunchCount < MINIMUM_LAUNCH_COUNT || positiveMomentCount < MINIMUM_POSITIVE_MOMENTS) return false
        if (!defaults.contains(FIRST_OPEN)) return false
        return clock.now().toEpochMilli() - defaults.getLong(FIRST_OPEN) >= MINIMUM_DAYS_SINCE_FIRST_OPEN * DAY_MS
    }

    fun shouldShowAfterPositiveMoment(hasCompletedSetup: Boolean): Boolean =
        hasPendingPositiveMoment && canPresent(hasCompletedSetup, hasPendingMilestoneMoment)

    /** Spent when requested, not when answered: Play may show nothing at all. */
    fun markShown() {
        defaults.putLong(LAST_SHOWN, clock.now().toEpochMilli())
        consumePendingPositiveMoment()
    }

    fun markOpenedWriteReview() {
        defaults.putString(OUTCOME, "openedWriteReview")
        markShown()
    }

    fun markFeedbackSubmitted() {
        defaults.putString(OUTCOME, "submittedFeedback")
        markShown()
    }

    companion object {
        const val MINIMUM_LAUNCH_COUNT = 3
        const val MINIMUM_DAYS_SINCE_FIRST_OPEN = 3L
        const val MINIMUM_POSITIVE_MOMENTS = 2
        const val COOLDOWN_DAYS = 120L
        const val MINIMUM_LAUNCH_COUNT_FOR_MILESTONE = 2

        private const val LAUNCH_COUNT = "reviewPrompt.appLaunchCount"
        private const val FIRST_OPEN = "reviewPrompt.firstAppOpenDate"
        private const val LAST_SHOWN = "reviewPrompt.lastShownDate"
        private const val OUTCOME = "reviewPrompt.outcome"
        private const val POSITIVE_MOMENTS = "reviewPrompt.positiveMomentCount"
        private const val PENDING = "reviewPrompt.pendingPositiveMoment"
        private const val PENDING_MILESTONE = "reviewPrompt.pendingMilestoneMoment"
    }
}

enum class ConversionEvent(val key: String) {
    ONBOARDING_REACHED("onboardingReached"),
    ONBOARDING_COMPLETED("onboardingCompleted"),
    TRIAL_OFFER_REACHED("trialOfferReached"),
    TRIAL_CTA_TAPPED("trialCTATapped"),
    FREE_VERSION_CHOSEN("freeVersionChosen"),
    PURCHASE_CANCELLED("purchaseCancelled"),
    PURCHASE_FAILED("purchaseFailed"),
    PURCHASE_PENDING("purchasePending"),
    PURCHASE_SUCCEEDED("purchaseSucceeded"),
    REMINDERS_STEP_REACHED("remindersStepReached"),
    REMINDERS_GRANTED("remindersGranted"),
    REMINDERS_DECLINED("remindersDeclined"),
}

/**
 * On-device funnel counters and the fleet-wide paywall record, mirrored onto
 * the RevenueCat customer as attributes. Counts, dates and surface names only.
 */
class ConversionDiagnostics(private val defaults: KeyValueStore, private val clock: AppClock) {
    fun record(event: ConversionEvent) {
        val key = "conversion.${event.key}"
        defaults.putInt(key, defaults.getInt(key) + 1)
    }

    fun count(event: ConversionEvent): Int = defaults.getInt("conversion.${event.key}")

    val counts: Map<ConversionEvent, Int>
        get() = ConversionEvent.entries.mapNotNull { event -> count(event).takeIf { it > 0 }?.let { event to it } }.toMap()

    fun recordAppOpen() {
        if (!defaults.contains(INSTALLED_AT)) defaults.putLong(INSTALLED_AT, millis())
        defaults.putInt(APP_OPENS, defaults.getInt(APP_OPENS) + 1)
    }

    fun recordPitchView(impressionId: String) {
        val surface = impressionId.removePrefix(PREFIX)
        defaults.putInt(TOTAL_VIEWS, defaults.getInt(TOTAL_VIEWS) + 1)
        defaults.putInt(views(surface), defaults.getInt(views(surface)) + 1)
        defaults.putString(LAST_SURFACE, surface)
        if (!defaults.contains(FIRST_SEEN)) {
            defaults.putLong(FIRST_SEEN, millis())
            defaults.putInt(OPENS_BEFORE_FIRST_PITCH, defaults.getInt(APP_OPENS))
            if (defaults.contains(INSTALLED_AT)) defaults.putInt(DAYS_TO_FIRST_PITCH, daysSince(defaults.getLong(INSTALLED_AT)))
        }
    }

    /** Only the first conversion is recorded. */
    fun recordConversion(plan: String, startedTrial: Boolean, offeringId: String?) {
        if (defaults.contains(CONVERTED_ON)) return
        defaults.putString(CONVERTED_ON, defaults.getString(LAST_SURFACE) ?: "unknown")
        defaults.putInt(VIEWS_AT_CONVERT, defaults.getInt(TOTAL_VIEWS))
        defaults.putString(CONVERTED_PLAN, plan)
        defaults.putBoolean(CONVERTED_WITH_TRIAL, startedTrial)
        defaults.putLong(CONVERTED_AT, millis())
        offeringId?.let { defaults.putString(CONVERTED_OFFERING, it) }
        if (defaults.contains(FIRST_SEEN)) defaults.putInt(DAYS_TO_CONVERT, daysSince(defaults.getLong(FIRST_SEEN)))
    }

    /** Empty until the first pitch. Keys stay under RevenueCat's 40-character limit. */
    val subscriberAttributes: Map<String, String>
        get() {
            val total = defaults.getInt(TOTAL_VIEWS)
            if (total <= 0) return emptyMap()
            val attributes = mutableMapOf("pitch_views_total" to total.toString())
            for (key in defaults.keys()) {
                if (!key.startsWith(VIEWS_PREFIX) || key == TOTAL_VIEWS) continue
                val count = defaults.getInt(key)
                if (count > 0) attributes["pitch_views_${key.removePrefix(VIEWS_PREFIX)}".take(40)] = count.toString()
            }
            defaults.getString(LAST_SURFACE)?.let { attributes["pitch_last"] = it }
            if (defaults.contains(FIRST_SEEN)) {
                val first = defaults.getLong(FIRST_SEEN)
                attributes["pitch_first_seen"] = Instant.ofEpochMilli(first).toString()
                attributes["days_since_first_pitch"] = daysSince(first).toString()
            }
            if (defaults.contains(DAYS_TO_FIRST_PITCH)) attributes["days_since_install"] = defaults.getInt(DAYS_TO_FIRST_PITCH).toString()
            if (defaults.contains(OPENS_BEFORE_FIRST_PITCH)) attributes["opens_before_first_pitch"] = defaults.getInt(OPENS_BEFORE_FIRST_PITCH).toString()
            defaults.getString(CONVERTED_ON)?.let { convertedOn ->
                attributes["converted_surface"] = convertedOn
                attributes["converted_at"] = Instant.ofEpochMilli(defaults.getLong(CONVERTED_AT)).toString()
                attributes["pitch_views_at_convert"] = defaults.getInt(VIEWS_AT_CONVERT).toString()
                attributes["days_to_convert"] = defaults.getInt(DAYS_TO_CONVERT).toString()
                attributes["converted_plan"] = defaults.getString(CONVERTED_PLAN) ?: "unknown"
                attributes["converted_with_trial"] = if (defaults.getBoolean(CONVERTED_WITH_TRIAL)) "true" else "false"
                defaults.getString(CONVERTED_OFFERING)?.let { attributes["converted_offering"] = it }
            }
            return attributes
        }

    private fun millis() = clock.now().toEpochMilli()
    private fun daysSince(millis: Long): Int = maxOf(0, ((millis() - millis) / DAY_MS).toInt())
    private fun views(surface: String) = "$VIEWS_PREFIX$surface"

    private companion object {
        const val PREFIX = "sober_"
        const val VIEWS_PREFIX = "conv.pitchViews."
        const val TOTAL_VIEWS = "conv.pitchViews.total"
        const val FIRST_SEEN = "conv.pitchFirstSeen"
        const val LAST_SURFACE = "conv.pitchLastSurface"
        const val INSTALLED_AT = "conv.installedAt"
        const val APP_OPENS = "conv.appOpens"
        const val OPENS_BEFORE_FIRST_PITCH = "conv.opensBeforeFirstPitch"
        const val DAYS_TO_FIRST_PITCH = "conv.daysToFirstPitch"
        const val CONVERTED_ON = "conv.convertedOn"
        const val CONVERTED_AT = "conv.convertedAt"
        const val VIEWS_AT_CONVERT = "conv.viewsAtConvert"
        const val DAYS_TO_CONVERT = "conv.daysToConvert"
        const val CONVERTED_PLAN = "conv.convertedPlan"
        const val CONVERTED_WITH_TRIAL = "conv.convertedWithTrial"
        const val CONVERTED_OFFERING = "conv.convertedOffering"
    }
}
