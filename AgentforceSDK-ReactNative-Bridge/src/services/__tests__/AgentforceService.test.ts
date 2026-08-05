/**
 * Tests for AgentforceService.
 *
 * react-native is mocked so the singleton can be exercised on the JVM-less
 * jest environment. The mock captures event-emitter listeners in a registry
 * (`__emit`) so tests can drive native events through the delegate plumbing,
 * and exposes a mutable `Platform.OS` to exercise the platform guards.
 */
import type { AgentConfig, LegacyServiceAgentConfig } from '../../types/AgentConfig';
import type { AgentforceAdditionalContext } from '../../types/AgentforceContext';

jest.mock('react-native', () => {
  const listeners: Record<string, Array<(payload: unknown) => void>> = {};

  const AgentforceModule = {
    enableLogForwarding: jest.fn(),
    enableNavigationForwarding: jest.fn(),
    enableUIDelegateForwarding: jest.fn(),
    provideModifiedUtterance: jest.fn(),
    registerViewProvider: jest.fn().mockResolvedValue(undefined),
    clearViewProvider: jest.fn().mockResolvedValue(undefined),
    configure: jest.fn().mockResolvedValue({ success: true, mode: 'service' }),
    configureWithConfig: jest.fn().mockResolvedValue({ success: true, mode: 'service' }),
    getFeatureFlags: jest.fn(),
    setFeatureFlags: jest.fn().mockResolvedValue(undefined),
    getInternalFlags: jest.fn().mockResolvedValue({}),
    setInternalFlags: jest.fn().mockResolvedValue(undefined),
    launchConversation: jest.fn().mockResolvedValue({ success: true }),
    startNewConversation: jest.fn().mockResolvedValue({ success: true }),
    closeConversation: jest.fn().mockResolvedValue({ success: true }),
    dismissConversation: jest.fn().mockResolvedValue({ success: true }),
    sendUtterance: jest.fn().mockResolvedValue({ success: true }),
    isConfigured: jest.fn(),
    getConfiguration: jest.fn(),
    getConfigurationInfo: jest.fn(),
    getEmployeeAgentId: jest.fn(),
    setEmployeeAgentId: jest.fn().mockResolvedValue(undefined),
    setAdditionalContext: jest.fn().mockResolvedValue({ success: true }),
    registerHiddenPreChatFields: jest.fn().mockResolvedValue(undefined),
    getHiddenPreChatFields: jest.fn(),
    resetSettings: jest.fn().mockResolvedValue({ success: true }),
  };

  class NativeEventEmitter {
    addListener(event: string, cb: (payload: unknown) => void) {
      (listeners[event] = listeners[event] || []).push(cb);
      return {
        remove: () => {
          listeners[event] = (listeners[event] || []).filter(c => c !== cb);
        },
      };
    }
  }

  return {
    NativeModules: { AgentforceModule },
    NativeEventEmitter,
    Platform: { OS: 'ios' },
    __listeners: listeners,
    __emit: (event: string, payload: unknown) =>
      (listeners[event] || []).slice().forEach(c => c(payload)),
  };
});

// Access the mocked module internals.
const RN = require('react-native');
const nativeModule = RN.NativeModules.AgentforceModule;
const emit = (event: string, payload?: unknown) => RN.__emit(event, payload);

// Import after the mock is registered.
import AgentforceService from '../AgentforceService';

const setPlatform = (os: string) => {
  RN.Platform.OS = os;
};

beforeEach(() => {
  jest.clearAllMocks();
  setPlatform('ios');
  jest.spyOn(console, 'log').mockImplementation(() => {});
  jest.spyOn(console, 'warn').mockImplementation(() => {});
  jest.spyOn(console, 'error').mockImplementation(() => {});
});

afterEach(() => {
  jest.restoreAllMocks();
});

const serviceConfig: AgentConfig = {
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  featureFlags: {
    enableMultiAgent: true,
    enableMultiModalInput: false,
    enablePDFUpload: false,
    enableVoice: false,
    enableCustomViewProvider: false,
  },
};

