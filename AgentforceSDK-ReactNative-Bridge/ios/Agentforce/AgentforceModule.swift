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

/// Clipboard copier for the Agentforce SDK copy button.
private struct BridgeCopier: AgentforceCopying {
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

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

    /// Navigation bar builder used to override the conversation header title with a
    /// client-supplied Employee Agent label. Strongly retained here because
    /// `NavigationBarManager` holds it as a weak reference. `nil` when no label is
    /// supplied, so the SDK falls back to the server-provided agent label.
    private var navigationBarBuilder: BridgeNavigationBarBuilder?

    /// Normalized voice options applied to the currently-live client. Compared
    /// against a fresh snapshot on reconfigure so a voice-options change forces a
    /// new client (the SDK reads voice options only at client creation). `nil`
    /// when no client is live.
    private var appliedVoiceOptions: VoiceOptionsSnapshot?

    /// Value snapshot of the voice options that actually affect client behavior,
    /// normalized the same way the SDK treats them: a missing, non-positive, or
    /// non-finite timeout collapses to `nil` ("never auto-end"), so cosmetic
    /// differences in the raw JS payload don't spuriously rebuild the client.
    private struct VoiceOptionsSnapshot: Equatable {
        let userSilenceTimeoutSeconds: Double?
        let autoEndWhileMuted: Bool
    }


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

    // MARK: - Splash Screen Provider

    /// Bridge splash screen provider for hosting a React Native welcome screen on
    /// top of the conversation. Initialized lazily so the RCT bridge is available.
    private lazy var bridgeSplashScreenProvider: BridgeSplashScreenProvider = {
        return BridgeSplashScreenProvider(bridge: self.bridge)
    }()

    // MARK: - UI Delegate

    /// Bridge UI delegate for forwarding SDK UI events to JavaScript.
    /// Wired to the splash screen provider so the SDK's splash-screen request is
    /// satisfied by a registered React Native component.
    private lazy var bridgeUIDelegate: BridgeUIDelegate = {
        return BridgeUIDelegate(module: self, splashScreenProvider: bridgeSplashScreenProvider)
    }()

    /// Pending modify-utterance continuations keyed by requestId.
    private var modifyContinuations: [String: CheckedContinuation<String?, Never>] = [:]
    private let modifyContinuationsLock = NSLock()

    // MARK: - Teardown State

    /// Set once the RN bridge tears this module down (hot reload or app teardown).
    /// Guarded by `invalidationLock`. Once true, in-flight async work must not touch
    /// the (deallocating) client or call promise resolvers back into a dead JS runtime.
    /// Mirrors the Android bridge, which cancels its coroutine scope in `invalidate()`.
    private var _isInvalidated = false
    private let invalidationLock = NSLock()

    /// True after `invalidate()` has begun. Async task bodies check this before
    /// resolving/rejecting promises or accessing `agentforceClient`.
    private var isInvalidated: Bool {
        invalidationLock.withLock { _isInvalidated }
    }

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
            "onAgentResponse",
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

