import {
  DEFAULT_VOICE_CLOSE_BEHAVIOR,
  getVoiceCloseBehavior,
  setVoiceCloseBehavior,
  resetVoiceCloseBehavior,
} from '../VoiceCloseBehaviorStore';

beforeEach(() => {
  resetVoiceCloseBehavior();
});

describe('VoiceCloseBehaviorStore defaults', () => {
  it('defaults to returnToChat', () => {
    expect(DEFAULT_VOICE_CLOSE_BEHAVIOR).toBe('returnToChat');
    expect(getVoiceCloseBehavior()).toBe('returnToChat');
  });
});

describe('setVoiceCloseBehavior', () => {
  it('round-trips a value', () => {
    setVoiceCloseBehavior('dismissContainer');
    expect(getVoiceCloseBehavior()).toBe('dismissContainer');
  });
});

describe('resetVoiceCloseBehavior', () => {
  it('restores the default', () => {
    setVoiceCloseBehavior('dismissContainer');
    resetVoiceCloseBehavior();
    expect(getVoiceCloseBehavior()).toBe(DEFAULT_VOICE_CLOSE_BEHAVIOR);
  });
});
