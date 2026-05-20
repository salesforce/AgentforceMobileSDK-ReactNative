/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge module for Agentforce SDK
 * Supports both Service Agent (guest) and Employee Agent (authenticated) modes
 */

import Foundation
import UIKit
import SwiftUI
import React
import AgentforceSDK
import AgentforceService
import SalesforceUser
import SalesforceNetwork

#if canImport(SalesforceSDKCore)
import SalesforceSDKCore
#endif

/// React Native bridge module for Agentforce SDK
/// Supports both Service Agent (guest) and Employee Agent (authenticated) modes
@objc(AgentforceModule)
class AgentforceModule: RCTEventEmitter {

    // MARK: - Properties

    /// Unified credential provider for both Service and Employee agents
    private let credentialProvider = UnifiedCredentialProvider()

    /// Agentforce client instance
    private var agentforceClient: AgentforceClient?

    /// Current conversation
    private var currentConversation: AgentConversation?

    /// Current mode configuration
    private var currentMode: AgentMode?


    private let listenerLock = NSLock()
    private var _hasListeners = false

    // MARK: - Hidden PreChat Fields

    /// Bridge delegate for hidden prechat fields (Service Agent only).
    /// Strongly retained here because AgentforceClient holds it as a weak reference.
    private let bridgeHiddenPreChat = BridgeHiddenPreChat()

    // MARK: - Logging

    /// Bridge logger for forwarding SDK logs to JavaScript.
    /// lazy var is not thread-safe in Swift; safe here because first access
    /// is in configure methods which run on @MainActor.
    private lazy var bridgeLogger: BridgeLogger = {
        return BridgeLogger(module: self)
    }()

    // MARK: - Navigation

    /// Bridge navigation for forwarding SDK navigation requests to JavaScript.
    /// lazy var is not thread-safe in Swift; safe here because first access
    /// is in configure methods which run on @MainActor.
    private lazy var bridgeNavigation: BridgeNavigation = {
        return BridgeNavigation(module: self)
    }()

    // MARK: - View Provider

    /// Bridge view provider for delegating native SDK views to React Native components.
    /// Initialized lazily so the RCT bridge is available.
    private lazy var bridgeViewProvider: BridgeViewProvider = {
        return BridgeViewProvider(bridge: self.bridge)
    }()

    // MARK: - UI Delegate

    /// Bridge UI delegate for forwarding SDK UI events to JavaScript.
    private lazy var bridgeUIDelegate: BridgeUIDelegate = {
        return BridgeUIDelegate(module: self)
    }()

    /// Pending modify-utterance continuations keyed by requestId.
    private var modifyContinuations: [String: CheckedContinuation<String?, Never>] = [:]
    private let modifyContinuationsLock = NSLock()

