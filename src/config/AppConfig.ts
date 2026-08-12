/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * App Configuration
 *
 * Controls app behavior and UI feature visibility.
 * See src/config/README.md for detailed documentation.
 */

import type { VoiceOptions } from '@salesforce/react-native-agentforce';

import { APP_MODE } from './AppConfig.generated';

// Widen the type for comparison - APP_MODE can be 'service', 'employee', or 'all'
const appMode: 'service' | 'employee' | 'all' = APP_MODE as any;

/**
 * Example voice-session options for the Employee Agent.
 *
 * Auto-ends a voice conversation after `userSilenceTimeoutSeconds` seconds of
 * continuous user silence. Pass this as `voiceOptions` on the config object —
 * it must be a top-level sibling of `type`, not nested inside `featureFlags`.
 * The native bridge only reads `config.voiceOptions`; anywhere else is ignored.
 *
 * Voice options are applied when the voice session's client is created. The
 * native bridge tracks the last-applied options and rebuilds the client when
 * they change, so an edit takes effect on the next `configure()` (e.g. the next
 * launch from Home) — at the cost of ending the active conversation. A
 * reconfigure with unchanged options reuses the existing client.
 *
 * `autoEndWhileMuted: false` (the default) pauses the silence timer while the
 * mic is muted, so a muted user is never auto-ended. Set `true` to count muted
 * time as silence.
 */
export const EMPLOYEE_VOICE_OPTIONS: VoiceOptions = {
  userSilenceTimeoutSeconds: 30,
  autoEndWhileMuted: false,
};
// These values seed the runtime-editable VoiceTimeoutStore (Settings > Employee
// > Voice Timeout). configure() sends the store's current values, not this
// constant directly. Note: the store defaults auto-end-on-silence *off* and uses
// these only as the pre-filled values when the user enables the toggle.

/**
 * Feature flags derived from APP_MODE
 */
export const FEATURES = {
  SHOW_SERVICE_AGENT: appMode === 'all' || appMode === 'service',
  SHOW_EMPLOYEE_AGENT: appMode === 'all' || appMode === 'employee',
};

/**
 * UI feature flags for conditional rendering
 */
export const UI_FEATURES = {
  SHOW_SERVICE_AGENT: FEATURES.SHOW_SERVICE_AGENT,
  SHOW_EMPLOYEE_AGENT: FEATURES.SHOW_EMPLOYEE_AGENT,
} as const;
