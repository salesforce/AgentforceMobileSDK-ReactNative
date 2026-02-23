/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.providers

import android.util.Log
import com.salesforce.android.agentforceservice.AgentforceAuthCredentialProvider
import com.salesforce.android.agentforceservice.AgentforceAuthCredentials
import com.salesforce.android.reactagentforce.delegates.TokenProvider
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
    
    /** Token provider for Employee Agent mode (null for Service Agent) */
    private var tokenProvider: TokenProvider? = null
    
    /** Direct token storage for simple token cases */
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
        this.tokenProvider = null
        this.directToken = ""  // Empty token for Service Agent
        this.directOrgId = serviceAgent.organizationId
        this.directUserId = ""  // Empty userId for Service Agent
        
        Log.d(TAG, "Configured for Service Agent mode")
    }
    
    /**
     * Configure for Employee Agent mode with a token provider delegate
     * @param config Employee Agent configuration
     * @param tokenProvider Token provider implementation
     */
    fun configure(employeeAgent: EmployeeAgentModeConfig, tokenProvider: TokenProvider) {
        this.mode = AgentMode.Employee(employeeAgent)
        this.tokenProvider = tokenProvider
        this.directToken = null
        this.directOrgId = null
        this.directUserId = null
        
        Log.d(TAG, "Configured for Employee Agent mode with token provider")
    }
    
    /**
     * Configure for Employee Agent mode with a direct token (simpler testing scenario)
     * @param config Employee Agent configuration with accessToken
     */
    fun configure(employeeAgent: EmployeeAgentModeConfig) {
        this.mode = AgentMode.Employee(employeeAgent)
        this.tokenProvider = null
        this.directToken = employeeAgent.accessToken
        this.directOrgId = employeeAgent.organizationId
        this.directUserId = employeeAgent.userId
        
        Log.d(TAG, "Configured for Employee Agent mode with direct token")
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
                // Get fresh token from Mobile SDK each time (Mobile SDK handles refresh internally)
                try {
                    val currentToken = SalesforceSDKManager.getInstance()
                        ?.userAccountManager?.currentUser?.authToken

                    if (currentToken != null) {
                        Log.d(TAG, "✅ Fetched fresh token from Mobile SDK")
                        return AgentforceAuthCredentials.OAuth(
                            authToken = currentToken,
                            orgId = currentMode.config.organizationId,
                            userId = currentMode.config.userId
                        )
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to get fresh token from Mobile SDK, falling back to cached", e)
                }

                // Fallback to cached token if Mobile SDK not available
                val provider = tokenProvider
                if (provider != null) {
                    // Delegate-based token
                    AgentforceAuthCredentials.OAuth(
                        authToken = provider.getAccessToken(),
                        orgId = provider.getOrganizationId(),
                        userId = provider.getUserId()
                    )
                } else {
                    // Direct token
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
        Log.d(TAG, "Token updated")
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
        tokenProvider = null
        directToken = null
        directOrgId = null
        directUserId = null
        Log.d(TAG, "Reset to unconfigured state")
    }
}