        // Parse voice options up-front but pass them in as a `let` argument to the
        // per-mode configurators rather than stashing on `self`. The value lives only
        // for the lifetime of this configure call (matches the "immutable for the
        // session lifetime" intent) and avoids a cross-actor write to instance state
        // that would later be read on `@MainActor`.
        let voiceSessionOptions = Self.parseVoiceSessionOptions(from: configDict)

        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
            do {
                switch type {
                case "service":
                    try await configureServiceAgent(configDict, voiceSessionOptions: voiceSessionOptions)
                    resolve(["success": true, "mode": "service"])

                case "employee":
                    try await configureEmployeeAgent(configDict, voiceSessionOptions: voiceSessionOptions)
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

    /// Parse `voiceOptions` from the JS-side config map into an `AgentforceVoiceSessionOptions`.
    ///
    /// Returns `.init()` (auto-end `.never`) when the field is missing. Any
    /// supplied value is routed through `VoiceAutoEndPolicy.afterUserSilence(clamping:)`,
    /// which normalizes non-finite (NaN / ±infinity) and non-positive durations
    /// to `.never` — so the bridge does not need to pre-validate the number.
    /// `autoEndWhileMuted` defaults to `false` when absent. Mirrors the Android bridge.
    private static func parseVoiceSessionOptions(from configDict: [String: Any]) -> AgentforceVoiceSessionOptions {
        guard let voiceOpts = configDict["voiceOptions"] as? [String: Any] else {
            return AgentforceVoiceSessionOptions()
        }
        let autoEndWhileMuted = (voiceOpts["autoEndWhileMuted"] as? NSNumber)?.boolValue ?? false
        guard let numberValue = voiceOpts["userSilenceTimeoutSeconds"] as? NSNumber else {
            return AgentforceVoiceSessionOptions(autoEndPolicy: .never, autoEndWhileMuted: autoEndWhileMuted)
        }
        return AgentforceVoiceSessionOptions(
            autoEndPolicy: .afterUserSilence(clamping: numberValue.doubleValue),
            autoEndWhileMuted: autoEndWhileMuted
        )
    }

    /// Build a normalized, comparable snapshot of the voice options from the JS
    /// config map. A missing, non-positive, or non-finite `userSilenceTimeoutSeconds`
    /// collapses to `nil` so it compares equal to an explicitly-disabled timeout —
    /// matching how `parseVoiceSessionOptions` maps those to `.never`.
    private static func voiceOptionsSnapshot(from configDict: [String: Any]) -> VoiceOptionsSnapshot {
        guard let voiceOpts = configDict["voiceOptions"] as? [String: Any] else {
            return VoiceOptionsSnapshot(userSilenceTimeoutSeconds: nil, autoEndWhileMuted: false)
        }
        let autoEndWhileMuted = (voiceOpts["autoEndWhileMuted"] as? NSNumber)?.boolValue ?? false
        let seconds = (voiceOpts["userSilenceTimeoutSeconds"] as? NSNumber)?.doubleValue
        let normalizedSeconds = seconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return VoiceOptionsSnapshot(userSilenceTimeoutSeconds: normalizedSeconds, autoEndWhileMuted: autoEndWhileMuted)
    }

    // MARK: - Service Agent Configuration

    private func configureServiceAgent(
        _ configDict: [String: Any],
        voiceSessionOptions: AgentforceVoiceSessionOptions
    ) async throws {
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

        // Service Agent has no client-supplied label override; clear any builder
        // left over from a prior Employee Agent session.
        navigationBarBuilder = nil

        // Persist trimmed values to UserDefaults for cross-session recall
        let trimmedSiteUrl = config.serviceApiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrgId = config.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDevName = config.esDeveloperName.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedSiteUrl, forKey: "ServiceAgentSiteUrl")
        UserDefaults.standard.set(trimmedOrgId, forKey: "ServiceAgentOrgUrl")
        UserDefaults.standard.set(trimmedDevName, forKey: "ServiceAgentDevName")

        // Build ServiceUISettings from JS config (use SDK defaults for omitted keys)
        let uiSettings: ServiceUISettings
        if let raw = config.serviceUISettings {
            uiSettings = ServiceUISettings(
                downloadTranscript: raw["downloadTranscript"] ?? true,
                endConversation: raw["endConversation"] ?? true,
                validationFailureChunkEnabled: raw["validationFailureChunkEnabled"] ?? true,
                useWelcomeUtterances: raw["useWelcomeUtterances"] ?? false,
                showQueueStatus: raw["showQueueStatus"] ?? true,
                enableVideoUpload: raw["enableVideoUpload"] ?? false,
                secureForms: raw["secureForms"] ?? true,
                enableAudioUpload: raw["enableAudioUpload"] ?? false
            )
        } else {
            uiSettings = ServiceUISettings(
                showQueueStatus: true,
                secureForms: true
            )
        }

        // Voice shipped for Service Agents in 262.0. Mirror the Employee path and
        // thread the enableVoice flag through; the SDK wires the voice stack
        // (LiveKit/MIAW) internally once the flag is on. shouldBlockMicrophone stays
        // false so the mic isn't gated; other public flags carry through too.
        let flags = getFeatureFlagsFromConfigOrUserDefaults(configDict)
        saveFeatureFlagsToUserDefaults(flags)
        let featureFlagSettings = AgentforceFeatureFlagSettings(
            enableMultiModalInput: flags.enableMultiModalInput,
            enablePDFFileUpload: flags.enablePDFUpload,
            multiAgent: flags.enableMultiAgent,
            shouldBlockMicrophone: false,
            enableVoice: flags.enableVoice,
            enableOnboarding: false,
            internalFlags: internalFlagsForSDK(configDict)
        )

        // Use .serviceAgent() mode with overrides for logger and navigation.
        var serviceConfig = ServiceAgentConfiguration(
            esDeveloperName: config.esDeveloperName,
            organizationId: config.organizationId,
            serviceApiURL: config.serviceApiURL,
            serviceUISettings: uiSettings,
            forceConfigEndPoint: config.serviceApiURL
        )
        .withFeatureFlags(featureFlagSettings)
        .withLogger(bridgeLogger)
        .withNavigation(bridgeNavigation)
        .withVoiceSessionOptions(voiceSessionOptions)

        if let mode = try AppearanceConfiguration.themeMode(from: configDict) {
            if AppearanceConfiguration.hasOverrides(from: configDict) {
                throw AppearanceError.invalid(
                    "iOS cannot combine appearance.themeMode with sparse appearance overrides in the installed AgentforceSDK"
                )
            }
            serviceConfig = serviceConfig.setTheming(.customManager(AppearanceConfiguration.themeManager(for: mode)))
        } else if let theming = try AppearanceConfiguration.theming(from: configDict) {
            serviceConfig = serviceConfig.setTheming(theming)
        }

        // Always pass bridgeViewProvider so late registrations take effect.
        // canHandle() returns false when the map is empty, matching nil behavior.
        agentforceClient = await AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .serviceAgent(serviceConfig),
            viewProvider: bridgeViewProvider
        )
        agentforceClient?.hiddenPreChatFieldDelegate = bridgeHiddenPreChat
    }

