/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */

import Foundation
import React
import SwiftUI
import AgentforceSDK

@objc(AgentforceModule)
class AgentforceModule: NSObject {
    
    private static var viewModel: ServiceAgentViewModel?
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc
    func configure(_ serviceApiURL: String,
                   organizationId: String,
                   esDeveloperName: String,
                   resolver resolve: @escaping RCTPromiseResolveBlock,
                   rejecter reject: @escaping RCTPromiseRejectBlock) {
        
        Task { @MainActor in
            do {
                // Create or get existing view model
                if AgentforceModule.viewModel == nil {
                    AgentforceModule.viewModel = ServiceAgentViewModel()
                }
                
                guard let viewModel = AgentforceModule.viewModel else {
                    reject("ERROR", "Failed to create view model", nil)
                    return
                }
                
                // Validate inputs
                guard !serviceApiURL.isEmpty,
                      !organizationId.isEmpty,
                      !esDeveloperName.isEmpty else {
                    reject("ERROR", "All configuration parameters are required", nil)
                    return
                }
                
                // Update configuration
                viewModel.updateConfiguration(
                    serviceApiURL: serviceApiURL,
                    organizationId: organizationId,
                    esDeveloperName: esDeveloperName
                )
                
                // Initialize SDK
                try await viewModel.initializeAgentforce()
                
                resolve(true)
            } catch {
                reject("ERROR", "Failed to configure: \(error.localizedDescription)", error)
            }
        }
    }
    
    @objc
    func launchConversation(_ resolve: @escaping RCTPromiseResolveBlock,
                           rejecter reject: @escaping RCTPromiseRejectBlock) {
        
        Task { @MainActor in
            do {
                guard let viewModel = AgentforceModule.viewModel else {
                    reject("ERROR", "SDK not configured. Call configure() first.", nil)
                    return
                }
                
                guard viewModel.isConfigured else {
                    reject("ERROR", "SDK not configured properly", nil)
                    return
                }
                
                // Start conversation
                try await viewModel.startConversation()
                
                // Present conversation UI
                DispatchQueue.main.async {
                    self.presentConversationUI(viewModel: viewModel)
                    resolve(true)
                }
            } catch {
                reject("ERROR", "Failed to launch conversation: \(error.localizedDescription)", error)
            }
        }
    }
    
    @objc
    func isConfigured(_ resolve: @escaping RCTPromiseResolveBlock,
                     rejecter reject: @escaping RCTPromiseRejectBlock) {
        
        Task { @MainActor in
            let configured = AgentforceModule.viewModel?.isConfigured ?? false
            resolve(configured)
        }
    }
    
    @MainActor
    private func presentConversationUI(viewModel: ServiceAgentViewModel) {
        guard let conversation = viewModel.conversation,
              let rootVC = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        let conversationView = ConversationView(
            conversation: conversation,
            onClose: {
                rootVC.dismiss(animated: true)
            }
        )
        
        let hostingController = UIHostingController(rootView: conversationView)
        hostingController.modalPresentationStyle = .fullScreen
        
        rootVC.present(hostingController, animated: true)
    }
}

/// SwiftUI view for displaying the conversation
struct ConversationView: View {
    let conversation: AgentforceConversation
    let onClose: () -> Void
    
    var body: some View {
        AgentforceConversationContainer(
            conversation: conversation,
            onClose: onClose
        )
    }
}

