/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Service Agent Credential Provider
 * Provides authentication for Service Agent mode
 */

import Foundation
import AgentforceSDK
import AgentforceService

/// Credential provider for Service Agent mode
/// Service Agents use OAuth with empty credentials and organization URL
class ServiceAgentCredentialProvider: AgentforceAuthCredentialProviding {
    
    private var organizationUrl: String
    
    init(organizationUrl: String = "") {
        self.organizationUrl = organizationUrl
    }
    
    // MARK: - AgentforceAuthCredentialProviding
    
    func getAuthCredentials() -> AgentforceAuthCredentials {
        // For Service Agent mode, use OAuth with empty authToken and userId
        // The orgId is set to the organization URL
        return .OAuth(authToken: "", orgId: organizationUrl, userId: "")
    }
    
    // MARK: - Configuration Update
    
    func updateConfiguration(organizationUrl: String) {
        self.organizationUrl = organizationUrl
    }
}
