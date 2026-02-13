/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import com.salesforce.android.agentforcesdkimpl.AgentforceClient
import com.salesforce.android.agentforcesdkimpl.AgentforceConversation
import com.salesforce.android.reactagentforce.models.AgentMode

/**
 * Singleton holder for AgentforceClient to share across activities.
 * This is necessary because ViewModels are activity-scoped.
 * Updated to support both Service Agent and Employee Agent modes.
 */
object AgentforceClientHolder {
    
    @Volatile
    var agentforceClient: AgentforceClient? = null
        private set
    
    @Volatile
    var currentConversation: AgentforceConversation? = null
        private set
    
    @Volatile
    var isConfigured: Boolean = false
        private set
    
    /** Current agent mode (Service or Employee) */
    @Volatile
    var currentMode: AgentMode? = null
        private set
    
    /** Agent ID for Employee Agent mode */
    @Volatile
    var agentId: String? = null
        private set
    
    /** ES Developer Name for Service Agent mode */
    @Volatile
    var esDeveloperName: String? = null
        private set
    
    /**
     * Set the Agentforce client
     */
    fun setClient(client: AgentforceClient) {
        agentforceClient = client
        isConfigured = true
    }
    
    /**
     * Set the current conversation
     */
    fun setConversation(conversation: AgentforceConversation?) {
        currentConversation = conversation
    }
    
    /**
     * Set the current agent mode
     */
    fun setMode(mode: AgentMode) {
        currentMode = mode
        
        // Extract agent identifiers based on mode
        when (mode) {
            is AgentMode.Service -> {
                esDeveloperName = mode.config.esDeveloperName
                agentId = null
            }
            is AgentMode.Employee -> {
                agentId = mode.config.agentId
                esDeveloperName = null
            }
        }
    }
    
    /**
     * Set the agent ID for Employee Agent mode
     */
    fun setAgentId(id: String) {
        agentId = id
    }
    
    /**
     * Set the ES Developer Name for Service Agent mode
     */
    fun setEsDeveloperName(name: String) {
        esDeveloperName = name
    }
    
    /**
     * Clear the conversation reference but keep the client
     */
    fun clearConversation() {
        currentConversation = null
    }
    
    /**
     * Clear all state
     */
    fun clear() {
        currentConversation = null
        agentforceClient = null
        isConfigured = false
        currentMode = null
        agentId = null
        esDeveloperName = null
    }
    
    /**
     * Check if the holder is configured for Employee Agent mode
     */
    val isEmployeeAgent: Boolean
        get() = currentMode is AgentMode.Employee
    
    /**
     * Check if the holder is configured for Service Agent mode
     */
    val isServiceAgent: Boolean
        get() = currentMode is AgentMode.Service
    
    /**
     * Get the mode type string
     */
    val modeTypeString: String?
        get() = currentMode?.typeString
}