describe('AgentforceService.configure', () => {
  it('routes to configureWithConfig on iOS', async () => {
    setPlatform('ios');
    const result = await AgentforceService.configure(serviceConfig);
    expect(nativeModule.configureWithConfig).toHaveBeenCalledTimes(1);
    expect(nativeModule.configure).not.toHaveBeenCalled();
    expect(result).toBe(true);
  });

  it('routes to configure on Android', async () => {
    setPlatform('android');
    await AgentforceService.configure(serviceConfig);
    expect(nativeModule.configure).toHaveBeenCalledTimes(1);
    expect(nativeModule.configureWithConfig).not.toHaveBeenCalled();
  });

  it('returns false on unsupported platforms', async () => {
    setPlatform('web');
    const result = await AgentforceService.configure(serviceConfig);
    expect(result).toBe(false);
    expect(nativeModule.configure).not.toHaveBeenCalled();
    expect(nativeModule.configureWithConfig).not.toHaveBeenCalled();
  });

  it('normalizes a legacy config (no type field) into a service config', async () => {
    setPlatform('ios');
    const legacy: LegacyServiceAgentConfig = {
      serviceApiURL: 'https://service.salesforce.com',
      organizationId: '00Dxx0000001234',
      esDeveloperName: 'LegacyAgent',
    };
    await AgentforceService.configure(legacy);
    const passed = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(passed.type).toBe('service');
    expect(passed.esDeveloperName).toBe('LegacyAgent');
  });

  it('merges stored feature flags when the config omits them', async () => {
    setPlatform('ios');
    nativeModule.getFeatureFlags.mockResolvedValue({
      enableMultiAgent: false,
      enableVoice: true,
    });
    const withoutFlags = { ...(serviceConfig as any) };
    delete withoutFlags.featureFlags;
    await AgentforceService.configure(withoutFlags);
    const passed = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(passed.featureFlags).toEqual({
      enableMultiAgent: false,
      enableMultiModalInput: false,
      enablePDFUpload: false,
      enableVoice: true,
      enableCustomViewProvider: false,
    });
  });

  it('keeps provided feature flags without consulting native storage', async () => {
    setPlatform('ios');
    await AgentforceService.configure(serviceConfig);
    expect(nativeModule.getFeatureFlags).not.toHaveBeenCalled();
  });

  it('rethrows when the native module throws', async () => {
    setPlatform('ios');
    nativeModule.configureWithConfig.mockRejectedValueOnce(new Error('boom'));
    await expect(AgentforceService.configure(serviceConfig)).rejects.toThrow('boom');
  });
});

describe('AgentforceService.getFeatureFlags', () => {
  const defaults = {
    enableMultiAgent: true,
    enableMultiModalInput: false,
    enablePDFUpload: false,
    enableVoice: false,
    enableCustomViewProvider: false,
  };

  it('returns defaults on an unsupported platform', async () => {
    setPlatform('web');
    await expect(AgentforceService.getFeatureFlags()).resolves.toEqual(defaults);
  });

  it('returns defaults when the native call throws', async () => {
    setPlatform('ios');
    nativeModule.getFeatureFlags.mockRejectedValueOnce(new Error('nope'));
    await expect(AgentforceService.getFeatureFlags()).resolves.toEqual(defaults);
  });

  it('fills missing fields with their defaults', async () => {
    setPlatform('ios');
    nativeModule.getFeatureFlags.mockResolvedValueOnce({ enableVoice: true });
    await expect(AgentforceService.getFeatureFlags()).resolves.toEqual({
      ...defaults,
      enableVoice: true,
    });
  });
});

describe('AgentforceService.getInternalFlags', () => {
  it('returns an empty object on an unsupported platform', async () => {
    setPlatform('web');
    await expect(AgentforceService.getInternalFlags()).resolves.toEqual({});
    expect(nativeModule.getInternalFlags).not.toHaveBeenCalled();
  });

  it('returns an empty object when the native call throws', async () => {
    setPlatform('ios');
    nativeModule.getInternalFlags.mockRejectedValueOnce(new Error('nope'));
    await expect(AgentforceService.getInternalFlags()).resolves.toEqual({});
  });

  it('passes through only the boolean-valued flags that were set', async () => {
    setPlatform('ios');
    nativeModule.getInternalFlags.mockResolvedValueOnce({
      tokenStreaming: true,
      enableClosedCaptions: false,
      // non-boolean values are dropped defensively
      bogus: 'nope',
    });
    await expect(AgentforceService.getInternalFlags()).resolves.toEqual({
      tokenStreaming: true,
      enableClosedCaptions: false,
    });
  });

  it('returns an empty object when native returns a non-object', async () => {
    setPlatform('ios');
    nativeModule.getInternalFlags.mockResolvedValueOnce(null);
    await expect(AgentforceService.getInternalFlags()).resolves.toEqual({});
  });
});

