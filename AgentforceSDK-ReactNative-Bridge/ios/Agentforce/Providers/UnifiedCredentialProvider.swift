/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Unified Credential Provider - Handles credentials for both Service and Employee Agent modes
 */

import Foundation
#if canImport(AgentforceService)
import AgentforceService
#endif

#if canImport(SalesforceSDKCore)
import SalesforceSDKCore
#endif

/// Credentials read together from one authentication source.
struct OAuthCredentialSnapshot: Equatable {
    let authToken: String
    let orgId: String
    let userId: String

    var isUsable: Bool {
        [authToken, orgId, userId].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// Resolves guest or Employee OAuth credentials and validates required Mobile SDK sessions.
class UnifiedCredentialProvider {
    
    // MARK: - Properties

    /// Current operating mode
    private(set) var mode: AgentMode?

    /// Direct token storage for simple token cases (fallback only)
    private var directToken: String?
    private var directOrgId: String?
    private var directUserId: String?

    private let loadMobileSDKCredentials: () -> OAuthCredentialSnapshot?

    /// Reports failures from SDK callbacks, whose synchronous protocol cannot throw.
    var onCredentialError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    init(mobileSDKCredentials: (() -> OAuthCredentialSnapshot?)? = nil) {
        self.loadMobileSDKCredentials = mobileSDKCredentials ?? Self.currentMobileSDKCredentials
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
    func configure(employeeAgent config: EmployeeAgentModeConfig) throws {
        // Validate before changing mode or replacing credentials on an existing client.
        try validate(employeeAgent: config)
        self.mode = .employee(config: config)
        switch config.authentication {
        case .directOAuth(let token): self.directToken = token
        case .legacy(let token): self.directToken = token
        case .mobileSDKOAuth: self.directToken = nil
        }
        self.directOrgId = config.organizationId
        self.directUserId = config.userId

    }
    
    // MARK: - Credential Resolution

    func validate(employeeAgent config: EmployeeAgentModeConfig) throws {
        if case .mobileSDKOAuth = config.authentication, mobileSDKCredentials() == nil {
            throw AgentConfigError.mobileSDKSessionUnavailable
        }
    }

    func validateCredentials() throws {
        _ = try resolvedCredentials()
    }

    func resolvedCredentials() throws -> OAuthCredentialSnapshot {
        guard let mode = mode else {
            throw AgentConfigError.notConfigured
        }

        switch mode {
        case .service(let config):
            // Service Agent uses OAuth with EMPTY token (guest access)
            return OAuthCredentialSnapshot(
                authToken: "",
                orgId: config.organizationId,
                userId: ""
            )

        case .employee(let config):
            switch config.authentication {
            case .directOAuth(let token):
                return OAuthCredentialSnapshot(authToken: directToken ?? token, orgId: config.organizationId, userId: config.userId)
            case .mobileSDKOAuth:
                guard let credentials = mobileSDKCredentials() else {
                    throw AgentConfigError.mobileSDKSessionUnavailable
                }
                return credentials
            case .legacy:
                if let credentials = mobileSDKCredentials() { return credentials }
                guard let token = directToken else { throw AgentConfigError.tokenRequired }
                return OAuthCredentialSnapshot(authToken: token, orgId: config.organizationId, userId: config.userId)
            }
        }
    }

    /// SDK callbacks have no error return. Withhold the token after session loss;
    /// never reuse a previously read Mobile SDK token or terminate the host process.
    func credentialsForSDK() -> OAuthCredentialSnapshot {
        do {
            return try resolvedCredentials()
        } catch {
            onCredentialError?(error)
            return OAuthCredentialSnapshot(authToken: "", orgId: directOrgId ?? "", userId: directUserId ?? "")
        }
    }

    private func mobileSDKCredentials() -> OAuthCredentialSnapshot? {
        guard let credentials = loadMobileSDKCredentials(), credentials.isUsable else { return nil }
        return credentials
    }

    private static func currentMobileSDKCredentials() -> OAuthCredentialSnapshot? {
        #if canImport(SalesforceSDKCore)
        if let currentUser = UserAccountManager.shared.currentUserAccount,
           let accessToken = currentUser.credentials.accessToken,
           let orgId = currentUser.credentials.organizationId,
           let userId = currentUser.credentials.userId {
            return OAuthCredentialSnapshot(
                authToken: accessToken,
                orgId: orgId,
                userId: userId
            )
        }
        #endif
        return nil
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

// Keep SDK adaptation separate from the credential resolution and validation logic.
#if canImport(AgentforceService)
extension UnifiedCredentialProvider: AgentforceAuthCredentialProviding {
    func getAuthCredentials() -> AgentforceAuthCredentials {
        let credentials = credentialsForSDK()
        return .OAuth(authToken: credentials.authToken, orgId: credentials.orgId, userId: credentials.userId)
    }
}
#endif
