package com.jackwallner.sober.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import com.google.android.play.core.review.ReviewManagerFactory
import com.jackwallner.sober.AppGraph
import com.jackwallner.sober.ui.screens.MainTabs
import com.jackwallner.sober.ui.screens.OnboardingScreen
import com.jackwallner.sober.ui.theme.SoberAlert

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("No AppGraph provided") }

fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

fun Context.openUrl(url: String) {
    runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

/** The Play in-app review card, never from a button and never after a question. */
fun Context.launchPlayReview() {
    val activity = findActivity() ?: return
    val manager = ReviewManagerFactory.create(activity)
    manager.requestReviewFlow().addOnCompleteListener { request ->
        if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
    }
}

/**
 * `RootView`: onboarding until it completes (a branch, never a cover, so Home
 * never flashes behind it), the tab host after, and the "Not saved" alert.
 */
@Composable
fun RootScreen(graph: AppGraph, deepLink: String?, onDeepLinkConsumed: () -> Unit) {
    val store = graph.store
    val onboarded = store.hasCompletedOnboarding

    // A trial just started and its reminder needs the permission the trial raised.
    LaunchedEffect(graph.trial.wantsReminderPermission) {
        if (!graph.trial.wantsReminderPermission) return@LaunchedEffect
        if (graph.notifications.ensureAuthorized()) graph.trial.scheduleReminderIfPossible()
        else graph.trial.wantsReminderPermission = false
    }

    if (com.jackwallner.sober.DebugLaunchOptions.gallery) {
        com.jackwallner.sober.ui.bonsai.BonsaiGallery()
        return
    }
    AnimatedContent(
        onboarded,
        transitionSpec = { fadeIn(tween(350)) togetherWith fadeOut(tween(350)) },
        label = "root",
    ) { done ->
        if (done) MainTabs(deepLink, onDeepLinkConsumed) else OnboardingScreen()
    }

    store.message?.let { message ->
        SoberAlert("Not saved", message, onConfirm = { store.clearMessage() })
    }
}
