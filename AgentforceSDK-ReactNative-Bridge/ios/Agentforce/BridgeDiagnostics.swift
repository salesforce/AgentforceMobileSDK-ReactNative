/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * Central diagnostic logging for the React Native bridge.
 */

import Foundation
import os.log

/// Central diagnostic logging used by the bridge to surface OAuth, network, and
/// credential failures that the underlying SDK would otherwise hide behind generic
/// UI errors ("Something went wrong", "invalid client credentials").
///
/// Every call writes to the unified system log (visible in Console.app / Xcode) AND,
/// when a JS LoggerDelegate is registered, forwards the same message to JavaScript via
/// the `onLogMessage` channel the SDK logger already uses. This lets a customer capture
/// the diagnostics from JS without attaching a native debugger.
///
/// Secrets (access tokens, consumer keys) must be passed through `redact(_:)` before
/// logging — never log a full token or key.
enum BridgeDiagnostics {

    private static let log = OSLog(subsystem: "com.salesforce.reactagentforce", category: "bridge-diagnostics")

    private static let sinkLock = NSLock()
    /// Weak-held module used to forward diagnostics to JS. Set by AgentforceModule.
    private static weak var _sink: AgentforceModule?

    static func setSink(_ module: AgentforceModule?) {
        sinkLock.lock(); defer { sinkLock.unlock() }
        _sink = module
    }

    private static var sink: AgentforceModule? {
        sinkLock.lock(); defer { sinkLock.unlock() }
        return _sink
    }

    static func debug(_ tag: String, _ message: String) {
        emit(level: "debug", osType: .debug, tag: tag, message: message)
    }

    static func warn(_ tag: String, _ message: String) {
        emit(level: "warn", osType: .error, tag: tag, message: message)
    }

    static func error(_ tag: String, _ message: String) {
        emit(level: "error", osType: .error, tag: tag, message: message)
    }

    private static func emit(level: String, osType: OSLogType, tag: String, message: String) {
        os_log("%{public}@", log: log, type: osType, "[\(tag)] \(message)")
        sink?.emitLogEvent([
            "level": level,
            "message": "[\(tag)] \(message)"
        ])
    }

    /// Redact a secret for logging: keeps the first 6 and last 4 characters plus the
    /// length, so a truncated/mismatched consumer key is diagnosable without exposing
    /// the full credential. Short values are fully masked.
    static func redact(_ secret: String?) -> String {
        guard let secret = secret, !secret.isEmpty else { return "<empty>" }
        let len = secret.count
        if len <= 12 {
            return "<redacted len=\(len)>"
        }
        let prefix = secret.prefix(6)
        let suffix = secret.suffix(4)
        return "\(prefix)…\(suffix) (len=\(len))"
    }
}
