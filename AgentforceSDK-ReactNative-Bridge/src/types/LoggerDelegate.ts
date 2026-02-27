/**
 * Logger Delegate Interface
 *
 * Defines the contract for receiving log messages from the native Agentforce SDK.
 * Consuming apps implement this interface to handle SDK logs in JavaScript
 * (e.g., forward to a custom analytics service, display in a debug console, etc.).
 *
 * Works for both Service Agent and Employee Agent modes.
 */

/**
 * Log levels emitted by the Agentforce SDK.
 * Android emits: error, warn, info. iOS additionally emits: debug.
 */
export type LogLevel = 'error' | 'warn' | 'info' | 'debug';

/**
 * Delegate interface for receiving log messages from the Agentforce SDK.
 *
 * Register using `AgentforceService.setLoggerDelegate()` before calling `configure()`.
 *
 * @example
 * ```typescript
 * const myLogger: LoggerDelegate = {
 *   onLog(level, message, error) {
 *     const prefix = `[Agentforce ${level.toUpperCase()}]`;
 *     if (error) {
 *       console.log(`${prefix} ${message} | ${error}`);
 *     } else {
 *       console.log(`${prefix} ${message}`);
 *     }
 *   },
 * };
 *
 * AgentforceService.setLoggerDelegate(myLogger);
 * ```
 */
export interface LoggerDelegate {
  /**
   * Called when the Agentforce SDK emits a log message.
   *
   * @param level - The log level: 'error', 'warn', 'info', or 'debug' (iOS only)
   * @param message - The log message from the SDK
   * @param error - Optional stringified exception (only present for error/warn with exceptions)
   */
  onLog(level: LogLevel, message: string, error?: string): void;
}
