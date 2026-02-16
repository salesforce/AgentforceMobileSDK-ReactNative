/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.util.Log
import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

/**
 * React Native package for Agentforce module.
 * Registers AgentforceModule always; registers EmployeeAgentAuthBridge only when
 * Salesforce Mobile SDK is available at runtime (so Service Agent–only apps
 * without the SDK don't fail loading the bridge).
 */
class AgentforcePackage : ReactPackage {
    override fun createNativeModules(
        reactContext: ReactApplicationContext
    ): List<NativeModule> {
        val modules = mutableListOf<NativeModule>(
            AgentforceModule(reactContext)
        )

        // Only register EmployeeAgentAuthBridge if Mobile SDK is present at runtime.
        // The bridge imports SalesforceSDKManager etc. at class level — if those
        // classes aren't on the classpath the class will fail to load. This mirrors
        // the iOS #if __has_include(<SalesforceSDKCore/...>) guard.
        if (isMobileSdkAvailable()) {
            try {
                modules.add(EmployeeAgentAuthBridge(reactContext))
            } catch (e: Throwable) {
                // NoClassDefFoundError / ExceptionInInitializerError if SDK removed
                // after build. Degrade gracefully — Employee Agent auth disabled.
                Log.w(
                    "AgentforcePackage",
                    "EmployeeAgentAuthBridge not loaded (Mobile SDK unavailable): ${e.message}"
                )
            }
        }

        return modules
    }

    override fun createViewManagers(
        reactContext: ReactApplicationContext
    ): List<ViewManager<*, *>> {
        return emptyList()
    }

    companion object {
        /**
         * Check if Salesforce Mobile SDK is on the runtime classpath.
         * Uses reflection so this class itself has no hard dependency.
         */
        private fun isMobileSdkAvailable(): Boolean {
            return try {
                Class.forName("com.salesforce.androidsdk.app.SalesforceSDKManager")
                true
            } catch (e: ClassNotFoundException) {
                false
            }
        }
    }
}
