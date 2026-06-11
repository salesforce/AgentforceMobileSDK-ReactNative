/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Central diagnostic logging for the React Native bridge.
 */
package com.salesforce.android.reactagentforce

import android.util.Log

/**
 * Central diagnostic logging used by the bridge to surface OAuth, network, and
 * credential failures that the underlying SDK would otherwise hide behind generic
 * UI errors ("Something went wrong", "invalid client credentials").
 *
 * Every call writes to Logcat AND, when a JS LoggerDelegate is registered (i.e. the
 * [sink]'s forwarding is enabled), forwards the same message to JavaScript via the
 * `onLogMessage` channel the SDK logger already uses. This lets a customer capture
 * the diagnostics from JS without attaching a native debugger.
 *
 * Secrets (access tokens, consumer keys) must be passed through [redact] before
 * logging — never log a full token or key.
 */
object BridgeDiagnostics {

    /**
     * Sink installed by [AgentforceModule] so diagnostics can also reach the JS
     * LoggerDelegate. Null until the module is constructed; diagnostics still go to
     * Logcat in that window.
     */
    @Volatile
    var sink: BridgeLogger? = null

    fun d(tag: String, message: String) {
        Log.d(tag, message)
        sink?.forwardDiagnostic("debug", "[$tag] $message", null)
    }

    fun w(tag: String, message: String, error: Throwable? = null) {
        Log.w(tag, message, error)
        sink?.forwardDiagnostic("warn", "[$tag] $message", error?.toString())
    }

    fun e(tag: String, message: String, error: Throwable? = null) {
        Log.e(tag, message, error)
        sink?.forwardDiagnostic("error", "[$tag] $message", error?.toString())
    }

    /**
     * Redact a secret for logging: keeps the first 6 and last 4 characters plus the
     * length, so a truncated/mismatched consumer key is diagnosable without exposing
     * the full credential. Short values are fully masked.
     */
    fun redact(secret: String?): String {
        if (secret.isNullOrEmpty()) return "<empty>"
        val len = secret.length
        return if (len <= 12) {
            "<redacted len=$len>"
        } else {
            "${secret.substring(0, 6)}…${secret.substring(len - 4)} (len=$len)"
        }
    }
}
