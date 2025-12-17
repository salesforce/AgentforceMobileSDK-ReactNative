/*
 Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