    // MARK: - Employee Agent Configuration

    private func configureEmployeeAgent(
        _ configDict: [String: Any],
        voiceSessionOptions: AgentforceVoiceSessionOptions
    ) async throws {
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
        
        // A live client only reads its voice options at creation, so a change to
        // them must force a rebuild. Only meaningful when a client already exists.
        let voiceOptionsSnapshot = Self.voiceOptionsSnapshot(from: configDict)
        let voiceOptionsChanged = agentforceClient != nil && appliedVoiceOptions != voiceOptionsSnapshot

        let needsNewClient = switchingModes || agentIdChanged || voiceOptionsChanged || agentforceClient == nil

        // Only cleanup if switching from Service mode, agentId changed, or voice options changed
        if switchingModes {
            print("[AgentforceModule] ⚠️ Switching from Service to Employee mode - cleaning up")
            cleanupClient()
        } else if agentIdChanged {
            print("[AgentforceModule] ⚠️ AgentId changed - cleaning up conversation")
            await closeCurrentConversation()
            cleanupClient()
        } else if voiceOptionsChanged {
            print("[AgentforceModule] ⚠️ Voice options changed - cleaning up conversation to rebuild client")
            await closeCurrentConversation()
            cleanupClient()
        } else if agentforceClient != nil {
            print("[AgentforceModule] ✓ AgentId unchanged - preserving client and conversation")
        }

        // Configure unified credential provider for Employee Agent mode
        // UnifiedCredentialProvider will fetch fresh tokens from Mobile SDK automatically
        credentialProvider.configure(employeeAgent: config)
        currentMode = .employee(config: config)

        // Install a navigation bar builder to override the header title when the
        // client supplies a non-empty agentLabel. When absent, leave it nil so the
        // SDK falls back to the server-provided agent label / default.
        if let label = config.agentLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            navigationBarBuilder = BridgeNavigationBarBuilder(agentLabel: label)
        } else {
            navigationBarBuilder = nil
        }

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
        saveFeatureFlagsToUserDefaults(flags)
        let featureFlagSettings = AgentforceFeatureFlagSettings(
            enableMultiModalInput: flags.enableMultiModalInput,
            enablePDFFileUpload: flags.enablePDFUpload,
            multiAgent: flags.enableMultiAgent,
            shouldBlockMicrophone: false,
            enableVoice: flags.enableVoice,
            enableOnboarding: false,
            internalFlags: internalFlagsForSDK(configDict)
        )

