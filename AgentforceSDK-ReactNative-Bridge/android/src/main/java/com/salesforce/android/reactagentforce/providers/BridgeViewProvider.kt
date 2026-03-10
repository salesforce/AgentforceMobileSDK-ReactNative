/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Bridges the native AgentforceViewProvider interface to React Native.
 * When enabled, delegates rendering of specified component types to a
 * registered React Native component via ReactRootView.
 */
package com.salesforce.android.reactagentforce.providers

import android.os.Bundle
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.facebook.react.ReactApplication
import com.facebook.react.ReactRootView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import com.salesforce.android.agentforcesdk.components.models.AgentforceComponent
import com.salesforce.android.agentforcesdk.components.models.AgentforceViewProvider
import java.util.concurrent.ConcurrentHashMap

/**
 * Implements AgentforceViewProvider by delegating to a React Native component.
 * Component types are registered synchronously from JS; rendering uses ReactRootView.
 */
class BridgeViewProvider(
    private val reactContext: ReactApplicationContext
) : AgentforceViewProvider {

    /**
     * Maps component definition strings to their React Native component names.
     * Thread-safe: `canHandle` may be called from the SDK rendering thread while
     * `register`/`reset` are called from the JS thread.
     */
    private val componentMap: ConcurrentHashMap<String, String> = ConcurrentHashMap()

    /** Register a 1:1 mapping of component types to React component names. */
    fun register(componentMap: Map<String, String>) {
        this.componentMap.clear()
        this.componentMap.putAll(componentMap)
    }

    /** Clear all registrations */
    fun reset() {
        componentMap.clear()
    }

    val isRegistered: Boolean
        get() = componentMap.isNotEmpty()

    // region AgentforceViewProvider

    override fun canHandle(definition: String): Boolean {
        return componentMap.containsKey(definition)
    }

    @Composable
    override fun GetView(modifier: Modifier, view: AgentforceComponent) {
        val moduleName = componentMap[view.definition] ?: return
        val props = componentToBundle(view)
        AndroidView(
            modifier = modifier,
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

    /** Convert AgentforceComponent to a Bundle for React Native initial properties */
    private fun componentToBundle(component: AgentforceComponent): Bundle {
        return Bundle().apply {
            putString("definition", component.definition)
            component.name?.let { putString("name", it) }
            putBundle("properties", mapToBundle(component.properties))
            if (component.subComponents.isNotEmpty()) {
                val subArray = component.subComponents.map { componentToBundle(it) }.toTypedArray()
                putParcelableArray("subComponents", subArray)
            }
        }
    }

    /** Recursively convert a Map to a Bundle */
    private fun mapToBundle(map: Map<String, Any>): Bundle {
        return Bundle().apply {
            for ((key, value) in map) {
                when (value) {
                    is String -> putString(key, value)
                    is Int -> putInt(key, value)
                    is Long -> putLong(key, value)
                    is Double -> putDouble(key, value)
                    is Float -> putFloat(key, value)
                    is Boolean -> putBoolean(key, value)
                    is Map<*, *> -> {
                        @Suppress("UNCHECKED_CAST")
                        putBundle(key, mapToBundle(value as Map<String, Any>))
                    }
                    is List<*> -> {
                        // Coerces all elements to strings via toString(). Numeric/nested
                        // type information is lost — acceptable for the current SDK contract
                        // where list properties are display-only string sequences.
                        putStringArray(key, value.map { it?.toString() ?: "" }.toTypedArray())
                    }
                    else -> putString(key, value.toString())
                }
            }
        }
    }

    // endregion
}
