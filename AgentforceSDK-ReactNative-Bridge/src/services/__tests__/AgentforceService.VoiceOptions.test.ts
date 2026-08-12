/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

jest.mock('react-native', () => {
  const configureWithConfig = jest.fn().mockResolvedValue({ success: true, mode: 'service' });
  const configure = jest.fn().mockResolvedValue({ success: true, mode: 'service' });
  const getFeatureFlags = jest.fn().mockResolvedValue({
    enableMultiAgent: true,
    enableMultiModalInput: false,
    enablePDFUpload: false,
    enableVoice: false,
    enableCustomViewProvider: false,
  });

  return {
    Platform: { OS: 'ios' },
    NativeModules: {
      AgentforceModule: {
        configureWithConfig,
        configure,
        getFeatureFlags,
        addListener: jest.fn(),
        removeListeners: jest.fn(),
      },
    },
    NativeEventEmitter: jest.fn().mockImplementation(() => ({
      addListener: jest.fn(() => ({ remove: jest.fn() })),
    })),
  };
});

import { NativeModules } from 'react-native';
import AgentforceService from '../AgentforceService';
import type { ServiceAgentConfig } from '../../types/AgentConfig';

const nativeModule = NativeModules.AgentforceModule;

const baseServiceConfig: ServiceAgentConfig = {
  type: 'service',
  serviceApiURL: 'https://example.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'TestAgent',
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe('voiceOptions round-trip via configure()', () => {
  it('forwards userSilenceTimeoutSeconds to the iOS native module', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      voiceOptions: { userSilenceTimeoutSeconds: 30 },
    });

    expect(nativeModule.configureWithConfig).toHaveBeenCalledTimes(1);
    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toEqual({ userSilenceTimeoutSeconds: 30 });
  });

  it('omits voiceOptions when not provided', async () => {
    await AgentforceService.configure({ ...baseServiceConfig });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toBeUndefined();
  });

  it('passes through zero for native-side coercion to disabled', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      voiceOptions: { userSilenceTimeoutSeconds: 0 },
    });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toEqual({ userSilenceTimeoutSeconds: 0 });
  });

  it('passes voiceOptions alongside featureFlags without losing either', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      featureFlags: {
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: true,
        enableCustomViewProvider: false,
      },
      voiceOptions: { userSilenceTimeoutSeconds: 60 },
    });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toEqual({ userSilenceTimeoutSeconds: 60 });
    expect(payload.featureFlags.enableVoice).toBe(true);
  });

  it('forwards autoEndWhileMuted alongside the silence timeout', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      voiceOptions: { userSilenceTimeoutSeconds: 30, autoEndWhileMuted: true },
    });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toEqual({
      userSilenceTimeoutSeconds: 30,
      autoEndWhileMuted: true,
    });
  });

  it('forwards autoEndWhileMuted: false verbatim (does not drop the explicit opt-out)', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      voiceOptions: { userSilenceTimeoutSeconds: 30, autoEndWhileMuted: false },
    });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).toEqual({
      userSilenceTimeoutSeconds: 30,
      autoEndWhileMuted: false,
    });
  });

  it('omits autoEndWhileMuted when not provided (native default applies)', async () => {
    await AgentforceService.configure({
      ...baseServiceConfig,
      voiceOptions: { userSilenceTimeoutSeconds: 30 },
    });

    const payload = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(payload.voiceOptions).not.toHaveProperty('autoEndWhileMuted');
  });
});
