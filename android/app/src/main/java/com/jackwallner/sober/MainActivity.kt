package com.jackwallner.sober

import android.Manifest
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.lifecycle.lifecycleScope
import com.jackwallner.sober.data.NotificationService
import com.jackwallner.sober.ui.LocalGraph
import com.jackwallner.sober.ui.RootScreen
import com.jackwallner.sober.ui.theme.SoberTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    private var pendingDeepLink by mutableStateOf<String?>(null)
    private val graph: AppGraph get() = (application as SoberApplication).graph

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        graph.permissions.complete(granted)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = graph
        graph.permissions.launch = { notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS) }
        if (savedInstanceState == null) {
            graph.review.recordAppLaunch()
            graph.diagnostics.recordAppOpen()
            DebugLaunchOptions.apply(graph, intent)
        }
        // The app is light-only on iOS (`preferredColorScheme(.light)`): dark icons on cream bars.
        val bars = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
        enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
        pendingDeepLink = intent?.getStringExtra(NotificationService.DEEP_LINK_KEY)
        lifecycleScope.launch { graph.subscriptions.start() }
        setContent {
            CompositionLocalProvider(LocalGraph provides graph) {
                SoberTheme {
                    // Test tags double as resource ids so UI Automator and capture scripts can find controls.
                    Box(Modifier.semantics { testTagsAsResourceId = true }) {
                        RootScreen(graph, pendingDeepLink, onDeepLinkConsumed = { pendingDeepLink = null })
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra(NotificationService.DEEP_LINK_KEY)?.let { pendingDeepLink = it }
    }

    override fun onResume() {
        super.onResume()
        // Renewals, restores, and late grants flip the app promptly, like iOS's foreground refresh.
        lifecycleScope.launch { graph.subscriptions.refreshCustomerInfo() }
    }

    override fun onStop() {
        super.onStop()
        // Sync on the way out: the funnel events that matter happen after launch.
        graph.subscriptions.syncConversionAttributes()
    }

    override fun onDestroy() {
        if (isFinishing) graph.permissions.launch = null
        super.onDestroy()
    }
}
