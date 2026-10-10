package com.jackwallner.sober.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.jackwallner.sober.MainActivity
import com.jackwallner.sober.R
import com.jackwallner.sober.SoberApplication
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CompletableDeferred
import org.json.JSONObject

/** One scheduled notification, persisted so a reboot can put it back. */
data class ReminderSpec(
    val id: String,
    val fireAtMillis: Long,
    val title: String,
    val body: String,
    val deepLink: String,
    val repeatsDaily: Boolean,
) {
    fun json(): String = JSONObject()
        .put("id", id).put("fireAt", fireAtMillis).put("title", title).put("body", body)
        .put("deepLink", deepLink).put("repeats", repeatsDaily).toString()

    companion object {
        fun parse(text: String): ReminderSpec? = runCatching {
            val o = JSONObject(text)
            ReminderSpec(o.getString("id"), o.getLong("fireAt"), o.getString("title"), o.getString("body"),
                o.getString("deepLink"), o.getBoolean("repeats"))
        }.getOrNull()
    }
}

/** The platform half of reminders, behind an interface so the copy and timing rules test on the JVM. */
interface ReminderPlatform {
    fun canNotify(): Boolean
    fun schedule(spec: ReminderSpec)
    fun cancel(id: String)
}

/**
 * `NotificationService.swift` on inexact alarms: the daily reminder, the
 * milestone-eve and lapse nudges that ride on its opt-in, and the trial-ending
 * warning. Same ids, copy, and timing. Nothing here ever prompts; the system
 * permission is asked only where the user asked for something that needs it.
 */
