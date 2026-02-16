/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Token Providing Protocol - Interface for OAuth token providers
 */

import Foundation

/// Protocol for providing OAuth tokens to the Agentforce SDK.
/// Consuming apps implement this to integrate with their auth system.
/// Only used when AgentMode is .employee
protocol TokenProviding {
    /// Returns the current valid access token
    func getAccessToken() -> String
    
    /// Returns the Salesforce organization ID
    func getOrganizationId() -> String
    
    /// Returns the Salesforce user ID
    func getUserId() -> String
    
    /// Called when token refresh is needed (async)
    /// - Returns: The new access token
    /// - Throws: Error if token refresh fails
    func refreshToken() async throws -> String
    
    /// Called when authentication fails completely
    /// Implementing classes can use this to trigger re-login flow
    func onAuthenticationFailure()
}

// MARK: - Default Implementation

extension TokenProviding {
    /// Default no-op implementation for optional authentication failure handler
    func onAuthenticationFailure() {
        // Default implementation does nothing
        print("[TokenProviding] Authentication failure - no handler registered")
    }
}

// MARK: - Token Errors

/// Errors related to token operations
enum TokenError: LocalizedError {
    case noRefreshHandler
    case refreshFailed(String)
    case tokenExpired
    case invalidToken
    
    var errorDescription: String? {
        switch self {
        case .noRefreshHandler:
            return "No token refresh handler configured"
        case .refreshFailed(let reason):
            return "Token refresh failed: \(reason)"
        case .tokenExpired:
            return "Access token has expired"
        case .invalidToken:
            return "Invalid or malformed access token"
        }
    }
}
