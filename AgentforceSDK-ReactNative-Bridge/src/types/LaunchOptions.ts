/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

import type { AgentforceAdditionalContext } from './AgentforceContext';

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
