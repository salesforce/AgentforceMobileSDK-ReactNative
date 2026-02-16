/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Simple Token Provider - Basic implementation of TokenProviding protocol
 */

import Foundation

/// Simple token provider that holds tokens directly.
/// Used for testing or when tokens are provided via JS configuration.
/// Implements TokenProviding for use with UnifiedCredentialProvider in delegate mode.
class SimpleTokenProvider: TokenProviding {
    
    // MARK: - Properties
    
    private var accessToken: String
    private let organizationId: String
    private let userId: String
    
    /// Handler called when token refresh is needed
    private var tokenRefreshHandler: (() async throws -> String)?
    
    /// Handler called when authentication fails
    private var authFailureHandler: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with token credentials
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - organizationId: Salesforce organization ID
    ///   - userId: Salesforce user ID
    init(accessToken: String, organizationId: String, userId: String) {
        self.accessToken = accessToken
        self.organizationId = organizationId
        self.userId = userId
    }
    
    // MARK: - TokenProviding Implementation
    
    func getAccessToken() -> String {
        return accessToken
    }
    
    func getOrganizationId() -> String {
        return organizationId
    }
    
    func getUserId() -> String {
        return userId
    }
    
    func refreshToken() async throws -> String {
        guard let handler = tokenRefreshHandler else {
            throw TokenError.noRefreshHandler
        }
        
        do {
            let newToken = try await handler()
            accessToken = newToken
            print("[SimpleTokenProvider] Token refreshed successfully")
            return newToken
        } catch {
            print("[SimpleTokenProvider] Token refresh failed: \(error)")
            throw TokenError.refreshFailed(error.localizedDescription)
        }
    }
    
    func onAuthenticationFailure() {
        print("[SimpleTokenProvider] Authentication failure triggered")
        authFailureHandler?()
    }
    
    // MARK: - Configuration
    
    /// Set a handler for token refresh (called from JS delegate)
    /// - Parameter handler: Async closure that returns a new token
    func setRefreshHandler(_ handler: @escaping () async throws -> String) {
        self.tokenRefreshHandler = handler
    }
    
    /// Set a handler for authentication failure
    /// - Parameter handler: Closure called when auth fails
    func setAuthFailureHandler(_ handler: @escaping () -> Void) {
        self.authFailureHandler = handler
    }
    
    /// Update token directly (e.g., when JS provides new token)
    /// - Parameter newToken: The new access token
    func updateToken(_ newToken: String) {
        self.accessToken = newToken
        print("[SimpleTokenProvider] Token updated directly")
    }
}
