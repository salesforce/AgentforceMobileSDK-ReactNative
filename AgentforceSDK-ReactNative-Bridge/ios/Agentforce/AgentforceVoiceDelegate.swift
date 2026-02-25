/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */

import Foundation
import UIKit
import SwiftUI
import AgentforceSDK
import AgentforceService

/// Delegate that handles voice interactions for the Agentforce SDK
public class AgentforceVoiceDelegate: AgentforceUIDelegate {

    weak var agentforceClient: AgentforceClient?
    weak var presentingViewController: UIViewController?

    public init(agentforceClient: AgentforceClient?, presentingViewController: UIViewController?) {
        self.agentforceClient = agentforceClient
        self.presentingViewController = presentingViewController
    }

    /// Called when the user taps the voice button in the chat UI
    public func userInitiatedVoice(for conversation: AgentConversation) {
        guard let client = agentforceClient else {
            print("[AgentforceVoiceDelegate] ❌ No agentforceClient available")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Get the topmost presented view controller to present voice UI on top
            let topViewController = self.getTopMostViewController()

            guard let voiceView = try? client.createAgentforceVoiceView(
                conversation: conversation,
                circleSizeRatio: 0.4,
                onContainerClose: { [weak topViewController] in
                    DispatchQueue.main.async {
                        if let presented = topViewController?.presentedViewController {
                            presented.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            ) else {
                print("[AgentforceVoiceDelegate] ❌ Failed to create AgentforceVoiceView")
                return
            }

            let voiceViewController = UIHostingController(rootView: voiceView)
            voiceViewController.modalPresentationStyle = .fullScreen

            topViewController.present(voiceViewController, animated: true, completion: nil)
            print("[AgentforceVoiceDelegate] ✅ Presented voice view")
        }
    }

    /// Get the topmost presented view controller in the view hierarchy
    private func getTopMostViewController() -> UIViewController {
        var topController = presentingViewController

        // If no presenting view controller was set, start from the root
        if topController == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                topController = window.rootViewController
            }
        }

        // Traverse to find the topmost presented view controller
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }

        return topController ?? UIViewController()
    }

    // MARK: - Optional AgentforceUIDelegate methods (default implementations)

    public func modifyUtteranceBeforeSending(_ utterance: AgentforceUtterance) async -> AgentforceUtterance {
        return utterance
    }

    public func didSendUtterance(_ utterance: AgentforceUtterance) {
        // No-op
    }

    public func userDidSwitchAgents(newConversation: AgentConversation) {
        // No-op
    }
}
