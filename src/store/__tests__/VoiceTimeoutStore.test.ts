import { EMPLOYEE_VOICE_OPTIONS } from '../../config/AppConfig';
import {
  DEFAULT_VOICE_TIMEOUT_SETTINGS,
  getVoiceTimeoutSettings,
  setVoiceTimeoutSettings,
  resetVoiceTimeoutSettings,
  getVoiceOptions,
} from '../VoiceTimeoutStore';

beforeEach(() => {
  resetVoiceTimeoutSettings();
});

describe('VoiceTimeoutStore defaults', () => {
  it('defaults auto-end-on-silence to off, pre-seeding the timeout value', () => {
    expect(DEFAULT_VOICE_TIMEOUT_SETTINGS).toEqual({
      enabled: false,
      userSilenceTimeoutSeconds: EMPLOYEE_VOICE_OPTIONS.userSilenceTimeoutSeconds ?? 30,
      autoEndWhileMuted: EMPLOYEE_VOICE_OPTIONS.autoEndWhileMuted ?? false,
      defaultClosedCaptionsEnabled: EMPLOYEE_VOICE_OPTIONS.defaultClosedCaptionsEnabled ?? false,
    });
  });

  it('returns the defaults initially', () => {
    expect(getVoiceTimeoutSettings()).toEqual(DEFAULT_VOICE_TIMEOUT_SETTINGS);
  });
});

describe('getVoiceOptions', () => {
  it('includes the timeout when enabled', () => {
    setVoiceTimeoutSettings({
      enabled: true,
      userSilenceTimeoutSeconds: 45,
      autoEndWhileMuted: true,
      defaultClosedCaptionsEnabled: false,
    });

    expect(getVoiceOptions()).toEqual({
      userSilenceTimeoutSeconds: 45,
      autoEndWhileMuted: true,
      defaultClosedCaptionsEnabled: false,
    });
  });

  it('omits the timeout when disabled but keeps autoEndWhileMuted and defaultClosedCaptionsEnabled', () => {
    setVoiceTimeoutSettings({
      enabled: false,
      userSilenceTimeoutSeconds: 45,
      autoEndWhileMuted: true,
      defaultClosedCaptionsEnabled: true,
    });

    const options = getVoiceOptions();
    expect(options.userSilenceTimeoutSeconds).toBeUndefined();
    expect(options.autoEndWhileMuted).toBe(true);
    expect(options.defaultClosedCaptionsEnabled).toBe(true);
  });
});

describe('setVoiceTimeoutSettings', () => {
  it('round-trips a settings object', () => {
    const next = {
      enabled: false,
      userSilenceTimeoutSeconds: 10,
      autoEndWhileMuted: false,
      defaultClosedCaptionsEnabled: false,
    };
    setVoiceTimeoutSettings(next);
    expect(getVoiceTimeoutSettings()).toEqual(next);
  });

  it('returns a copy, not a reference to internal state', () => {
    const result = getVoiceTimeoutSettings();
    result.userSilenceTimeoutSeconds = 999;
    expect(getVoiceTimeoutSettings().userSilenceTimeoutSeconds).not.toBe(999);
  });

  it('does not retain a reference to the input object', () => {
    const input = {
      enabled: true,
      userSilenceTimeoutSeconds: 20,
      autoEndWhileMuted: false,
      defaultClosedCaptionsEnabled: false,
    };
    setVoiceTimeoutSettings(input);
    input.userSilenceTimeoutSeconds = 999;
    expect(getVoiceTimeoutSettings().userSilenceTimeoutSeconds).toBe(20);
  });
});

describe('resetVoiceTimeoutSettings', () => {
  it('restores the defaults', () => {
    setVoiceTimeoutSettings({
      enabled: false,
      userSilenceTimeoutSeconds: 5,
      autoEndWhileMuted: true,
      defaultClosedCaptionsEnabled: true,
    });
    resetVoiceTimeoutSettings();
    expect(getVoiceTimeoutSettings()).toEqual(DEFAULT_VOICE_TIMEOUT_SETTINGS);
  });
});
