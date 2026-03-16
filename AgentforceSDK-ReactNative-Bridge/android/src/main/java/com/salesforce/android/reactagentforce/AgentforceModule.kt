/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 *
 * React Native bridge module for Agentforce SDK
 * Supports both Service Agent (guest) and Employee Agent (authenticated) modes
 */
package com.salesforce.android.reactagentforce

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStoreOwner
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.salesforce.android.agentforcesdkimpl.AgentforceClient
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceConfiguration
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceMode
import com.salesforce.android.agentforcesdkimpl.configuration.ServiceAgentConfiguration
import com.salesforce.android.agentforcesdkimpl.utils.AgentforceFeatureFlagSettings
import com.salesforce.android.agentforceservice.conversationservice.data.CopilotContextVariable
import com.salesforce.android.agentforceservice.conversationservice.data.CopilotAdditionalContext
import com.salesforce.android.reactagentforce.models.AgentMode as LocalAgentMode
import com.salesforce.android.reactagentforce.models.EmployeeAgentModeConfig
import com.salesforce.android.reactagentforce.models.ServiceAgentModeConfig
import com.salesforce.android.reactagentforce.providers.BridgeViewProvider
import com.salesforce.android.reactagentforce.providers.UnifiedCredentialProvider
import kotlinx.coroutines.*

/**
 * React Native bridge module for Agentforce SDK.
 * Supports both Service Agent (guest) and Employee Agent (authenticated) modes.
 */
class AgentforceModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private const val TAG = "AgentforceModule"
        private const val MODULE_NAME = "AgentforceModule"
        private const val EMPLOYEE_PREFS_NAME = "EmployeeAgentPrefs"
        private const val KEY_EMPLOYEE_AGENT_ID = "employeeAgentId"
        private const val FEATURE_FLAGS_PREFS_NAME = "AgentforceFeatureFlags"
        private const val KEY_ENABLE_MULTI_AGENT = "enableMultiAgent"
        private const val KEY_ENABLE_MULTI_MODAL_INPUT = "enableMultiModalInput"
        private const val KEY_ENABLE_PDF_UPLOAD = "enablePDFUpload"
        private const val KEY_ENABLE_VOICE = "enableVoice"
        // Advisory only — gating is done on the JS side (HomeScreen checks this flag
        // before calling setViewProviderDelegate). The native layer does not gate on it.
        private const val KEY_ENABLE_CUSTOM_VIEW_PROVIDER = "enableCustomViewProvider"
    }

    private val employeePrefs: SharedPreferences
        get() = reactApplicationContext.getSharedPreferences(EMPLOYEE_PREFS_NAME, Context.MODE_PRIVATE)

    private val featureFlagsPrefs: SharedPreferences
        get() = reactApplicationContext.getSharedPreferences(FEATURE_FLAGS_PREFS_NAME, Context.MODE_PRIVATE)

    // Legacy ViewModel for Service Agent backward compatibility
    private var viewModel: ServiceAgentViewModel? = null

    // Unified credential provider for both modes
    private val credentialProvider = UnifiedCredentialProvider()

    // Current mode configuration
    private var currentMode: LocalAgentMode? = null

    // Bridge logger for forwarding SDK logs to JS
    private val bridgeLogger = BridgeLogger(reactContext)

    // Bridge navigation for forwarding SDK navigation requests to JS
    private val bridgeNavigation = BridgeNavigation(reactContext)

    // Bridge view provider for delegating native SDK views to React Native components
    private val bridgeViewProvider = BridgeViewProvider(reactContext)

    // Bridge hidden prechat fields (Service Agent only)
    private val bridgeHiddenPreChat = BridgeHiddenPreChat()

    // Coroutine scope for async operations
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun getName(): String = MODULE_NAME

    // region Unified Configuration Method
    
    /**
     * Configure the SDK with either Service or Employee agent settings.
     * Expects a map with 'type' field set to 'service' or 'employee'.
     */
    @ReactMethod
    fun configure(config: ReadableMap, promise: Promise) {
        val type = config.getString("type")
        
        Log.d(TAG, "configure() called with type: $type")
        
        when (type) {
            "service" -> configureServiceAgent(config, promise)
            "employee" -> configureEmployeeAgent(config, promise)
            null -> {
                // Legacy mode - check if it has service agent fields
                if (config.hasKey("serviceApiURL") && config.hasKey("organizationId") && config.hasKey("esDeveloperName")) {
                    configureLegacyServiceAgent(
                        config.getString("serviceApiURL") ?: "",
                        config.getString("organizationId") ?: "",
                        config.getString("esDeveloperName") ?: "",
                        promise
                    )
                } else {
                    promise.reject("INVALID_CONFIG", "Invalid or missing type. Must be 'service' or 'employee'")
                }
            }
            else -> promise.reject("INVALID_CONFIG", "Invalid type '$type'. Must be 'service' or 'employee'")
        }
    }

    // endregion

    // region Service Agent Configuration

    private fun configureServiceAgent(config: ReadableMap, promise: Promise) {
        val serviceConfig = ServiceAgentModeConfig.fromReadableMap(config)
        if (serviceConfig == null) {
            promise.reject("INVALID_CONFIG", "Missing required Service Agent configuration fields")
            return
        }
        
        Log.d(TAG, "Configuring Service Agent - Org: ${serviceConfig.organizationId}")
        
        // Configure unified credential provider
        credentialProvider.configure(serviceConfig)
        currentMode = LocalAgentMode.Service(serviceConfig)
        
        // Clear existing client
        AgentforceClientHolder.clear()
        
        // Also update the legacy ViewModel for backward compatibility
        ensureViewModel()
        viewModel?.updateConfiguration(
            serviceApiURL = serviceConfig.serviceApiURL,
            organizationId = serviceConfig.organizationId,
            esDeveloperName = serviceConfig.esDeveloperName
        )
        
        scope.launch {
            try {
                // Create SDK Service Agent configuration
                val sdkServiceConfig = ServiceAgentConfiguration
                    .builder(
                        esDeveloperName = serviceConfig.esDeveloperName,
                        organizationId = serviceConfig.organizationId,
                        serviceApiURL = serviceConfig.serviceApiURL
                    )
                    .build()
                
                val flags = getFeatureFlagsFromConfigOrPrefs(config)
                val featureFlagSettings = AgentforceFeatureFlagSettings.builder()
                    .enableMultiAgent(flags.enableMultiAgent)
                    .enableMultiModalInput(flags.enableMultiModalInput)
                    .enablePDFUpload(flags.enablePDFUpload)
                    .enableVoice(false) // Voice off for Service Agent
                    .build()

                val cameraUriProvider = AgentforceClientCameraUriProvider(reactApplicationContext.applicationContext)
                val permissions = reactApplicationContext.currentActivity?.let { AgentforceClientPermissions(it) }

                val agentforceConfigBuilder = AgentforceConfiguration
                    .builder(credentialProvider)
                    .setServiceApiURL(serviceConfig.serviceApiURL)
                    .setSalesforceDomain(serviceConfig.serviceApiURL)
                    .setApplication(reactApplicationContext.applicationContext as Application)
                    .setFeatureFlagSettings(featureFlagSettings)
                    .setCameraUriProvider(cameraUriProvider)
                    .setLogger(bridgeLogger)
                    .setNavigation(bridgeNavigation)
                permissions?.let { agentforceConfigBuilder.setPermission(it) }
                // Always attach bridgeViewProvider so late registrations take effect.
                // canHandle() returns false when the map is empty, matching no-provider behavior.
                agentforceConfigBuilder.setViewProvider(bridgeViewProvider)
                val agentforceConfig = agentforceConfigBuilder.build()

                val sdkMode = AgentforceMode.ServiceAgent(
                    serviceAgentConfiguration = sdkServiceConfig,
                    agentforceConfiguration = agentforceConfig
                )

                // Initialize client
                val client = AgentforceClient()
                client.init(
                    agentforceMode = sdkMode,
                    application = reactApplicationContext.applicationContext as Application,
                    hiddenPreChatFieldDelegate = bridgeHiddenPreChat
                )
                
                AgentforceClientHolder.setClient(client)
                AgentforceClientHolder.setMode(LocalAgentMode.Service(serviceConfig))
                
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("mode", "service")
                })
            } catch (e: Exception) {
                Log.e(TAG, "Service Agent configuration failed", e)
                promise.reject("CONFIG_ERROR", e.message, e)
            }
        }
    }

    // endregion

    // region Employee Agent Configuration

    private fun configureEmployeeAgent(config: ReadableMap, promise: Promise) {
        val employeeConfig = EmployeeAgentModeConfig.fromReadableMap(config)
        if (employeeConfig == null) {
            promise.reject("INVALID_CONFIG", "Missing required Employee Agent configuration fields")
            return
        }
        
        Log.d(TAG, "Configuring Employee Agent - Org: ${employeeConfig.organizationId}, User: ${employeeConfig.userId}")

        // Configure unified credential provider for Employee Agent mode
        // UnifiedCredentialProvider will fetch fresh tokens from Mobile SDK automatically
        credentialProvider.configure(employeeConfig)
        currentMode = LocalAgentMode.Employee(employeeConfig)
        
        // Persist employee agentId (editable in Settings tab)
        employeePrefs.edit().putString(KEY_EMPLOYEE_AGENT_ID, employeeConfig.agentId ?: "").apply()
        
        // Clear existing client
        AgentforceClientHolder.clear()
        
        scope.launch {
            try {
                // Create AgentforceConfiguration for FullConfig mode
                val flags = getFeatureFlagsFromConfigOrPrefs(config)
                val featureFlagSettings = AgentforceFeatureFlagSettings.builder()
                    .enableMultiAgent(flags.enableMultiAgent)
                    .enableMultiModalInput(flags.enableMultiModalInput)
                    .enablePDFUpload(flags.enablePDFUpload)
                    .enableVoice(flags.enableVoice)
                    .build()

                val cameraUriProvider = AgentforceClientCameraUriProvider(reactApplicationContext.applicationContext)
                val permissions = reactApplicationContext.currentActivity?.let { AgentforceClientPermissions(it) }

                val agentforceConfigBuilder = AgentforceConfiguration
                    .builder(credentialProvider)
                    .setServiceApiURL(employeeConfig.instanceUrl)
                    .setSalesforceDomain(employeeConfig.instanceUrl)
                    .setApplication(reactApplicationContext.applicationContext as Application)
                    .setFeatureFlagSettings(featureFlagSettings)
                    .setCameraUriProvider(cameraUriProvider)
                    .setLogger(bridgeLogger)
                    .setNavigation(bridgeNavigation)
                permissions?.let { agentforceConfigBuilder.setPermission(it) }
                // Always attach bridgeViewProvider so late registrations take effect.
                // canHandle() returns false when the map is empty, matching no-provider behavior.
                agentforceConfigBuilder.setViewProvider(bridgeViewProvider)
                val agentforceConfig = agentforceConfigBuilder.build()

                // Use FullConfig mode for Employee Agent
                val sdkMode = AgentforceMode.FullConfig(
                    agentforceConfiguration = agentforceConfig
                )
                
                // Initialize client
                val client = AgentforceClient()
                client.init(
                    agentforceMode = sdkMode,
                    application = reactApplicationContext.applicationContext as Application
                )
                
                AgentforceClientHolder.setClient(client)
                AgentforceClientHolder.setMode(LocalAgentMode.Employee(employeeConfig))
                
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("mode", "employee")
                })
            } catch (e: Exception) {
                Log.e(TAG, "Employee Agent configuration failed", e)
                promise.reject("CONFIG_ERROR", e.message, e)
            }
        }
    }

    // endregion

    // region Legacy Configuration (Backward Compatibility)

    private fun configureLegacyServiceAgent(
        serviceApiURL: String,
        organizationId: String,
        esDeveloperName: String,
        promise: Promise
    ) {
        Log.d(TAG, "Legacy configure() called - converting to new format")
        
        val config = Arguments.createMap().apply {
            putString("type", "service")
            putString("serviceApiURL", serviceApiURL)
            putString("organizationId", organizationId)
            putString("esDeveloperName", esDeveloperName)
        }
        
        configureServiceAgent(config, promise)
    }

    // endregion

    // region Conversation Methods

    /**
     * Launch the Agentforce conversation UI - works for both Service and Employee agents
     */
    @ReactMethod
    fun launchConversation(promise: Promise) {
        Log.d(TAG, "launchConversation() called")

        val activity = currentActivity
        if (activity == null) {
            promise.reject("ERROR", "Activity not available")
            return
        }

        // Check if configured via new unified path or legacy path
        val isConfiguredUnified = credentialProvider.isConfigured
        val isConfiguredLegacy = viewModel?.isConfigured?.value == true
        
        if (!isConfiguredUnified && !isConfiguredLegacy) {
            promise.reject("NOT_CONFIGURED", "Agent not configured. Call configure() first.")
            return
        }

        // Initialize SDK if needed (legacy path)
        if (!AgentforceClientHolder.isConfigured && isConfiguredLegacy) {
            scope.launch {
                try {
                    viewModel?.initializeAgentforce()

                    val intent = Intent(activity, AgentforceConversationActivity::class.java)
                    activity.startActivity(intent)
                    promise.resolve(Arguments.createMap().apply {
                        putBoolean("success", true)
                    })
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to initialize SDK", e)
                    promise.reject("ERROR", "Failed to initialize: ${e.message}")
                }
            }
            return
        }

        // Create conversation before launching Activity so setAdditionalContext
        // can find it immediately after the promise resolves (matches iOS behavior).
        if (AgentforceClientHolder.currentConversation == null) {
            if (!createConversation(promise, "LAUNCH_ERROR")) return
        }

        // Launch conversation UI
        val intent = Intent(activity, AgentforceConversationActivity::class.java)
        activity.startActivity(intent)

        Log.d(TAG, "Conversation activity launched")
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
        })
    }

    /**
     * Start a new conversation (closes existing one)
     */
    @ReactMethod
    fun startNewConversation(promise: Promise) {
        Log.d(TAG, "startNewConversation() called")

        val activity = currentActivity
        if (activity == null) {
            promise.reject("ERROR", "Activity not available")
            return
        }

        if (!AgentforceClientHolder.isConfigured && viewModel?.isConfigured?.value != true) {
            promise.reject("NOT_CONFIGURED", "Agent not configured. Call configure() first.")
            return
        }

        // Clear existing conversation
        AgentforceClientHolder.clearConversation()
        viewModel?.closeConversation()

        // Create new conversation before launching Activity so setAdditionalContext
        // can find it immediately after the promise resolves (matches iOS behavior).
        if (!createConversation(promise, "START_NEW_ERROR")) return

        val intent = Intent(activity, AgentforceConversationActivity::class.java)
        activity.startActivity(intent)

        Log.d(TAG, "New conversation started")
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
        })
    }

    // endregion

    // region Configuration Query Methods

    @ReactMethod
    fun isConfigured(promise: Promise) {
        ensureViewModel()
        
        val configuredUnified = credentialProvider.isConfigured
        val configuredLegacy = viewModel?.isConfigured?.value ?: false
        
        promise.resolve(configuredUnified || configuredLegacy)
    }

    @ReactMethod
    fun getConfiguration(promise: Promise) {
        // Return service agent config format for backward compatibility
        if (currentMode is LocalAgentMode.Service) {
            val config = (currentMode as LocalAgentMode.Service).config
            promise.resolve(Arguments.createMap().apply {
                putString("serviceApiURL", config.serviceApiURL)
                putString("organizationId", config.organizationId)
                putString("esDeveloperName", config.esDeveloperName)
            })
            return
        }
        
        // Fall back to legacy ViewModel
        ensureViewModel()
        val config = viewModel?.getConfiguration() ?: mapOf(
            "serviceApiURL" to "",
            "organizationId" to "",
            "esDeveloperName" to ""
        )
        promise.resolve(Arguments.createMap().apply {
            putString("serviceApiURL", config["serviceApiURL"])
            putString("organizationId", config["organizationId"])
            putString("esDeveloperName", config["esDeveloperName"])
        })
    }

    @ReactMethod
    fun getEmployeeAgentId(promise: Promise) {
        val agentId = employeePrefs.getString(KEY_EMPLOYEE_AGENT_ID, null) ?: ""
        promise.resolve(agentId)
    }

    @ReactMethod
    fun setEmployeeAgentId(agentId: String, promise: Promise) {
        employeePrefs.edit().putString(KEY_EMPLOYEE_AGENT_ID, agentId ?: "").apply()
        promise.resolve(null)
    }

    private data class FeatureFlags(
        val enableMultiAgent: Boolean,
        val enableMultiModalInput: Boolean,
        val enablePDFUpload: Boolean,
        val enableVoice: Boolean,
        val enableCustomViewProvider: Boolean
    )

    private fun getFeatureFlagsFromConfigOrPrefs(config: ReadableMap): FeatureFlags {
        val featureFlagsMap = if (config.hasKey("featureFlags")) config.getMap("featureFlags") else null
        return if (featureFlagsMap != null) {
            FeatureFlags(
                enableMultiAgent = featureFlagsMap.hasKey("enableMultiAgent") && featureFlagsMap.getBoolean("enableMultiAgent"),
                enableMultiModalInput = featureFlagsMap.hasKey("enableMultiModalInput") && featureFlagsMap.getBoolean("enableMultiModalInput"),
                enablePDFUpload = featureFlagsMap.hasKey("enablePDFUpload") && featureFlagsMap.getBoolean("enablePDFUpload"),
                enableVoice = featureFlagsMap.hasKey("enableVoice") && featureFlagsMap.getBoolean("enableVoice"),
                enableCustomViewProvider = featureFlagsMap.hasKey("enableCustomViewProvider") && featureFlagsMap.getBoolean("enableCustomViewProvider")
            )
        } else {
            FeatureFlags(
                enableMultiAgent = featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_AGENT, true),
                enableMultiModalInput = featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, false),
                enablePDFUpload = featureFlagsPrefs.getBoolean(KEY_ENABLE_PDF_UPLOAD, false),
                enableVoice = featureFlagsPrefs.getBoolean(KEY_ENABLE_VOICE, false),
                enableCustomViewProvider = featureFlagsPrefs.getBoolean(KEY_ENABLE_CUSTOM_VIEW_PROVIDER, false)
            )
        }
    }

    private fun saveFeatureFlagsToPrefs(flags: FeatureFlags) {
        featureFlagsPrefs.edit()
            .putBoolean(KEY_ENABLE_MULTI_AGENT, flags.enableMultiAgent)
            .putBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, flags.enableMultiModalInput)
            .putBoolean(KEY_ENABLE_PDF_UPLOAD, flags.enablePDFUpload)
            .putBoolean(KEY_ENABLE_VOICE, flags.enableVoice)
            .putBoolean(KEY_ENABLE_CUSTOM_VIEW_PROVIDER, flags.enableCustomViewProvider)
            .apply()
    }

    @ReactMethod
    fun getFeatureFlags(promise: Promise) {
        promise.resolve(Arguments.createMap().apply {
            putBoolean("enableMultiAgent", featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_AGENT, true))
            putBoolean("enableMultiModalInput", featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, false))
            putBoolean("enablePDFUpload", featureFlagsPrefs.getBoolean(KEY_ENABLE_PDF_UPLOAD, false))
            putBoolean("enableVoice", featureFlagsPrefs.getBoolean(KEY_ENABLE_VOICE, false))
            putBoolean("enableCustomViewProvider", featureFlagsPrefs.getBoolean(KEY_ENABLE_CUSTOM_VIEW_PROVIDER, false))
        })
    }

    @ReactMethod
    fun setFeatureFlags(flags: ReadableMap, promise: Promise) {
        featureFlagsPrefs.edit()
            .putBoolean(KEY_ENABLE_MULTI_AGENT, flags.hasKey("enableMultiAgent") && flags.getBoolean("enableMultiAgent"))
            .putBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, flags.hasKey("enableMultiModalInput") && flags.getBoolean("enableMultiModalInput"))
            .putBoolean(KEY_ENABLE_PDF_UPLOAD, flags.hasKey("enablePDFUpload") && flags.getBoolean("enablePDFUpload"))
            .putBoolean(KEY_ENABLE_VOICE, flags.hasKey("enableVoice") && flags.getBoolean("enableVoice"))
            .putBoolean(KEY_ENABLE_CUSTOM_VIEW_PROVIDER, flags.hasKey("enableCustomViewProvider") && flags.getBoolean("enableCustomViewProvider"))
            .apply()
        promise.resolve(null)
    }

    @ReactMethod
    fun getConfigurationInfo(promise: Promise) {
        if (credentialProvider.isConfigured) {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("configured", true)
                putString("mode", if (credentialProvider.isServiceAgent) "service" else "employee")
                putString("description", credentialProvider.currentConfiguration)
            })
        } else if (viewModel?.isConfigured?.value == true) {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("configured", true)
                putString("mode", "service")
                putString("description", "Service Agent (legacy)")
            })
        } else {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("configured", false)
                putNull("mode")
            })
        }
    }

    @ReactMethod
    fun isInitialized(promise: Promise) {
        promise.resolve(AgentforceClientHolder.isConfigured)
    }

    // endregion

    // region Log Forwarding

    @ReactMethod
    fun enableLogForwarding(enabled: Boolean, promise: Promise) {
        bridgeLogger.forwardingEnabled = enabled
        Log.d(TAG, "Log forwarding ${if (enabled) "enabled" else "disabled"}")
        promise.resolve(true)
    }

    // endregion

    // region Navigation Forwarding

    @ReactMethod
    fun enableNavigationForwarding(enabled: Boolean, promise: Promise) {
        bridgeNavigation.forwardingEnabled = enabled
        Log.d(TAG, "Navigation forwarding ${if (enabled) "enabled" else "disabled"}")
        promise.resolve(true)
    }

    // endregion

    // region View Provider

    @ReactMethod
    fun registerViewProvider(config: ReadableMap, promise: Promise) {
        val mapData = config.getMap("componentMap")

        if (mapData == null) {
            promise.reject("INVALID_CONFIG", "Must provide a non-empty componentMap dictionary")
            return
        }

        val componentMap = mutableMapOf<String, String>()
        val iterator = mapData.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            mapData.getString(key)?.let { componentMap[key] = it }
        }

        if (componentMap.isEmpty()) {
            promise.reject("INVALID_CONFIG", "Must provide a non-empty componentMap dictionary")
            return
        }

        bridgeViewProvider.register(componentMap)
        val keysArray = Arguments.createArray().apply {
            componentMap.keys.forEach { pushString(it) }
        }
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
            putArray("registeredTypes", keysArray)
        })
    }

    @ReactMethod
    fun clearViewProvider(promise: Promise) {
        bridgeViewProvider.reset()
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
        })
    }

    // endregion

    // region Cleanup

    @ReactMethod
    fun closeConversation(promise: Promise) {
        AgentforceClientHolder.clearConversation()
        viewModel?.closeConversation()
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
        })
    }

    @ReactMethod
    fun resetSettings(promise: Promise) {
        AgentforceClientHolder.clear()
        viewModel?.resetConfiguration()
        currentMode = null
        credentialProvider.reset()
        bridgeViewProvider.reset()
        bridgeHiddenPreChat.setFields(emptyMap())
        employeePrefs.edit().remove(KEY_EMPLOYEE_AGENT_ID).apply()
        promise.resolve(Arguments.createMap().apply {
            putBoolean("success", true)
        })
    }

    // endregion

    // region Event Emitter Support
    // endregion

    // region Hidden PreChat Fields

    /**
     * Pre-register hidden prechat field values for the next Service Agent session.
     */
    @ReactMethod
    fun registerHiddenPreChatFields(fields: ReadableMap, promise: Promise) {
        val map = mutableMapOf<String, String>()
        val iterator = fields.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            fields.getString(key)?.let { map[key] = it }
        }
        bridgeHiddenPreChat.setFields(map)
        promise.resolve(null)
    }

    @ReactMethod
    fun getHiddenPreChatFields(promise: Promise) {
        val result = Arguments.createMap()
        for ((key, value) in bridgeHiddenPreChat.getFields()) {
            result.putString(key, value)
        }
        promise.resolve(result)
    }
    // endregion

    // region Additional Context

    /**
     * Set additional context for the current conversation.
     * Must be called after launching a conversation.
     *
     * @param context ReadableMap with "variables" array
     * @param promise Promise to resolve/reject
     */
    @ReactMethod
    fun setAdditionalContext(context: ReadableMap, promise: Promise) {
        Log.d(TAG, "setAdditionalContext() called")

        try {
            // Validate context structure
            val variablesArray = context.getArray("variables")
            if (variablesArray == null) {
                promise.reject("INVALID_CONTEXT", "Missing 'variables' array in context")
                return
            }

            // Convert to CopilotContextVariable list (do this synchronously)
            val contextVariables = mutableListOf<CopilotContextVariable>()
            for (i in 0 until variablesArray.size()) {
                val varMap = variablesArray.getMap(i)
                if (varMap == null) {
                    promise.reject("INVALID_CONTEXT", "Invalid variable at index $i")
                    return
                }

                val name = varMap.getString("name")
                val type = varMap.getString("type")

                if (name == null || type == null) {
                    promise.reject(
                        "INVALID_CONTEXT",
                        "Variable at index $i missing 'name' or 'type'"
                    )
                    return
                }

                // Extract optional fields
                val description = varMap.getString("description")
                val value = when {
                    varMap.hasKey("value") && !varMap.isNull("value") -> {
                        // Read value based on type
                        when (varMap.getType("value")) {
                            ReadableType.String -> varMap.getString("value")
                            ReadableType.Number -> varMap.getDouble("value")
                            ReadableType.Boolean -> varMap.getBoolean("value")
                            ReadableType.Map -> varMap.getMap("value")?.toHashMap()
                            ReadableType.Array -> varMap.getArray("value")?.toArrayList()
                            else -> null
                        }
                    }
                    else -> null
                }

                // Create CopilotContextVariable
                val variable = CopilotContextVariable(
                    name = name,
                    type = type,
                    description = description,
                    value = value
                )
                contextVariables.add(variable)
            }

            // Create CopilotAdditionalContext
            val additionalContext = CopilotAdditionalContext(variables = contextVariables)

            // Apply context to conversation (async) - check conversation inside coroutine
            scope.launch {
                try {
                    // Re-check conversation inside coroutine to avoid race condition
                    val conversation = AgentforceClientHolder.currentConversation
                    if (conversation == null) {
                        Log.w(TAG, "No active conversation for setAdditionalContext")
                        promise.reject(
                            "NO_CONVERSATION",
                            "No active conversation. Launch conversation first, then set context."
                        )
                        return@launch
                    }

                    conversation.setAdditionalContext(additionalContext)
                    Log.d(TAG, "✓ Additional context set: ${contextVariables.size} variables")

                    promise.resolve(Arguments.createMap().apply {
                        putBoolean("success", true)
                    })
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to set additional context", e)
                    promise.reject("CONTEXT_ERROR", e.message, e)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "setAdditionalContext parsing error", e)
            promise.reject("CONTEXT_ERROR", e.message, e)
        }
    }
    // endregion


    @ReactMethod
    fun addListener(eventName: String) {
        // Required for RN event emitter
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        // Required for RN event emitter
    }

    // endregion

    // region Helper Methods

    /**
     * Create a new conversation on [AgentforceClientHolder] so that callers like
     * setAdditionalContext can find it immediately after the promise resolves.
     *
     * @return true if a conversation now exists, false if creation failed
     *         (in which case the [promise] has already been rejected).
     */
    private fun createConversation(promise: Promise, errorCode: String): Boolean {
        val client = AgentforceClientHolder.agentforceClient ?: return true
        return try {
            val agentIdParam = AgentforceClientHolder.agentId?.takeIf { it.isNotBlank() }
            val conversation = client.startAgentforceConversation(agentId = agentIdParam)
            AgentforceClientHolder.setConversation(conversation)
            Log.d(TAG, "Conversation created in module (agentId=${agentIdParam ?: "null/multi-agent"})")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create conversation", e)
            promise.reject(errorCode, "Failed to start conversation: ${e.message}", e)
            false
        }
    }

    private fun ensureViewModel() {
        if (viewModel == null) {
            val activity = currentActivity
            if (activity != null && activity is ViewModelStoreOwner) {
                viewModel = ViewModelProvider(
                    activity,
                    ViewModelProvider.AndroidViewModelFactory.getInstance(
                        reactApplicationContext.applicationContext as Application
                    )
                )[ServiceAgentViewModel::class.java]
            }
        }
    }

    override fun invalidate() {
        super.invalidate()
        scope.cancel()
        viewModel = null
    }

    // endregion
}
