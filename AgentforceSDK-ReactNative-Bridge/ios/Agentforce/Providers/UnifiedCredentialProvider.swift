/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Unified Credential Provider - Handles credentials for both Service and Employee Agent modes
 */

import Foundation
import AgentforceSDK
import AgentforceService
import SalesforceUser

#if canImport(SalesforceSDKCore)
import SalesforceSDKCore
#endif

/// Unified credential provider that handles both Service Agent and Employee Agent modes.
/// Returns .OAuth credentials for both modes:
/// - Service Agent: empty token and userId (guest access)
/// - Employee Agent: real token and userId (authenticated access)
class UnifiedCredentialProvider: AgentforceAuthCredentialProviding {
    
    // MARK: - Properties

    /// Current operating mode
    private(set) var mode: AgentMode?

    /// Direct token storage for simple token cases (fallback only)
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
        self.directToken = ""  // Empty token for Service Agent
        self.directOrgId = config.organizationId
        self.directUserId = ""  // Empty userId for Service Agent

    }

    /// Configure for Employee Agent mode
    /// - Parameter config: Employee Agent configuration
    func configure(employeeAgent config: EmployeeAgentModeConfig) {
        self.mode = .employee(config: config)
        self.directToken = config.accessToken
        self.directOrgId = config.organizationId
        self.directUserId = config.userId

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
            // Get fresh credentials from Mobile SDK each time (Mobile SDK handles refresh internally)
            #if canImport(SalesforceSDKCore)
            if let currentUser = UserAccountManager.shared.currentUserAccount,
               let accessToken = currentUser.credentials.accessToken,
               let orgId = currentUser.credentials.organizationId,
               let userId = currentUser.credentials.userId {
                return .OAuth(
                    authToken: accessToken,
                    orgId: orgId,
                    userId: userId
                )
            }
            #endif

            // Fallback to cached token if Mobile SDK not available
            if let token = directToken {
                return .OAuth(
                    authToken: token,
                    orgId: directOrgId ?? config.organizationId,
                    userId: directUserId ?? config.userId
                )
            } else {
                fatalError("Employee Agent mode requires either Mobile SDK or cached token")
            }
        }
    }
    
    // MARK: - Token Management (Employee Agent only)
    
    /// Update the direct token (used when JS provides a refreshed token)
    /// - Parameter newToken: The new access token
    func updateToken(_ newToken: String) {
        guard case .employee = mode else {
            return
        }
        self.directToken = newToken
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
        directToken = nil
        directOrgId = nil
        directUserId = nil
    }
}
