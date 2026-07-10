/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge UI delegate for Agentforce SDK
 */

import Foundation
import SwiftUI
import AgentforceSDK
import AgentforceService

/// Bridge UI delegate that forwards Agentforce SDK UI events to React Native JavaScript
///
/// Implements the iOS Agentforce SDK's AgentforceUIDelegate protocol and emits events
/// to the React Native event emitter. Forwarding can be enabled/disabled
/// to avoid bridge overhead when no JS delegate is registered.
///
/// The `modifyUtteranceBeforeSending` method emits a request to JS and waits
/// (with a timeout) for JS to respond via `awaitModifiedUtterance` on the module.
class BridgeUIDelegate: AgentforceUIDelegate {

    // MARK: - Properties

    /// Weak reference to the module to avoid retain cycles
    weak var module: AgentforceModule?

    /// Splash screen provider that hosts a React Native welcome screen. Held
    /// strongly: the module owns this delegate, and the provider owns no reference
    /// back to it, so there is no retain cycle.
    private let splashScreenProvider: BridgeSplashScreenProvider

    private let lock = NSLock()
    private var _forwardingEnabled: Bool = false

    /// Controls whether UI delegate events should be forwarded to JavaScript.
    /// Thread-safe: written on the JS thread, read on SDK callback threads.
    var forwardingEnabled: Bool {
        get { lock.withLock { _forwardingEnabled } }
        set { lock.withLock { _forwardingEnabled = newValue } }
    }

    /// Timeout for awaiting a modified utterance from JavaScript (seconds).
    /// If JS does not respond within this window, the original utterance is returned.
    var modifyUtteranceTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    init(module: AgentforceModule, splashScreenProvider: BridgeSplashScreenProvider) {
        self.module = module
        self.splashScreenProvider = splashScreenProvider
    }

    // MARK: - AgentforceUIDelegate Protocol Implementation

    func modifyUtteranceBeforeSending(_ utterance: AgentforceUtterance) async -> AgentforceUtterance {
        guard forwardingEnabled, let module = module else {
            return utterance
        }

        let requestId = UUID().uuidString

        // Ask JS to modify the utterance; the module handles the continuation/timeout internally.
        let modifiedText = await module.awaitModifiedUtterance(
            requestId: requestId,
            utteranceText: utterance.utterance,
            timeout: modifyUtteranceTimeout
        )

        if let modifiedText = modifiedText {
            return AgentforceUtterance(utterance: modifiedText, attachment: utterance.attachment)
        }

        return utterance
    }

    func didSendUtterance(_ utterance: AgentforceUtterance) {
        guard forwardingEnabled else { return }

        let payload: [String: Any] = [
            "utterance": utterance.utterance,
            "hasAttachment": utterance.attachment != nil,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        module?.emitUtteranceSentEvent(payload)
    }

    func userDidSwitchAgents(newConversation: any AgentConversation) {
        guard forwardingEnabled else { return }

        let payload: [String: Any] = [
            "conversationId": newConversation.conversationId.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        module?.emitAgentSwitchEvent(payload)
    }

    func userInitiatedVoice(for conversation: any AgentConversation) {
        // Voice is managed internally in 260.5 - no forwarding needed.
    }

    func didReceiveResponse(_ message: AgentforceMessage, from conversation: any AgentConversation) {
        guard forwardingEnabled, message.state == .finished else { return }

        // AgentforceSDK.AgentforceMessage does not yet expose `id` or `type`.
        // Generate a local responseId and derive type from isUserMessage until
        // the SDK surfaces those properties.
        let payload: [String: Any] = [
            "responseId": UUID().uuidString,
            "message": message.message ?? NSNull(),
            "type": message.isUserMessage ? "user" : "agent",
            "conversationId": conversation.conversationId.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        module?.emitAgentResponseEvent(payload)
    }

    // Splash screen is not gated by `forwardingEnabled`: it renders a registered
    // React Native component (independent of the JS event stream), and the provider
    // returns nil when no component is registered for the agent.
    @MainActor
    func splashScreen(
        forAgent agentId: String,
        utteranceDelegate: AgentforceSplashScreenUtteranceDelegate
    ) -> AnyView? {
        splashScreenProvider.splashScreen(forAgent: agentId, utteranceDelegate: utteranceDelegate)
    }
}
