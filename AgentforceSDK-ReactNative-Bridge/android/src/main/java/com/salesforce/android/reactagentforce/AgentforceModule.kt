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
import android.content.SharedPreferences
import android.util.Log
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStoreOwner
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.salesforce.android.agentforcesdk.components.models.DefaultTopAppBarBuilder
import com.salesforce.android.agentforcesdkimpl.AgentforceClient
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceConfiguration
import com.salesforce.android.agentforcesdkimpl.configuration.AgentforceMode
import com.salesforce.android.agentforcesdkimpl.configuration.ServiceAgentConfiguration
import com.salesforce.android.agentforcesdkimpl.configuration.ServiceAgentVoiceConfig
import com.salesforce.android.agentforcesdkimpl.configuration.ServiceUISettings
import com.salesforce.android.agentforcesdkimpl.utils.AgentforceFeatureFlagSettings
import com.salesforce.android.agentforcesdkvoice.AgentforceVoiceProviderFactory
import com.salesforce.android.agentforcesdkvoice.AgentforceVoiceUIProvider
import com.salesforce.android.agentforcesdkvoice.miaw.MiawVoiceProvider
import com.salesforce.android.agentforceservice.voice.MiawVoiceProviderFactory
import com.salesforce.android.smi.multimedia.core.MultimediaExtension
import com.salesforce.android.agentforceservice.conversationservice.data.CopilotContextVariable
import com.salesforce.android.agentforceservice.conversationservice.data.CopilotAdditionalContext
import com.salesforce.android.agentforceservice.voice.AgentforceVoiceSessionOptions
import kotlin.time.Duration.Companion.seconds
import com.salesforce.android.reactagentforce.models.AgentMode as LocalAgentMode
import com.salesforce.android.reactagentforce.models.EmployeeAgentModeConfig
import com.salesforce.android.reactagentforce.models.ServiceAgentModeConfig
import com.salesforce.android.reactagentforce.providers.BridgeViewProvider
import com.salesforce.android.reactagentforce.providers.UnifiedCredentialProvider
import com.salesforce.android.agentforcesdkimpl.data.AgentforceDataProviderImpl
import com.salesforce.android.agentforcesdkimpl.network.AgentforceNetworkImpl
import com.salesforce.android.mobile.interfaces.user.Org
import com.salesforce.android.mobile.interfaces.user.User
import com.salesforce.androidsdk.app.SalesforceSDKManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

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

        // Internal (experimental) flags are persisted in their own store, keyed by the SDK's
        // own internal-flag names (passed straight through — the bridge does not enumerate,
        // rename, or validate them). Only flags that have been explicitly set are stored.
        // Shared with ServiceAgentViewModel (legacy Service path) so the two paths can't drift.
        //
        // ⚠️ Internal flags are not covered by API stability guarantees.
        internal const val INTERNAL_FLAGS_PREFS_NAME = "AgentforceInternalFlags"
    }

    private val employeePrefs: SharedPreferences
        get() = reactApplicationContext.getSharedPreferences(EMPLOYEE_PREFS_NAME, Context.MODE_PRIVATE)

    private val featureFlagsPrefs: SharedPreferences
        get() = reactApplicationContext.getSharedPreferences(FEATURE_FLAGS_PREFS_NAME, Context.MODE_PRIVATE)

    private val internalFlagsPrefs: SharedPreferences
        get() = reactApplicationContext.getSharedPreferences(INTERNAL_FLAGS_PREFS_NAME, Context.MODE_PRIVATE)

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

    // Bridge UI delegate for forwarding SDK UI events to JS
    private val bridgeUIDelegate = BridgeUIDelegate(reactContext)

    // Behavioral options applied to the next voice session.
    // Populated from `voiceOptions` on the JS-side configuration map and
    // forwarded into [AgentforceConfiguration.Builder.setVoiceSessionOptions]
    // so the SDK's voice UI ViewModel reads them via the conversation's
    // configuration when starting a session.
    // Defaults to all-off (`AgentforceVoiceSessionOptions()`).
    private var voiceSessionOptions: AgentforceVoiceSessionOptions = AgentforceVoiceSessionOptions()

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

        // Parse voice options once, before dispatching to the per-mode configurator.
        // Stored on the module so they apply to the next voice session created by
        // either path; both per-mode configurators forward this value to
        // `AgentforceConfiguration.Builder.setVoiceSessionOptions(...)` so the
        // SDK's voice UI ViewModel honors the option when the user launches voice
        // from the chat UI.
        voiceSessionOptions = parseVoiceSessionOptions(config)

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

        // Also update the legacy ViewModel for backward compatibility
        ensureViewModel()
        viewModel?.updateConfiguration(
            serviceApiURL = serviceConfig.serviceApiURL,
            organizationId = serviceConfig.organizationId,
            esDeveloperName = serviceConfig.esDeveloperName
        )

        scope.launch(Dispatchers.Main) {
            // Destroy overlay and clear client on main thread to avoid
            // "Method recordObserver must be called on the main thread" error
            AgentforceConversationOverlay.destroy()
            AgentforceClientHolder.clear()
            try {
                // Build ServiceUISettings from JS config (use SDK defaults for omitted keys)
                val uiSettings = serviceConfig.serviceUISettings?.let { raw ->
                    ServiceUISettings(
                        downloadTranscript = raw["downloadTranscript"] ?: true,
                        endConversation = raw["endConversation"] ?: true,
                        clearChat = raw["clearChat"] ?: false
                    )
                } ?: ServiceUISettings()

                // Create SDK Service Agent configuration
                val sdkServiceConfig = ServiceAgentConfiguration
                    .builder(
                        esDeveloperName = serviceConfig.esDeveloperName,
                        organizationId = serviceConfig.organizationId,
                        serviceApiURL = serviceConfig.serviceApiURL
                    )
                    .setServiceUISettings(uiSettings)
                    .build()
                // Voice shipped for Service Agents in 262.0 (MIAW). Honor the
                // enableVoice flag like the Employee path; the MIAW voice provider is
                // registered below via setBridgeVoiceModule().
                val flags = getFeatureFlagsFromConfigOrPrefs(config)
                saveFeatureFlagsToPrefs(flags)
                val featureFlagSettings = AgentforceFeatureFlagSettings.builder()
                    .enableMultiAgent(flags.enableMultiAgent)
                    .enableMultiModalInput(flags.enableMultiModalInput)
                    .enablePDFUpload(flags.enablePDFUpload)
                    .enableVoice(flags.enableVoice)
                    .setupFlags(internalFlagsForSDK(config))
                    .build()

                val cameraUriProvider = AgentforceClientCameraUriProvider(reactApplicationContext.applicationContext)
                val application = reactApplicationContext.applicationContext as Application
                val permissions = AgentforceClientPermissions(application)

                val agentforceConfigBuilder = AgentforceConfiguration
                    .builder(credentialProvider)
                    .setServiceApiURL(serviceConfig.serviceApiURL)
                    .setSalesforceDomain(serviceConfig.serviceApiURL)
                    .setApplication(application)
                    .setFeatureFlagSettings(featureFlagSettings)
                    .setCameraUriProvider(cameraUriProvider)
                    .setLogger(bridgeLogger)
                    .setNavigation(bridgeNavigation)
                    .setVoiceSessionOptions(voiceSessionOptions)
                agentforceConfigBuilder.setPermission(permissions)
                agentforceConfigBuilder.setBridgeVoiceModule()
                // Always attach bridgeViewProvider so late registrations take effect.
                // canHandle() returns false when the map is empty, matching no-provider behavior.
                agentforceConfigBuilder.setViewProvider(bridgeViewProvider)
                agentforceConfigBuilder.setDelegate(bridgeUIDelegate)
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

        // Rebuild the client only when switching from Service mode, the agentId changed, or no
        // client exists yet (mirrors iOS's needsNewClient). Otherwise reuse it: rebuilding while
        // preserving the conversation orphans that conversation on the old client and breaks
        // re-launch with a 404. See [[project_rn_android_bootstrap_fix]].
        val currentEmployeeMode = currentMode as? LocalAgentMode.Employee
        val switchingModes = AgentforceClientHolder.isServiceAgent
        val agentIdChanged = currentEmployeeMode?.config?.agentId != employeeConfig.agentId

        // Cross-activity re-launch: reuse is only safe while the overlay is still attached to the
        // SAME host Activity, because the SDK scopes its conversation ViewModel + one-shot bootstrap
        // to that Activity (getActivityScopedViewModelStoreOwner). If the host app handed us a
        // different Activity (multi-activity nav, recreated host, etc.), reusing the conversation
        // re-fires bootstrap on a fresh activity-scoped ViewModel, hits the by-design discovery 404
        // it can't recover from, and the chat hangs on "I'm on my way…". Force a fresh client+
        // conversation in that case so the recoverable fresh-bootstrap path runs instead.
        // Trade-off: conversation history is lost on an activity swap, but the chat never hangs.
        // The sample app is single-Activity so this never triggers there; some customer host apps
        // are not. See [[project_rn_android_bootstrap_fix]].
        val activity = currentActivity
        val activityChanged = AgentforceClientHolder.agentforceClient != null &&
            activity != null &&
            !AgentforceConversationOverlay.isAttachedTo(activity)

        val needsNewClient = switchingModes || agentIdChanged ||
            AgentforceClientHolder.agentforceClient == null || activityChanged

        if (activityChanged) {
            Log.d(TAG, "Host Activity changed since last attach - forcing fresh client to avoid re-launch hang")
        }

        // Configure unified credential provider for Employee Agent mode
        // UnifiedCredentialProvider will fetch fresh tokens from Mobile SDK automatically
        credentialProvider.configure(employeeConfig)
        currentMode = LocalAgentMode.Employee(employeeConfig)

        // Persist employee agentId (editable in Settings tab)
        employeePrefs.edit().putString(KEY_EMPLOYEE_AGENT_ID, employeeConfig.agentId ?: "").apply()

        scope.launch(Dispatchers.Main) {
            val flags = getFeatureFlagsFromConfigOrPrefs(config)
            saveFeatureFlagsToPrefs(flags)

            if (!needsNewClient) {
                // Reuse the existing client and its conversation (credentials refresh automatically
                // via UnifiedCredentialProvider). Preserves conversation history across re-launch.
                Log.d(TAG, "AgentId unchanged - reusing existing client and conversation")
                AgentforceClientHolder.setMode(LocalAgentMode.Employee(employeeConfig))
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                    putString("mode", "employee")
                })
                return@launch
            }

            // Tear down the previous overlay/client/conversation before building a fresh one, so
            // launchConversation() recreates a conversation paired with the new client.
            Log.d(TAG, "Switching modes or agentId changed - clearing client and conversation")
            AgentforceConversationOverlay.destroy()
            AgentforceClientHolder.clear()
            try {
                // Create AgentforceConfiguration for FullConfig mode
                val featureFlagSettings = AgentforceFeatureFlagSettings.builder()
                    .enableMultiAgent(flags.enableMultiAgent)
                    .enableMultiModalInput(flags.enableMultiModalInput)
                    .enablePDFUpload(flags.enablePDFUpload)
                    .enableVoice(flags.enableVoice)
                    .setupFlags(internalFlagsForSDK(config))
                    .build()

                val cameraUriProvider = AgentforceClientCameraUriProvider(reactApplicationContext.applicationContext)
                val application = reactApplicationContext.applicationContext as Application
                val permissions = AgentforceClientPermissions(application)

                // Employee Agent uses BridgeNetwork with RestClient for authenticated requests
                val restClient = SalesforceSDKManager.getInstance().clientManager.peekRestClient()
                if (restClient == null) {
                    Log.w(TAG, "RestClient is null - user may not be logged in. Record rendering may fail.")
                }
                val network = restClient?.let { BridgeNetwork(it) } ?: AgentforceNetworkImpl()
                val dataProvider = AgentforceDataProviderImpl(network)

                val agentforceConfigBuilder = AgentforceConfiguration
                    .builder(credentialProvider)
                    .setServiceApiURL(employeeConfig.instanceUrl)
                    .setSalesforceDomain(employeeConfig.instanceUrl)
                    .setApplication(application)
                    .setFeatureFlagSettings(featureFlagSettings)
                    .setCameraUriProvider(cameraUriProvider)
                    .setLogger(bridgeLogger)
                    .setNavigation(bridgeNavigation)
                    // Route bootstrap (BotsAPI connect calls) through the authenticated
                    // RestClient-backed network, matching the iOS bridge (which passes
                    // salesforceNetwork). Without this, the SDK falls back to a default
                    // AgentforceNetworkImpl() with no salesforceDomain, so the bootstrap
                    // connect call 404s and the client never gets connectionInfo.
                    .setNetwork(network)
                    .setDataProvider(dataProvider)
                    // Set the User/Org so the SDK knows the orgId. The SDK derives the
                    // runtime connection info from user.org.id when the internal-core
                    // discovery endpoints are unavailable (the external-app case), via
                    // AgentforceConnectionInfo(orgId=...). The iOS bridge sets this too;
                    // without it, orgId is null and that fallback can't resolve a host.
                    .setUser(
                        User(
                            org = Org(id = employeeConfig.organizationId, community = null),
                            userName = employeeConfig.userId,
                            displayName = employeeConfig.userId
                        )
                    )
                    .setVoiceSessionOptions(voiceSessionOptions)
                agentforceConfigBuilder.setPermission(permissions)
                agentforceConfigBuilder.setBridgeVoiceModule()
                // Always attach bridgeViewProvider so late registrations take effect.
                // canHandle() returns false when the map is empty, matching no-provider behavior.
                agentforceConfigBuilder.setViewProvider(bridgeViewProvider)
                agentforceConfigBuilder.setDelegate(bridgeUIDelegate)
                // Override the header title with the client-supplied agentLabel when
                // present (client wins); otherwise use the SDK default bar, which falls
                // back to the server-provided agent label. Mirrors the iOS bridge.
                val agentLabel = employeeConfig.agentLabel?.trim()
                if (!agentLabel.isNullOrEmpty()) {
                    agentforceConfigBuilder.setTopAppBarBuilder(BridgeTopAppBarBuilder(agentLabel))
                } else {
                    agentforceConfigBuilder.setTopAppBarBuilder(DefaultTopAppBarBuilder)
                }
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
     *
     * @param options Optional map with "initialMode": "chat" | "voice"
     * @param promise Promise to resolve/reject
     */
    @ReactMethod
    fun launchConversation(options: ReadableMap?, promise: Promise) {
        Log.d(TAG, "launchConversation() called")

        val initialMode = options?.getString("initialMode") ?: "chat"
        Log.d(TAG, "launchConversation: initialMode=$initialMode")

        val activity = currentActivity
        if (activity == null) {
            promise.reject("ERROR", "Activity not available")
            return
        }

        // Validate Voice feature flag if Voice mode requested
        if (initialMode == "voice" && !getFeatureFlagsFromConfigOrPrefs(Arguments.createMap()).enableVoice) {
            Log.e(TAG, "Voice mode requested but enableVoice feature flag is disabled")
            promise.reject("VOICE_DISABLED", "Voice is not enabled for this Agentforce configuration")
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
            scope.launch(Dispatchers.Main) {
                try {
                    viewModel?.initializeAgentforce()

                    AgentforceConversationOverlay.show(activity, voiceMode = initialMode == "voice")
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

        // Create conversation and show overlay on main thread to avoid
        // "Method addObserver must be called on the main thread" error
        scope.launch(Dispatchers.Main) {
            try {
                // Create conversation before showing UI so setAdditionalContext
                // can find it immediately after the promise resolves (matches iOS behavior).
                if (AgentforceClientHolder.currentConversation == null) {
                    if (!createConversation(promise, "LAUNCH_ERROR")) return@launch
                }

                AgentforceConversationOverlay.show(activity, voiceMode = initialMode == "voice")
                Log.d(TAG, "Conversation shown (initialMode=$initialMode)")

                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                })
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch conversation", e)
                promise.reject("LAUNCH_ERROR", "Failed to start conversation: ${e.message}", e)
            }
        }
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

        // Clear existing conversation and start new one on main thread to avoid
        // "Method addObserver must be called on the main thread" error
        scope.launch(Dispatchers.Main) {
            try {
                // Destroy overlay so a fresh ViewModel is created for the new conversation
                AgentforceConversationOverlay.destroy()

                AgentforceClientHolder.clearConversation()
                viewModel?.closeConversation()

                // Create new conversation before showing UI so setAdditionalContext
                // can find it immediately after the promise resolves (matches iOS behavior).
                if (!createConversation(promise, "START_NEW_ERROR")) return@launch

                // Show conversation as overlay on current Activity
                AgentforceConversationOverlay.show(activity)

                Log.d(TAG, "New conversation started")
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                })
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start new conversation", e)
                promise.reject("START_NEW_ERROR", "Failed to start conversation: ${e.message}", e)
            }
        }
    }

    /**
     * Send an utterance (text message) to the current conversation.
     * Must be called after launching a conversation.
     *
     * @param utterance The text to send to the agent
     * @param promise Promise to resolve/reject
     */
    @ReactMethod
    fun sendUtterance(utterance: String, promise: Promise) {
        Log.d(TAG, "sendUtterance() called")

        scope.launch(Dispatchers.Main) {
            val conversation = AgentforceClientHolder.currentConversation
            if (conversation == null) {
                Log.w(TAG, "No active conversation for sendUtterance")
                promise.reject(
                    "NO_CONVERSATION",
                    "No active conversation. Launch conversation first, then send an utterance."
                )
                return@launch
            }

            try {
                conversation.sendUtterance(utterance)
                Log.d(TAG, "Utterance sent")
                promise.resolve(Arguments.createMap().apply {
                    putBoolean("success", true)
                })
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send utterance", e)
                promise.reject("SEND_UTTERANCE_ERROR", e.message, e)
            }
        }
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

    /**
     * Parse `voiceOptions` from the JS-side config map into an [AgentforceVoiceSessionOptions].
     *
     * Returns the all-off default when the field is missing or empty. A
     * `userSilenceTimeoutSeconds` of zero or negative is forwarded to the
     * native layer, which already coerces non-positive durations to disabled
     * and emits a warning. Non-finite values (NaN, +/-infinity) are dropped to
     * avoid passing them to `Duration` arithmetic. `autoEndWhileMuted` defaults
     * to `false` when absent.
     */
    private fun parseVoiceSessionOptions(config: ReadableMap): AgentforceVoiceSessionOptions {
        if (!config.hasKey("voiceOptions")) return AgentforceVoiceSessionOptions()
        val voiceOpts = config.getMap("voiceOptions") ?: return AgentforceVoiceSessionOptions()

        val timeout = if (
            voiceOpts.hasKey("userSilenceTimeoutSeconds") &&
            !voiceOpts.isNull("userSilenceTimeoutSeconds")
        ) {
            val raw = voiceOpts.getDouble("userSilenceTimeoutSeconds")
            if (raw.isFinite()) raw.seconds else null
        } else {
            null
        }

        val autoEndWhileMuted = voiceOpts.hasKey("autoEndWhileMuted") &&
            !voiceOpts.isNull("autoEndWhileMuted") &&
            voiceOpts.getBoolean("autoEndWhileMuted")

        return AgentforceVoiceSessionOptions(
            userSilenceTimeout = timeout,
            autoEndWhileMuted = autoEndWhileMuted,
        )
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
                enableMultiModalInput = featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, true),
                enablePDFUpload = featureFlagsPrefs.getBoolean(KEY_ENABLE_PDF_UPLOAD, true),
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
            putBoolean("enableMultiModalInput", featureFlagsPrefs.getBoolean(KEY_ENABLE_MULTI_MODAL_INPUT, true))
            putBoolean("enablePDFUpload", featureFlagsPrefs.getBoolean(KEY_ENABLE_PDF_UPLOAD, true))
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

    // region Internal (experimental) flags

    /**
     * Read the internal-flag map from the JS config if present, else from SharedPreferences.
     * Keys are the SDK's own flag names; values are the raw booleans. Only flags that were
     * explicitly set appear — absent flags fall back to the SDK's own defaults.
     */
    private fun getInternalFlagsFromConfigOrPrefs(config: ReadableMap): Map<String, Boolean> {
        val internalFlagsMap = if (config.hasKey("internalFlags")) config.getMap("internalFlags") else null
        if (internalFlagsMap != null) {
            val result = mutableMapOf<String, Boolean>()
            val iterator = internalFlagsMap.keySetIterator()
            while (iterator.hasNextKey()) {
                val key = iterator.nextKey()
                if (internalFlagsMap.getType(key) == ReadableType.Boolean) {
                    result[key] = internalFlagsMap.getBoolean(key)
                }
            }
            return result
        }
        return readStoredInternalFlags()
    }

    /** Read all persisted internal flags from SharedPreferences. */
    private fun readStoredInternalFlags(): Map<String, Boolean> {
        val result = mutableMapOf<String, Boolean>()
        for ((key, value) in internalFlagsPrefs.all) {
            if (value is Boolean) {
                result[key] = value
            }
        }
        return result
    }

    /**
     * Build the SDK internal-flags map for a configure() call. Keys are passed through
     * unchanged as the SDK's own flag names — the bridge does not rename or filter them.
     */
    private fun internalFlagsForSDK(config: ReadableMap): Map<String, Boolean> {
        return getInternalFlagsFromConfigOrPrefs(config)
    }

    @ReactMethod
    fun getInternalFlags(promise: Promise) {
        // Return only the flags that were explicitly set (empty map if none).
        promise.resolve(Arguments.createMap().apply {
            for ((key, value) in readStoredInternalFlags()) {
                putBoolean(key, value)
            }
        })
    }

    @ReactMethod
    fun setInternalFlags(flags: ReadableMap, promise: Promise) {
        val editor = internalFlagsPrefs.edit()
        val iterator = flags.keySetIterator()
        // Persist the caller's flags verbatim (keyed by the SDK's own flag names). Non-boolean
        // values are skipped; keys the running SDK doesn't recognize are simply ignored by it.
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            if (flags.getType(key) == ReadableType.Boolean) {
                editor.putBoolean(key, flags.getBoolean(key))
            }
        }
        editor.apply()
        promise.resolve(null)
    }

    // endregion

    @ReactMethod
    fun getConfigurationInfo(promise: Promise) {
        if (credentialProvider.isConfigured && AgentforceClientHolder.isConfigured) {
            promise.resolve(Arguments.createMap().apply {
                putBoolean("configured", true)
                putString("mode", if (credentialProvider.isServiceAgent) "service" else "employee")
                putString("description", credentialProvider.currentConfiguration)
            })
        } else if (viewModel?.isConfigured?.value == true && AgentforceClientHolder.isConfigured) {
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

    // region UI Delegate Forwarding

    @ReactMethod
    fun enableUIDelegateForwarding(enabled: Boolean, promise: Promise) {
        bridgeUIDelegate.forwardingEnabled = enabled
        Log.d(TAG, "UI delegate forwarding ${if (enabled) "enabled" else "disabled"}")
        promise.resolve(true)
    }

    @ReactMethod
    fun provideModifiedUtterance(requestId: String, utterance: String, promise: Promise) {
        val completed = bridgeUIDelegate.completeModification(requestId, utterance)
        promise.resolve(completed)
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
        scope.launch(Dispatchers.Main) {
            AgentforceConversationOverlay.destroy()
            AgentforceClientHolder.clearConversation()
            viewModel?.closeConversation()
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
            })
        }
    }

    /**
     * Dismiss the conversation UI while preserving the conversation and its history.
     *
     * This is the programmatic equivalent of the in-chat close (X) button: it only
     * hides the overlay (see [AgentforceConversationOverlay.hide]) and leaves the
     * client + conversation in [AgentforceClientHolder] intact, so the next
     * [launchConversation] reuses the existing conversation with history preserved.
     *
     * Contrast with [closeConversation], which destroys the overlay and clears the
     * conversation, forcing a fresh conversation on the next launch.
     */
    @ReactMethod
    fun dismissConversation(promise: Promise) {
        scope.launch(Dispatchers.Main) {
            AgentforceConversationOverlay.hide()
            promise.resolve(Arguments.createMap().apply {
                putBoolean("success", true)
            })
        }
    }

    @ReactMethod
    fun resetSettings(promise: Promise) {
        scope.launch(Dispatchers.Main) {
            AgentforceConversationOverlay.destroy()
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
                    Log.d(TAG, "Additional context set: ${contextVariables.size} variables")

                    promise.resolve(Arguments.createMap().apply {
                        putBoolean("success", true)
                    })
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to set additional context", e)
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

/**
 * Registers voice with the SDK config builder using the non-deprecated
 * [AgentforceConfiguration.Builder.setVoiceModule] entry point. Wires both:
 *  - Employee Agent voice (LiveKit) via [AgentforceVoiceProviderFactory]
 *  - Service Agent voice (MIAW) via [ServiceAgentVoiceConfig] — new in 262.0.
 *
 * Both modes share the same [AgentforceVoiceUIProvider]. The MIAW multimedia
 * stack ([MultimediaExtension]) is provided transitively by `agentforce-sdk-voice`.
 * Whether voice actually surfaces is still gated by the `enableVoice` feature flag
 * and the backend advertising voice support for the conversation.
 *
 * Top-level `internal` (not a private member) so both [AgentforceModule] and the
 * legacy [ServiceAgentViewModel] path register voice identically — one definition,
 * no drift when the SDK `setVoiceModule` signature next changes.
 */
internal fun AgentforceConfiguration.Builder.setBridgeVoiceModule() = setVoiceModule(
    uiProvider = AgentforceVoiceUIProvider(),
    employeeAgentFactory = AgentforceVoiceProviderFactory(),
    serviceAgentConfig = ServiceAgentVoiceConfig(
        extension = MultimediaExtension,
        // 3rd ctor arg (instrumentationHandler) defaults to null; omit it.
        factory = MiawVoiceProviderFactory { _, conversationClientProvider, multimediaClient ->
            MiawVoiceProvider(conversationClientProvider, multimediaClient)
        }
    )
)
