/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */

import Foundation
import UIKit
import SwiftUI
@preconcurrency import AgentforceSDK
@preconcurrency import AgentforceService

/// Delegate that handles voice interactions for the Agentforce SDK
public class AgentforceVoiceDelegate: AgentforceUIDelegate {

    weak var agentforceClient: AgentforceClient?
    weak var presentingViewController: UIViewController?
    weak var module: AgentforceModule?

    private let forwardingLock = NSLock()
    private var _forwardingEnabled: Bool = false

    var forwardingEnabled: Bool {
        get { forwardingLock.withLock { _forwardingEnabled } }
        set { forwardingLock.withLock { _forwardingEnabled = newValue } }
    }

    init(agentforceClient: AgentforceClient?, presentingViewController: UIViewController?, module: AgentforceModule? = nil) {
        self.agentforceClient = agentforceClient
        self.presentingViewController = presentingViewController
        self.module = module
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
            guard let topViewController = self.getTopMostViewController() else {
                print("[AgentforceVoiceDelegate] ❌ Could not find a view controller to present voice UI")
                return
            }

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
    private func getTopMostViewController() -> UIViewController? {
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

        return topController
    }

    // MARK: - AgentforceUIDelegate forwarding methods

    public func modifyUtteranceBeforeSending(_ utterance: AgentforceUtterance) async -> AgentforceUtterance {
        guard forwardingEnabled, let module = module else { return utterance }

        let requestId = UUID().uuidString

        // awaitModifiedUtterance registers the continuation then emits the request internally
        let result = await module.awaitModifiedUtterance(
            requestId: requestId,
            utteranceText: utterance.utterance,
            timeout: 5.0
        )
        if let modifiedText = result {
            return AgentforceUtterance(utterance: modifiedText, attachment: utterance.attachment)
        }
        return utterance
    }

    public func didSendUtterance(_ utterance: AgentforceUtterance) {
        guard forwardingEnabled else { return }

        module?.emitUtteranceSentEvent([
            "utterance": utterance.utterance,
            "hasAttachment": utterance.attachment != nil,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    public func userDidSwitchAgents(newConversation: AgentConversation) {
        guard forwardingEnabled else { return }

        module?.emitAgentSwitchEvent([
            "conversationId": newConversation.conversationId.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }

    public func didReceiveResponse(_ message: AgentforceMessage, from conversation: AgentConversation) {
        guard forwardingEnabled else { return }

        // AgentforceSDK.AgentforceMessage does not yet expose `id` or `type`.
        // Generate a local responseId and derive type from isUserMessage until
        // the SDK surfaces those properties.
        let payload: [String: Any] = [
            "responseId": UUID().uuidString,
            "message": message.message ?? NSNull(),
            "type": message.isUserMessage ? "user" : "agent",
            "conversationId": conversation.conversationId.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        module?.emitAgentResponseEvent(payload)
    }
}