    // MARK: - Module Setup

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return [
            "onLogMessage",
            "onNavigationRequest",
            "onUtteranceSent",
            "onAgentSwitch",
            "onModifyUtteranceRequest",
        ]
    }

    override func startObserving() {
        listenerLock.withLock { _hasListeners = true }
    }

    override func stopObserving() {
        listenerLock.withLock { _hasListeners = false }
    }

    // MARK: - Unified Configuration Method

    /// Configure the SDK with either Service or Employee agent settings.
    /// Expects a dictionary with 'type' field set to 'service' or 'employee'.
    /// This is the new unified configuration method.
    @objc
    func configureWithConfig(
        _ config: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let configDict = config as? [String: Any],
              let type = configDict["type"] as? String else {
            reject("INVALID_CONFIG", "Missing 'type' field (must be 'service' or 'employee')", nil)
            return
        }

        Task { @MainActor in
            do {
                switch type {
                case "service":
                    try await configureServiceAgent(configDict)
                    resolve(["success": true, "mode": "service"])

                case "employee":
                    try await configureEmployeeAgent(configDict)
                    resolve(["success": true, "mode": "employee"])

                default:
                    reject("INVALID_CONFIG", "Invalid type '\(type)'. Must be 'service' or 'employee'", nil)
                }
            } catch {
                print("[AgentforceModule] ❌ Configuration failed: \(error)")
                reject("CONFIG_ERROR", error.localizedDescription, error)
            }
        }
    }

    // MARK: - Service Agent Configuration

    private func configureServiceAgent(_ configDict: [String: Any]) async throws {
        guard let config = ServiceAgentModeConfig.from(dictionary: configDict) else {
            throw AgentConfigError.missingRequiredField("serviceApiURL, organizationId, or esDeveloperName")
        }
        // Validate serviceApiURL is a valid URL (avoids 400 "Start session failed" from wrong base URL)
        guard URL(string: config.serviceApiURL) != nil else {
            throw AgentConfigError.missingRequiredField("serviceApiURL must be a valid URL (e.g. https://your-site.salesforce.com)")
        }

        // Always close existing conversation and recreate client on reconfigure.
        // This allows "Save Configuration" to act as a conversation reset.
        await closeCurrentConversation()
        cleanupClient()

        // Configure unified credential provider for Service Agent mode
        credentialProvider.configure(serviceAgent: config)
        currentMode = .service(config: config)

        // Persist trimmed values to UserDefaults for cross-session recall
        let trimmedSiteUrl = config.serviceApiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrgId = config.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDevName = config.esDeveloperName.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedSiteUrl, forKey: "ServiceAgentSiteUrl")
        UserDefaults.standard.set(trimmedOrgId, forKey: "ServiceAgentOrgUrl")
        UserDefaults.standard.set(trimmedDevName, forKey: "ServiceAgentDevName")

        // Use .serviceAgent() mode with overrides for logger and navigation.
        let serviceConfig = ServiceAgentConfiguration(
            esDeveloperName: config.esDeveloperName,
            organizationId: config.organizationId,
            serviceApiURL: config.serviceApiURL,
            serviceUISettings: ServiceUISettings(
                showQueueStatus: true,
                secureForms: true
            ),
            forceConfigEndPoint: config.serviceApiURL
        )
        .withLogger(bridgeLogger)
        .withNavigation(bridgeNavigation)

        // Always pass bridgeViewProvider so late registrations take effect.
        // canHandle() returns false when the map is empty, matching nil behavior.
        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .serviceAgent(serviceConfig),
            viewProvider: bridgeViewProvider
        )
        agentforceClient?.hiddenPreChatFieldDelegate = bridgeHiddenPreChat
    }

    // MARK: - Employee Agent Configuration

    private func configureEmployeeAgent(_ configDict: [String: Any]) async throws {
        guard let config = EmployeeAgentModeConfig.from(dictionary: configDict) else {
            throw AgentConfigError.missingRequiredField("instanceUrl, organizationId, userId, agentId, or accessToken")
        }

        // Check if agentId changed or we're switching modes
        var agentIdChanged = false
        var switchingModes = false
        
        if case .service = currentMode {
            switchingModes = true
        } else if case .employee(let existingConfig) = currentMode {
            agentIdChanged = existingConfig.agentId != config.agentId
        }
        
        let needsNewClient = switchingModes || agentIdChanged || agentforceClient == nil

        // Only cleanup if switching from Service mode or agentId changed
        if switchingModes {
            print("[AgentforceModule] ⚠️ Switching from Service to Employee mode - cleaning up")
            cleanupClient()
        } else if agentIdChanged {
            print("[AgentforceModule] ⚠️ AgentId changed - cleaning up conversation")
            await closeCurrentConversation()
            cleanupClient()
        } else if agentforceClient != nil {
            print("[AgentforceModule] ✓ AgentId unchanged - preserving client and conversation")
        }

        // Configure unified credential provider for Employee Agent mode
        // UnifiedCredentialProvider will fetch fresh tokens from Mobile SDK automatically
        credentialProvider.configure(employeeAgent: config)
        currentMode = .employee(config: config)

        // Persist employee agentId (editable in Settings tab)
        UserDefaults.standard.set(config.agentId ?? "", forKey: "EmployeeAgentId")

        // Get orgId and userId from Mobile SDK if available (more reliable than config)
        var userId = config.userId
        var organizationId = config.organizationId

        #if canImport(SalesforceSDKCore)
        if let currentUser = UserAccountManager.shared.currentUserAccount {
            if let mobileUserId = currentUser.credentials.userId {
                userId = mobileUserId
            }
            if let mobileOrgId = currentUser.credentials.organizationId {
                organizationId = mobileOrgId
            }
        }
        #endif

        // Use .fullConfig() for Employee Agent to support custom feature flags.
        let user = User(
            userId: userId,
            org: Org(id: organizationId),
            username: userId,
            displayName: userId
        )

        let flags = getFeatureFlagsFromConfigOrUserDefaults(configDict)
        let featureFlagSettings = AgentforceFeatureFlagSettings(
            enableMultiModalInput: flags.enableMultiModalInput,
            enablePDFFileUpload: flags.enablePDFUpload,
            multiAgent: flags.enableMultiAgent,
            shouldBlockMicrophone: false,
            enableVoice: flags.enableVoice,
            enableOnboarding: false,
            internalFlags: [:]
        )

        // Build full configuration with authenticated network and data provider for Employee Agent.
        let network = createAuthenticatedNetwork()
        let dataProvider = createDataProvider(network: network)

        let fullConfiguration = AgentforceConfiguration(
            user: user,
            forceConfigEndpoint: config.instanceUrl,
            dataProvider: dataProvider,
            agentforceFeatureFlagSettings: featureFlagSettings,
            salesforceNetwork: network,
            salesforceNavigation: bridgeNavigation,
            salesforceLogger: bridgeLogger
        )

        // Only create new client if needed (otherwise reuse existing to preserve conversation)
        if needsNewClient {
            print("[AgentforceModule] Creating new AgentforceClient for Employee Agent")
            // Always pass bridgeViewProvider so late registrations take effect.
            // canHandle() returns false when the map is empty, matching nil behavior.
            agentforceClient = AgentforceClient(
                credentialProvider: credentialProvider,
                mode: .fullConfig(fullConfiguration),
                viewProvider: bridgeViewProvider
            )
        } else {
            print("[AgentforceModule] Reusing existing AgentforceClient - credentials will be refreshed automatically")
        }
    }

    // MARK: - Network Configuration Helpers

    /// Create authenticated network implementation for Employee Agent.
    /// Returns BridgeNetwork when Mobile SDK is available, nil otherwise.
    private func createAuthenticatedNetwork() -> SalesforceNetwork.Network? {
        #if canImport(SalesforceSDKCore)
        return BridgeNetwork(restClient: RestClient.shared)
        #else
        return nil
        #endif
    }

    /// Create data provider for fetching record data from Salesforce UI APIs.
    /// Returns BridgeDataProvider when network is available, nil otherwise.
    private func createDataProvider(network: SalesforceNetwork.Network?) -> AgentforceDataProviding? {
        #if canImport(SalesforceSDKCore)
        guard let network = network else {
            return nil
        }
        return BridgeDataProvider(network: network, restClient: RestClient.shared)
        #else
        return nil
        #endif
    }

    // MARK: - Legacy Configuration Method (Backward Compatibility)

    /// Configure Service Agent (JavaScript-friendly interface)
    /// This is the legacy method for backward compatibility
    @objc
    func configure(
        _ serviceApiURL: String,
        organizationId: String,
        esDeveloperName: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // Convert to new format and call unified method
        let config: [String: Any] = [
            "type": "service",
            "serviceApiURL": serviceApiURL,
            "organizationId": organizationId,
            "esDeveloperName": esDeveloperName
        ]

        configureWithConfig(config as NSDictionary, resolver: resolve, rejecter: reject)
    }

    /// Legacy method for initializing Service Agent
    @objc
    func initializeServiceAgent(
        _ orgUrl: String,
        devName: String,
        siteUrl: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // Convert to new format
        let config: [String: Any] = [
            "type": "service",
            "serviceApiURL": siteUrl,
            "organizationId": orgUrl,
            "esDeveloperName": devName
        ]

        configureWithConfig(config as NSDictionary, resolver: resolve, rejecter: reject)
    }

    // MARK: - Conversation Methods (Unified for both modes)

    /// Launch the conversation UI - works for both Service and Employee agents
    @objc
    func launchConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                guard let client = agentforceClient, let mode = currentMode else {
                    throw AgentConfigError.notConfigured
                }

                let conversation = try getOrCreateConversation(client: client, mode: mode)

                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: bridgeUIDelegate,
                    showTopBar: true,
                    onContainerClose: { [weak self] in
                        Task { @MainActor in
                            self?.dismissConversation()
                        }
                    }
                )

                presentConversationView(chatView)
                resolve(["success": true])
            } catch {
                print("[AgentforceModule] ❌ Launch failed: \(error)")
                let desc = (error as NSError).localizedDescription
                let hint = desc.contains("sessionId")
                    ? " Session start failed (400 = config; 500 = server/org). See docs/TROUBLESHOOTING.md."
                    : ""
                reject("LAUNCH_ERROR", error.localizedDescription + hint, error)
            }
        }
    }

    /// Start a new conversation (closes existing one and launches fresh)
    @objc
    func startNewConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                await closeCurrentConversation()

                guard let client = agentforceClient, let mode = currentMode else {
                    throw AgentConfigError.notConfigured
                }

                let conversation = try getOrCreateConversation(client: client, mode: mode, forceNew: true)

                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: bridgeUIDelegate,
                    showTopBar: true,
                    onContainerClose: { [weak self] in
                        Task { @MainActor in
                            self?.dismissConversation()
                        }
                    }
                )

                presentConversationView(chatView)
                resolve(["success": true])
            } catch {
                print("[AgentforceModule] ❌ Start new conversation failed: \(error)")
                reject("START_NEW_ERROR", error.localizedDescription, error)
            }
        }
    }

    // MARK: - Conversation Helpers

    private func getOrCreateConversation(client: AgentforceClient, mode: AgentMode, forceNew: Bool = false) throws -> AgentConversation {
        // Return existing if available and not forcing new
        if !forceNew, let existing = currentConversation {
            return existing
        }

        // Start new conversation based on mode
        let conversation: AgentConversation

        switch mode {
        case .service(let config):
            conversation = client.startAgentforceConversation(
                forESDeveloperName: config.esDeveloperName
            )

        case .employee(let config):
            // For Employee Agent, check if agentId is provided
            if let agentId = config.agentId, !agentId.isEmpty {
                // Specific agent ID provided - always use it
                conversation = client.startAgentforceConversation(
                    forAgentId: agentId
                )
            } else {
                // No agentId provided - check if multi-agent is enabled
                let multiAgentEnabled = UserDefaults.standard.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : UserDefaults.standard.bool(forKey: Self.featureFlagKeys.enableMultiAgent)

                if !multiAgentEnabled {
                    // Multi-agent disabled but no agentId - this will likely fail at SDK level
                    print("[AgentforceModule] ⚠️ WARNING: No agentId provided and multi-agent is disabled. Chat panel will likely fail.")
                }

                // Pass nil and let SDK handle it (will succeed if multi-agent enabled, fail otherwise)
                conversation = client.startAgentforceConversation(
                    forAgentId: nil
                )
            }
        }

        currentConversation = conversation
        return conversation
    }

    private func closeCurrentConversation() async {
        if let conversation = currentConversation {
            do {
                try await conversation.closeConversation()
            } catch {
                print("[AgentforceModule] ⚠️ Error closing conversation: \(error)")
            }
        }
        currentConversation = nil
    }

    // MARK: - Configuration Query Methods

    /// Check if SDK is configured
    @objc
    func isConfigured(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            resolve(credentialProvider.isConfigured)
        }
    }

    /// Get stored Employee Agent ID (set in Settings > Employee Agent tab)
    @objc
    func getEmployeeAgentId(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let agentId = UserDefaults.standard.string(forKey: "EmployeeAgentId") ?? ""
        resolve(agentId)
    }

    /// Set Employee Agent ID (from Settings > Employee Agent tab)
    @objc
    func setEmployeeAgentId(
        _ agentId: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let oldAgentId = UserDefaults.standard.string(forKey: "EmployeeAgentId") ?? ""
            let newAgentId = agentId.trimmingCharacters(in: .whitespaces)

            UserDefaults.standard.set(newAgentId, forKey: "EmployeeAgentId")

            // Clear conversation if agent ID changed
            if oldAgentId != newAgentId {
                print("[AgentforceModule] ⚠️ Agent ID changed ('\(oldAgentId)' → '\(newAgentId)') - clearing conversation")
                await closeCurrentConversation()
                cleanupClient()
            }

            resolve(nil)
        }
    }

    private static let featureFlagKeys = (
        enableMultiAgent: "AgentforceFF_enableMultiAgent",
        enableMultiModalInput: "AgentforceFF_enableMultiModalInput",
        enablePDFUpload: "AgentforceFF_enablePDFUpload",
        enableVoice: "AgentforceFF_enableVoice",
        enableCustomViewProvider: "AgentforceFF_enableCustomViewProvider"
    )

    private struct FeatureFlags {
        let enableMultiAgent: Bool
        let enableMultiModalInput: Bool
        let enablePDFUpload: Bool
        let enableVoice: Bool
        let enableCustomViewProvider: Bool
    }

    private func getFeatureFlagsFromConfigOrUserDefaults(_ configDict: [String: Any]) -> FeatureFlags {
        if let featureFlags = configDict["featureFlags"] as? [String: Any] {
            return FeatureFlags(
                enableMultiAgent: (featureFlags["enableMultiAgent"] as? NSNumber)?.boolValue ?? true,
                enableMultiModalInput: (featureFlags["enableMultiModalInput"] as? NSNumber)?.boolValue ?? true,
                enablePDFUpload: (featureFlags["enablePDFUpload"] as? NSNumber)?.boolValue ?? true,
                enableVoice: (featureFlags["enableVoice"] as? NSNumber)?.boolValue ?? false,
                enableCustomViewProvider: (featureFlags["enableCustomViewProvider"] as? NSNumber)?.boolValue ?? false
            )
        }
        let ud = UserDefaults.standard
        return FeatureFlags(
            enableMultiAgent: ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            enableMultiModalInput: ud.object(forKey: Self.featureFlagKeys.enableMultiModalInput) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            enablePDFUpload: ud.object(forKey: Self.featureFlagKeys.enablePDFUpload) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            enableVoice: ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableVoice),
            enableCustomViewProvider: ud.object(forKey: Self.featureFlagKeys.enableCustomViewProvider) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableCustomViewProvider)
        )
    }

    private func saveFeatureFlagsToUserDefaults(_ flags: FeatureFlags) {
        UserDefaults.standard.set(flags.enableMultiAgent, forKey: Self.featureFlagKeys.enableMultiAgent)
        UserDefaults.standard.set(flags.enableMultiModalInput, forKey: Self.featureFlagKeys.enableMultiModalInput)
        UserDefaults.standard.set(flags.enablePDFUpload, forKey: Self.featureFlagKeys.enablePDFUpload)
        UserDefaults.standard.set(flags.enableVoice, forKey: Self.featureFlagKeys.enableVoice)
        UserDefaults.standard.set(flags.enableCustomViewProvider, forKey: Self.featureFlagKeys.enableCustomViewProvider)
    }

    @objc
    func getFeatureFlags(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let ud = UserDefaults.standard
        let flags = [
            "enableMultiAgent": ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            "enableMultiModalInput": ud.object(forKey: Self.featureFlagKeys.enableMultiModalInput) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            "enablePDFUpload": ud.object(forKey: Self.featureFlagKeys.enablePDFUpload) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            "enableVoice": ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableVoice),
            "enableCustomViewProvider": ud.object(forKey: Self.featureFlagKeys.enableCustomViewProvider) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableCustomViewProvider)
        ]
        resolve(flags)
    }

    @objc
    func setFeatureFlags(
        _ flags: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            guard let dict = flags as? [String: Any] else {
                resolve(nil)
                return
            }

            // Get new flags
            let newMultiAgent = (dict["enableMultiAgent"] as? NSNumber)?.boolValue ?? true
            let newMultiModal = (dict["enableMultiModalInput"] as? NSNumber)?.boolValue ?? true
            let newPDF = (dict["enablePDFUpload"] as? NSNumber)?.boolValue ?? true
            let newVoice = (dict["enableVoice"] as? NSNumber)?.boolValue ?? false
            let newCustomViewProvider = (dict["enableCustomViewProvider"] as? NSNumber)?.boolValue ?? false

            // Save new flags (will take effect on next app restart / new conversation)
            UserDefaults.standard.set(newMultiAgent, forKey: Self.featureFlagKeys.enableMultiAgent)
            UserDefaults.standard.set(newMultiModal, forKey: Self.featureFlagKeys.enableMultiModalInput)
            UserDefaults.standard.set(newPDF, forKey: Self.featureFlagKeys.enablePDFUpload)
            UserDefaults.standard.set(newVoice, forKey: Self.featureFlagKeys.enableVoice)
            UserDefaults.standard.set(newCustomViewProvider, forKey: Self.featureFlagKeys.enableCustomViewProvider)

            print("[AgentforceModule] Feature flags saved (will apply on app restart)")
            resolve(nil)
        }
    }

    /// Get current service agent configuration values
    @objc
    func getConfiguration(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            if case .service(let config) = currentMode {
                resolve([
                    "serviceApiURL": config.serviceApiURL,
                    "organizationId": config.organizationId,
                    "esDeveloperName": config.esDeveloperName
                ])
                return
            }

            // Read persisted values from UserDefaults (survives app restart)
            let config: [String: String] = [
                "serviceApiURL": UserDefaults.standard.string(forKey: "ServiceAgentSiteUrl") ?? "",
                "organizationId": UserDefaults.standard.string(forKey: "ServiceAgentOrgUrl") ?? "",
                "esDeveloperName": UserDefaults.standard.string(forKey: "ServiceAgentDevName") ?? ""
            ]
            resolve(config)
        }
    }

    /// Get detailed configuration info including mode
    @objc
    func getConfigurationInfo(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            if credentialProvider.isConfigured {
                resolve([
                    "configured": true,
                    "mode": credentialProvider.isServiceAgent ? "service" : "employee",
                    "description": credentialProvider.currentConfiguration
                ])
            } else {
                resolve([
                    "configured": false,
                    "mode": NSNull()
                ])
            }
        }
    }

    /// Check if SDK is initialized and ready
    @objc
    func isInitialized(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            resolve(agentforceClient != nil)
        }
    }

    // MARK: - Logging

    /// Enable or disable forwarding of native SDK logs to JavaScript
    /// Called by AgentforceService.setLoggerDelegate() and clearLoggerDelegate()
    @objc
    func enableLogForwarding(
        _ enabled: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        bridgeLogger.forwardingEnabled = enabled
        resolve(true)
    }

    /// Emits a log event to JavaScript if listeners are active.
    /// Called by BridgeLogger when forwarding is enabled.
    ///
    /// Events require both `forwardingEnabled` (on BridgeLogger) and active
    /// NativeEventEmitter listeners to flow. JS must call `addListener` before
    /// `enableLogForwarding(true)` to avoid a window where events are dropped.
    func emitLogEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onLogMessage", body: payload)
    }

    // MARK: - Navigation

    @objc
    func enableNavigationForwarding(
        _ enabled: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        bridgeNavigation.forwardingEnabled = enabled
        resolve(true)
    }

    /// Emits a navigation event to JavaScript if listeners are active.
    /// Called by BridgeNavigation when forwarding is enabled.
    ///
    /// Events require both `forwardingEnabled` (on BridgeNavigation) and active
    /// NativeEventEmitter listeners to flow. JS must call `addListener` before
    /// `enableNavigationForwarding(true)` to avoid a window where events are dropped.
    func emitNavigationEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onNavigationRequest", body: payload)
    }

    // MARK: - UI Delegate Forwarding

    @objc
    func enableUIDelegateForwarding(
        _ enabled: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        bridgeUIDelegate.forwardingEnabled = enabled
        resolve(true)
    }

    @objc
    func provideModifiedUtterance(
        _ requestId: String,
        utterance: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        modifyContinuationsLock.lock()
        let continuation = modifyContinuations.removeValue(forKey: requestId)
        modifyContinuationsLock.unlock()

        if let continuation = continuation {
            continuation.resume(returning: utterance)
            resolve(true)
        } else {
            resolve(false)
        }
    }

    /// Called by BridgeUIDelegate to emit a modify-utterance request to JS
    /// and await the response (or timeout).
    func awaitModifiedUtterance(requestId: String, utteranceText: String, timeout: TimeInterval) async -> String? {
        guard listenerLock.withLock({ _hasListeners }) else { return nil }

        sendEvent(withName: "onModifyUtteranceRequest", body: [
            "requestId": requestId,
            "utterance": utteranceText,
        ])

        return await withCheckedContinuation { continuation in
            modifyContinuationsLock.lock()
            modifyContinuations[requestId] = continuation
            modifyContinuationsLock.unlock()

            Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.modifyContinuationsLock.lock()
                let pending = self.modifyContinuations.removeValue(forKey: requestId)
                self.modifyContinuationsLock.unlock()
                pending?.resume(returning: nil)
            }
        }
    }

    func emitUtteranceSentEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onUtteranceSent", body: payload)
    }

    func emitAgentSwitchEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onAgentSwitch", body: payload)
    }

    // MARK: - View Provider

    /// Register a React Native component as a custom view provider for specified types.
    /// Can be called before or after configure() — the provider is always attached to the
    /// client and canHandle() checks the map dynamically.
    @objc
    func registerViewProvider(
        _ config: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let dict = config as? [String: Any],
              let componentMap = dict["componentMap"] as? [String: String],
              !componentMap.isEmpty else {
            reject("INVALID_CONFIG", "Must provide a non-empty componentMap dictionary", nil)
            return
        }
        bridgeViewProvider.register(componentMap: componentMap)
        resolve(["success": true, "registeredTypes": Array(componentMap.keys)])
    }

    /// Clear the custom view provider registration.
    @objc
    func clearViewProvider(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        bridgeViewProvider.reset()
        resolve(["success": true])
    }

    // MARK: - Cleanup

    private func cleanupClient() {
        currentConversation = nil
        agentforceClient = nil
        bridgeHiddenPreChat.setFields([:])
    }

    /// Close the conversation
    @objc
    func closeConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await closeCurrentConversation()
            dismissConversation()
            resolve(["success": true])
        }
    }

    // MARK: - Hidden PreChat Fields

    /// Pre-register hidden prechat field values for the next Service Agent session.
    @objc
    func registerHiddenPreChatFields(
        _ fields: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let dict = fields as? [String: String] else {
            reject(
                "INVALID_FIELDS",
                "Hidden prechat fields must be a map of string keys to string values",
                nil
            )
            return
        }
        bridgeHiddenPreChat.setFields(dict)
        resolve(nil)
    }

    /// Get the currently registered hidden prechat field values.
    @objc
    func getHiddenPreChatFields(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        resolve(bridgeHiddenPreChat.getFields())
    }

    // MARK: - Additional Context

    /// Helper function to recursively convert Any value to JSEncodableValue
    private func convertToJSEncodableValue(_ rawValue: Any) -> JSEncodableValue? {
        if let stringValue = rawValue as? String {
            return .string(stringValue)
        } else if let numberValue = rawValue as? NSNumber {
            // Check if it's a boolean first (NSNumber can represent booleans)
            if CFBooleanGetTypeID() == CFGetTypeID(numberValue) {
                return .boolean(numberValue.boolValue)
            } else {
                return .number(numberValue.doubleValue)
            }
        } else if let arrayValue = rawValue as? [Any] {
            // Recursively convert array elements
            let encodableArray = arrayValue.compactMap { element in
                convertToJSEncodableValue(element)
            }
            return .array(encodableArray)
        } else if let dictValue = rawValue as? [String: Any] {
            // Recursively convert dictionary values
            var encodableDict: [String: JSEncodableValue] = [:]
            for (key, val) in dictValue {
                if let converted = convertToJSEncodableValue(val) {
                    encodableDict[key] = converted
                }
            }
            return .object(encodableDict)
        } else {
            return nil
        }
    }

    /// Set additional context for the current conversation.
    /// Must be called after launching a conversation.
    ///
    /// @param contextDict Dictionary with "variables" array
    /// @param resolve Promise resolver
    /// @param reject Promise rejecter
    @objc
    func setAdditionalContext(
        _ contextDict: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                // Validate context structure
                guard let variables = contextDict["variables"] as? [[String: Any]] else {
                    reject("INVALID_CONTEXT", "Missing or invalid 'variables' array", nil)
                    return
                }

                // Check if conversation exists
                guard let conversation = currentConversation else {
                    reject(
                        "NO_CONVERSATION",
                        "No active conversation. Launch conversation first, then set context.",
                        nil
                    )
                    return
                }

                // Convert to AgentforceVariable array
                var agentforceVariables: [AgentforceVariable] = []
                for (index, varDict) in variables.enumerated() {
                    guard let name = varDict["name"] as? String,
                          let type = varDict["type"] as? String else {
                        reject(
                            "INVALID_CONTEXT",
                            "Variable at index \(index) missing 'name' or 'type'",
                            nil
                        )
                        return
                    }

                    // Convert value to JSEncodableValue enum using recursive helper
                    let value: JSEncodableValue?
                    if let rawValue = varDict["value"] {
                        value = convertToJSEncodableValue(rawValue)
                        if value == nil {
                            print("[AgentforceModule] ⚠️ Unsupported value type at index \(index)")
                        }
                    } else {
                        value = nil
                    }

                    // Create AgentforceVariable
                    // Note: iOS AgentforceVariable doesn't support description field (Android only)
                    let variable = AgentforceVariable(
                        name: name,
                        type: type,
                        value: value
                    )
                    agentforceVariables.append(variable)
                }

                // Set context on conversation
                try await conversation.setAdditionalContext(context: agentforceVariables)

                print("[AgentforceModule] ✓ Additional context set: \(agentforceVariables.count) variables")
                resolve(["success": true])

            } catch {
                print("[AgentforceModule] ❌ Failed to set additional context: \(error)")
                reject("CONTEXT_ERROR", error.localizedDescription, error)
            }
        }
    }

    /// Reset all settings
    @objc
    func resetSettings(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await closeCurrentConversation()
            cleanupClient()
            currentMode = nil
            credentialProvider.reset()
            bridgeViewProvider.reset()
            UserDefaults.standard.removeObject(forKey: "ServiceAgentSiteUrl")
            UserDefaults.standard.removeObject(forKey: "ServiceAgentOrgUrl")
            UserDefaults.standard.removeObject(forKey: "ServiceAgentDevName")
            UserDefaults.standard.removeObject(forKey: "EmployeeAgentId")
            resolve(["success": true])
        }
    }

    // MARK: - UI Presentation Helpers

    @MainActor
    private func presentConversationView<Content: View>(_ conversationView: Content) {
        guard let rootViewController = getRootViewController() else {
            print("[AgentforceModule] ⚠️ Could not find root view controller")
            return
        }

        let hostingController = UIHostingController(rootView: conversationView)
        hostingController.modalPresentationStyle = .fullScreen
        hostingController.modalTransitionStyle = .coverVertical

        rootViewController.present(hostingController, animated: true)
    }

    @MainActor
    private func dismissConversation() {
        guard let rootViewController = getRootViewController() else {
            print("[AgentforceModule] ⚠️ Could not find root view controller for dismissal")
            return
        }

        if rootViewController.presentedViewController != nil {
            // Dismiss the UI but preserve the conversation so it persists across launches
            rootViewController.dismiss(animated: true)
        }
    }

    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        return window.rootViewController
    }
}
