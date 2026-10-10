package com.jackwallner.sober

import android.content.Intent

/** Release and QA builds: launch extras never change anything. */
object DebugLaunchOptions {
    @Suppress("UNUSED_PARAMETER")
    fun apply(graph: AppGraph, intent: Intent?) = Unit

    val launchTab: Int? = null
    val showProgress: Boolean = false
    val onboardingStep: Int? = null
    val gallery: Boolean = false
}
