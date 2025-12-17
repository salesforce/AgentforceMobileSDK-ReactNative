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

