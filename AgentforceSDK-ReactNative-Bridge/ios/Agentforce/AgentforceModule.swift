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

    /// Voice delegate for handling voice interactions
    private var voiceDelegate: AgentforceVoiceDelegate?

    private let listenerLock = NSLock()
    private var _hasListeners = false

    // MARK: - Logging

    /// Bridge logger for forwarding SDK logs to JavaScript
    private lazy var bridgeLogger: BridgeLogger = {
        return BridgeLogger(module: self)
    }()

    // MARK: - Module Setup

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return ["onLogMessage", "onNavigationRequest"]
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
        
        // Configure unified credential provider for Service Agent mode
        credentialProvider.configure(serviceAgent: config)
        currentMode = .service(config: config)
        
        // Clean up any existing client
        cleanupClient()
        
        // Also update the legacy ServiceAgentManager for backward compatibility
        await MainActor.run {
            ServiceAgentManager.shared.configure(
                orgUrl: config.organizationId,
                devName: config.esDeveloperName,
                siteUrl: config.serviceApiURL
            )
        }
        
        // Using fullConfig instead of .serviceAgent() to inject bridgeLogger.
        // TODO: Migrate to mode .serviceAgent(config) when ServiceAgentConfiguration supports a logger parameter.
        let serviceUser = User(
            userId: "",
            org: Org(id: config.organizationId),
            username: "service_user",
            displayName: "Service User"
        )

        let fullConfiguration = AgentforceConfiguration(
            user: serviceUser,
            forceConfigEndpoint: config.serviceApiURL,
            agentforceFeatureFlagSettings: AgentforceFeatureFlagSettings(),
            salesforceNetwork: nil,
            salesforceNavigation: nil,
            salesforceLogger: bridgeLogger,
            serviceApiURL: config.serviceApiURL
        )

        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .fullConfig(fullConfiguration)
        )
    }
    
    // MARK: - Employee Agent Configuration
    
    private func configureEmployeeAgent(_ configDict: [String: Any]) async throws {
        guard let config = EmployeeAgentModeConfig.from(dictionary: configDict) else {
            throw AgentConfigError.missingRequiredField("instanceUrl, organizationId, userId, agentId, or accessToken")
        }

        // Configure unified credential provider for Employee Agent mode
        // UnifiedCredentialProvider will fetch fresh tokens from Mobile SDK automatically
        credentialProvider.configure(employeeAgent: config)
        currentMode = .employee(config: config)

        // Persist employee agentId (editable in Settings tab)
        UserDefaults.standard.set(config.agentId ?? "", forKey: "EmployeeAgentId")

        // Clean up any existing client
        cleanupClient()

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

        // Create User for FullConfig mode (SDK 14.x). We use .fullConfig(AgentforceConfiguration)
        // instead of .employeeAgent so we can set feature flags explicitly (e.g. multiAgent only).
        // TODO: Migrate to mode .employeeAgent(config) when EmployeeAgentConfiguration supports a logger parameter.
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
        
        // Build full configuration so we control agentforceFeatureFlagSettings.
        // Passing nil for optional params uses SDK defaults (network, imageProvider, theme, etc.).
        let fullConfiguration = AgentforceConfiguration(
            user: user,
            forceConfigEndpoint: config.instanceUrl,
            agentforceFeatureFlagSettings: featureFlagSettings,
            salesforceNetwork: nil,
            salesforceNavigation: nil,
            salesforceLogger: bridgeLogger
        )
        
        // Initialize Agentforce Client with fullConfig mode (explicit config + feature flags).
        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .fullConfig(fullConfiguration)
        )
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
                // Try new unified path first
                if let client = agentforceClient, let mode = currentMode {
                    let conversation = try getOrCreateConversation(client: client, mode: mode)

                    // Create voice delegate to handle voice button taps
                    let delegate = AgentforceVoiceDelegate(
                        agentforceClient: client,
                        presentingViewController: nil // Will find topmost VC automatically
                    )
                    self.voiceDelegate = delegate

                    let chatView = try client.createAgentforceChatView(
                        conversation: conversation,
                        delegate: delegate,
                        showTopBar: true,
                        onContainerClose: { [weak self] in
                            Task { @MainActor in
                                self?.dismissConversation()
                            }
                        }
                    )

                    presentConversationView(chatView)
                    resolve(["success": true])
                    return
                }
                
                // Fall back to legacy ServiceAgentManager path
                if !ServiceAgentManager.shared.isInitialized {
                    guard ServiceAgentManager.shared.isConfigured else {
                        throw ServiceAgentError.notConfigured
                    }
                    try ServiceAgentManager.shared.initializeSDK()
                }
                
                guard let client = ServiceAgentManager.shared.getClient() else {
                    throw ServiceAgentError.sdkNotInitialized
                }

                let conversation = ServiceAgentManager.shared.startConversation()

                // Create voice delegate to handle voice button taps
                let delegate = AgentforceVoiceDelegate(
                    agentforceClient: client,
                    presentingViewController: nil // Will find topmost VC automatically
                )
                self.voiceDelegate = delegate

                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: delegate,
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
                print("[AgentforceModule] ❌ Error details: \((error as NSError).domain) code: \((error as NSError).code)")
                print("[AgentforceModule] ❌ Full error: \(error)")
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
                // Close existing conversation
                await closeCurrentConversation()
                
                // Try new unified path first
                if let client = agentforceClient, let mode = currentMode {
                    let conversation = try getOrCreateConversation(client: client, mode: mode, forceNew: true)

                    // Create voice delegate to handle voice button taps
                    let delegate = AgentforceVoiceDelegate(
                        agentforceClient: client,
                        presentingViewController: nil // Will find topmost VC automatically
                    )
                    self.voiceDelegate = delegate

                    let chatView = try client.createAgentforceChatView(
                        conversation: conversation,
                        delegate: delegate,
                        showTopBar: true,
                        onContainerClose: { [weak self] in
                            Task { @MainActor in
                                self?.dismissConversation()
                            }
                        }
                    )
                    
                    presentConversationView(chatView)
                    resolve(["success": true])
                    return
                }
                
                // Fall back to legacy path
                if !ServiceAgentManager.shared.isInitialized {
                    guard ServiceAgentManager.shared.isConfigured else {
                        throw ServiceAgentError.notConfigured
                    }
                    try ServiceAgentManager.shared.initializeSDK()
                }
                
                guard let client = ServiceAgentManager.shared.getClient() else {
                    throw ServiceAgentError.sdkNotInitialized
                }

                let conversation = await ServiceAgentManager.shared.startNewConversation()

                // Create voice delegate to handle voice button taps
                let delegate = AgentforceVoiceDelegate(
                    agentforceClient: client,
                    presentingViewController: nil // Will find topmost VC automatically
                )
                self.voiceDelegate = delegate

                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: delegate,
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
            // Check new unified path first
            if credentialProvider.isConfigured {
                resolve(true)
                return
            }
            // Fall back to legacy
            let configured = ServiceAgentManager.shared.isConfigured
            resolve(configured)
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
        UserDefaults.standard.set(agentId, forKey: "EmployeeAgentId")
        resolve(nil)
    }
    
    private static let featureFlagKeys = (
        enableMultiAgent: "AgentforceFF_enableMultiAgent",
        enableMultiModalInput: "AgentforceFF_enableMultiModalInput",
        enablePDFUpload: "AgentforceFF_enablePDFUpload",
        enableVoice: "AgentforceFF_enableVoice"
    )
    
    private struct FeatureFlags {
        let enableMultiAgent: Bool
        let enableMultiModalInput: Bool
        let enablePDFUpload: Bool
        let enableVoice: Bool
    }
    
    private func getFeatureFlagsFromConfigOrUserDefaults(_ configDict: [String: Any]) -> FeatureFlags {
        if let featureFlags = configDict["featureFlags"] as? [String: Any] {
            return FeatureFlags(
                enableMultiAgent: (featureFlags["enableMultiAgent"] as? NSNumber)?.boolValue ?? true,
                enableMultiModalInput: (featureFlags["enableMultiModalInput"] as? NSNumber)?.boolValue ?? false,
                enablePDFUpload: (featureFlags["enablePDFUpload"] as? NSNumber)?.boolValue ?? false,
                enableVoice: (featureFlags["enableVoice"] as? NSNumber)?.boolValue ?? false
            )
        }
        let ud = UserDefaults.standard
        return FeatureFlags(
            enableMultiAgent: ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            enableMultiModalInput: ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            enablePDFUpload: ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            enableVoice: ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableVoice)
        )
    }
    
    private func saveFeatureFlagsToUserDefaults(_ flags: FeatureFlags) {
        UserDefaults.standard.set(flags.enableMultiAgent, forKey: Self.featureFlagKeys.enableMultiAgent)
        UserDefaults.standard.set(flags.enableMultiModalInput, forKey: Self.featureFlagKeys.enableMultiModalInput)
        UserDefaults.standard.set(flags.enablePDFUpload, forKey: Self.featureFlagKeys.enablePDFUpload)
        UserDefaults.standard.set(flags.enableVoice, forKey: Self.featureFlagKeys.enableVoice)
    }
    
    @objc
    func getFeatureFlags(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let ud = UserDefaults.standard
        let flags = [
            "enableMultiAgent": ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            "enableMultiModalInput": ud.object(forKey: Self.featureFlagKeys.enableMultiModalInput) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            "enablePDFUpload": ud.object(forKey: Self.featureFlagKeys.enablePDFUpload) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            "enableVoice": ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? false : ud.bool(forKey: Self.featureFlagKeys.enableVoice)
        ]
        resolve(flags)
    }

    @objc
    func setFeatureFlags(
        _ flags: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let dict = flags as? [String: Any] else {
            resolve(nil)
            return
        }
        let enableMultiAgent = (dict["enableMultiAgent"] as? NSNumber)?.boolValue ?? true
        let enableMultiModalInput = (dict["enableMultiModalInput"] as? NSNumber)?.boolValue ?? false
        let enablePDFUpload = (dict["enablePDFUpload"] as? NSNumber)?.boolValue ?? false
        let enableVoice = (dict["enableVoice"] as? NSNumber)?.boolValue ?? false

        UserDefaults.standard.set(enableMultiAgent, forKey: Self.featureFlagKeys.enableMultiAgent)
        UserDefaults.standard.set(enableMultiModalInput, forKey: Self.featureFlagKeys.enableMultiModalInput)
        UserDefaults.standard.set(enablePDFUpload, forKey: Self.featureFlagKeys.enablePDFUpload)
        UserDefaults.standard.set(enableVoice, forKey: Self.featureFlagKeys.enableVoice)

        resolve(nil)
    }
    
    /// Get current configuration values (legacy format for backward compatibility)
    @objc
    func getConfiguration(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Return service agent config format for backward compatibility
            if case .service(let config) = currentMode {
                let configDict: [String: String] = [
                    "serviceApiURL": config.serviceApiURL,
                    "organizationId": config.organizationId,
                    "esDeveloperName": config.esDeveloperName
                ]
                resolve(configDict)
                return
            }
            
            // Fall back to legacy ServiceAgentManager
            let config: [String: String] = [
                "serviceApiURL": ServiceAgentManager.shared.siteUrl,
                "organizationId": ServiceAgentManager.shared.orgUrl,
                "esDeveloperName": ServiceAgentManager.shared.devName
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
            } else if ServiceAgentManager.shared.isConfigured {
                resolve([
                    "configured": true,
                    "mode": "service",
                    "description": "Service Agent (legacy) - Org: \(ServiceAgentManager.shared.orgUrl)"
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
            if agentforceClient != nil {
                resolve(true)
                return
            }
            let initialized = ServiceAgentManager.shared.isInitialized
            resolve(initialized)
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

    /// Emits a log event to JavaScript if listeners are active
    /// Called by BridgeLogger when forwarding is enabled
    func emitLogEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onLogMessage", body: payload)
    }

    // MARK: - Navigation (stub until iOS implementation)

    @objc
    func enableNavigationForwarding(
        _ enabled: Bool,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // No-op: iOS navigation forwarding not yet implemented
        resolve(true)
    }

    // MARK: - Cleanup
    
    private func cleanupClient() {
        currentConversation = nil
        agentforceClient = nil
    }
    
    /// Close the conversation
    @objc
    func closeConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await closeCurrentConversation()
            await ServiceAgentManager.shared.closeConversation()
            dismissConversation()
            resolve(["success": true])
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
            ServiceAgentManager.shared.resetToDefaults()
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
