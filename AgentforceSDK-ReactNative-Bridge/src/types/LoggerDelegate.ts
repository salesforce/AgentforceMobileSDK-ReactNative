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
 * Maps to the native Logger interface methods: e() → error, w() → warn, i() → info.
 */
export type LogLevel = 'error' | 'warn' | 'info';

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
   * @param level - The log level: 'error', 'warn', or 'info'
   * @param message - The log message from the SDK
   * @param error - Optional stringified exception (only present for error/warn with exceptions)
   */
  onLog(level: LogLevel, message: string, error?: string): void;
}
