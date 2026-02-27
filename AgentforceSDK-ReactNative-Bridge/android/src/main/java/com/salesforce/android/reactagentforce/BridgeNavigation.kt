/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Bridge navigation that forwards Agentforce SDK navigation requests to React Native JS via events.
 */
package com.salesforce.android.reactagentforce

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.salesforce.android.mobile.interfaces.navigation.Navigation
import com.salesforce.android.mobile.interfaces.navigation.destination.App
import com.salesforce.android.mobile.interfaces.navigation.destination.Destination
import com.salesforce.android.mobile.interfaces.navigation.destination.Link
import com.salesforce.android.mobile.interfaces.navigation.destination.ObjectHome
import com.salesforce.android.mobile.interfaces.navigation.destination.PageReference
import com.salesforce.android.mobile.interfaces.navigation.destination.QuickAction
import com.salesforce.android.mobile.interfaces.navigation.destination.Record

/**
 * Implements the Agentforce SDK Navigation interface and forwards navigation requests
 * to JavaScript via NativeEventEmitter events.
 *
 * Navigation forwarding is disabled by default and enabled when JS registers a NavigationDelegate.
 */
class BridgeNavigation(private val reactContext: ReactContext) : Navigation {

    /** Controls whether navigation requests are forwarded to JS. */
    var forwardingEnabled: Boolean = false

    override fun goto(destination: Destination) {
        if (!forwardingEnabled) return
        emitDestination(destination, replace = false)
    }

    override fun goto(destination: Destination, replace: Boolean) {
        if (!forwardingEnabled) return
        emitDestination(destination, replace = replace)
    }

    override fun openApp(app: App): App.OpenResult {
        if (!forwardingEnabled) return App.OpenResult.NOTOPEN

        val params = Arguments.createMap().apply {
            putString("type", "app")
            putString("packageName", app.packageName)
            app.uri?.let { putString("uri", it.toString()) }
        }
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onNavigationRequest", params)

        // We can't know if JS actually opened the app, so return OPEN optimistically
        return App.OpenResult.OPEN
    }

    private fun emitDestination(destination: Destination, replace: Boolean) {
        val params = Arguments.createMap()

        when (destination) {
            is Record -> {
                params.putString("type", "record")
                params.putString("recordId", destination.id)
                destination.type?.let { params.putString("objectType", it) }
                destination.pageReference?.let { params.putString("pageReference", it) }
            }
            is ObjectHome -> {
                params.putString("type", "objectHome")
                params.putString("objectType", destination.type)
                destination.pageReference?.let { params.putString("pageReference", it) }
            }
            is Link -> {
                params.putString("type", "link")
                params.putString("uri", destination.uri.toString())
                destination.pageReference?.let { params.putString("pageReference", it) }
            }
            is QuickAction -> {
                params.putString("type", "quickAction")
                params.putString("actionName", destination.actionName)
                destination.target?.let { target ->
                    params.putString("recordId", target.id)
                    target.type?.let { params.putString("objectType", it) }
                }
            }
            is PageReference -> {
                params.putString("type", "pageReference")
                destination.pageReference?.let { params.putString("pageReference", it) }
            }
            else -> {
                params.putString("type", "unknown")
                params.putString("raw", destination.toString())
            }
        }

        if (replace) {
            params.putBoolean("replace", true)
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onNavigationRequest", params)
    }
}
