/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat

/**
 * Dedicated, bridge-owned host Activity for the Agentforce conversation UI.
 *
 * Why a separate Activity instead of an overlay on the host's current Activity:
 * the SDK scopes its conversation ViewModel — and the one-shot bootstrap that
 * lives inside [AgentforceConversationContainer]'s `LaunchedEffect(Unit)` — to the
 * host Activity via `getActivityScopedViewModelStoreOwner()`. An in-host-Activity
 * overlay only survives a dismiss/re-launch when the host hands back the SAME
 * Activity instance. Some host apps (multi-activity nav, recreated RN host) don't,
 * so the overlay re-attaches to a new Activity, the SDK ViewModel is recreated,
 * bootstrap re-fires on the reused conversation, hits the by-design discovery 404
 * it can't recover from, and the chat hangs on "I'm on my way…".
 * See [[project_rn_android_bootstrap_fix]].
 *
 * This Activity is declared `singleTask` with its own taskAffinity, so it is a
 * single, stable instance independent of the host app's Activity stack. Dismiss
 * sends it to the background (it is NOT finished — see [AgentforceConversationOverlay]),
 * so the instance, its ViewModelStore, and the completed bootstrap all survive.
 * Re-launch brings the same instance forward (no recreation, no re-bootstrap),
 * preserving conversation history regardless of what the host app's navigation does.
 */
class AgentforceConversationActivity : ComponentActivity() {

    companion object {
        private const val TAG = "AgentforceConvActivity"
    }

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        AgentforceConversationOverlay.registerActivity(this)

        // Draw edge-to-edge and let the IME resize the content, matching the prior overlay.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        @Suppress("DEPRECATION")
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        setContent {
            // Read the shared client + conversation. If state was cleared (logout, reset,
            // mode switch) finish immediately rather than render an empty container.
            val client = AgentforceClientHolder.agentforceClient
            val conversation = AgentforceClientHolder.currentConversation
            if (client == null || conversation == null) {
                Log.w(TAG, "No client/conversation when rendering - finishing")
                finish()
                return@setContent
            }

            // Render the SDK container directly — it draws its own header (showTopBar
            // defaults true); the agentLabel override is wired via BridgeTopAppBarBuilder
            // in AgentforceModule.configureEmployeeAgent. onClose backgrounds this Activity
            // (see AgentforceConversationOverlay.hide) so SDK state survives re-launch.
            MaterialTheme {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .statusBarsPadding()
                        .padding(top = 12.dp)
                        .navigationBarsPadding()
                        .imePadding()
                ) {
                    client.AgentforceConversationContainer(
                        conversation = conversation,
                        onClose = { AgentforceConversationOverlay.hide() }
                    )
                }
            }
        }
    }

    /**
     * Hardware/gesture back dismisses the conversation the same way the SDK's close
     * action does — background (don't finish) so bootstrap state survives re-launch.
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        AgentforceConversationOverlay.hide()
    }

    override fun onDestroy() {
        AgentforceConversationOverlay.unregisterActivity(this)
        super.onDestroy()
    }
}
