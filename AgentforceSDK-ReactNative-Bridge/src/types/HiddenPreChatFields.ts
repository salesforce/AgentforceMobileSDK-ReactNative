/**
 * Hidden prechat field values for Service Agent conversations.
 *
 * Maps field developer names to their string values. These values are
 * submitted with the prechat form but are not visible to the end user.
 *
 * @remarks Service Agent only. Has no effect for Employee Agent conversations.
 *
 * @example
 * ```typescript
 * const fields: HiddenPreChatFields = {
 *   ContactId: '003xx0000001234',
 *   AccountId: '001xx0000005678',
 *   Subject: 'Mobile App Support',
 * };
 * ```
 */
export type HiddenPreChatFields = Record<string, string>;
