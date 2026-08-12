jest.mock('react-native', () => {
  const registerSplashScreenProvider = jest.fn().mockResolvedValue({
    success: true,
    registeredAgents: [],
  });
  const clearSplashScreenProvider = jest.fn().mockResolvedValue({ success: true });
  const selectSplashScreenUtterance = jest.fn();
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
        registerSplashScreenProvider,
        clearSplashScreenProvider,
        selectSplashScreenUtterance,
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
import type { SplashScreenDelegate } from '../../types/SplashScreenDelegate';

const nativeModule = NativeModules.AgentforceModule;

beforeEach(() => {
  jest.clearAllMocks();
});

describe('SplashScreen delegate', () => {
  it('registers the component map with the native module', async () => {
    const delegate: SplashScreenDelegate = {
      componentMap: {
        '0XxABC0000001234': 'WelcomeSplash',
        '*': 'DefaultSplash',
      },
    };

    await AgentforceService.setSplashScreenDelegate(delegate);

    expect(nativeModule.registerSplashScreenProvider).toHaveBeenCalledWith({
      componentMap: delegate.componentMap,
    });
  });

  it('clears the splash screen registration on the native module', async () => {
    await AgentforceService.setSplashScreenDelegate({
      componentMap: { agent: 'Splash' },
    });

    await AgentforceService.clearSplashScreenDelegate();

    expect(nativeModule.clearSplashScreenProvider).toHaveBeenCalled();
  });

  it('forwards a chosen utterance to the native module', () => {
    AgentforceService.selectSplashScreenUtterance('0XxABC0000001234', 'Track my order');

    expect(nativeModule.selectSplashScreenUtterance).toHaveBeenCalledWith(
      '0XxABC0000001234',
      'Track my order',
    );
  });

  it('coerces null agentId/utterance to empty strings', () => {
    // @ts-expect-error exercising the runtime null-guard
    AgentforceService.selectSplashScreenUtterance(null, null);

    expect(nativeModule.selectSplashScreenUtterance).toHaveBeenCalledWith('', '');
  });

  it('propagates native registration errors', async () => {
    (nativeModule.registerSplashScreenProvider as jest.Mock).mockRejectedValueOnce(
      new Error('boom'),
    );

    await expect(
      AgentforceService.setSplashScreenDelegate({ componentMap: { a: 'B' } }),
    ).rejects.toThrow('boom');
  });
});
