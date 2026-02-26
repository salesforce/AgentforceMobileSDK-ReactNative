/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.salesforce.android.agentforcesdkimpl.AgentforceClient
import com.salesforce.android.agentforcesdkimpl.AgentforceConversation
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceConfiguration
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceMode
import com.salesforce.android.agentforcesdkimpl.configuration.ServiceAgentConfiguration
import com.salesforce.android.agentforcesdkimpl.utils.AgentforceFeatureFlagSettings
import com.salesforce.android.agentforceservice.AgentforceAuthCredentialProvider
import com.salesforce.android.agentforceservice.AgentforceAuthCredentials
import com.salesforce.android.mobile.interfaces.user.Org
import com.salesforce.android.mobile.interfaces.user.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing Agentforce Service Agent SDK lifecycle and state
 */
class ServiceAgentViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "ServiceAgentViewModel"
        private const val PREFS_NAME = "ServiceAgentPrefs"
        private const val KEY_SERVICE_API_URL = "serviceApiURL"
        private const val KEY_ORGANIZATION_ID = "organizationId"
        private const val KEY_ES_DEVELOPER_NAME = "esDeveloperName"
        // Same as AgentforceModule so Service Agent uses the same feature flags
        private const val FEATURE_FLAGS_PREFS_NAME = "AgentforceFeatureFlags"
        private const val KEY_ENABLE_MULTI_AGENT = "enableMultiAgent"
        private const val KEY_ENABLE_MULTI_MODAL_INPUT = "enableMultiModalInput"
        private const val KEY_ENABLE_PDF_UPLOAD = "enablePDFUpload"
        private const val KEY_ENABLE_VOICE = "enableVoice"
    }
    
    private val prefs: SharedPreferences = application.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val featureFlagsPrefs: SharedPreferences = application.getSharedPreferences(FEATURE_FLAGS_PREFS_NAME, Context.MODE_PRIVATE)

    // Service Agent configuration
    private val _serviceApiURL = MutableStateFlow("")
    val serviceApiURL: StateFlow<String> = _serviceApiURL.asStateFlow()

    private val _organizationId = MutableStateFlow("")
    val organizationId: StateFlow<String> = _organizationId.asStateFlow()

    private val _esDeveloperName = MutableStateFlow("")
    val esDeveloperName: StateFlow<String> = _esDeveloperName.asStateFlow()

    // SDK state - using shared holder to persist across activities
    val agentforceClient: AgentforceClient? get() = AgentforceClientHolder.agentforceClient

    private val _conversation = MutableStateFlow<AgentforceConversation?>(null)
    val conversation: StateFlow<AgentforceConversation?> = _conversation.asStateFlow()

    private val _isConfigured = MutableStateFlow(false)
    val isConfigured: StateFlow<Boolean> = _isConfigured.asStateFlow()
    
    init {
        // Load saved configuration from SharedPreferences
        loadConfiguration()
        
        // Update isConfigured based on loaded values
        updateConfiguredState()
        
        // Sync conversation state with holder
        _conversation.value = AgentforceClientHolder.currentConversation
    }
    
    /**
     * Load configuration from SharedPreferences
     */
    private fun loadConfiguration() {
        _serviceApiURL.value = prefs.getString(KEY_SERVICE_API_URL, "") ?: ""
        _organizationId.value = prefs.getString(KEY_ORGANIZATION_ID, "") ?: ""
        _esDeveloperName.value = prefs.getString(KEY_ES_DEVELOPER_NAME, "") ?: ""
    }
    
    /**
     * Update configured state based on current configuration values
     */
    private fun updateConfiguredState() {
        val hasValidConfig = _serviceApiURL.value.isNotBlank() &&
                             _organizationId.value.isNotBlank() &&
                             _esDeveloperName.value.isNotBlank()
        _isConfigured.value = hasValidConfig
    }
    
    /**
     * Save configuration to SharedPreferences
     */
    private fun saveConfiguration() {
        prefs.edit()
            .putString(KEY_SERVICE_API_URL, _serviceApiURL.value)
            .putString(KEY_ORGANIZATION_ID, _organizationId.value)
            .putString(KEY_ES_DEVELOPER_NAME, _esDeveloperName.value)
            .commit()
    }

    /**
     * Update Service Agent configuration
     */
    fun updateConfiguration(
        serviceApiURL: String,
        organizationId: String,
        esDeveloperName: String
    ) {
        _serviceApiURL.value = serviceApiURL
        _organizationId.value = organizationId
        _esDeveloperName.value = esDeveloperName
        saveConfiguration()
        updateConfiguredState()
    }
    
    /**
     * Get current configuration
     */
    fun getConfiguration(): Map<String, String> {
        return mapOf(
            "serviceApiURL" to _serviceApiURL.value,
            "organizationId" to _organizationId.value,
            "esDeveloperName" to _esDeveloperName.value
        )
    }
    
    /**
     * Reset configuration to defaults
     */
    fun resetConfiguration() {
        _serviceApiURL.value = ""
        _organizationId.value = ""
        _esDeveloperName.value = ""
        _isConfigured.value = false
        saveConfiguration()
        AgentforceClientHolder.clear()
    }

    /**
     * Initialize Agentforce SDK with Service Agent mode
     * Clears any existing client and conversation to start fresh
     */
    fun initializeAgentforce() {
        if (_serviceApiURL.value.isEmpty() ||
            _organizationId.value.isEmpty() ||
            _esDeveloperName.value.isEmpty()
        ) {
            Log.e(TAG, "Configuration incomplete")
            return
        }

        // Clear existing client and conversation when reconfiguring
        AgentforceClientHolder.clear()
        _conversation.value = null

        viewModelScope.launch {
            try {

                // Simple auth provider for Service Agent (no authentication needed)
                val authCredentialProvider = object : AgentforceAuthCredentialProvider {
                    override fun getAuthCredentials(): AgentforceAuthCredentials {
                        return AgentforceAuthCredentials.OAuth(
                            authToken = "", // Service agent doesn't need token
                            orgId = _organizationId.value,
                            userId = "" // Service agent doesn't need userId
                        )
                    }
                }

                // Use same feature flags as AgentforceModule (from shared prefs)
                val featureFlagSettings = AgentforceFeatureFlagSettings.builder()
                    .enableMultiAgent(featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_AGENT, true))
                    .enableMultiModalInput(featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, false))
                    .enablePDFUpload(featureFlagsPrefs.getBoolean(KEY_ENABLE_PDF_UPLOAD, false))
                    .enableVoice(false) // Voice off for Service Agent
                    .build()

                val cameraUriProvider = AgentforceClientCameraUriProvider(getApplication())

                // Service Agent mode configuration
                val serviceAgentMode = AgentforceMode.ServiceAgent(
                    serviceAgentConfiguration = ServiceAgentConfiguration
                        .builder(
                            esDeveloperName = _esDeveloperName.value,
                            organizationId = _organizationId.value,
                            serviceApiURL = _serviceApiURL.value
                        )
                        .build(),
                    agentforceConfiguration = AgentforceConfiguration
                        .builder(authCredentialProvider)
                        .setServiceApiURL(_serviceApiURL.value)
                        .setSalesforceDomain(_serviceApiURL.value)
                        .setUser(
                            User(
                                org = Org(id = _organizationId.value, community = null),
                                userName = "service_user",
                                displayName = "Service User"
                            )
                        )
                        .setApplication(getApplication())
                        .setFeatureFlagSettings(featureFlagSettings)
                        .setCameraUriProvider(cameraUriProvider)
                        .build()
                )

                // Initialize client
                val client = AgentforceClient()
                client.init(
                    agentforceMode = serviceAgentMode,
                    application = getApplication()
                )

                // Store in shared holder
                AgentforceClientHolder.setClient(client)
                _isConfigured.value = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Agentforce", e)
                _isConfigured.value = false
                throw e
            }
        }
    }

    /**
     * Get or start a conversation (reuses existing if available)
     */
    fun startConversation() {
        // Reuse existing conversation if available
        val existingConversation = AgentforceClientHolder.currentConversation
        if (existingConversation != null) {
            _conversation.value = existingConversation
            return
        }
        
        val client = AgentforceClientHolder.agentforceClient
        if (client == null) {
            Log.e(TAG, "AgentforceClient is null - not initialized")
            return
        }
        
        viewModelScope.launch {
            try {
                val newConversation = client.startAgentforceConversation()
                _conversation.value = newConversation
                AgentforceClientHolder.setConversation(newConversation)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start conversation", e)
            }
        }
    }
    
    /**
     * Start a new conversation (closes existing one)
     */
    fun startNewConversation() {
        closeConversation()
        startConversation()
    }
    
    /**
     * Close the current conversation
     * Android SDK doesn't require explicit conversation closure,
     * just clear the reference to allow a new conversation to start
     */
    fun closeConversation() {
        _conversation.value = null
        AgentforceClientHolder.setConversation(null)
    }

    /**
     * Clean up resources
     */
    override fun onCleared() {
        super.onCleared()
        // Don't clear the shared client holder - it should persist
        _conversation.value = null
    }
}

