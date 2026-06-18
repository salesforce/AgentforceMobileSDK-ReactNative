/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.app.Activity
import android.content.Intent
import android.util.Log

/**
 * Drives the Agentforce conversation UI hosted in the dedicated, bridge-owned
 * [AgentforceConversationActivity].
 *
 * Previously the conversation was an overlay ComposeView attached to the host app's
 * current Activity. That made the SDK's activity-scoped conversation ViewModel (and its
 * one-shot bootstrap) depend on the host handing back the SAME Activity instance across
 * dismiss/re-launch — which some host apps don't, causing a re-bootstrap 404 hang on
 * re-launch. See [[project_rn_android_bootstrap_fix]].
 *
 * Now the conversation lives in its own `singleTask` Activity with a stable instance.
 * - [show]   starts (or brings forward) the conversation Activity.
 * - [hide]   sends it to the background WITHOUT finishing it, so its ViewModelStore and
 *            completed bootstrap survive — re-launch reuses the same instance, no
 *            re-bootstrap, conversation history preserved.
 * - [destroy] actually finishes the Activity; call when a fresh conversation is required
 *            (logout, reset, mode/agent switch).
 *
 * The public API (show/hide/destroy/isVisible) is unchanged so existing AgentforceModule
 * call-sites keep working.
 */
object AgentforceConversationOverlay {

    private const val TAG = "AgentforceConvOverlay"

    /**
     * Whether the conversation is currently presented. Kept as a plain flag (not Compose
     * state) for parity with the previous API; the Activity owns its own composition now.
     */
    @Volatile
    internal var isVisible: Boolean = false
        private set

    /** The live conversation Activity instance, set from its own lifecycle callbacks. */
    @Volatile
    private var activityRef: AgentforceConversationActivity? = null

    /** Called by [AgentforceConversationActivity.onCreate]/onDestroy to track the instance. */
    internal fun registerActivity(activity: AgentforceConversationActivity) {
        activityRef = activity
    }

    internal fun unregisterActivity(activity: AgentforceConversationActivity) {
        if (activityRef === activity) {
            activityRef = null
        }
    }

    /**
     * Present the conversation. Launches [AgentforceConversationActivity] if not already
     * running, or brings the existing (backgrounded) instance forward — which does NOT
     * recreate it, so the SDK bootstrap state is preserved.
     */
    fun show(activity: Activity) {
        val intent = Intent(activity, AgentforceConversationActivity::class.java).apply {
            // Reuse the existing single task instance instead of creating a new one.
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        activity.startActivity(intent)
        isVisible = true
        Log.d(TAG, "Conversation activity shown")
    }

    /**
     * Dismiss the conversation WITHOUT finishing the Activity, so its ViewModelStore and
     * the SDK's completed bootstrap survive for the next [show]. Backgrounds the task.
     */
    fun hide() {
        isVisible = false
        activityRef?.let { activity ->
            activity.runOnUiThread {
                // moveTaskToBack keeps the Activity instance (and its ViewModelStore) alive.
                activity.moveTaskToBack(true)
            }
        }
        Log.d(TAG, "Conversation activity hidden (backgrounded, state preserved)")
    }

    /**
     * Finish the conversation Activity entirely. Call when a fresh conversation is
     * required (logout, reset, mode/agent switch) — the next [show] starts clean.
     */
    fun destroy() {
        isVisible = false
        activityRef?.let { activity ->
            activity.runOnUiThread { activity.finish() }
        }
        activityRef = null
        Log.d(TAG, "Conversation activity destroyed")
    }
}