describe('AgentforceService.setInternalFlags', () => {
  it('is a no-op on an unsupported platform', async () => {
    setPlatform('web');
    await AgentforceService.setInternalFlags({ tokenStreaming: true });
    expect(nativeModule.setInternalFlags).not.toHaveBeenCalled();
  });

  it('forwards flags to the native module', async () => {
    setPlatform('android');
    await AgentforceService.setInternalFlags({ enableMocking: true });
    expect(nativeModule.setInternalFlags).toHaveBeenCalledWith({ enableMocking: true });
  });

  it('swallows native errors', async () => {
    setPlatform('ios');
    nativeModule.setInternalFlags.mockRejectedValueOnce(new Error('boom'));
    await expect(AgentforceService.setInternalFlags({ citations: true })).resolves.toBeUndefined();
  });
});

describe('AgentforceService.configure internal-flags merge', () => {
  it('merges stored internal flags when the config omits them', async () => {
    setPlatform('ios');
    nativeModule.getInternalFlags.mockResolvedValueOnce({ tokenStreaming: true });
    const withoutFlags = { ...(serviceConfig as any) };
    await AgentforceService.configure(withoutFlags);
    const passed = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(passed.internalFlags).toEqual({ tokenStreaming: true });
  });

  it('does not attach internalFlags when nothing is stored', async () => {
    setPlatform('ios');
    nativeModule.getInternalFlags.mockResolvedValueOnce({});
    await AgentforceService.configure({ ...(serviceConfig as any) });
    const passed = nativeModule.configureWithConfig.mock.calls[0][0];
    expect('internalFlags' in passed).toBe(false);
  });

  it('keeps provided internal flags without consulting native storage', async () => {
    setPlatform('ios');
    await AgentforceService.configure({
      ...(serviceConfig as any),
      internalFlags: { citations: true },
    });
    expect(nativeModule.getInternalFlags).not.toHaveBeenCalled();
    const passed = nativeModule.configureWithConfig.mock.calls[0][0];
    expect(passed.internalFlags).toEqual({ citations: true });
  });
});

describe('AgentforceService logger delegate', () => {
  it('registers, forwards events, then stops after clear', () => {
    const onLog = jest.fn();
    AgentforceService.setLoggerDelegate({ onLog });
    expect(nativeModule.enableLogForwarding).toHaveBeenCalledWith(true);

    emit('onLogMessage', { level: 'error', message: 'bad', error: 'stack' });
    expect(onLog).toHaveBeenCalledWith('error', 'bad', 'stack');

    AgentforceService.clearLoggerDelegate();
    expect(nativeModule.enableLogForwarding).toHaveBeenLastCalledWith(false);

    onLog.mockClear();
    emit('onLogMessage', { level: 'info', message: 'after-clear' });
    expect(onLog).not.toHaveBeenCalled();
  });
});

describe('AgentforceService navigation delegate', () => {
  it('forwards navigation requests to the delegate', () => {
    const onNavigate = jest.fn();
    AgentforceService.setNavigationDelegate({ onNavigate });
    expect(nativeModule.enableNavigationForwarding).toHaveBeenCalledWith(true);

    emit('onNavigationRequest', { type: 'link', uri: 'https://x.test' });
    expect(onNavigate).toHaveBeenCalledWith({ type: 'link', uri: 'https://x.test' });

    AgentforceService.clearNavigationDelegate();
    expect(nativeModule.enableNavigationForwarding).toHaveBeenLastCalledWith(false);
  });
});

describe('AgentforceService UI delegate', () => {
  afterEach(() => {
    AgentforceService.clearUIDelegate();
  });

  it('forwards agent response, utterance, and switch events', () => {
    const onAgentResponse = jest.fn();
    const onUtteranceSent = jest.fn();
    const onAgentSwitch = jest.fn();
    AgentforceService.setUIDelegate({ onAgentResponse, onUtteranceSent, onAgentSwitch });
    expect(nativeModule.enableUIDelegateForwarding).toHaveBeenCalledWith(true);

    const response = {
      responseId: '1',
      message: 'hi',
      type: 'text',
      conversationId: 'c',
      sessionId: 'session-1',
    };
    emit('onAgentResponse', response);
    emit('onUtteranceSent', { utterance: 'hello', hasAttachment: false, timestamp: 't' });
    emit('onAgentSwitch', { conversationId: 'c2', timestamp: 't' });

    expect(onAgentResponse).toHaveBeenCalledWith(response);
    expect(onUtteranceSent).toHaveBeenCalledTimes(1);
    expect(onAgentSwitch).toHaveBeenCalledTimes(1);
  });

  it('echoes the original utterance when no modifyUtterance handler is set', async () => {
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn() });
    emit('onModifyUtteranceRequest', { requestId: 'r1', utterance: 'orig' });
    await Promise.resolve();
    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('r1', 'orig');
  });

  it('forwards the modified utterance from the handler', async () => {
    AgentforceService.setUIDelegate({
      onAgentResponse: jest.fn(),
      modifyUtterance: req => req.utterance.toUpperCase(),
    });
    emit('onModifyUtteranceRequest', { requestId: 'r2', utterance: 'orig' });
    await Promise.resolve();
    await Promise.resolve();
    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('r2', 'ORIG');
  });

  it('falls back to the original utterance when the handler throws', async () => {
    AgentforceService.setUIDelegate({
      onAgentResponse: jest.fn(),
      modifyUtterance: () => {
        throw new Error('handler failed');
      },
    });
    emit('onModifyUtteranceRequest', { requestId: 'r3', utterance: 'orig' });
    await Promise.resolve();
    await Promise.resolve();
    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('r3', 'orig');
  });
});

