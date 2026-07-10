/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

/**
 * Optional behavioral configuration for voice conversations.
 *
 * Pass via `AgentforceService.configure({ ..., voiceOptions: { ... } })`
 * to opt into per-session voice behaviors. All fields default to "off"
 * when omitted; supplying no `voiceOptions` preserves existing behavior.
 *
 * Voice options are immutable for the lifetime of a configured session.
 * Re-configure to change them; changes take effect on the next voice
 * session, not any session that is already active.
 */
export interface VoiceOptions {
  /**
   * Auto-end the voice conversation after this many seconds of continuous
   * user silence.
   *
   * `undefined` (default) disables auto-end — the conversation stays open
   * until the user closes it or the connection drops. Non-positive values
   * are treated as disabled.
   *
   * Units: seconds (matches the native iOS `TimeInterval` type).
   */
  userSilenceTimeoutSeconds?: number;
}
