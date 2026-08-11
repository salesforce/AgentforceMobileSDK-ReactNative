/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

/**
 * Optional parameters for launching Agentforce conversation.
 *
 * Pass via `AgentforceService.launchConversation({ initialMode: 'voiceOnly' })`
 * to control how the conversation opens.
 */
export interface LaunchOptions {
  /**
   * Initial conversation mode.
   *
   * - `'chat'` (default) opens the conversation in Chat (text) mode.
   * - `'voice'` opens directly in Voice mode. On iOS this is the combined
   *   voice + text experience (the chat view launched in Voice, where the
   *   user can still switch to text). On Android it opens the dedicated
   *   Voice view.
   * - `'voiceOnly'` opens the dedicated Voice-only view with no text /
   *   interaction content — iOS `AgentforceVoiceView`, Android
   *   `AgentforceVoiceContainer`.
   *
   * Both `'voice'` and `'voiceOnly'` require `enableVoice: true` in feature
   * flags. When Voice is disabled or unavailable, launch fails with an error.
   *
   * @default 'chat'
   */
  initialMode?: 'chat' | 'voice' | 'voiceOnly';
}
