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

    /// Set of component definition strings this provider handles (e.g. "copilot/richText")
    private var registeredTypes: Set<String> = []

    /// The React Native component name to render for matching types
    private var reactComponentName: String = ""

    /// Reference to the RCT bridge for creating root views
    private weak var bridge: RCTBridge?

    init(bridge: RCTBridge?) {
        self.bridge = bridge
    }

    /// Register component types and the React component to render them.
    /// Called from JS via the native module before launching conversation.
    func register(componentTypes: [String], reactComponentName: String) {
        self.registeredTypes = Set(componentTypes)
        self.reactComponentName = reactComponentName
    }

    /// Clear all registrations
    func reset() {
        registeredTypes.removeAll()
        reactComponentName = ""
    }

    var isRegistered: Bool {
        !registeredTypes.isEmpty && !reactComponentName.isEmpty
    }

    // MARK: - AgentforceViewProviding

    func canHandle(type: String) -> Bool {
        registeredTypes.contains(type)
    }

    @MainActor
    func view(for type: String, data: [String: Any]) -> AnyView {
        let props: [String: Any] = [
            "definition": type,
            "properties": data,
        ]
        return AnyView(ReactNativeViewWrapper(
            bridge: bridge,
            moduleName: reactComponentName,
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
