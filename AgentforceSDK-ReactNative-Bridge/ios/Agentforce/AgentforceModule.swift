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
    
    /// Simple token provider for Employee Agent mode
    private var simpleTokenProvider: SimpleTokenProvider?
    
    /// Current mode configuration
    private var currentMode: AgentMode?
    
    /// Continuation for async token refresh
    private var tokenRefreshContinuation: CheckedContinuation<String, Error>?
    
    /// Track if we have listeners registered
    private var hasListeners = false
    
    // MARK: - Module Setup
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override func supportedEvents() -> [String]! {
        return ["onTokenRefreshNeeded", "onAuthenticationFailure"]
    }
    
    override func startObserving() {
        hasListeners = true
    }
    
    override func stopObserving() {
        hasListeners = false
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
        
        print("[AgentforceModule] 📍 Service Agent config - serviceApiURL: \(config.serviceApiURL), organizationId: \(config.organizationId), esDeveloperName: \(config.esDeveloperName)")
        
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
        
        // Create Service Agent Configuration for SDK
        let sdkServiceConfig = ServiceAgentConfiguration(
            esDeveloperName: config.esDeveloperName,
            organizationId: config.organizationId,
            serviceApiURL: config.serviceApiURL
        )
        
        // Initialize Agentforce Client with Service Agent mode
        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .serviceAgent(sdkServiceConfig)
        )
        
        print("[AgentforceModule] ✅ Service Agent configured - Org: \(config.organizationId). If you see 'Start session failed with 400' or keyNotFound(sessionId), check serviceApiURL, organizationId, and esDeveloperName match your org/site.")
    }
    
    // MARK: - Employee Agent Configuration
    
    private func configureEmployeeAgent(_ configDict: [String: Any]) async throws {
        guard let config = EmployeeAgentModeConfig.from(dictionary: configDict) else {
            throw AgentConfigError.missingRequiredField("instanceUrl, organizationId, userId, agentId, or accessToken")
        }
        
        // Create simple token provider for delegate-based refresh
        simpleTokenProvider = SimpleTokenProvider(
            accessToken: config.accessToken,
            organizationId: config.organizationId,
            userId: config.userId
        )
        
        // Set up refresh handler that calls back to JS
        simpleTokenProvider?.setRefreshHandler { [weak self] in
            guard let self = self else {
                throw TokenError.refreshFailed("Module deallocated")
            }
            return try await self.requestTokenRefreshFromJS()
        }
        
        // Set up auth failure handler
        simpleTokenProvider?.setAuthFailureHandler { [weak self] in
            self?.emitAuthenticationFailure(error: "Token refresh failed")
        }
        
        // Configure unified credential provider for Employee Agent mode with delegate
        credentialProvider.configure(
            employeeAgent: config,
            tokenProvider: simpleTokenProvider!
        )
        currentMode = .employee(config: config)
        
        // Persist employee agentId (editable in Settings tab)
        UserDefaults.standard.set(config.agentId ?? "", forKey: "EmployeeAgentId")
        
        // Clean up any existing client
        cleanupClient()
        
        // Create User for FullConfig mode (SDK 14.x). We use .fullConfig(AgentforceConfiguration)
        // instead of .employeeAgent so we can set feature flags explicitly (e.g. multiAgent only).
        let user = User(
            userId: config.userId,
            org: Org(id: config.organizationId),
            username: config.userId,
            displayName: config.userId
        )
        
        let flags = getFeatureFlagsFromConfigOrUserDefaults(configDict)
        saveFeatureFlagsToUserDefaults(flags)
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
            salesforceNavigation: nil
        )
        
        // Initialize Agentforce Client with fullConfig mode (explicit config + feature flags).
        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .fullConfig(fullConfiguration)
        )
        
        print("[AgentforceModule] ✅ Employee Agent configured - Org: \(config.organizationId), User: \(config.userId)")
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
                    
                    let chatView = try client.createAgentforceChatView(
                        conversation: conversation,
                        delegate: nil,
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
                
                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: nil,
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
                // Close existing conversation
                await closeCurrentConversation()
                
                // Try new unified path first
                if let client = agentforceClient, let mode = currentMode {
                    let conversation = try getOrCreateConversation(client: client, mode: mode, forceNew: true)
                    
                    let chatView = try client.createAgentforceChatView(
                        conversation: conversation,
                        delegate: nil,
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
                
                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: nil,
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
            print("[AgentforceModule] ♻️ Reusing existing conversation")
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
            conversation = client.startAgentforceConversation(
                forAgentId: config.agentId
            )
        }
        
        currentConversation = conversation
        switch mode {
        case .service(let config):
            print("[AgentforceModule] 📝 New conversation started (Service Agent) - esDeveloperName: \(config.esDeveloperName). Session start API will use serviceApiURL: \(config.serviceApiURL)")
        case .employee(let config):
            print("[AgentforceModule] 📝 New conversation started (Employee Agent) - agentId: \(config.agentId ?? "nil (multi-agent)"). Session start API will use instanceUrl and credentials.")
        }
        return conversation
    }
    
    private func closeCurrentConversation() async {
        if let conversation = currentConversation {
            do {
                try await conversation.closeConversation()
                print("[AgentforceModule] 📪 Conversation closed")
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
                enableVoice: (featureFlags["enableVoice"] as? NSNumber)?.boolValue ?? true
            )
        }
        let ud = UserDefaults.standard
        return FeatureFlags(
            enableMultiAgent: ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            enableMultiModalInput: ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            enablePDFUpload: ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            enableVoice: ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableVoice)
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
        resolve([
            "enableMultiAgent": ud.object(forKey: Self.featureFlagKeys.enableMultiAgent) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableMultiAgent),
            "enableMultiModalInput": ud.bool(forKey: Self.featureFlagKeys.enableMultiModalInput),
            "enablePDFUpload": ud.bool(forKey: Self.featureFlagKeys.enablePDFUpload),
            "enableVoice": ud.object(forKey: Self.featureFlagKeys.enableVoice) == nil ? true : ud.bool(forKey: Self.featureFlagKeys.enableVoice)
        ])
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
        let enableVoice = (dict["enableVoice"] as? NSNumber)?.boolValue ?? true
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
    
    // MARK: - Token Refresh (Employee Agent only)
    
    /// Called when token needs refresh - emits event to JS
    private func requestTokenRefreshFromJS() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // Emit event to JS to request token refresh
            if hasListeners {
                sendEvent(withName: "onTokenRefreshNeeded", body: nil)
            }
            
            // Store continuation to be resolved when JS calls back
            self.tokenRefreshContinuation = continuation
        }
    }
    
    /// Called by JS when it has a fresh token
    @objc
    func provideRefreshedToken(
        _ token: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard credentialProvider.isEmployeeAgent else {
            reject("INVALID_MODE", "Token refresh only valid for Employee Agent mode", nil)
            return
        }
        
        if let continuation = tokenRefreshContinuation {
            simpleTokenProvider?.updateToken(token)
            credentialProvider.updateToken(token)
            continuation.resume(returning: token)
            tokenRefreshContinuation = nil
            resolve(["success": true])
        } else {
            reject("NO_PENDING_REFRESH", "No token refresh was pending", nil)
        }
    }
    
    /// Emit authentication failure event to JS
    private func emitAuthenticationFailure(error: String) {
        if hasListeners {
            sendEvent(withName: "onAuthenticationFailure", body: ["error": error])
        }
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
            simpleTokenProvider = nil
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
        
        print("[AgentforceModule] 🚀 Presenting conversation view")
        rootViewController.present(hostingController, animated: true)
    }
    
    @MainActor
    private func dismissConversation() {
        guard let rootViewController = getRootViewController() else {
            print("[AgentforceModule] ⚠️ Could not find root view controller for dismissal")
            return
        }
        
        if rootViewController.presentedViewController != nil {
            print("[AgentforceModule] 📪 Dismissing conversation view")
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
