/**
 * Variable type for context variables (Android SDK types).
 *
 * Android: Use these exact strings (case-sensitive)
 * iOS: Type is just a label; value type is determined by the actual value
 */
export type CopilotContextVariableType =
  | 'Text'
  | 'Number'
  | 'Boolean'
  | 'Date'
  | 'DateTime'
  | 'Json'
  | 'List'
  | 'Money'
  | 'Object'
  | 'Ref'
  | 'Variable';

/**
 * Represents a single context variable for Agentforce.
 *
 * Compatible with both iOS (AgentforceVariable) and Android (CopilotContextVariable).
 *
 * **Type Mapping:**
 * - Text: string value
 * - Number: number value (double on iOS)
 * - Boolean: boolean value
 * - Date/DateTime: ISO date string
 * - Object: object/map value
 * - List: array value
 */
export interface CopilotContextVariable {
  /** Variable name/key */
  name: string;

  /**
   * Variable type (Android SDK type name)
   * Use: 'Text', 'Number', 'Boolean', 'Date', 'DateTime', 'Object', 'List', etc.
   */
  type: string;

  /** Optional description (Android only, ignored on iOS) */
  description?: string;

  /** Variable value (type must match the 'type' field) */
  value?: any;
}

/**
 * Additional context to pass to an Agentforce conversation.
 *
 * @example
 * ```typescript
 * const context: CopilotAdditionalContext = {
 *   variables: [
 *     { name: 'userId', type: 'Text', value: '005xx0000001234' },
 *     { name: 'accountId', type: 'Text', value: '001xx0000001234' },
 *     { name: 'priority', type: 'Text', value: 'high' },
 *     { name: 'score', type: 'Number', value: 95.5 },
 *     { name: 'isVIP', type: 'Boolean', value: true },
 *     { name: 'createdDate', type: 'DateTime', value: '2026-03-06T15:53:32.891Z' }
 *   ]
 * };
 *
 * await AgentforceService.launchConversation();
 * await AgentforceService.setAdditionalContext(context);
 * ```
 */
export interface CopilotAdditionalContext {
  /** Array of context variables */
  variables: CopilotContextVariable[];
}
