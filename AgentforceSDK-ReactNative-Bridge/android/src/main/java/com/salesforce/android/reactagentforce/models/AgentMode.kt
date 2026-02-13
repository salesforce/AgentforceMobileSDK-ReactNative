/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.models

import com.facebook.react.bridge.ReadableMap

/**
 * Sealed class defining the operating mode for the Agentforce SDK.
 * Mirrors the AgentConfig union type from JavaScript.
 */
sealed class AgentMode {
    
    /**
     * Service Agent mode - anonymous/guest access with empty OAuth token
     */
    data class Service(val config: ServiceAgentModeConfig) : AgentMode()
    
    /**
     * Employee Agent mode - authenticated access with real OAuth token
     * Uses SDK's FullConfig mode for full control over AgentforceConfiguration
     */
    data class Employee(val config: EmployeeAgentModeConfig) : AgentMode()
    
    /**
     * Returns the mode type as a string
     */
    val typeString: String
        get() = when (this) {
            is Service -> "service"
            is Employee -> "employee"
        }
}

/**
 * Configuration for Service Agent mode (anonymous/guest access)
 */
data class ServiceAgentModeConfig(
    /** The Service API URL endpoint */
    val serviceApiURL: String,
    /** Salesforce Organization ID */
    val organizationId: String,
    /** The Einstein Service Agent developer name */
    val esDeveloperName: String
) {
    companion object {
        /**
         * Creates a ServiceAgentModeConfig from a ReadableMap
         * @param map ReadableMap containing configuration values
         * @return ServiceAgentModeConfig if all required fields are present, null otherwise
         */
        fun fromReadableMap(map: ReadableMap): ServiceAgentModeConfig? {
            val serviceApiURL = map.getString("serviceApiURL") ?: return null
            val organizationId = map.getString("organizationId") ?: return null
            val esDeveloperName = map.getString("esDeveloperName") ?: return null
            
            return ServiceAgentModeConfig(
                serviceApiURL = serviceApiURL,
                organizationId = organizationId,
                esDeveloperName = esDeveloperName
            )
        }
    }
}

/**
 * Configuration for Employee Agent mode (authenticated access)
 */
data class EmployeeAgentModeConfig(
    /** Salesforce instance URL (e.g., "https://myorg.my.salesforce.com") */
    val instanceUrl: String,
    /** Salesforce Organization ID */
    val organizationId: String,
    /** Salesforce User ID */
    val userId: String,
    /** Agentforce Agent ID; null when multi-agent is used and SDK should pick first available agent from org */
    val agentId: String? = null,
    /** Optional display label for the agent */
    val agentLabel: String? = null,
    /** OAuth access token for authentication */
    var accessToken: String
) {
    companion object {
        /**
         * Creates an EmployeeAgentModeConfig from a ReadableMap
         * @param map ReadableMap containing configuration values
         * @return EmployeeAgentModeConfig if all required fields are present, null otherwise
         */
        fun fromReadableMap(map: ReadableMap): EmployeeAgentModeConfig? {
            val instanceUrl = map.getString("instanceUrl") ?: return null
            val organizationId = map.getString("organizationId") ?: return null
            val userId = map.getString("userId") ?: return null
            val accessToken = map.getString("accessToken") ?: return null
            val agentId = map.getString("agentId")?.takeIf { it.isNotBlank() }

            return EmployeeAgentModeConfig(
                instanceUrl = instanceUrl,
                organizationId = organizationId,
                userId = userId,
                agentId = agentId,
                agentLabel = if (map.hasKey("agentLabel")) map.getString("agentLabel") else null,
                accessToken = accessToken
            )
        }
    }
}
