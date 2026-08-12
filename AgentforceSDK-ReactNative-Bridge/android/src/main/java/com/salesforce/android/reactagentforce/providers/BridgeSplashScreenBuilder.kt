/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Bridges the native SplashScreenBuilder hook to React Native.
 * When a splash screen is registered for an agent, the SDK renders a registered
 * React Native component (via ReactRootView) as the welcome screen, and the user's
 * chosen utterance is routed back into the SDK.
 */
package com.salesforce.android.reactagentforce.providers

import android.os.Bundle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.facebook.react.ReactApplication
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.ReactRootView
import com.salesforce.android.agentforcesdk.components.models.SplashScreenBuilder
import com.salesforce.android.agentforcesdk.components.models.SplashScreenState
import java.util.concurrent.atomic.AtomicReference

/**
 * Implements [SplashScreenBuilder] by delegating to a React Native component.
 *
 * Agent IDs are mapped 1:1 to React Native component names, registered synchronously
 * from JS. When the SDK asks whether an agent has a splash screen, [hasSplashScreen]
 * checks the map; when it renders one, [SplashScreen] hosts the mapped component in a
 * [ReactRootView], passing `{ agentId }` as initial props.
 *
 * The SDK hands each [SplashScreenState] a fresh `onSelectUtterance` callback. We
 * capture the latest one per agent so a later [selectUtterance] call from JS (via the
 * native module's `selectSplashScreenUtterance`) can report the user's choice, which
 * dismisses the splash and sends the utterance into the conversation.
 */
class BridgeSplashScreenBuilder(
    private val reactContext: ReactApplicationContext
) : SplashScreenBuilder {

    /**
     * Maps agent IDs to their React Native component names. Uses AtomicReference to
     * swap the whole immutable map in one shot, so [hasSplashScreen] never sees a
     * partially-updated map during registration.
     */
    private val componentMap: AtomicReference<Map<String, String>> = AtomicReference(emptyMap())

    /**
     * Latest `onSelectUtterance` callback per agent, captured while the splash for
     * that agent is composed. Swapped atomically for the same reason as [componentMap].
     */
    private val utteranceCallbacks: AtomicReference<Map<String, (String) -> Unit>> =
        AtomicReference(emptyMap())

    /** Register a 1:1 mapping of agent IDs to React component names. */
    fun register(componentMap: Map<String, String>) {
        this.componentMap.set(componentMap.toMap())
    }

    /** Clear all registrations and captured callbacks. */
    fun reset() {
        componentMap.set(emptyMap())
        utteranceCallbacks.set(emptyMap())
    }

    val isRegistered: Boolean
        get() = componentMap.get().isNotEmpty()

    /** Component name for [agentId], falling back to the wildcard entry when present. */
    private fun componentName(agentId: String): String? {
        val map = componentMap.get()
        return map[agentId] ?: map[WILDCARD_KEY]
    }

    // region SplashScreenBuilder

    override fun hasSplashScreen(agentId: String): Boolean = componentName(agentId) != null

    @Composable
    override fun SplashScreen(state: SplashScreenState) {
        val moduleName = componentName(state.agentId) ?: return

        // Capture the current callback so selectUtterance() can invoke it from the
        // native module thread when JS reports a chosen utterance.
        SideEffect {
            utteranceCallbacks.updateAndGet { current ->
                current + (state.agentId to state.onSelectUtterance)
            }
        }

        val props = Bundle().apply { putString("agentId", state.agentId) }
        AndroidView(
            modifier = Modifier,
            factory = { context ->
                ReactRootView(context).apply {
                    val reactApp = reactContext.applicationContext as? ReactApplication
                    val instanceManager = reactApp?.reactNativeHost?.reactInstanceManager
                    startReactApplication(instanceManager, moduleName, props)
                }
            },
            onRelease = { view -> view.unmountReactApplication() }
        )
    }

    // endregion

    /**
     * Forward a user-chosen utterance from the React Native splash component into the
     * SDK. Invokes the captured `onSelectUtterance` callback for [agentId] (falling
     * back to the sole captured callback when the JS component reports an empty or
     * unknown agent ID, e.g. single-agent apps using the wildcard).
     *
     * @return true if a callback was found and invoked, false otherwise.
     */
    fun selectUtterance(agentId: String, utterance: String): Boolean {
        val callbacks = utteranceCallbacks.get()
        val callback = callbacks[agentId]
            ?: callbacks.values.singleOrNull()
            ?: return false
        callback(utterance)
        return true
    }

    companion object {
        /** Wildcard key matching any agent that has no explicit entry. */
        private const val WILDCARD_KEY = "*"
    }
}
