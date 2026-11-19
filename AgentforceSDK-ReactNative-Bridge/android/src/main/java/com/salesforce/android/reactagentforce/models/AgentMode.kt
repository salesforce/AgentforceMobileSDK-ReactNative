/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce.models

import com.facebook.react.bridge.ReadableMap

/** ReadableNativeMap throws for an absent key, even when the return type is nullable. */
private fun ReadableMap.stringOrNull(key: String): String? =
    if (hasKey(key)) getString(key) else null

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
    val esDeveloperName: String,
    /** Optional UI settings parsed from JS config */
    val serviceUISettings: Map<String, Boolean>? = null
) {
    companion object {
        /**
         * Creates a ServiceAgentModeConfig from a ReadableMap
         * @param map ReadableMap containing configuration values
         * @return ServiceAgentModeConfig if all required fields are present, null otherwise
         */
        fun fromReadableMap(map: ReadableMap): ServiceAgentModeConfig? {
            val serviceApiURL = map.stringOrNull("serviceApiURL") ?: return null
            val organizationId = map.stringOrNull("organizationId") ?: return null
            val esDeveloperName = map.stringOrNull("esDeveloperName") ?: return null

            val uiSettings: Map<String, Boolean>? = if (map.hasKey("serviceUISettings")) {
                map.getMap("serviceUISettings")?.let { settingsMap ->
                    val result = mutableMapOf<String, Boolean>()
                    val iterator = settingsMap.keySetIterator()
                    while (iterator.hasNextKey()) {
                        val key = iterator.nextKey()
                        result[key] = settingsMap.getBoolean(key)
                    }
                    result.ifEmpty { null }
                }
            } else {
                null
            }

            return ServiceAgentModeConfig(
                serviceApiURL = serviceApiURL,
                organizationId = organizationId,
                esDeveloperName = esDeveloperName,
                serviceUISettings = uiSettings
            )
        }
    }
}

/**
 * Configuration for Employee Agent mode (authenticated access)
 */
sealed class EmployeeAuthentication {
    data class Legacy(val accessToken: String) : EmployeeAuthentication()
    data object MobileSDKOAuth : EmployeeAuthentication()
    data class DirectOAuth(val accessToken: String) : EmployeeAuthentication()

    /** Token values may rotate without changing the authentication source. */
    fun hasSameSourceAs(other: EmployeeAuthentication): Boolean = when (this) {
        is Legacy -> other is Legacy
        is MobileSDKOAuth -> other is MobileSDKOAuth
        is DirectOAuth -> other is DirectOAuth
    }

    val usesMobileSDKNetwork: Boolean
        get() = this is Legacy || this is MobileSDKOAuth
}

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
    var accessToken: String,
    val authentication: EmployeeAuthentication = EmployeeAuthentication.Legacy(accessToken)
) {
    /** User/account identity and authentication source determine whether a client can be reused. */
    fun hasSameIdentityAs(other: EmployeeAgentModeConfig): Boolean =
        instanceUrl == other.instanceUrl &&
            organizationId == other.organizationId &&
            userId == other.userId &&
            authentication.hasSameSourceAs(other.authentication)

    /**
     * Multi-agent discovery is used only when the host leaves [agentId] unset.
     *
     * The React Native contract accepts one direct agent ID, not a list of IDs. When that ID is
     * present, the Android SDK must stay on its direct-agent path so missing agent-info metadata
     * does not become an authoritative per-agent voice denial.
     */
    fun effectiveEnableMultiAgent(requested: Boolean): Boolean = requested && agentId == null

    /** Resolves the immutable settings installed when the native Employee client is created. */
    fun clientConfigurationPlan(
        requestedEnableMultiAgent: Boolean,
        enableMultiModalInput: Boolean,
        enablePDFUpload: Boolean,
        enableVoice: Boolean,
        voiceOptions: VoiceOptionsSnapshot,
        internalFlags: Map<String, Boolean>
    ): EmployeeClientConfigurationPlan = EmployeeClientConfigurationPlan(
        enableMultiAgent = effectiveEnableMultiAgent(requestedEnableMultiAgent),
        enableMultiModalInput = enableMultiModalInput,
        enablePDFUpload = enablePDFUpload,
        enableVoice = enableVoice,
        voiceOptions = voiceOptions,
        internalFlags = internalFlags.toMap(),
        directAgentId = agentId,
        directAgentLabel = agentLabel?.trim()?.takeIf { it.isNotEmpty() }
    )

    companion object {
        /**
         * Creates an EmployeeAgentModeConfig from a ReadableMap
         * @param map ReadableMap containing configuration values
         * @return EmployeeAgentModeConfig if all required fields are present, null otherwise
         */
        fun fromReadableMap(map: ReadableMap): EmployeeAgentModeConfig? {
            val instanceUrl = map.stringOrNull("instanceUrl") ?: return null
            val organizationId = map.stringOrNull("organizationId") ?: return null
            val userId = map.stringOrNull("userId") ?: return null
            val accessToken = map.stringOrNull("accessToken")
            val authentication = if (map.hasKey("authentication")) {
                if (accessToken != null) return null
                val auth = map.getMap("authentication") ?: return null
                when (auth.stringOrNull("type") to auth.stringOrNull("source")) {
                    "oauth" to "salesforceMobileSdk" -> EmployeeAuthentication.MobileSDKOAuth
                    "oauth" to "direct" -> {
                        val token = auth.stringOrNull("accessToken")?.takeIf { it.isNotBlank() } ?: return null
                        EmployeeAuthentication.DirectOAuth(token)
                    }
                    else -> return null
                }
            } else {
                EmployeeAuthentication.Legacy(accessToken ?: return null)
            }
            val agentId = map.stringOrNull("agentId")?.takeIf { it.isNotBlank() }

            return EmployeeAgentModeConfig(
                instanceUrl = instanceUrl,
                organizationId = organizationId,
                userId = userId,
                agentId = agentId,
                agentLabel = map.stringOrNull("agentLabel"),
                accessToken = accessToken ?: "",
                authentication = authentication
            )
        }
    }
}

/** Normalized voice options that affect native client behavior. */
data class VoiceOptionsSnapshot(
    val userSilenceTimeoutSeconds: Double?,
    val autoEndWhileMuted: Boolean,
    val defaultClosedCaptionsEnabled: Boolean,
)

/** Creation-time Employee Agent settings applied to a native client. */
data class EmployeeClientConfigurationPlan(
    val enableMultiAgent: Boolean,
    val enableMultiModalInput: Boolean,
    val enablePDFUpload: Boolean,
    val enableVoice: Boolean,
    val voiceOptions: VoiceOptionsSnapshot,
    val internalFlags: Map<String, Boolean>,
    val directAgentId: String?,
    val directAgentLabel: String?,
) {
    fun requiresClientRebuild(comparedTo: EmployeeClientConfigurationPlan?): Boolean = this != comparedTo
}