        // Build full configuration with authenticated network and data provider for Employee Agent.
        let network = createAuthenticatedNetwork()
        let dataProvider = createDataProvider(network: network)

        var fullConfiguration = AgentforceConfiguration(
            user: user,
            agentforceCopier: BridgeCopier(),
            forceConfigEndpoint: config.instanceUrl,
            dataProvider: dataProvider,
            agentforceFeatureFlagSettings: featureFlagSettings,
            salesforceNetwork: network,
            salesforceNavigation: bridgeNavigation,
            salesforceLogger: bridgeLogger,
            voiceSessionOptions: voiceSessionOptions
        )

        if let mode = try AppearanceConfiguration.themeMode(from: configDict) {
            if AppearanceConfiguration.hasOverrides(from: configDict) {
                throw AppearanceError.invalid(
                    "iOS cannot combine appearance.themeMode with sparse appearance overrides in the installed AgentforceSDK"
                )
            }
            fullConfiguration = fullConfiguration.setTheming(.customManager(AppearanceConfiguration.themeManager(for: mode)))
        } else if let theming = try AppearanceConfiguration.theming(from: configDict) {
            fullConfiguration = fullConfiguration.setTheming(theming)
        }

        // Only create new client if needed (otherwise reuse existing to preserve conversation)
        if needsNewClient {
            print("[AgentforceModule] Creating new AgentforceClient for Employee Agent")
            // Always pass bridgeViewProvider so late registrations take effect.
            // canHandle() returns false when the map is empty, matching nil behavior.
            agentforceClient = await AgentforceClient(
                credentialProvider: credentialProvider,
                mode: .fullConfig(fullConfiguration),
                viewProvider: bridgeViewProvider
            )
            appliedVoiceOptions = voiceOptionsSnapshot
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
        _ options: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
            do {
                guard let client = agentforceClient, let mode = currentMode else {
                    throw AgentConfigError.notConfigured
                }

                let conversation = try getOrCreateConversation(client: client, mode: mode)

                // Parse initialMode from options (defaults to chat)
                let initialModeString = options["initialMode"] as? String ?? "chat"
                let initialMode: AgentforceViewMode = (initialModeString == "voice") ? .voice : .chat

                // Validate Voice is enabled if voice mode requested
                if initialMode == .voice {
                    guard getFeatureFlagsFromConfigOrUserDefaults([:]).enableVoice else {
                        throw NSError(
                            domain: "AgentforceModule",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "Voice is not enabled. Set enableVoice: true in feature flags."]
                        )
                    }
                }

                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    initialMode: initialMode,
                    delegate: bridgeUIDelegate,
                    showTopBar: true,
                    onContainerClose: { [weak self] in
                        Task { @MainActor in
                            self?.dismissConversation()
                        }
                    },
                    navigationBarBuilder: navigationBarBuilder
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
                    },
                    navigationBarBuilder: navigationBarBuilder
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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

    // MARK: - Internal (experimental) flags

    /// Internal flags are a free-form `[String: Bool]` map passed straight through to the iOS
    /// SDK using its own flag key names. The bridge does not enumerate, rename, or validate
    /// them — keys the SDK doesn't recognize are ignored by the SDK (silent no-op).
    ///
    /// ⚠️ Internal flags are not covered by API stability guarantees.
    ///
    /// The full map is persisted as a single UserDefaults dictionary so the set of keys need
    /// not be known ahead of time.
    private static let internalFlagsDefaultsKey = "AgentforceInternalFlags"

