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
import AgentforceSDK

/// Coordinates UI presentation and lifecycle for Agentforce chat views
class AgentforceUICoordinator {

    /// Currently presented chat view controller
    private var currentChatViewController: UIViewController?

    /// Agentforce UI delegate instance
    private var agentforceDelegate: AgentforceDelegate?

    /// Present the Agentforce chat view
    /// - Parameters:
    ///   - chatView: SwiftUI view containing the chat interface
    ///   - completion: Completion handler called after presentation
    func presentChatView<T: View>(_ chatView: T, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {

                let hostingController = UIHostingController(rootView: chatView)
                hostingController.modalPresentationStyle = .pageSheet

                self?.currentChatViewController = hostingController
                rootViewController.present(hostingController, animated: true) {
                    completion(nil)
                }
            } else {
                completion(NSError(domain: "AgentforceUICoordinator", code: 2, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"]))
            }
        }
    }

    /// Dismiss the currently presented chat view
    /// - Parameter completion: Completion handler called after dismissal
    func dismissChatView(completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let chatViewController = self?.currentChatViewController {
                chatViewController.dismiss(animated: true) {
                    self?.currentChatViewController = nil
                    self?.agentforceDelegate = nil
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    /// Create and return a new AgentforceDelegate instance
    /// - Returns: Configured AgentforceDelegate
    func createDelegate() -> AgentforceDelegate {
        let delegate = AgentforceDelegate()
        self.agentforceDelegate = delegate
        return delegate
    }
}

/// Delegate implementation for handling Agentforce UI events
class AgentforceDelegate: AgentforceUIDelegate {

    /// Called when the Agentforce UI has loaded successfully
    func agentforceUIDidLoad() {
        // UI loaded successfully
        print("Agentforce UI loaded successfully")
    }

    /// Called when the Agentforce UI encounters an error
    /// - Parameter error: The error that occurred
    func agentforceUIDidEncounterError(_ error: Error) {
        // Handle UI errors if needed
        print("Agentforce UI error: \(error.localizedDescription)")
    }
}