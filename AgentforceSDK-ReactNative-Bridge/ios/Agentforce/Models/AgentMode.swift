/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Agent Mode - Defines operating modes for the Agentforce SDK
 */

import Foundation

/// Defines the operating mode for the Agentforce SDK.
/// Mirrors the AgentConfig union type from the JavaScript layer.
enum AgentMode {
    /// Service Agent mode - anonymous/guest access with empty OAuth token
    case service(config: ServiceAgentModeConfig)
    
    /// Employee Agent mode - authenticated access with real OAuth token
    /// Uses SDK's .fullConfig mode for full control over AgentforceConfiguration
    case employee(config: EmployeeAgentModeConfig)
    
    /// Returns the mode type as a string
    var typeString: String {
        switch self {
        case .service:
            return "service"
        case .employee:
            return "employee"
        }
    }
}

// MARK: - Service Agent Configuration

/// Configuration for Service Agent mode (anonymous/guest access)
struct ServiceAgentModeConfig {
    /// The Service API URL endpoint
    let serviceApiURL: String

    /// Salesforce Organization ID
    let organizationId: String

    /// The Einstein Service Agent developer name
    let esDeveloperName: String

    /// Optional UI settings parsed from JS config
    let serviceUISettings: [String: Bool]?

    /// Leave the Force config endpoint unset so AgentforceSDK derives the core org host
    /// from the SCRT service URL. Reusing `serviceApiURL` here sends Mobile Types and
    /// branding requests to the SCRT host, where they return HTTP 404.
    var forceConfigEndPoint: String { "" }

    /// Creates a ServiceAgentModeConfig from a dictionary
    /// - Parameter dict: Dictionary containing configuration values
    /// - Returns: ServiceAgentModeConfig if all required fields are present, nil otherwise
    static func from(dictionary dict: [String: Any]) -> ServiceAgentModeConfig? {
        guard let serviceApiURL = dict["serviceApiURL"] as? String,
              let organizationId = dict["organizationId"] as? String,
              let esDeveloperName = dict["esDeveloperName"] as? String else {
            return nil
        }

        return ServiceAgentModeConfig(
            serviceApiURL: serviceApiURL,
            organizationId: organizationId,
            esDeveloperName: esDeveloperName,
            serviceUISettings: dict["serviceUISettings"] as? [String: Bool]
        )
    }
}

// MARK: - Employee Agent Configuration

/// Configuration for Employee Agent mode (authenticated access)
enum EmployeeAuthentication: Equatable {
    case legacy(accessToken: String)
    case mobileSDKOAuth
    case directOAuth(accessToken: String)

    /// Token values may rotate without changing the authentication source.
    func hasSameSource(as other: EmployeeAuthentication) -> Bool {
        switch (self, other) {
        case (.legacy, .legacy), (.mobileSDKOAuth, .mobileSDKOAuth), (.directOAuth, .directOAuth):
            return true
        default:
            return false
        }
    }

    var usesMobileSDKNetwork: Bool {
        switch self {
        case .legacy, .mobileSDKOAuth: return true
        case .directOAuth: return false
        }
    }
}

struct EmployeeAgentModeConfig {
    /// Salesforce instance URL (e.g., "https://myorg.my.salesforce.com")
    let instanceUrl: String
    
    /// Salesforce Organization ID
    let organizationId: String
    
    /// Salesforce User ID
    let userId: String
    
    /// Agentforce Agent ID; nil when multi-agent is used and SDK should pick first available agent from org
    let agentId: String?
    
    /// Optional display label for the agent
    let agentLabel: String?
    
    /// OAuth access token for authentication
    var accessToken: String
    var authentication: EmployeeAuthentication

    /// User/account identity and authentication source determine whether a client can be reused.
    func hasSameIdentity(as other: EmployeeAgentModeConfig) -> Bool {
        instanceUrl == other.instanceUrl &&
            organizationId == other.organizationId &&
            userId == other.userId &&
            authentication.hasSameSource(as: other.authentication)
    }

    /// Metadata supplied to the native SDK for a directly configured agent.
    ///
    /// Direct-agent hosts do not rely on agent discovery, so seed the configured agent and let the
    /// host's `enableVoice` choice drive voice eligibility. Multi-agent configurations leave this
    /// unset so the native SDK can discover the available agents.
    func directAgentInfoSeed(enableVoice: Bool) -> DirectAgentInfoSeed? {
        guard let agentId else { return nil }
        let trimmedLabel = agentLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DirectAgentInfoSeed(
            agentId: agentId,
            label: trimmedLabel.flatMap { $0.isEmpty ? nil : $0 } ?? "Agentforce",
            isVoiceEnabled: enableVoice
        )
    }