    /// Read the internal-flag map from the JS config if present, else from UserDefaults.
    /// Only boolean-valued entries are kept; absent keys fall back to the SDK's own defaults.
    private func getInternalFlagsFromConfigOrUserDefaults(_ configDict: [String: Any]) -> [String: Bool] {
        if let internalFlags = configDict["internalFlags"] as? [String: Any] {
            var result: [String: Bool] = [:]
            for (key, value) in internalFlags {
                if let boolValue = (value as? NSNumber)?.boolValue {
                    result[key] = boolValue
                }
            }
            return result
        }
        return readStoredInternalFlags()
    }

    /// Read the persisted internal-flag map from UserDefaults.
    private func readStoredInternalFlags() -> [String: Bool] {
        let stored = UserDefaults.standard.dictionary(forKey: Self.internalFlagsDefaultsKey) ?? [:]
        var result: [String: Bool] = [:]
        for (key, value) in stored {
            if let boolValue = (value as? NSNumber)?.boolValue {
                result[key] = boolValue
            }
        }
        return result
    }

    /// Build the SDK internal-flags dict for a configure() call. Keys are passed through
    /// unchanged as the SDK's own flag names.
    private func internalFlagsForSDK(_ configDict: [String: Any]) -> [String: Bool] {
        return getInternalFlagsFromConfigOrUserDefaults(configDict)
    }

    @objc
    func getInternalFlags(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        // Return only the flags that were explicitly set (empty map if none).
        resolve(readStoredInternalFlags())
    }

    @objc
    func setInternalFlags(
        _ flags: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
            guard let dict = flags as? [String: Any] else {
                resolve(nil)
                return
            }

            // Merge the caller's flags into the persisted map (matching the Android path,
            // which accumulates across calls). Non-boolean values are dropped; keys are stored
            // as-is (the SDK ignores any it doesn't recognize).
            var toStore = UserDefaults.standard.dictionary(forKey: Self.internalFlagsDefaultsKey) ?? [:]
            for (key, value) in dict {
                guard let boolValue = (value as? NSNumber)?.boolValue else { continue }
                toStore[key] = boolValue
            }
            UserDefaults.standard.set(toStore, forKey: Self.internalFlagsDefaultsKey)

            print("[AgentforceModule] Internal flags saved (will apply on next configure)")
            resolve(nil)
        }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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

        if !enabled {
            drainPendingContinuations()
        }

