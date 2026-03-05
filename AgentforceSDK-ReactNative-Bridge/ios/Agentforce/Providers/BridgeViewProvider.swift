/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Bridges the native AgentforceViewProviding protocol to React Native.
 * When enabled, delegates rendering of specified component types to a
 * registered React Native component via RCTRootView.
 */

import Foundation
import UIKit
import SwiftUI
import React
import AgentforceSDK

/// Implements AgentforceViewProviding by delegating to a React Native component.
/// Component types are registered synchronously from JS; rendering uses RCTRootView.
class BridgeViewProvider: AgentforceViewProviding {

    /// Maps component definition strings to React Native component names (1:1).
    /// e.g. ["copilot/richText": "CustomRichTextView", "copilot/markdown": "CustomMarkdownView"]
    private var componentMap: [String: String] = [:]

    /// Reference to the RCT bridge for creating root views
    private weak var bridge: RCTBridge?

    init(bridge: RCTBridge?) {
        self.bridge = bridge
    }

    /// Register a 1:1 mapping of component definition strings to React component names.
    /// Called from JS via the native module before launching conversation.
    func register(componentMap: [String: String]) {
        self.componentMap = componentMap
    }

    /// Clear all registrations
    func reset() {
        componentMap.removeAll()
    }

    var isRegistered: Bool {
        !componentMap.isEmpty
    }

    // MARK: - AgentforceViewProviding

    func canHandle(type: String) -> Bool {
        componentMap[type] != nil
    }

    @MainActor
    func view(for type: String, data: [String: Any]) -> AnyView {
        guard let moduleName = componentMap[type] else {
            return AnyView(EmptyView())
        }
        let props: [String: Any] = [
            "definition": type,
            "properties": data,
        ]
        return AnyView(ReactNativeViewWrapper(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: props
        ))
    }
}

// MARK: - SwiftUI wrapper for RCTRootView

/// Wraps an RCTRootView in a UIViewRepresentable for use in SwiftUI.
private struct ReactNativeViewWrapper: UIViewRepresentable {
    let bridge: RCTBridge?
    let moduleName: String
    let initialProperties: [String: Any]

    func makeUIView(context: Context) -> UIView {
        guard let bridge = bridge else {
            let label = UILabel()
            label.text = "Bridge unavailable"
            label.textAlignment = .center
            return label
        }
        let rootView = RCTRootView(
            bridge: bridge,
            moduleName: moduleName,
            initialProperties: initialProperties
        )
        rootView.backgroundColor = .clear
        return rootView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // RCTRootView handles its own updates via the bridge
    }
}
