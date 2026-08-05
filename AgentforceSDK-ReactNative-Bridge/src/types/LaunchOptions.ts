/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

/**
 * Optional parameters for launching Agentforce conversation.
 *
 * Pass via `AgentforceService.launchConversation({ initialMode: 'voice' })`
 * to control how the conversation opens.
 */
export interface LaunchOptions {
  /**
   * Initial conversation mode.
   *
   * - `'chat'` (default) opens the conversation in Chat mode
   * - `'voice'` opens directly in Voice mode when Voice is enabled
   *
   * Voice launch requires `enableVoice: true` in feature flags.
   * When Voice is disabled or unavailable, launch fails with error.
   *
   * @default 'chat'
   */
  initialMode?: 'chat' | 'voice';
}
