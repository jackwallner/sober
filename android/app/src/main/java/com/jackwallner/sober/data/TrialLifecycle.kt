package com.jackwallner.sober.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sober.model.AppClock
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Tracks an in-flight Bloom+ free trial so the app can warn before it
 * converts: the end date, the pre-conversion reminder, and the Home recap.
 */
class TrialLifecycle(
    private val defaults: KeyValueStore,
    private val clock: AppClock,
    private val notifications: NotificationService,
) {
    /** Bumped on every change so Compose re-reads the banner state. */
    var revision by mutableIntStateOf(0)
        private set

    /** Set when a trial starts and the reminder still needs the permission asked. */
    var wantsReminderPermission by mutableStateOf(false)

    val endsAtMillis: Long? get() = defaults.getLong(ENDS_AT).takeIf { it > 0 }

    fun daysRemaining(): Int? {
        val end = endsAtMillis ?: return null
        return daysRemaining(Instant.ofEpochMilli(end), clock.now(), clock.zone())
    }

    var recapSummary: String?
        get() = defaults.getString(RECAP_SUMMARY)?.takeIf { it.isNotEmpty() }
        set(value) {
            if (value.isNullOrEmpty()) defaults.remove(RECAP_SUMMARY) else defaults.putString(RECAP_SUMMARY, value)
        }

    /** Idempotent: only does work when the trial's end date actually changes. */
    fun sync(isTrialing: Boolean, endsAt: Long?) {
        val now = clock.now().toEpochMilli()
        if (!isTrialing || endsAt == null || endsAt <= now) {
            clear()
            return
        }
        val current = endsAtMillis
        if (current != null && kotlin.math.abs(current - endsAt) < 60_000) return
        defaults.putLong(ENDS_AT, endsAt)
        defaults.remove(RECAP_DISMISSED_FOR)
        if (notifications.isAuthorized) {
            notifications.scheduleTrialEndingReminder(endsAt, recapSummary)
        } else {
            wantsReminderPermission = true
        }
        revision++
    }

    /** After the permission prompt the trial start raised. */
    fun scheduleReminderIfPossible() {
        wantsReminderPermission = false
        val end = endsAtMillis ?: return
        notifications.scheduleTrialEndingReminder(end, recapSummary)
    }

    fun clear() {
        if (defaults.getLong(ENDS_AT) <= 0) return
        defaults.remove(ENDS_AT)
        defaults.remove(RECAP_DISMISSED_FOR)
        notifications.cancelTrialEndingReminder()
        revision++
    }

    fun shouldShowRecap(): Boolean {
        val end = endsAtMillis ?: return false
        if (end <= clock.now().toEpochMilli()) return false
        val remaining = daysRemaining() ?: return false
        if (remaining > RECAP_LEAD_DAYS) return false
        return defaults.getLong(RECAP_DISMISSED_FOR) != end
    }

    fun dismissRecap() {
        val end = endsAtMillis ?: return
        defaults.putLong(RECAP_DISMISSED_FOR, end)
        revision++
    }

    companion object {
        /**
         * Calendar days until the trial's last day: 0 on that day, 1 the day
         * before. Counting whole 24-hour blocks and rounding "less than a day"
         * up to 1 told someone "ends tomorrow" hours before the charge.
         */
        fun daysRemaining(endsAt: Instant, now: Instant, zone: ZoneId): Int? {
            if (endsAt <= now) return null
            val days = ChronoUnit.DAYS.between(now.atZone(zone).toLocalDate(), endsAt.atZone(zone).toLocalDate())
            return maxOf(0, days.toInt())
        }

        const val RECAP_LEAD_DAYS = 3
        private const val ENDS_AT = "trialLifecycle.endsAt"
        private const val RECAP_SUMMARY = "trialLifecycle.recapSummary"
        private const val RECAP_DISMISSED_FOR = "trialLifecycle.recapDismissedForEnd"
    }
}
