/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Bridges the native splash-screen delegate hook to React Native.
 * When a splash screen is registered for an agent, the SDK's request for a
 * splash view is satisfied by hosting a registered React Native component via
 * RCTRootView, and the user's chosen utterance is routed back into the SDK.
 */

import Foundation
import UIKit
import SwiftUI
import React
import AgentforceSDK

/// Backs `AgentforceService.setSplashScreenDelegate` on iOS.
///
/// Stores a 1:1 map of agent IDs to React Native component names (registered from
/// JS) and, when the SDK asks the UI delegate for a splash screen, builds an
/// `AnyView` that hosts the mapped component in an `RCTRootView`. It also retains
/// the SDK-supplied `AgentforceSplashScreenUtteranceDelegate` per agent so a later
/// `selectSplashScreenUtterance(agentId:utterance:)` call from JS can report the
/// chosen utterance back to the SDK.
final class BridgeSplashScreenProvider {

    /// Wildcard key matching any agent that has no explicit entry.
    private static let wildcardKey = "*"

    /// Maps agent IDs to React Native component names (1:1).
    /// e.g. ["0XxABC": "WelcomeSplash", "*": "DefaultSplash"]
    /// Protected by `lock` — read from the SDK rendering thread while
    /// `register`/`reset` are called from the JS thread.
    private var componentMap: [String: String] = [:]

    /// The most recent utterance delegate handed to us by the SDK, keyed by agent
    /// ID. Retained so `selectUtterance(agentId:utterance:)` can forward the user's
    /// choice into the conversation.
    private var utteranceDelegates: [String: AgentforceSplashScreenUtteranceDelegate] = [:]

    /// Protects all reads/writes to `componentMap` and `utteranceDelegates`.
    private let lock = NSLock()

    /// Reference to the RCT bridge for creating root views.
    private weak var bridge: RCTBridge?

    init(bridge: RCTBridge?) {
        self.bridge = bridge
    }

    /// Register a 1:1 mapping of agent IDs to React component names.
    /// Called from JS via the native module before launching a conversation.
    func register(componentMap: [String: String]) {
        lock.withLock { self.componentMap = componentMap }
    }

    /// Clear all registrations and any retained utterance delegates.
    func reset() {
        lock.withLock {
            componentMap.removeAll()
            utteranceDelegates.removeAll()
        }
    }

    var isRegistered: Bool {
        lock.withLock { !componentMap.isEmpty }
    }

    /// The React Native component name to show for `agentId`, or `nil` if none is
    /// registered (falling back to the wildcard entry when present).
    private func componentName(forAgent agentId: String) -> String? {
        lock.withLock { componentMap[agentId] ?? componentMap[Self.wildcardKey] }
    }

    /// Build the splash screen view for the SDK, or return `nil` when no component
    /// is registered for `agentId`.
    ///
    /// The `utteranceDelegate` is retained so a subsequent `selectUtterance` call
    /// can dismiss the splash and send the chosen utterance into the conversation.
    @MainActor
    func splashScreen(
        forAgent agentId: String,
        utteranceDelegate: AgentforceSplashScreenUtteranceDelegate
    ) -> AnyView? {
        guard let moduleName = componentName(forAgent: agentId) else {
            return nil
        }

        lock.withLock { utteranceDelegates[agentId] = utteranceDelegate }

        let props: [String: Any] = ["agentId": agentId]
        return AnyView(SplashReactNativeViewWrapper(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: props
        ))
    }

    /// Forward a user-chosen utterance from the React Native splash component into
    /// the SDK. Looks up the utterance delegate the SDK supplied for `agentId`.
    @MainActor
    func selectUtterance(agentId: String, utterance: String) {
        // Fall back to the sole registered delegate when the JS component reports
        // an empty/unknown agent ID (e.g. single-agent apps using the wildcard).
        let delegate: AgentforceSplashScreenUtteranceDelegate? = lock.withLock {
            utteranceDelegates[agentId]
                ?? (utteranceDelegates.count == 1 ? utteranceDelegates.values.first : nil)
        }
        delegate?.didChooseUtterance(utterance)
    }
}

// MARK: - SwiftUI wrapper for RCTRootView

/// Wraps an RCTRootView in a UIViewRepresentable so a React Native component can be
/// used as a SwiftUI splash screen. Fills the space the SDK gives it (the splash is
/// laid out in the conversation content region), rather than sizing to content.
private struct SplashReactNativeViewWrapper: UIViewRepresentable {
    let bridge: RCTBridge?
    let moduleName: String
    let initialProperties: [String: Any]

    func makeUIView(context: Context) -> UIView {
        guard let bridge = bridge else {
            assertionFailure("[BridgeSplashScreenProvider] RCT bridge is nil — cannot render React Native splash screen")
            return UIView()
        }
        let rootView = RCTRootView(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: initialProperties
        )
        rootView.backgroundColor = .clear
        // Fill the region the SDK lays the splash into (below the top bar, above the
        // input bar); the React component drives its own internal layout.
        rootView.sizeFlexibility = .none
        return rootView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // RCTRootView handles its own updates via the bridge.
    }
}
