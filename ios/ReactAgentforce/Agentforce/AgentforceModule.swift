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
import UIKit
import SwiftUI
import React
import AgentforceSDK

/// React Native bridge module for Agentforce SDK
/// Exposes native SDK functionality to JavaScript layer
@objc(AgentforceModule)
class AgentforceModule: NSObject {
    
    // MARK: - Module Setup
    
    /// Required: Tell React Native this module needs to run on main thread
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - Configuration Methods
    
    /// Configure Service Agent (JavaScript-friendly interface)
    /// Maps JavaScript parameters to native configuration
    /// Called from React Native: AgentforceModule.configure(serviceApiURL, organizationId, esDeveloperName)
    @objc
    func configure(
        _ serviceApiURL: String,
        organizationId: String,
        esDeveloperName: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                // Map JavaScript parameters to native configuration:
                // - serviceApiURL -> siteUrl (the Service API endpoint)
                // - organizationId -> orgUrl (the organization URL/ID)
                // - esDeveloperName -> devName (Einstein Service developer name)
                ServiceAgentManager.shared.configure(
                    orgUrl: organizationId,
                    devName: esDeveloperName,
                    siteUrl: serviceApiURL
                )
                
                // Initialize SDK
                try ServiceAgentManager.shared.initializeSDK()
                
                print("[AgentforceModule] ✅ Service Agent configured successfully")
                resolve(true)
            } catch {
                print("[AgentforceModule] ❌ Configuration failed: \(error)")
                reject("CONFIG_ERROR", error.localizedDescription, error)
            }
        }
    }
    
    /// Configure Service Agent settings and initialize SDK
    /// Called from React Native: AgentforceModule.initializeServiceAgent(...)
    @objc
    func initializeServiceAgent(
        _ orgUrl: String,
        devName: String,
        siteUrl: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                // Update configuration
                ServiceAgentManager.shared.configure(
                    orgUrl: orgUrl,
                    devName: devName,
                    siteUrl: siteUrl
                )
                
                // Initialize SDK
                try ServiceAgentManager.shared.initializeSDK()
                
                resolve(["success": true])
            } catch {
                print("[AgentforceModule] ❌ Initialization failed: \(error)")
                reject("INIT_ERROR", error.localizedDescription, error)
            }
        }
    }
    
    /// Check if SDK is configured
    @objc
    func isConfigured(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let configured = ServiceAgentManager.shared.isConfigured
            resolve(configured)
        }
    }
    
    /// Get current configuration values
    @objc
    func getConfiguration(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let config: [String: String] = [
                "serviceApiURL": ServiceAgentManager.shared.siteUrl,
                "organizationId": ServiceAgentManager.shared.orgUrl,
                "esDeveloperName": ServiceAgentManager.shared.devName
            ]
            resolve(config)
        }
    }
    
    /// Check if SDK is initialized and ready
    @objc
    func isInitialized(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            let initialized = ServiceAgentManager.shared.isInitialized
            resolve(initialized)
        }
    }
    
    // MARK: - Conversation Methods
    
    /// Launch the conversation UI
    /// Presents AgentforceConversationContainer as a modal
    @objc
    func launchConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                // Ensure SDK is initialized
                if !ServiceAgentManager.shared.isInitialized {
                    guard ServiceAgentManager.shared.isConfigured else {
                        throw ServiceAgentError.notConfigured
                    }
                    try ServiceAgentManager.shared.initializeSDK()
                }
                
                // Get the Agentforce client
                guard let client = ServiceAgentManager.shared.getClient() else {
                    throw ServiceAgentError.sdkNotInitialized
                }
                
                // Start and retain the conversation through ServiceAgentManager
                // This ensures the conversation is kept alive for its duration
                let conversation = ServiceAgentManager.shared.startConversation()
                
                // Create the chat view
                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: nil,
                    showTopBar: true,
                    onContainerClose: {
                        Task { @MainActor in
                            self.dismissConversation()
                        }
                    }
                )
                
                // Present the conversation
                self.presentConversationView(chatView)
                
                resolve(["success": true])
            } catch {
                print("[AgentforceModule] ❌ Launch failed: \(error)")
                reject("LAUNCH_ERROR", error.localizedDescription, error)
            }
        }
    }
    
    /// Close the conversation
    @objc
    func closeConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            await ServiceAgentManager.shared.closeConversation()
            self.dismissConversation()
            resolve(["success": true])
        }
    }
    
    /// Start a new conversation (closes existing one and launches fresh)
    @objc
    func startNewConversation(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            do {
                // Ensure SDK is initialized
                if !ServiceAgentManager.shared.isInitialized {
                    guard ServiceAgentManager.shared.isConfigured else {
                        throw ServiceAgentError.notConfigured
                    }
                    try ServiceAgentManager.shared.initializeSDK()
                }
                
                // Get the Agentforce client
                guard let client = ServiceAgentManager.shared.getClient() else {
                    throw ServiceAgentError.sdkNotInitialized
                }
                
                // Start a fresh conversation (closes existing one)
                let conversation = await ServiceAgentManager.shared.startNewConversation()
                
                // Create the chat view
                let chatView = try client.createAgentforceChatView(
                    conversation: conversation,
                    delegate: nil,
                    showTopBar: true,
                    onContainerClose: {
                        Task { @MainActor in
                            self.dismissConversation()
                        }
                    }
                )
                
                // Present the conversation
                self.presentConversationView(chatView)
                
                resolve(["success": true])
            } catch {
                print("[AgentforceModule] ❌ Start new conversation failed: \(error)")
                reject("START_NEW_ERROR", error.localizedDescription, error)
            }
        }
    }
    
    /// Reset all settings
    @objc
    func resetSettings(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        Task { @MainActor in
            ServiceAgentManager.shared.resetToDefaults()
            resolve(["success": true])
        }
    }
    
    // MARK: - UI Presentation Helpers
    
    /// Present conversation view as modal
    @MainActor
    private func presentConversationView<Content: View>(_ conversationView: Content) {
        guard let rootViewController = getRootViewController() else {
            print("[AgentforceModule] ⚠️ Could not find root view controller")
            return
        }
        
        // Wrap SwiftUI view in UIHostingController
        let hostingController = UIHostingController(rootView: conversationView)
        hostingController.modalPresentationStyle = .fullScreen
        hostingController.modalTransitionStyle = .coverVertical
        
        print("[AgentforceModule] 🚀 Presenting conversation view")
        rootViewController.present(hostingController, animated: true)
    }
    
    /// Dismiss presented conversation
    @MainActor
    private func dismissConversation() {
        guard let rootViewController = getRootViewControllerForPresentation() else { 
            print("[AgentforceModule] ⚠️ Could not find root view controller for dismissal")
            return 
        }
        
        if rootViewController.presentedViewController != nil {
            print("[AgentforceModule] 📪 Dismissing conversation view")
            rootViewController.dismiss(animated: true) {
                print("[AgentforceModule] ✅ Conversation dismissed")
            }
        } else {
            print("[AgentforceModule] ⚠️ No presented view controller to dismiss")
        }
    }
    
    /// Get the root view controller for presenting modals
    @MainActor
    private func getRootViewController() -> UIViewController? {
        return getRootViewControllerForPresentation()
    }
    
    /// Get the base root view controller (for presenting new modals)
    @MainActor
    private func getRootViewControllerForPresentation() -> UIViewController? {
        // Get key window for iOS 13+
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        // Return the base root view controller (NOT the topmost presented one)
        // This is the view controller that presented the modal
        return window.rootViewController
    }
}
