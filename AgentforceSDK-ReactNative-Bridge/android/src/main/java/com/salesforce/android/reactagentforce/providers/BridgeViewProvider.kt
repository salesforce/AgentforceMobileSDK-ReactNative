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
import java.util.concurrent.atomic.AtomicReference

/**
 * Implements AgentforceViewProvider by delegating to a React Native component.
 * Component types are registered synchronously from JS; rendering uses ReactRootView.
 */
class BridgeViewProvider(
    private val reactContext: ReactApplicationContext
) : AgentforceViewProvider {

    /**
     * Maps component definition strings to their React Native component names.
     * Uses AtomicReference to swap the entire immutable map in one shot, so
     * `canHandle` never sees a partially-updated (empty) map during registration.
     */
    private val componentMap: AtomicReference<Map<String, String>> = AtomicReference(emptyMap())

    /** Register a 1:1 mapping of component types to React component names. */
    fun register(componentMap: Map<String, String>) {
        this.componentMap.set(componentMap.toMap())
    }

    /** Clear all registrations */
    fun reset() {
        componentMap.set(emptyMap())
    }

    val isRegistered: Boolean
        get() = componentMap.get().isNotEmpty()

    // region AgentforceViewProvider

    override fun canHandle(definition: String): Boolean {
        return componentMap.get().containsKey(definition)
    }

    @Composable
    override fun GetView(modifier: Modifier, view: AgentforceComponent) {
        val moduleName = componentMap.get()[view.definition] ?: return
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
                        putParcelableArray(key, listToBundleArray(value))
                    }
                    else -> putString(key, value.toString())
                }
            }
        }
    }

    /**
     * Convert a heterogeneous list to an array of Bundles.
     * Each element is wrapped in a Bundle with a "value" key for primitives,
     * or inlined for Map elements, preserving type information across the bridge.
     */
    private fun listToBundleArray(list: List<*>): Array<Bundle> {
        return list.map { item ->
            when (item) {
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    mapToBundle(item as Map<String, Any>)
                }
                else -> Bundle().apply {
                    when (item) {
                        is String -> putString("value", item)
                        is Int -> putInt("value", item)
                        is Long -> putLong("value", item)
                        is Double -> putDouble("value", item)
                        is Float -> putFloat("value", item)
                        is Boolean -> putBoolean("value", item)
                        is List<*> -> putParcelableArray("value", listToBundleArray(item))
                        else -> putString("value", item?.toString() ?: "")
                    }
                }
            }
        }.toTypedArray()
    }

    // endregion
}
