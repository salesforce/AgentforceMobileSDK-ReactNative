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
            esDeveloperName: esDeveloperName
        )
    }
}

// MARK: - Employee Agent Configuration

/// Configuration for Employee Agent mode (authenticated access)
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
    
    /// Creates an EmployeeAgentModeConfig from a dictionary
    /// - Parameter dict: Dictionary containing configuration values
    /// - Returns: EmployeeAgentModeConfig if all required fields are present, nil otherwise
    static func from(dictionary dict: [String: Any]) -> EmployeeAgentModeConfig? {
        guard let instanceUrl = dict["instanceUrl"] as? String,
              let organizationId = dict["organizationId"] as? String,
              let userId = dict["userId"] as? String,
              let accessToken = dict["accessToken"] as? String else {
            return nil
        }
        let agentId: String? = (dict["agentId"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return EmployeeAgentModeConfig(
            instanceUrl: instanceUrl,
            organizationId: organizationId,
            userId: userId,
            agentId: agentId,
            agentLabel: dict["agentLabel"] as? String,
            accessToken: accessToken
        )
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
        }
    }
}
