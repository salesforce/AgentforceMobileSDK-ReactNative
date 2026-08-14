import type { LaunchOptions } from '@salesforce/react-native-agentforce';

/**
 * Runtime-editable Voice close behavior for the Employee Agent, backing the
 * Settings segmented control. Mirrors the in-memory pattern of
 * VoiceTimeoutStore — state lives for the process lifetime, not across cold
 * starts.
 *
 * iOS-only: the native bridge ignores `voiceCloseBehavior` on Android, which
 * retains its existing Voice close behavior regardless of this setting.
 */
export type VoiceCloseBehavior = NonNullable<LaunchOptions['voiceCloseBehavior']>;

export const DEFAULT_VOICE_CLOSE_BEHAVIOR: VoiceCloseBehavior = 'returnToChat';

let voiceCloseBehavior: VoiceCloseBehavior = DEFAULT_VOICE_CLOSE_BEHAVIOR;

export function getVoiceCloseBehavior(): VoiceCloseBehavior {
  return voiceCloseBehavior;
}

export function setVoiceCloseBehavior(next: VoiceCloseBehavior): void {
  voiceCloseBehavior = next;
}

export function resetVoiceCloseBehavior(): void {
  voiceCloseBehavior = DEFAULT_VOICE_CLOSE_BEHAVIOR;
}
