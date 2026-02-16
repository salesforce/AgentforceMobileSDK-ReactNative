/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for Employee Agent auth via Salesforce Mobile SDK.
 * When Mobile SDK is present and initialized, isAuthSupported is true and methods delegate to the SDK.
 * Bootconfig (res/values/bootconfig.xml) supplies OAuth client id, redirect URI, scopes.
 */

package com.salesforce.android.reactagentforce

import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableNativeMap
import com.salesforce.androidsdk.app.SalesforceSDKManager
import com.salesforce.androidsdk.rest.ClientManager
import com.salesforce.androidsdk.rest.RestClient

class EmployeeAgentAuthBridge(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private const val TAG = "EmployeeAgentAuthBridge"
        // Default account type for Salesforce Mobile SDK (matches res/values/strings.xml in SDK)
        private const val DEFAULT_ACCOUNT_TYPE = "com.salesforce.androidsdk"
    }

    override fun getName(): String = "EmployeeAgentAuthBridge"

    private fun clientManager(): ClientManager? {
        val manager = SalesforceSDKManager.getInstance() ?: return null
        return try {
            ClientManager(reactApplicationContext, DEFAULT_ACCOUNT_TYPE, true)
        } catch (e: Exception) {
            Log.e(TAG, "ClientManager init failed", e)
            null
        }
    }

    private fun credentialsFromRestClient(client: RestClient): WritableNativeMap {
        val map = WritableNativeMap()
        val info = client.clientInfo
        map.putString("instanceUrl", info?.instanceUrl?.toString() ?: "")
        map.putString("organizationId", info?.orgId ?: "")
        map.putString("userId", info?.userId ?: "")
        map.putString("accessToken", client.authToken ?: "")
        return map
    }

    @ReactMethod
    fun isAuthSupported(promise: Promise) {
        try {
            // Verify SDK is actually initialized, not just on the classpath
            val sdkManager = SalesforceSDKManager.getInstance()
            promise.resolve(sdkManager != null)
        } catch (e: Exception) {
            Log.w(TAG, "isAuthSupported: SDK not available", e)
            promise.resolve(false)
        }
    }

    @ReactMethod
    fun getAuthCredentials(promise: Promise) {
        try {
            val mgr = clientManager() ?: run {
                promise.resolve(null)
                return
            }
            val client = mgr.peekRestClient()
            if (client != null && client.authToken != null) {
                promise.resolve(credentialsFromRestClient(client))
            } else {
                promise.resolve(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "getAuthCredentials failed", e)
            promise.reject("ERROR", e.message)
        }
    }

    /**
     * Ask the Mobile SDK to refresh the current session and return updated credentials.
     * Use this when the Agentforce backend returns 401 (e.g. expired token). getRestClient()
     * causes the SDK to provide a RestClient, which may trigger an automatic token refresh.
     */
    @ReactMethod
    fun refreshAuthCredentials(promise: Promise) {
        try {
            val activity = currentActivity
            if (activity == null) {
                promise.reject("NO_ACTIVITY", "No current activity for refresh")
                return
            }
            val mgr = clientManager()
            if (mgr == null) {
                promise.reject("NOT_AVAILABLE", "Salesforce SDK not initialized")
                return
            }
            mgr.getRestClient(activity, object : ClientManager.RestClientCallback {
                override fun authenticatedRestClient(client: RestClient?) {
                    if (client != null && client.authToken != null) {
                        promise.resolve(credentialsFromRestClient(client))
                    } else {
                        promise.reject("REFRESH_FAILED", "No credentials after refresh")
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "refreshAuthCredentials failed", e)
            promise.reject("ERROR", e.message)
        }
    }

    @ReactMethod
    fun login(promise: Promise) {
        try {
            val activity = currentActivity
            if (activity == null) {
                promise.reject("NO_ACTIVITY", "No current activity for login")
                return
            }
            val mgr = clientManager()
            if (mgr == null) {
                promise.reject("NOT_AVAILABLE", "Salesforce SDK not initialized")
                return
            }
            // getRestClient kicks off login flow if no account; callback runs when RestClient is ready
            mgr.getRestClient(activity, object : ClientManager.RestClientCallback {
                override fun authenticatedRestClient(client: RestClient?) {
                    if (client != null && client.authToken != null) {
                        promise.resolve(credentialsFromRestClient(client))
                    } else {
                        promise.reject("LOGIN_FAILED", "No credentials after login")
                    }
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "login failed", e)
            promise.reject("ERROR", e.message)
        }
    }

    @ReactMethod
    fun logout(promise: Promise) {
        try {
            SalesforceSDKManager.getInstance()?.logout(currentActivity)
            promise.resolve(null)
        } catch (e: Exception) {
            Log.e(TAG, "logout failed", e)
            promise.reject("ERROR", e.message)
        }
    }
}
