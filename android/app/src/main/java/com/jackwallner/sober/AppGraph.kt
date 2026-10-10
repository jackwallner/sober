package com.jackwallner.sober

import android.content.Context
import androidx.glance.appwidget.updateAll
import com.jackwallner.sober.content.SoberContent
import com.jackwallner.sober.data.AlarmReminderPlatform
import com.jackwallner.sober.data.AtomicStateFile
import com.jackwallner.sober.data.ConversionDiagnostics
import com.jackwallner.sober.data.NotificationService
import com.jackwallner.sober.data.PermissionBridge
import com.jackwallner.sober.data.PitchScheduler
import com.jackwallner.sober.data.ReviewPromptTracker
import com.jackwallner.sober.data.SharedPreferencesStore
import com.jackwallner.sober.data.SoberStore
import com.jackwallner.sober.data.SubscriptionService
import com.jackwallner.sober.data.TrialLifecycle
import com.jackwallner.sober.data.TrialNudgeGate
import com.jackwallner.sober.data.TrialOfferCoordinator
import com.jackwallner.sober.data.TrialSubsequentPitchGate
import com.jackwallner.sober.model.SystemAppClock
import com.jackwallner.sober.widget.SoberWidget
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

/** Every long-lived object the screens share, built once per process. */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val clock = SystemAppClock()
    val content = SoberContent.shared
    val defaults = SharedPreferencesStore(appContext)
    val permissions = PermissionBridge()
    val notifications = NotificationService(AlarmReminderPlatform(appContext), defaults).also {
        it.permissionRequester = permissions::request
    }
    val store = SoberStore(AtomicStateFile(appContext.filesDir), clock, content) { refreshWidgets() }
    val review = ReviewPromptTracker(defaults, clock)
    val diagnostics = ConversionDiagnostics(defaults, clock)
    val trial = TrialLifecycle(defaults, clock, notifications)
    val subscriptions = SubscriptionService(appContext, defaults, diagnostics, trial)
    val coordinator = TrialOfferCoordinator()
    val nudges = TrialNudgeGate(defaults, clock)
    val pitchGate = TrialSubsequentPitchGate(defaults, nudges)
    val pitches = PitchScheduler(subscriptions, coordinator, nudges, pitchGate)

    /** `WidgetSnapshotPump.push`: the home-screen widget reads the store directly. */
    fun refreshWidgets() {
        scope.launch { runCatching { SoberWidget().updateAll(appContext) } }
    }
}