        resolve(true)
    }

    /// Resume all pending modify-utterance continuations with nil to prevent leaks.
    private func drainPendingContinuations() {
        modifyContinuationsLock.lock()
        let pending = modifyContinuations
        modifyContinuations.removeAll()
        modifyContinuationsLock.unlock()

        for (_, continuation) in pending {
            continuation.resume(returning: nil)
        }
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

        return await withCheckedContinuation { continuation in
            modifyContinuationsLock.lock()
            modifyContinuations[requestId] = continuation
            modifyContinuationsLock.unlock()

            sendEvent(withName: "onModifyUtteranceRequest", body: [
                "requestId": requestId,
                "utterance": utteranceText,
            ])

            // Timeout task: weak self so a hot-reload teardown between scheduling and
            // firing can't reach through a deallocated module (W-23231222). If the
            // sleep is cancelled or the module is gone, `invalidate()` has already
            // drained this continuation via `drainPendingContinuations()`, so we do
            // nothing. `removeValue` under the lock guarantees a single resume.
            Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                } catch {
                    return
                }
                guard let self else { return }
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

    func emitAgentResponseEvent(_ payload: [String: Any]) {
        guard listenerLock.withLock({ _hasListeners }) else { return }
        sendEvent(withName: "onAgentResponse", body: payload)
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

    // MARK: - Splash Screen Provider

    /// Register a React Native component as the splash (welcome) screen for one or
    /// more agents. Can be called before or after configure() — the provider is
    /// always attached via the UI delegate and checks the map dynamically.
    @objc
    func registerSplashScreenProvider(
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
        bridgeSplashScreenProvider.register(componentMap: componentMap)
        resolve(["success": true, "registeredAgents": Array(componentMap.keys)])
    }

    /// Clear the splash screen registration.
    @objc
    func clearSplashScreenProvider(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            bridgeSplashScreenProvider.reset()
            resolve(["success": true])
        }
    }

    /// Report that the user chose a starter utterance on a React Native splash
    /// screen. Routes the utterance back into the SDK's splash utterance delegate,
    /// which animates the splash away and sends the utterance into the conversation.
    @objc
    func selectSplashScreenUtterance(
        _ agentId: String,
        utterance: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            bridgeSplashScreenProvider.selectUtterance(agentId: agentId, utterance: utterance)
            resolve(true)
        }
    }

    // MARK: - Teardown

    /// Called by the RN bridge when it tears this module down — the exact
    /// `-[RCTCxxBridge invalidate]` path seen in the hot-reload crash (W-23231222).
    /// Marks the module invalidated (so guarded async bodies bail out before touching
    /// the client or resolving into a dead JS runtime), resumes any pending
    /// continuations, and releases the client so no in-flight async completion touches
    /// a deallocating object.
    ///
    /// Mirrors the Android bridge's `invalidate()` (`scope.cancel()` + client release).
    /// `RCTEventEmitter` already conforms to `RCTInvalidating` and declares
    /// `invalidate` as `NS_REQUIRES_SUPER`, so this overrides and calls `super`.
    override func invalidate() {
        invalidationLock.withLock { _isInvalidated = true }

        // Resume any awaiting modify-utterance continuations so nothing leaks or
        // resumes into a torn-down JS runtime. Thread-safe (locks internally).
        drainPendingContinuations()

        // Release the client/conversation on the main actor (they were created there).
        // The `isInvalidated` guard on every bridge task prevents new work from racing
        // this teardown.
        Task { @MainActor [weak self] in
            self?.cleanupClient()
        }

        super.invalidate()
    }

    /// Belt-and-suspenders: in the standard RN lifecycle the bridge always calls
    /// `invalidate()` before releasing this module, which drains continuations. This
    /// `deinit` covers any non-standard dealloc path that skips `invalidate()` so a
    /// suspended `withCheckedContinuation` awaiter can never be orphaned/leaked.
    /// Safe from `deinit`: only touches `modifyContinuations` and its lock.
    deinit {
        drainPendingContinuations()
    }

    // MARK: - Cleanup

    private func cleanupClient() {
        currentConversation = nil
        agentforceClient = nil
        appliedVoiceOptions = nil
        bridgeHiddenPreChat.setFields([:])
    }

    /// Close the conversation
    @objc
    func closeConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
            await closeCurrentConversation()
            dismissConversation()
            resolve(["success": true])
        }
    }

    /// Dismiss the conversation UI while preserving the conversation and its history.
    ///
    /// Programmatic equivalent of the in-chat close (X) button: it only dismisses the
    /// presented UI via `dismissConversation()` and deliberately leaves
    /// `currentConversation` alive, so the next `launchConversation` reuses it with
    /// history preserved. Contrast with `closeConversation`, which ends the conversation
    /// (via `closeCurrentConversation()`) before dismissing.
    @objc
    func dismissConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
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

    /// Send an utterance (text message) to the current conversation.
    /// Must be called after launching a conversation.
    ///
    /// @param utterance The text to send to the agent
    /// @param resolve Promise resolver
    /// @param reject Promise rejecter
    @objc
    func sendUtterance(
        _ utterance: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }

            // Check if conversation exists
            guard let conversation = currentConversation else {
                reject(
                    "NO_CONVERSATION",
                    "No active conversation. Launch conversation first, then send an utterance.",
                    nil
                )
                return
            }

            await conversation.sendUtterance(utterance: utterance, attachment: nil)
            print("[AgentforceModule] ✓ Utterance sent")
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
            // Skip if the RN bridge has torn this module down (hot reload) so we
            // don't run bridge work or resolve promises into a dead JS runtime.
            guard !isInvalidated else { return }
            await closeCurrentConversation()
            cleanupClient()
            currentMode = nil
            credentialProvider.reset()
            bridgeViewProvider.reset()
            bridgeSplashScreenProvider.reset()
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
