/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.delegates

/**
 * Interface for providing OAuth tokens to the Agentforce SDK.
 * Consuming apps implement this to integrate with their auth system.
 * Only used when AgentMode is Employee.
 */
interface TokenProvider {
    /**
     * Returns the current valid access token
     */
    fun getAccessToken(): String
    
    /**
     * Returns the Salesforce organization ID
     */
    fun getOrganizationId(): String
    
    /**
     * Returns the Salesforce user ID
     */
    fun getUserId(): String
    
    /**
     * Returns the Salesforce instance URL
     */
    fun getInstanceUrl(): String
    
    /**
     * Called when token refresh is needed
     * @return The new access token
     * @throws Exception if token refresh fails
     */
    suspend fun refreshToken(): String
    
    /**
     * Called when authentication fails completely
     * Implementing classes can use this to trigger re-login flow
     */
    fun onAuthenticationFailure() {
        // Default no-op implementation
    }
}

/**
 * Exception thrown when token operations fail
 */
class TokenException(message: String, cause: Throwable? = null) : Exception(message, cause)
