//
//  BridgeLogger.swift
//  AgentforceSDK-ReactNative-Bridge
//
//  Created for React Native bridge logging integration
//

import Foundation
import SalesforceLogging

/// Bridge logger that forwards Agentforce SDK logs to React Native JavaScript
///
/// Implements the iOS Agentforce SDK's Logger protocol and emits log events
/// to the React Native event emitter. Forwarding can be enabled/disabled
/// to avoid bridge overhead when no JS delegate is registered.
class BridgeLogger: Logger {

    // MARK: - Properties

    /// Weak reference to the module to avoid retain cycles
    private weak var module: AgentforceModule?

    private let lock = NSLock()
    private var _forwardingEnabled: Bool = false

    /// Controls whether logs should be forwarded to JavaScript.
    /// Thread-safe: written on the JS thread, read on SDK callback threads.
    var forwardingEnabled: Bool {
        get { lock.withLock { _forwardingEnabled } }
        set { lock.withLock { _forwardingEnabled = newValue } }
    }

    // MARK: - Initialization

    init(module: AgentforceModule) {
        self.module = module
    }

    // MARK: - Logger Protocol Implementation

    /// Logs a message at the specified level
    /// Forwards to React Native if forwarding is enabled
    func log(_ logMessage: String, level: LogLevel) {
        guard forwardingEnabled else { return }

        // Map iOS LogLevel to TypeScript string literal
        let levelString: String
        switch level {
        case .error:
            levelString = "error"
        case .warning:
            levelString = "warn"
        case .info:
            levelString = "info"
        case .debug:
            levelString = "debug"
        @unknown default:
            levelString = "info"  // Fallback for future log levels
        }

        // Build event payload matching TypeScript LoggerDelegate interface
        let payload: [String: Any] = [
            "level": levelString,
            "message": logMessage
        ]

        // Emit to React Native (must be called from module with hasListeners check)
        module?.emitLogEvent(payload)
    }
}
