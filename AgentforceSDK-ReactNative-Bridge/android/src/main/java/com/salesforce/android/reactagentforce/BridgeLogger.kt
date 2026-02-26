/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Bridge logger that forwards Agentforce SDK log calls to React Native JS via events.
 */
package com.salesforce.android.reactagentforce

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.salesforce.android.mobile.interfaces.logging.Logger

/**
 * Implements the Agentforce SDK Logger interface and forwards log messages
 * to JavaScript via NativeEventEmitter events.
 *
 * Log forwarding is disabled by default and enabled when JS registers a LoggerDelegate.
 */
class BridgeLogger(private val reactContext: ReactContext) : Logger {

    /** Controls whether log messages are forwarded to JS. */
    var forwardingEnabled: Boolean = false

    private fun emit(level: String, message: String, error: String? = null) {
        if (!forwardingEnabled) return

        val params = Arguments.createMap().apply {
            putString("level", level)
            putString("message", message)
            error?.let { putString("error", it) }
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onLogMessage", params)
    }

    override fun e(message: String) = emit("error", message)
    override fun e(message: String, exception: Throwable) = emit("error", message, exception.toString())
    override fun i(message: String) = emit("info", message)
    override fun i(message: String, exception: Throwable) = emit("info", message, exception.toString())
    override fun w(message: String) = emit("warn", message)
    override fun w(message: String, exception: Throwable) = emit("warn", message, exception.toString())
}
