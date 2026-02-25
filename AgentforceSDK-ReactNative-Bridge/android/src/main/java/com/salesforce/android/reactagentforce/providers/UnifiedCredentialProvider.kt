/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.providers

import android.util.Log
import com.salesforce.android.agentforceservice.AgentforceAuthCredentialProvider
import com.salesforce.android.agentforceservice.AgentforceAuthCredentials
import com.salesforce.android.reactagentforce.models.AgentMode
import com.salesforce.android.reactagentforce.models.EmployeeAgentModeConfig
import com.salesforce.android.reactagentforce.models.ServiceAgentModeConfig
import com.salesforce.androidsdk.app.SalesforceSDKManager

/**
 * Unified credential provider that handles both Service Agent and Employee Agent modes.
 * Returns .OAuth credentials for both modes:
 * - Service Agent: empty token and userId (guest access)
 * - Employee Agent: real token and userId (authenticated access)
 */
class UnifiedCredentialProvider : AgentforceAuthCredentialProvider {
    
    companion object {
        private const val TAG = "UnifiedCredentialProvider"
    }
    
    /** Current operating mode */
    var mode: AgentMode? = null
        private set

    /** Direct token storage for simple token cases (fallback only) */
    @Volatile
    private var directToken: String? = null
    private var directOrgId: String? = null
    private var directUserId: String? = null
    
    /**
     * Configure for Service Agent mode (anonymous/guest access)
     * @param config Service Agent configuration
     */
    fun configure(serviceAgent: ServiceAgentModeConfig) {
        this.mode = AgentMode.Service(serviceAgent)
        this.directToken = ""  // Empty token for Service Agent
        this.directOrgId = serviceAgent.organizationId
        this.directUserId = ""  // Empty userId for Service Agent

    }

    /**
     * Configure for Employee Agent mode
     * @param config Employee Agent configuration
     */
    fun configure(employeeAgent: EmployeeAgentModeConfig) {
        this.mode = AgentMode.Employee(employeeAgent)
        this.directToken = employeeAgent.accessToken
        this.directOrgId = employeeAgent.organizationId
        this.directUserId = employeeAgent.userId

    }
    
    override fun getAuthCredentials(): AgentforceAuthCredentials {
        val currentMode = mode
            ?: throw IllegalStateException("UnifiedCredentialProvider not configured. Call configure() first.")
        
        return when (currentMode) {
            is AgentMode.Service -> {
                // Service Agent uses OAuth with EMPTY token (guest access)
                AgentforceAuthCredentials.OAuth(
                    authToken = "",
                    orgId = currentMode.config.organizationId,
                    userId = ""
                )
            }
            
            is AgentMode.Employee -> {
                // Employee Agent uses OAuth with REAL token
                // Get fresh credentials from Mobile SDK each time (Mobile SDK handles refresh internally)
                try {
                    val currentUser = SalesforceSDKManager.getInstance()
                        ?.userAccountManager?.currentUser

                    if (currentUser != null) {
                        val authToken = currentUser.authToken
                        val orgId = currentUser.orgId
                        val userId = currentUser.userId

                        if (authToken != null && orgId != null && userId != null) {
                            return AgentforceAuthCredentials.OAuth(
                                authToken = authToken,
                                orgId = orgId,
                                userId = userId
                            )
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to get fresh credentials from Mobile SDK, falling back to cached", e)
                }

                // Fallback to cached token if Mobile SDK not available
                val token = directToken
                    ?: throw IllegalStateException("Employee Agent mode requires either Mobile SDK or cached token")
                AgentforceAuthCredentials.OAuth(
                    authToken = token,
                    orgId = directOrgId ?: currentMode.config.organizationId,
                    userId = directUserId ?: currentMode.config.userId
                )
            }
        }
    }
    
    /**
     * Update the direct token (used when JS provides a refreshed token)
     * @param newToken The new access token
     */
    fun updateToken(newToken: String) {
        if (mode !is AgentMode.Employee) {
            Log.w(TAG, "updateToken called but not in Employee Agent mode")
            return
        }
        this.directToken = newToken
    }
    
    /** Check if currently in Employee Agent mode */
    val isEmployeeAgent: Boolean
        get() = mode is AgentMode.Employee
    
    /** Check if currently in Service Agent mode */
    val isServiceAgent: Boolean
        get() = mode is AgentMode.Service
    
    /** Check if the provider is configured */
    val isConfigured: Boolean
        get() = mode != null
    
    /** Get the current mode's configuration description (for debugging/logging) */
    val currentConfiguration: String
        get() = when (val m = mode) {
            null -> "Unconfigured"
            is AgentMode.Service -> "Service Agent - Org: ${m.config.organizationId}"
            is AgentMode.Employee -> "Employee Agent - Org: ${m.config.organizationId}, User: ${m.config.userId}"
        }
    
    /**
     * Reset the provider to unconfigured state
     */
    fun reset() {
        mode = null
        directToken = null
        directOrgId = null
        directUserId = null
    }
}
