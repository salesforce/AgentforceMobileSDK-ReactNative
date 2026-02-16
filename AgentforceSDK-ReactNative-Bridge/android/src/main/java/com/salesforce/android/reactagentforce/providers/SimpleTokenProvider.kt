/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.providers

import android.util.Log
import com.salesforce.android.reactagentforce.delegates.TokenException
import com.salesforce.android.reactagentforce.delegates.TokenProvider

/**
 * Simple token provider that holds tokens directly.
 * Used for testing or when tokens are provided via JS configuration.
 * Implements TokenProvider for use with UnifiedCredentialProvider in delegate mode.
 */
class SimpleTokenProvider(
    @Volatile private var accessToken: String,
    private val organizationId: String,
    private val userId: String,
    private val instanceUrl: String
) : TokenProvider {
    
    companion object {
        private const val TAG = "SimpleTokenProvider"
    }
    
    /** Handler called when token refresh is needed */
    private var tokenRefreshHandler: (suspend () -> String)? = null
    
    /** Handler called when authentication fails */
    private var authFailureHandler: (() -> Unit)? = null
    
    override fun getAccessToken(): String = accessToken
    
    override fun getOrganizationId(): String = organizationId
    
    override fun getUserId(): String = userId
    
    override fun getInstanceUrl(): String = instanceUrl
    
    override suspend fun refreshToken(): String {
        val handler = tokenRefreshHandler
            ?: throw TokenException("No refresh handler configured")
        
        return try {
            val newToken = handler()
            accessToken = newToken
            Log.d(TAG, "Token refreshed successfully")
            newToken
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh failed: ${e.message}")
            throw TokenException("Token refresh failed: ${e.message}", e)
        }
    }
    
    override fun onAuthenticationFailure() {
        Log.d(TAG, "Authentication failure triggered")
        authFailureHandler?.invoke()
    }
    
    /**
     * Set a handler for token refresh (called from JS delegate)
     * @param handler Suspending function that returns a new token
     */
    fun setRefreshHandler(handler: suspend () -> String) {
        this.tokenRefreshHandler = handler
    }
    
    /**
     * Set a handler for authentication failure
     * @param handler Function called when auth fails
     */
    fun setAuthFailureHandler(handler: () -> Unit) {
        this.authFailureHandler = handler
    }
    
    /**
     * Update token directly (e.g., when JS provides new token)
     * @param newToken The new access token
     */
    fun updateToken(newToken: String) {
        this.accessToken = newToken
        Log.d(TAG, "Token updated directly")
    }
}