describe('AgentforceService.setAdditionalContext validation', () => {
  beforeEach(() => setPlatform('ios'));

  it('throws when variables is not an array', async () => {
    await expect(
      AgentforceService.setAdditionalContext({} as AgentforceAdditionalContext),
    ).rejects.toThrow(/variables/);
  });

  it('throws when a variable is missing a name', async () => {
    await expect(
      AgentforceService.setAdditionalContext({
        variables: [{ type: 'Text', value: 'x' } as any],
      }),
    ).rejects.toThrow(/name/);
  });

  it('throws on an unknown variable type', async () => {
    await expect(
      AgentforceService.setAdditionalContext({
        variables: [{ name: 'a', type: 'Bogus' as any, value: 'x' }],
      }),
    ).rejects.toThrow(/unknown type/);
  });

  it('forwards a valid context to the native module', async () => {
    const context: AgentforceAdditionalContext = {
      variables: [
        { name: 'userId', type: 'Text', value: '005' },
        { name: 'score', type: 'Number', value: 95.5 },
      ],
    };
    await expect(AgentforceService.setAdditionalContext(context)).resolves.toBe(true);
    expect(nativeModule.setAdditionalContext).toHaveBeenCalledWith(context);
  });
});

describe('AgentforceService passthrough + normalization', () => {
  beforeEach(() => setPlatform('ios'));

  it('launchConversation resolves the native success flag', async () => {
    await expect(AgentforceService.launchConversation()).resolves.toBe(true);
    expect(nativeModule.launchConversation).toHaveBeenCalled();
  });

  it('isConfigured handles a raw boolean return', async () => {
    nativeModule.isConfigured.mockResolvedValueOnce(true);
    await expect(AgentforceService.isConfigured()).resolves.toBe(true);
  });

  it('isConfigured handles an object return', async () => {
    nativeModule.isConfigured.mockResolvedValueOnce({ configured: true });
    await expect(AgentforceService.isConfigured()).resolves.toBe(true);
  });

  it('getConfiguration returns null when all fields are empty', async () => {
    nativeModule.getConfiguration.mockResolvedValueOnce({
      serviceApiURL: '',
      organizationId: '',
      esDeveloperName: '',
    });
    await expect(AgentforceService.getConfiguration()).resolves.toBeNull();
  });

  it('getConfiguration returns a typed service config when populated', async () => {
    nativeModule.getConfiguration.mockResolvedValueOnce({
      serviceApiURL: 'https://x',
      organizationId: '00D',
      esDeveloperName: 'Agent',
    });
    const config = await AgentforceService.getConfiguration();
    expect(config).toMatchObject({ type: 'service', esDeveloperName: 'Agent' });
  });

  it('getConfigurationInfo falls back to isConfigured when the new method is absent', async () => {
    const original = nativeModule.getConfigurationInfo;
    // Simulate an older native module without getConfigurationInfo.
    (nativeModule as any).getConfigurationInfo = undefined;
    nativeModule.isConfigured.mockResolvedValueOnce(true);
    const info = await AgentforceService.getConfigurationInfo();
    expect(info).toEqual({ configured: true, mode: 'service' });
    (nativeModule as any).getConfigurationInfo = original;
  });

  it('getEmployeeAgentId returns empty string on a non-string result', async () => {
    nativeModule.getEmployeeAgentId.mockResolvedValueOnce(undefined);
    await expect(AgentforceService.getEmployeeAgentId()).resolves.toBe('');
  });

  it('clearHiddenPreChatFields registers an empty map', async () => {
    await AgentforceService.clearHiddenPreChatFields();
    expect(nativeModule.registerHiddenPreChatFields).toHaveBeenCalledWith({});
  });
});

