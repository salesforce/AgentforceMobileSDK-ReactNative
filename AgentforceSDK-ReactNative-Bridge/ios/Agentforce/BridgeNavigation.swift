/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge navigation for Agentforce SDK
 */

import Foundation
import SalesforceNavigation

/// Bridge navigation that forwards Agentforce SDK navigation requests to React Native JavaScript
///
/// Implements the iOS Agentforce SDK's Navigation protocol and emits navigation events
/// to the React Native event emitter. Forwarding can be enabled/disabled
/// to avoid bridge overhead when no JS delegate is registered.
class BridgeNavigation: Navigation {

    // MARK: - Properties

    /// Weak reference to the module to avoid retain cycles
    private weak var module: AgentforceModule?

    private let lock = NSLock()
    private var _forwardingEnabled: Bool = false

    /// Controls whether navigation requests should be forwarded to JavaScript.
    /// Thread-safe: written on the JS thread, read on SDK callback threads.
    var forwardingEnabled: Bool {
        get { lock.withLock { _forwardingEnabled } }
        set { lock.withLock { _forwardingEnabled = newValue } }
    }

    // MARK: - Initialization

    init(module: AgentforceModule) {
        self.module = module
    }

    // MARK: - Navigation Protocol Implementation

    func go(to destination: Destination) {
        go(to: destination, replace: false)
    }

    func go(to destination: Destination, replace: Bool) {
        guard forwardingEnabled else { return }
        emitDestination(destination, replace: replace)
    }

    // TODO: Implement open(app:) for parity with Android BridgeNavigation.openApp().
    // Currently returns .notOpen via the default extension because App is not in
    // SalesforceNavigation's public API. Android emits a "type":"app" event and
    // returns .OPEN optimistically.

    // MARK: - Destination Serialization

    private func emitDestination(_ destination: Destination, replace: Bool, depth: Int = 0) {
        var payload: [String: Any] = [:]

        switch destination {
        case let record as Record:
            payload["type"] = "record"
            payload["recordId"] = record.id
            if let objectType = record.type {
                payload["objectType"] = objectType
            }
            if let pageRef = serializePageReference(record.pageReference) {
                payload["pageReference"] = pageRef
            }

        case let link as Link:
            payload["type"] = "link"
            payload["uri"] = link.url.absoluteString
            if let pageRef = serializePageReference(link.pageReference) {
                payload["pageReference"] = pageRef
            }

        case let objectHome as ObjectHome:
            payload["type"] = "objectHome"
            payload["objectType"] = objectHome.type
            if let pageRef = serializePageReference(objectHome.pageReference) {
                payload["pageReference"] = pageRef
            }

        case let quickAction as QuickAction:
            payload["type"] = "quickAction"
            payload["actionName"] = quickAction.actionName
            if let target = quickAction.target {
                payload["recordId"] = target.id
                if let objectType = target.type {
                    payload["objectType"] = objectType
                }
            }

        case let pageRef as PageReferenceDestination:
            payload["type"] = "pageReference"
            if let serialized = serializePageReference(pageRef.pageReference) {
                payload["pageReference"] = serialized
            }

        default:
            // Unwrap wrapper types (e.g. OrgDestinationWrapper) via the
            // Destination.original protocol property. OrgDestinationWrapper
            // is internal to AgentforceSDK so we can't reference it directly.
            // Depth guard prevents infinite recursion if a non-wrapper
            // Destination returns self from .original instead of nil.
            if depth < 5, let inner = destination.original {
                emitDestination(inner, replace: replace, depth: depth + 1)
                return
            }
            payload["type"] = "unknown"
            payload["raw"] = String(describing: destination)
        }

        if replace {
            payload["replace"] = true
        }

        module?.emitNavigationEvent(payload)
    }

    // MARK: - PageReference Serialization

    /// Serializes a PageReference struct to a JSON string matching the format
    /// used by DestinationFactory.create(pageReference:).
    ///
    /// The Android SDK exposes pageReference as a pre-serialized String, but the
    /// iOS SDK exposes it as a PageReference struct (type, attributes, state).
    /// We serialize manually here to produce an equivalent JSON string.
    /// Note: JSONSerialization does not guarantee key ordering, so the output
    /// may differ from Android's. JS consumers should parse rather than compare
    /// as strings.
    private func serializePageReference(_ pageRef: PageReference) -> String? {
        var dict: [String: Any] = [
            "type": pageRef.type,
            "attributes": pageRef.attributes
        ]
        if let state = pageRef.state {
            dict["state"] = state
        }
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: data, encoding: .utf8) else {
            NSLog("[BridgeNavigation] Failed to serialize pageReference: %@", String(describing: dict))
            return nil
        }
        return jsonString
    }
}
