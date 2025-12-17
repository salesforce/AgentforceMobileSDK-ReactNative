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
import SwiftUI
import AgentforceSDK
import AgentforceService

/// Manages Agentforce SDK lifecycle for Service Agent mode
/// This is the main class that handles SDK initialization, conversation management,
/// and UI creation for React Native integration
@MainActor
class ServiceAgentManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ServiceAgentManager()
    
    // MARK: - Configuration Properties
    
    @Published var orgUrl: String = "" {
        didSet {
            UserDefaults.standard.set(orgUrl, forKey: "ServiceAgentOrgUrl")
        }
    }
    
    @Published var devName: String = "" {
        didSet {
            UserDefaults.standard.set(devName, forKey: "ServiceAgentDevName")
        }
    }
    
    @Published var siteUrl: String = "" {
        didSet {
            UserDefaults.standard.set(siteUrl, forKey: "ServiceAgentSiteUrl")
        }
    }
    
    // MARK: - SDK State
    
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private var agentforceClient: AgentforceClient?
    private var currentConversation: AgentConversation?
    
    private let credentialProvider: ServiceAgentCredentialProvider
    
    // MARK: - Initialization
    
    private init() {
        self.credentialProvider = ServiceAgentCredentialProvider()
        loadFromUserDefaults()
    }
    
    // MARK: - UserDefaults Persistence
    
    private func loadFromUserDefaults() {
        orgUrl = UserDefaults.standard.string(forKey: "ServiceAgentOrgUrl") ?? ""
        devName = UserDefaults.standard.string(forKey: "ServiceAgentDevName") ?? ""
        siteUrl = UserDefaults.standard.string(forKey: "ServiceAgentSiteUrl") ?? ""
        
        credentialProvider.updateConfiguration(organizationUrl: orgUrl)
        validateConfiguration()
    }
    
    // MARK: - Configuration
    
    /// Update all configuration values at once
    func configure(
        orgUrl: String,
        devName: String,
        siteUrl: String
    ) {
        self.orgUrl = orgUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        self.devName = devName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.siteUrl = siteUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        
        credentialProvider.updateConfiguration(organizationUrl: self.orgUrl)
        validateConfiguration()
    }
    
    /// Validate that all required fields are present
    private func validateConfiguration() {
        isConfigured = !orgUrl.isEmpty &&
                       !devName.isEmpty &&
                       !siteUrl.isEmpty
    }
    
    // MARK: - SDK Initialization
    
    /// Initialize the Agentforce SDK with Service Agent credentials
    func initializeSDK() throws {
        guard isConfigured else {
            throw ServiceAgentError.notConfigured
        }
        
        // Clean up any existing client
        cleanupSDK()
        
        // Create Service Agent Configuration
        // For Service Agent mode, we need: esDeveloperName, organizationId, and serviceApiURL
        let serviceConfig = ServiceAgentConfiguration(
            esDeveloperName: devName,
            organizationId: orgUrl,
            serviceApiURL: siteUrl
        )
        
        // Initialize Agentforce Client with Service Agent mode
        agentforceClient = AgentforceClient(
            credentialProvider: credentialProvider,
            mode: .serviceAgent(serviceConfig)
        )
        
        isInitialized = true
        lastError = nil
        
        print("[ServiceAgentManager] ✅ SDK initialized successfully")
        print("[ServiceAgentManager]    Org URL: \(orgUrl)")
        print("[ServiceAgentManager]    Site URL: \(siteUrl)")
        print("[ServiceAgentManager]    Agent: \(devName)")
    }
    
    // MARK: - Conversation Management
    
    /// Get or create the Agentforce client
    func getClient() -> AgentforceClient? {
        return agentforceClient
    }
    
    /// Get or start a conversation (reuses existing if available)
    /// This preserves the conversation history across multiple launches
    func startConversation() -> AgentConversation {
        // If we already have an active conversation, return it
        if let existingConversation = currentConversation {
            print("[ServiceAgentManager] ♻️ Reusing existing conversation")
            return existingConversation
        }
        
        guard let client = agentforceClient else {
            fatalError("SDK not initialized. Call initializeSDK() first.")
        }
        
        // Start a new conversation with the configured developer name
        let conversation = client.startAgentforceConversation(
            forESDeveloperName: devName
        )
        
        // Store the conversation to keep it alive
        currentConversation = conversation
        
        print("[ServiceAgentManager] 📝 New conversation started and retained")
        return conversation
    }
    
    /// Force start a new conversation (closes existing one if present)
    func startNewConversation() async -> AgentConversation {
        // Close existing conversation if present
        if currentConversation != nil {
            print("[ServiceAgentManager] 🔄 Closing existing conversation to start fresh")
            await closeConversation()
        }
        
        // Start a new conversation
        return startConversation()
    }
    
    /// Get the current conversation
    func getCurrentConversation() -> AgentConversation? {
        return currentConversation
    }
    
    // MARK: - Cleanup
    
    /// Clean up SDK resources (call when reinitializing or resetting)
    func cleanupSDK() {
        currentConversation = nil
        agentforceClient = nil
        isInitialized = false
        print("[ServiceAgentManager] 🧹 SDK cleaned up")
    }
    
    /// Close current conversation
    func closeConversation() async {
        if let conversation = currentConversation {
            do {
                try await conversation.closeConversation()
                print("[ServiceAgentManager] 📪 Conversation closed")
            } catch {
                print("[ServiceAgentManager] ⚠️ Error closing conversation: \(error)")
            }
        }
        // Clear the conversation reference but keep the client alive
        currentConversation = nil
        print("[ServiceAgentManager] 🧹 Conversation reference cleared")
    }
    
    // MARK: - Reset
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        orgUrl = ""
        devName = ""
        siteUrl = ""
        cleanupSDK()
        validateConfiguration()
        print("[ServiceAgentManager] 🔄 Reset to defaults")
    }
}

// MARK: - Error Types

enum ServiceAgentError: LocalizedError {
    case notConfigured
    case sdkNotInitialized
    case failedToStartConversation
    case noActiveConversation
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Service Agent is not configured. Please provide all required fields in Settings."
        case .sdkNotInitialized:
            return "SDK has not been initialized. Please configure settings first."
        case .failedToStartConversation:
            return "Failed to start a conversation with the Service Agent."
        case .noActiveConversation:
            return "No active conversation. Start a conversation first."
        case .invalidConfiguration:
            return "Invalid configuration values provided. Please check all URLs and names."
        }
    }
}
