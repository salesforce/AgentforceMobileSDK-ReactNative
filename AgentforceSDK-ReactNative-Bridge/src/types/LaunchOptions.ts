/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

import type { AgentforceAdditionalContext } from './AgentforceContext';

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

  /**
   * Behavior when a user closes the Voice UI.
   *
   * - `'returnToChat'` (default) returns to the chat transcript.
   * - `'dismissContainer'` dismisses the entire native Agentforce UI.
   *
   * This is currently supported on iOS only. Android retains its existing
   * Voice close behavior.
   *
   * @default 'returnToChat'
   */
  voiceCloseBehavior?: 'returnToChat' | 'dismissContainer';

  /**
   * Context to apply before the native conversation UI is shown.
   *
   * Use this when the initial agent response needs the context. Call
   * `setAdditionalContext()` to update context after launch.
   */
  additionalContext?: AgentforceAdditionalContext;
}
