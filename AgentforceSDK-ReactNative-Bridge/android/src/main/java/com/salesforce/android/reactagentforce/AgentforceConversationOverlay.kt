/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.app.Activity
import android.util.Log
import android.view.MotionEvent
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner

/**
 * Manages the Agentforce conversation UI as an overlay on the current Activity.
 *
 * This matches the SDK test harness pattern: the AgentforceConversationContainer
 * composable lives in the same Activity's composition tree, so the SDK's internal
 * ViewModel persists across show/hide cycles. This prevents stale state issues
 * (like secure forms reappearing) that occur when using a separate Activity.
 */
object AgentforceConversationOverlay {

    private const val TAG = "AgentforceConvOverlay"

    internal var isVisible = mutableStateOf(false)
    private var overlayContainer: ViewGroup? = null
    private var attachedActivity: ComponentActivity? = null

    /**
     * Show the conversation overlay on the given Activity.
     * Creates the ComposeView on first call, then toggles visibility.
     */
    fun show(activity: Activity) {
        if (activity !is ComponentActivity) {
            Log.e(TAG, "Activity must be a ComponentActivity")
            return
        }

        if (overlayContainer == null || attachedActivity !== activity) {
            attachToActivity(activity)
        }

        isVisible.value = true
        Log.d(TAG, "Conversation overlay shown")
    }

    /**
     * Hide the conversation overlay (preserves state).
     */
    fun hide() {
        isVisible.value = false
        Log.d(TAG, "Conversation overlay hidden")
    }

    /**
     * Detach and destroy the overlay. Call when configuration changes
     * require a fresh conversation. Must be called on the main thread.
     */
    fun destroy() {
        overlayContainer?.let { container ->
            (container.parent as? ViewGroup)?.removeView(container)
        }
        overlayContainer = null
        attachedActivity = null
        isVisible.value = false
        Log.d(TAG, "Conversation overlay destroyed")
    }

    private fun attachToActivity(activity: ComponentActivity) {
        destroy()

        val overlayState = isVisible
        val wrapper = object : FrameLayout(activity) {
            override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
                if (!overlayState.value) return false
                return super.dispatchTouchEvent(ev)
            }
        }

        val overlay = ComposeView(activity).apply {
            setViewTreeLifecycleOwner(activity)
            setViewTreeViewModelStoreOwner(activity)
            setViewTreeSavedStateRegistryOwner(activity)

            setContent {
                ConversationOverlayContent(
                    onClose = { hide() }
                )
            }
        }

        wrapper.addView(
            overlay,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        val contentView = activity.findViewById<ViewGroup>(android.R.id.content)
        contentView.addView(
            wrapper,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        overlayContainer = wrapper
        attachedActivity = activity
        Log.d(TAG, "Overlay attached to activity: ${activity.javaClass.simpleName}")
    }
}

@Composable
private fun ConversationOverlayContent(onClose: () -> Unit) {
    val visible by AgentforceConversationOverlay.isVisible

    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(
            initialOffsetY = { fullHeight -> fullHeight },
            animationSpec = tween(durationMillis = 250)
        ),
        exit = slideOutVertically(
            targetOffsetY = { fullHeight -> fullHeight },
            animationSpec = tween(durationMillis = 250)
        )
    ) {
        BackHandler { onClose() }

        val client = AgentforceClientHolder.agentforceClient
        val conversation = AgentforceClientHolder.currentConversation

        if (conversation != null && client != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .systemBarsPadding()
            ) {
                client.AgentforceConversationContainer(
                    conversation = conversation,
                    onClose = onClose
                )
            }
        }
    }
}