class NotificationService(
    private val platform: ReminderPlatform,
    private val defaults: KeyValueStore,
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
) {
    /** Bridged to the activity's permission launcher by `MainActivity`. */
    var permissionRequester: (suspend () -> Boolean)? = null

    val isAuthorized: Boolean get() = platform.canNotify()

    /** Denied means asked and refused (or blocked in system settings); never asked still counts as enabled. */
    val isDenied: Boolean get() = !platform.canNotify() && defaults.getBoolean(ASKED_KEY)

    /** Ask for permission, at a moment the user asked for something that needs it. */
    suspend fun ensureAuthorized(): Boolean {
        if (platform.canNotify()) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        val requester = permissionRequester ?: return false
        defaults.putBoolean(ASKED_KEY, true)
        return requester()
    }

    fun scheduleDailyReminder(hour: Int, committed: Boolean = true, streakDays: Int = 0) {
        if (!isAuthorized) return
        val (title, body) = dailyCopy(committed, streakDays)
        val zoneId = zone()
        val now = Instant.ofEpochMilli(nowMillis()).atZone(zoneId)
        var next = now.toLocalDate().atTime(hour, 0).atZone(zoneId)
        if (!next.isAfter(now)) next = next.plusDays(1)
        put(ReminderSpec(DAILY_ID, next.toInstant().toEpochMilli(), title, body, DEEP_LINK_CHECK_IN, repeatsDaily = true))
    }

    /** Fresh streak copy, but only if a reminder is pending: never resurrects one the user turned off. */
    fun refreshDailyReminder(hour: Int, committed: Boolean, streakDays: Int) {
        if (!isScheduled(DAILY_ID)) return
        scheduleDailyReminder(hour, committed, streakDays)
    }

    fun cancelDailyReminder() = remove(DAILY_ID)

    fun scheduleMilestoneEve(currentDays: Int, milestoneDays: Int, milestoneTitle: String, hour: Int) {
        if (!isAuthorized) return
        cancelMilestoneEve()
        val fire = milestoneEveFireDate(currentDays, milestoneDays, hour) ?: return
        put(ReminderSpec(
            MILESTONE_EVE_ID, fire,
            "Tomorrow is day $milestoneDays",
            "One more sober day and $milestoneTitle is yours. Your bonsai is ready for it.",
            DEEP_LINK_CHECK_IN, repeatsDaily = false,
        ))
    }

    fun milestoneEveFireDate(currentDays: Int, milestoneDays: Int, hour: Int): Long? {
        val daysUntil = milestoneDays - currentDays
        if (daysUntil < 1) return null
        val zoneId = zone()
        val now = nowMillis()
        val today = Instant.ofEpochMilli(now).atZone(zoneId).toLocalDate()
        val fire = today.plusDays((daysUntil - 1).toLong()).atTime(hour, 0).atZone(zoneId).toInstant().toEpochMilli()
        return fire.takeIf { it > now }
    }

    fun cancelMilestoneEve() = remove(MILESTONE_EVE_ID)

    fun scheduleLapseNudge(streakDays: Int) {
        if (!isAuthorized) return
        cancelLapseNudge()
        val body = if (streakDays > 0) {
            "$streakDays days is still $streakDays days. Pick up wherever you are, no catching up required."
        } else {
            "Whenever you're ready, day one is waiting. No streak to rebuild first."
        }
        put(ReminderSpec(LAPSE_ID, nowMillis() + LAPSE_NUDGE_DAYS * DAY_MS, "Your garden is still here", body, DEEP_LINK_CHECK_IN, false))
    }

    fun cancelLapseNudge() = remove(LAPSE_ID)

    fun cancelRetentionNudges() {
        cancelMilestoneEve()
        cancelLapseNudge()
    }

    fun scheduleTrialEndingReminder(endsAtMillis: Long, summary: String?) {
        if (!isAuthorized) return
        cancelTrialEndingReminder()
        val fire = trialReminderFireDate(endsAtMillis) ?: return
        val body = if (!summary.isNullOrEmpty()) {
            "$summary Keep the full garden, or cancel any time before it renews."
        } else {
            "Keep your full garden, journal, and savings, or cancel any time before it renews."
        }
        put(ReminderSpec(TRIAL_ENDING_ID, maxOf(nowMillis() + 60_000, fire), "Your Bloom+ trial ends soon", body, DEEP_LINK_BLOOM_PLUS, false))
    }

    /** Two days before conversion, or the midpoint for trials too short for that. */
    fun trialReminderFireDate(endsAtMillis: Long): Long? {
        val now = nowMillis()
        val remaining = endsAtMillis - now
        if (remaining <= 3_600_000L) return null
        val lead = TRIAL_REMINDER_LEAD_DAYS * DAY_MS
        val fire = if (remaining > lead) endsAtMillis - lead else now + remaining / 2
        return fire.takeIf { it > now }
    }

    fun cancelTrialEndingReminder() = remove(TRIAL_ENDING_ID)

    fun isScheduled(id: String): Boolean = defaults.getString(specKey(id)) != null

    fun spec(id: String): ReminderSpec? = defaults.getString(specKey(id))?.let(ReminderSpec::parse)

    /** After a reboot or clock change: re-arm everything still in the future (or repeating). */
    fun rescheduleAll() {
        val now = nowMillis()
        for (id in ALL_IDS) {
            val spec = spec(id) ?: continue
            when {
                spec.repeatsDaily -> {
                    var fire = spec.fireAtMillis
                    while (fire <= now) fire += DAY_MS
                    put(spec.copy(fireAtMillis = fire))
                }
                spec.fireAtMillis > now -> platform.schedule(spec)
                else -> remove(id)
            }
        }
    }

    /** A one-shot that fired is spent; a repeating one is re-armed for its next day. */
    fun markDelivered(id: String) {
        val spec = spec(id) ?: return
        if (!spec.repeatsDaily) {
            defaults.remove(specKey(id))
            return
        }
        var fire = spec.fireAtMillis + DAY_MS
        while (fire <= nowMillis()) fire += DAY_MS
        put(spec.copy(fireAtMillis = fire))
    }

    /** Debug launch extras only: arm a reminder seconds from now to exercise delivery. */
    fun scheduleForTesting(id: String, secondsFromNow: Int) {
        val (title, body) = dailyCopy(true, 12)
        put(ReminderSpec(id, nowMillis() + secondsFromNow * 1000L, title, body, if (id == TRIAL_ENDING_ID) DEEP_LINK_BLOOM_PLUS else DEEP_LINK_CHECK_IN, false))
    }

    private fun put(spec: ReminderSpec) {
        defaults.putString(specKey(spec.id), spec.json())
        platform.schedule(spec)
    }

    private fun remove(id: String) {
        defaults.remove(specKey(id))
        platform.cancel(id)
    }

    companion object {
        const val DAILY_ID = "sober.daily-reminder"
        const val MILESTONE_EVE_ID = "sober.milestone-eve"
        const val LAPSE_ID = "sober.lapse-nudge"
        const val TRIAL_ENDING_ID = "sober.trial-ending"
        val ALL_IDS = listOf(DAILY_ID, MILESTONE_EVE_ID, LAPSE_ID, TRIAL_ENDING_ID)

        const val DEEP_LINK_KEY = "deepLink"
        const val DEEP_LINK_CHECK_IN = "checkIn"
        const val DEEP_LINK_BLOOM_PLUS = "bloomPlus"

        const val TRIAL_REMINDER_LEAD_DAYS = 2L
        const val LAPSE_NUDGE_DAYS = 3L
        const val CHANNEL_ID = "reminders"
        private const val ASKED_KEY = "notifications.permissionAsked"

        fun specKey(id: String) = "reminderSpec.$id"

        /** Supportive copy, never guilt. Leads with the streak when there is one. */
        fun dailyCopy(committed: Boolean, streakDays: Int): Pair<String, String> = if (streakDays > 1) {
            "Day ${streakDays + 1} is waiting" to if (committed) {
                "You're $streakDays days in. Log today and water your bonsai."
            } else {
                "$streakDays days and growing. If today's a sober one, log it."
            }
        } else {
            (if (committed) "Showing up today" else "Daily check-in") to if (committed) {
                "Log today and water your garden. You've got this."
            } else {
                "If today's a sober one, log it and water your garden."
            }
        }

        fun ensureChannel(context: Context) {
            val channel = NotificationChannel(CHANNEL_ID, "Reminders", NotificationManager.IMPORTANCE_DEFAULT)
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}

/** Inexact alarms: exact ones need a Play declaration, and a reminder a few minutes late costs nothing. */
class AlarmReminderPlatform(private val context: Context) : ReminderPlatform {
    private val alarms = context.getSystemService(AlarmManager::class.java)

    override fun canNotify(): Boolean {
        val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return granted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    /**
     * A bounded window rather than `setInexactRepeating`, whose daily window
     * runs to 18 hours and can deliver a 9am reminder in the small hours. The
     * daily one re-arms itself on delivery (`markDelivered`).
     */
    override fun schedule(spec: ReminderSpec) {
        alarms.setWindow(AlarmManager.RTC_WAKEUP, spec.fireAtMillis, WINDOW_MS, pending(spec.id))
    }

    override fun cancel(id: String) = alarms.cancel(pending(id))

    private fun pending(id: String): PendingIntent = PendingIntent.getBroadcast(
        context,
        id.hashCode(),
        Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        const val EXTRA_ID = "sober.reminderId"
        private const val WINDOW_MS = 15 * 60 * 1000L
    }
}

/** Waits on the activity's permission dialog. */
class PermissionBridge {
    private var pending: CompletableDeferred<Boolean>? = null
    var launch: (() -> Unit)? = null

    suspend fun request(): Boolean {
        val launcher = launch ?: return false
        val deferred = CompletableDeferred<Boolean>()
        pending = deferred
        launcher()
        return deferred.await()
    }

    fun complete(granted: Boolean) {
        pending?.complete(granted)
        pending = null
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(AlarmReminderPlatform.EXTRA_ID) ?: return
        val graph = (context.applicationContext as? SoberApplication)?.graph ?: return
        val spec = graph.notifications.spec(id) ?: return
        graph.notifications.markDelivered(id)
        if (!graph.notifications.isAuthorized) return
        NotificationService.ensureChannel(context)
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(NotificationService.DEEP_LINK_KEY, spec.deepLink)
        val content = PendingIntent.getActivity(
            context, id.hashCode(), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NotificationService.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(spec.title)
            .setContentText(spec.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(spec.body))
            .setContentIntent(content)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id.hashCode(), notification)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the post.
        }
    }
}

/** Alarms do not survive a reboot, an update, or a clock change. */
class ScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val graph = (context.applicationContext as? SoberApplication)?.graph ?: return
        graph.notifications.rescheduleAll()
        graph.refreshWidgets()
    }
}