    /// Resolves every Employee Agent setting that is immutable after client creation.
    /// The bridge compares this plan with the one applied to the live client so a repeated
    /// `configure()` call can reuse only a genuinely equivalent client.
    func clientConfigurationPlan(
        enableMultiAgent: Bool,
        enableMultiModalInput: Bool,
        enablePDFUpload: Bool,
        enableVoice: Bool,
        userSilenceTimeoutSeconds: Double?,
        autoEndWhileMuted: Bool,
        defaultClosedCaptionsEnabled: Bool,
        internalFlags: [String: Bool]
    ) -> EmployeeClientConfigurationPlan {
        EmployeeClientConfigurationPlan(
            enableMultiAgent: enableMultiAgent,
            enableMultiModalInput: enableMultiModalInput,
            enablePDFUpload: enablePDFUpload,
            enableVoice: enableVoice,
            userSilenceTimeoutSeconds: userSilenceTimeoutSeconds,
            autoEndWhileMuted: autoEndWhileMuted,
            defaultClosedCaptionsEnabled: defaultClosedCaptionsEnabled,
            internalFlags: internalFlags,
            directAgentInfoSeed: directAgentInfoSeed(enableVoice: enableVoice)
        )
    }
    
    /// Creates an EmployeeAgentModeConfig from a dictionary
    /// - Parameter dict: Dictionary containing configuration values
    /// - Returns: EmployeeAgentModeConfig if all required fields are present, nil otherwise
    static func from(dictionary dict: [String: Any]) -> EmployeeAgentModeConfig? {
        guard let instanceUrl = dict["instanceUrl"] as? String,
              let organizationId = dict["organizationId"] as? String,
              let userId = dict["userId"] as? String else {
            return nil
        }
        let accessToken = dict["accessToken"] as? String
        let authentication: EmployeeAuthentication
        if let rawAuth = dict["authentication"] as? [String: Any] {
            guard accessToken == nil,
                  let type = rawAuth["type"] as? String,
                  let source = rawAuth["source"] as? String else { return nil }
            switch (type, source) {
            case ("oauth", "salesforceMobileSdk"):
                authentication = .mobileSDKOAuth
            case ("oauth", "direct"):
                guard let token = rawAuth["accessToken"] as? String,
                      !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                authentication = .directOAuth(accessToken: token)
            default: return nil
            }
        } else {
            guard let accessToken else { return nil }
            authentication = .legacy(accessToken: accessToken)
        }
        let agentId: String? = (dict["agentId"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return EmployeeAgentModeConfig(
            instanceUrl: instanceUrl,
            organizationId: organizationId,
            userId: userId,
            agentId: agentId,
            agentLabel: dict["agentLabel"] as? String,
            accessToken: accessToken ?? "",
            authentication: authentication
        )
    }
}

/// Foundation-only representation of the `AgentInfo` that the bridge passes to AgentforceSDK.
/// Keeping this conversion input independent of the SDK makes the direct-agent policy unit-testable.
struct DirectAgentInfoSeed: Equatable {
    let agentId: String
    let label: String
    let isVoiceEnabled: Bool
}

/// Creation-time Employee Agent settings applied to a native client.
struct EmployeeClientConfigurationPlan: Equatable {
    let enableMultiAgent: Bool
    let enableMultiModalInput: Bool
    let enablePDFUpload: Bool
    let enableVoice: Bool
    let userSilenceTimeoutSeconds: Double?
    let autoEndWhileMuted: Bool
    let defaultClosedCaptionsEnabled: Bool
    let internalFlags: [String: Bool]
    let directAgentInfoSeed: DirectAgentInfoSeed?

    func requiresClientRebuild(comparedTo applied: EmployeeClientConfigurationPlan?) -> Bool {
        self != applied
    }
}

// MARK: - Error Types

/// Errors related to agent configuration
enum AgentConfigError: LocalizedError {
    case notConfigured
    case missingRequiredField(String)
    case invalidMode(String)
    case tokenRequired
    case sdkNotInitialized
    case mobileSDKSessionUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Agent not configured. Call configure() first."
        case .missingRequiredField(let field):
            return "Missing required configuration field: \(field)"
        case .invalidMode(let mode):
            return "Invalid agent mode: \(mode). Must be 'service' or 'employee'."
        case .tokenRequired:
            return "Employee Agent requires an access token."
        case .sdkNotInitialized:
            return "SDK not initialized. Configuration may have failed."
        case .mobileSDKSessionUnavailable:
            return "Mobile SDK OAuth session is unavailable. Integrate Salesforce Mobile SDK and sign in before configuring Employee Agent."
        }
    }
}
