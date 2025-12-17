/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */

import Foundation
import AgentforceSDK
import AgentforceService

/// ViewModel for managing Service Agent state
@MainActor
class ServiceAgentViewModel: ObservableObject {
    @Published var serviceApiURL: String = ""
    @Published var organizationId: String = ""
    @Published var esDeveloperName: String = ""
    @Published var isConfigured: Bool = false
    
    var agentforceClient: AgentforceClient?
    var conversation: AgentforceConversation?
    
    func updateConfiguration(serviceApiURL: String, organizationId: String, esDeveloperName: String) {
        self.serviceApiURL = serviceApiURL
        self.organizationId = organizationId
        self.esDeveloperName = esDeveloperName
    }
    
    func initializeAgentforce() async throws {
        guard !serviceApiURL.isEmpty,
              !organizationId.isEmpty,
              !esDeveloperName.isEmpty else {
            throw NSError(domain: "ServiceAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration incomplete"])
        }
        
        // Create Service Agent configuration
        let serviceAgentConfig = ServiceAgentConfiguration(
            esDeveloperName: esDeveloperName,
            organizationId: organizationId,
            serviceApiURL: serviceApiURL
        )
        
        // Simple auth provider for Service Agent
        let authProvider = SimpleAuthProvider(orgId: organizationId)
        
        // Create Agentforce configuration
        let agentforceConfig = AgentforceConfiguration(
            authCredentialProvider: authProvider,
            serviceApiURL: serviceApiURL,
            salesforceDomain: serviceApiURL
        )
        
        // Create and initialize client
        let client = AgentforceClient()
        try await client.initialize(
            mode: .serviceAgent(
                serviceAgentConfiguration: serviceAgentConfig,
                agentforceConfiguration: agentforceConfig
            )
        )
        
        self.agentforceClient = client
        self.isConfigured = true
    }
    
    func startConversation() async throws {
        guard let client = agentforceClient else {
            throw NSError(domain: "ServiceAgent", code: -2, userInfo: [NSLocalizedDescriptionKey: "Client not initialized"])
        }
        
        conversation = try await client.startConversation()
    }
}

/// Simple authentication provider for Service Agent (no auth needed)
class SimpleAuthProvider: AgentforceAuthCredentialProvider {
    private let orgId: String
    
    init(orgId: String) {
        self.orgId = orgId
    }
    
    func authCredentials() async throws -> AgentforceAuthCredentials {
        return AgentforceAuthCredentials.oauth(
            authToken: "",
            orgId: orgId,
            userId: ""
        )
    }
}

