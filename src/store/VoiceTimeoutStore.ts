import type { VoiceOptions } from '@salesforce/react-native-agentforce';

import { EMPLOYEE_VOICE_OPTIONS } from '../config/AppConfig';

/**
 * Runtime-editable voice auto-end (silence timeout) settings for the Employee
 * Agent, backing the Settings toggle. Mirrors the in-memory pattern of
 * ContextVariablesStore — state lives for the process lifetime, not across
 * cold starts.
 *
 * `enabled` maps to the native `.afterUserSilence` vs `.never` auto-end policy:
 * disabling omits the timeout from the derived VoiceOptions so the bridge treats
 * it as "never auto-end".
 */
export interface VoiceTimeoutSettings {
  enabled: boolean;
  userSilenceTimeoutSeconds: number;
  autoEndWhileMuted: boolean;
}

// Auto-end on silence is opt-in: default the toggle off, but pre-seed the
// timeout and muted values from EMPLOYEE_VOICE_OPTIONS so enabling it starts
// from sensible defaults rather than an empty field.
export const DEFAULT_VOICE_TIMEOUT_SETTINGS: VoiceTimeoutSettings = {
  enabled: false,
  userSilenceTimeoutSeconds: EMPLOYEE_VOICE_OPTIONS.userSilenceTimeoutSeconds ?? 30,
  autoEndWhileMuted: EMPLOYEE_VOICE_OPTIONS.autoEndWhileMuted ?? false,
};

let settings: VoiceTimeoutSettings = { ...DEFAULT_VOICE_TIMEOUT_SETTINGS };

export function getVoiceTimeoutSettings(): VoiceTimeoutSettings {
  return { ...settings };
}

export function setVoiceTimeoutSettings(next: VoiceTimeoutSettings): void {
  settings = { ...next };
}

export function resetVoiceTimeoutSettings(): void {
  settings = { ...DEFAULT_VOICE_TIMEOUT_SETTINGS };
}

/**
 * Derive the bridge `VoiceOptions` from the current settings. Pass the result as
 * `voiceOptions` on the Employee Agent `configure()` call.
 *
 * When disabled, `userSilenceTimeoutSeconds` is omitted so the native layer maps
 * it to "never auto-end"; `autoEndWhileMuted` is always forwarded.
 */
export function getVoiceOptions(): VoiceOptions {
  if (!settings.enabled) {
    return { autoEndWhileMuted: settings.autoEndWhileMuted };
  }
  return {
    userSilenceTimeoutSeconds: settings.userSilenceTimeoutSeconds,
    autoEndWhileMuted: settings.autoEndWhileMuted,
  };
}
