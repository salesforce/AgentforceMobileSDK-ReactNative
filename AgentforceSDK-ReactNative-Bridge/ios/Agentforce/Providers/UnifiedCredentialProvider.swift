/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Unified Credential Provider - Handles credentials for both Service and Employee Agent modes
 */

import Foundation
import AgentforceSDK
import AgentforceService

/// Unified credential provider that handles both Service Agent and Employee Agent modes.
/// Returns .OAuth credentials for both modes:
/// - Service Agent: empty token and userId (guest access)
/// - Employee Agent: real token and userId (authenticated access)
class UnifiedCredentialProvider: AgentforceAuthCredentialProviding {
    
    // MARK: - Properties
    
    /// Current operating mode
    private(set) var mode: AgentMode?
    
    /// Token provider for Employee Agent mode (nil for Service Agent)
    private var tokenProvider: TokenProviding?
    
    /// Direct token storage for simple token cases
    private var directToken: String?
    private var directOrgId: String?
    private var directUserId: String?
    
    // MARK: - Initialization
    
    init() {
        // Starts unconfigured
    }
    
    // MARK: - Configuration
    
    /// Configure for Service Agent mode (anonymous/guest access)
    /// - Parameter config: Service Agent configuration
    func configure(serviceAgent config: ServiceAgentModeConfig) {
        self.mode = .service(config: config)
        self.tokenProvider = nil
        self.directToken = ""  // Empty token for Service Agent
        self.directOrgId = config.organizationId
        self.directUserId = ""  // Empty userId for Service Agent
        
        print("[UnifiedCredentialProvider] Configured for Service Agent mode")
    }
    
    /// Configure for Employee Agent mode with a token provider delegate
    /// - Parameters:
    ///   - config: Employee Agent configuration
    ///   - tokenProvider: Token provider implementation
    func configure(employeeAgent config: EmployeeAgentModeConfig, tokenProvider: TokenProviding) {
        self.mode = .employee(config: config)
        self.tokenProvider = tokenProvider
        self.directToken = nil
        self.directOrgId = nil
        self.directUserId = nil
        
        print("[UnifiedCredentialProvider] Configured for Employee Agent mode with token provider")
    }
    
    /// Configure for Employee Agent mode with a direct token (simpler testing scenario)
    /// - Parameter config: Employee Agent configuration with accessToken
    func configure(employeeAgent config: EmployeeAgentModeConfig) {
        self.mode = .employee(config: config)
        self.tokenProvider = nil
        self.directToken = config.accessToken
        self.directOrgId = config.organizationId
        self.directUserId = config.userId
        
        print("[UnifiedCredentialProvider] Configured for Employee Agent mode with direct token")
    }
    
    // MARK: - AgentforceAuthCredentialProviding
    
    func getAuthCredentials() -> AgentforceAuthCredentials {
        guard let mode = mode else {
            fatalError("UnifiedCredentialProvider not configured. Call configure() first.")
        }
        
        switch mode {
        case .service(let config):
            // Service Agent uses OAuth with EMPTY token (guest access)
            return .OAuth(
                authToken: "",
                orgId: config.organizationId,
                userId: ""
            )
            
        case .employee(let config):
            // Employee Agent uses OAuth with REAL token
            if let tokenProvider = tokenProvider {
                // Delegate-based token
                return .OAuth(
                    authToken: tokenProvider.getAccessToken(),
                    orgId: tokenProvider.getOrganizationId(),
                    userId: tokenProvider.getUserId()
                )
            } else if let token = directToken {
                // Direct token
                return .OAuth(
                    authToken: token,
                    orgId: directOrgId ?? config.organizationId,
                    userId: directUserId ?? config.userId
                )
            } else {
                fatalError("Employee Agent mode requires either tokenProvider or directToken")
            }
        }
    }
    
    // MARK: - Token Management (Employee Agent only)
    
    /// Update the direct token (used when JS provides a refreshed token)
    /// - Parameter newToken: The new access token
    func updateToken(_ newToken: String) {
        guard case .employee = mode else {
            print("[UnifiedCredentialProvider] Warning: updateToken called but not in Employee Agent mode")
            return
        }
        self.directToken = newToken
        print("[UnifiedCredentialProvider] Token updated")
    }
    
    // MARK: - Mode Queries
    
    /// Check if currently in Employee Agent mode
    var isEmployeeAgent: Bool {
        if case .employee = mode {
            return true
        }
        return false
    }
    
    /// Check if currently in Service Agent mode
    var isServiceAgent: Bool {
        if case .service = mode {
            return true
        }
        return false
    }
    
    /// Check if the provider is configured
    var isConfigured: Bool {
        return mode != nil
    }
    
    /// Get the current mode's configuration description (for debugging/logging)
    var currentConfiguration: String {
        guard let mode = mode else {
            return "Unconfigured"
        }
        switch mode {
        case .service(let config):
            return "Service Agent - Org: \(config.organizationId)"
        case .employee(let config):
            return "Employee Agent - Org: \(config.organizationId), User: \(config.userId)"
        }
    }
    
    // MARK: - Cleanup
    
    /// Reset the provider to unconfigured state
    func reset() {
        mode = nil
        tokenProvider = nil
        directToken = nil
        directOrgId = nil
        directUserId = nil
        print("[UnifiedCredentialProvider] Reset to unconfigured state")
    }
}
