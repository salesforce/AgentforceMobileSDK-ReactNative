/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for hidden prechat field delegate
 */

import Foundation
import AgentforceSDK
import AgentforceService

/// Bridge delegate that returns pre-registered hidden prechat field values
/// to the native Agentforce SDK during Service Agent session initialization.
///
/// JavaScript calls `registerHiddenPreChatFields({ key: value })` to store
/// field values. When the SDK calls the delegate, only values for fields the
/// SDK actually requests are returned; absent fields are omitted.
///
/// Must be strongly retained on the module because `AgentforceClient` holds
/// `hiddenPreChatFieldDelegate` as a weak reference.
class BridgeHiddenPreChat: NSObject, AgentforceHiddenPreChatFieldDelegate {

    // MARK: - Properties

    private let lock = NSLock()
    private var _fields: [String: String] = [:]

    // MARK: - Public API

    /// Replace the stored field values. Pass an empty dictionary to clear.
    func setFields(_ fields: [String: String]) {
        lock.withLock { _fields = fields }
    }

    /// Return a snapshot of the current field values.
    func getFields() -> [String: String] {
        lock.withLock { _fields }
    }

    // MARK: - AgentforceHiddenPreChatFieldDelegate

    func agentforce(
        didRequestHiddenPreChatValues requestedFields: [AgentforceHiddenPreChatField]
    ) async -> [String: String]? {
        let stored = lock.withLock { _fields }
        guard !stored.isEmpty else { return nil }

        var result: [String: String] = [:]
        for field in requestedFields {
            if let value = stored[field.name] {
                result[field.name] = value
            }
        }
        return result.isEmpty ? nil : result
    }
}
