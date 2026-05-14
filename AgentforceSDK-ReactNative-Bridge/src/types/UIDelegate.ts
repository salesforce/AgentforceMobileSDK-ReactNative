/**
 * UI Delegate types for Agentforce SDK
 *
 * Allows JS to receive UI delegate events from the native Agentforce SDK:
 * - Agent responses (complete, non-streaming)
 * - Utterance sent notifications
 * - Agent switch notifications
 * - Utterance modification before sending (async request/response)
 */

export interface AgentResponseEvent {
  /** Unique message identifier */
  responseId: string;
  /** The agent's response text (may be null for non-text responses) */
  message: string | null;
  /** Message type classification */
  type: string;
  /** Conversation that produced this response (UUID string) */
  conversationId: string;
  /** ISO 8601 timestamp */
  timestamp?: string;
}

export interface UtteranceSentEvent {
  /** The utterance text that was sent */
  utterance: string;
  /** Whether the utterance had an attachment */
  hasAttachment: boolean;
  /** ISO 8601 timestamp */
  timestamp: string;
}

export interface AgentSwitchEvent {
  /** Identifier of the new conversation after the switch */
  conversationId: string;
  /** ISO 8601 timestamp */
  timestamp: string;
}

export interface ModifyUtteranceRequest {
  /** Unique request ID — pass back in the return value */
  requestId: string;
  /** The original utterance text before modification */
  utterance: string;
}

/**
 * Delegate interface for receiving UI delegate events from the Agentforce SDK.
 *
 * Register using `AgentforceService.setUIDelegate()` before or after launching a conversation.
 * All callbacks are optional except `onAgentResponse`.
 *
 * @example
 * ```typescript
 * AgentforceService.setUIDelegate({
 *   onAgentResponse(event) {
 *     console.log(`Agent said: ${event.message}`);
 *   },
 *   onUtteranceSent(event) {
 *     console.log(`User sent: ${event.utterance}`);
 *   },
 *   onAgentSwitch(event) {
 *     console.log(`Switched to conversation: ${event.conversationId}`);
 *   },
 *   modifyUtterance(request) {
 *     return request.utterance.toUpperCase(); // modify the text
 *   },
 * });
 * ```
 */
export interface UIDelegate {
  onAgentResponse(event: AgentResponseEvent): void;
  onUtteranceSent?(event: UtteranceSentEvent): void;
  onAgentSwitch?(event: AgentSwitchEvent): void;
  /** Return the modified utterance text, or the original to leave unchanged. */
  modifyUtterance?(request: ModifyUtteranceRequest): string | Promise<string>;
}