describe('AgentforceService.sendUtterance', () => {
  beforeEach(() => {
    setPlatform('ios');
    nativeModule.sendUtterance.mockClear();
    nativeModule.sendUtterance.mockResolvedValue({ success: true });
  });

  // SC1: happy path — forwards the utterance and resolves the native success flag.
  it('sends the utterance to the native module and resolves true', async () => {
    await expect(AgentforceService.sendUtterance('hello')).resolves.toBe(true);
    expect(nativeModule.sendUtterance).toHaveBeenCalledWith('hello');
  });

  // SC2: normalization — default to true when native omits success, honor explicit false.
  it('defaults to true when the native result omits success', async () => {
    nativeModule.sendUtterance.mockResolvedValueOnce({});
    await expect(AgentforceService.sendUtterance('hi')).resolves.toBe(true);
  });

  it('resolves false when the native result reports success: false', async () => {
    nativeModule.sendUtterance.mockResolvedValueOnce({ success: false });
    await expect(AgentforceService.sendUtterance('hi')).resolves.toBe(false);
  });

  // SC3: platform guard — unsupported platforms return false without touching native.
  it('returns false and skips the native call on unsupported platforms', async () => {
    setPlatform('web');
    await expect(AgentforceService.sendUtterance('hi')).resolves.toBe(false);
    expect(nativeModule.sendUtterance).not.toHaveBeenCalled();
  });

  // SC4: validation — empty / whitespace / non-string throw and never reach native.
  it('rejects an empty or whitespace-only utterance without calling native', async () => {
    await expect(AgentforceService.sendUtterance('')).rejects.toThrow('Invalid utterance');
    await expect(AgentforceService.sendUtterance('   ')).rejects.toThrow('Invalid utterance');
    await expect(AgentforceService.sendUtterance(undefined as unknown as string)).rejects.toThrow(
      'Invalid utterance',
    );
    expect(nativeModule.sendUtterance).not.toHaveBeenCalled();
  });

  // SC5: error propagation — a native rejection surfaces to the caller.
  it('propagates native errors', async () => {
    nativeModule.sendUtterance.mockRejectedValueOnce(new Error('NO_CONVERSATION'));
    await expect(AgentforceService.sendUtterance('hi')).rejects.toThrow('NO_CONVERSATION');
  });
});

describe('AgentforceService.dismissConversation', () => {
  beforeEach(() => {
    setPlatform('ios');
    nativeModule.dismissConversation.mockClear();
    nativeModule.dismissConversation.mockResolvedValue({ success: true });
  });

  // Happy path — forwards to the native dismiss (preserve-history) method.
  it('calls the native dismissConversation and resolves the success flag', async () => {
    await expect(AgentforceService.dismissConversation()).resolves.toBe(true);
    expect(nativeModule.dismissConversation).toHaveBeenCalledTimes(1);
  });

  // Distinct from closeConversation — dismiss must not tear the conversation down.
  it('does not call the destructive closeConversation', async () => {
    await AgentforceService.dismissConversation();
    expect(nativeModule.closeConversation).not.toHaveBeenCalled();
  });

  // Normalization — default to true when native omits success, honor explicit false.
  it('defaults to true when the native result omits success', async () => {
    nativeModule.dismissConversation.mockResolvedValueOnce({});
    await expect(AgentforceService.dismissConversation()).resolves.toBe(true);
  });

  it('resolves false when the native result reports success: false', async () => {
    nativeModule.dismissConversation.mockResolvedValueOnce({ success: false });
    await expect(AgentforceService.dismissConversation()).resolves.toBe(false);
  });

  // Platform guard — unsupported platforms return false without touching native.
  it('returns false and skips the native call on unsupported platforms', async () => {
    setPlatform('web');
    await expect(AgentforceService.dismissConversation()).resolves.toBe(false);
    expect(nativeModule.dismissConversation).not.toHaveBeenCalled();
  });

  // Back-compat guard — older native modules without the method resolve false, not throw.
  it('returns false when the native module lacks dismissConversation', async () => {
    const original = nativeModule.dismissConversation;
    (nativeModule as any).dismissConversation = undefined;
    await expect(AgentforceService.dismissConversation()).resolves.toBe(false);
    (nativeModule as any).dismissConversation = original;
  });

  // Error handling — a native rejection is swallowed and reported as false.
  it('returns false when the native call rejects', async () => {
    nativeModule.dismissConversation.mockRejectedValueOnce(new Error('boom'));
    await expect(AgentforceService.dismissConversation()).resolves.toBe(false);
  });
});
