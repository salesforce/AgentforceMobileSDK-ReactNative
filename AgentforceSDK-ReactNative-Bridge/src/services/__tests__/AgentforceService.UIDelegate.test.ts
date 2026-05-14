type Listener = (event: any) => void;
type ListenerEntry = { remove: jest.Mock };

const listeners: Record<string, { listener: Listener; entry: ListenerEntry }[]> = {};

jest.mock('react-native', () => {
  const enableUIDelegateForwarding = jest.fn();
  const enableLogForwarding = jest.fn();
  const enableNavigationForwarding = jest.fn();
  const provideModifiedUtterance = jest.fn();
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
        enableUIDelegateForwarding,
        enableLogForwarding,
        enableNavigationForwarding,
        provideModifiedUtterance,
        getFeatureFlags,
        addListener: jest.fn(),
        removeListeners: jest.fn(),
      },
    },
    NativeEventEmitter: jest.fn().mockImplementation(() => ({
      addListener: jest.fn((eventName: string, listener: Listener) => {
        if (!listeners[eventName]) {
          listeners[eventName] = [];
        }
        const entry: ListenerEntry = { remove: jest.fn() };
        listeners[eventName].push({ listener, entry });
        return entry;
      }),
    })),
  };
});

import { NativeModules } from 'react-native';
import AgentforceService from '../AgentforceService';
import type {
  UIDelegate,
  AgentResponseEvent,
  ModifyUtteranceRequest,
} from '../../types/UIDelegate';

const nativeModule = NativeModules.AgentforceModule;

function getListener(eventName: string): Listener | undefined {
  const entries = listeners[eventName];
  return entries?.[entries.length - 1]?.listener;
}

function getSubscriptionEntries(): ListenerEntry[] {
  return Object.values(listeners).flatMap(arr => arr.map(e => e.entry));
}

beforeEach(() => {
  jest.clearAllMocks();
  for (const key of Object.keys(listeners)) {
    delete listeners[key];
  }
  AgentforceService.clearUIDelegate();
});

describe('UIDelegate forwarding', () => {
  it('enables native forwarding and subscribes to all four events', () => {
    const delegate: UIDelegate = { onAgentResponse: jest.fn() };

    AgentforceService.setUIDelegate(delegate);

    expect(nativeModule.enableUIDelegateForwarding).toHaveBeenCalledWith(true);
    expect(Object.keys(listeners)).toEqual(
      expect.arrayContaining([
        'onAgentResponse',
        'onUtteranceSent',
        'onAgentSwitch',
        'onModifyUtteranceRequest',
      ]),
    );
  });

  it('forwards onAgentResponse events to the delegate', () => {
    const onAgentResponse = jest.fn();
    AgentforceService.setUIDelegate({ onAgentResponse });

    const event: AgentResponseEvent = {
      responseId: 'r-1',
      message: 'Hello',
      type: 'agent',
      conversationId: 'conv-1',
      timestamp: '2026-05-14T00:00:00Z',
    };

    getListener('onAgentResponse')!(event);

    expect(onAgentResponse).toHaveBeenCalledWith(event);
  });

  it('forwards onUtteranceSent events to the delegate', () => {
    const onUtteranceSent = jest.fn();
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn(), onUtteranceSent });

    const event = { utterance: 'hi', hasAttachment: false, timestamp: '2026-05-14T00:00:00Z' };
    getListener('onUtteranceSent')!(event);

    expect(onUtteranceSent).toHaveBeenCalledWith(event);
  });

  it('forwards onAgentSwitch events to the delegate', () => {
    const onAgentSwitch = jest.fn();
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn(), onAgentSwitch });

    const event = { conversationId: 'conv-2', timestamp: '2026-05-14T00:00:00Z' };
    getListener('onAgentSwitch')!(event);

    expect(onAgentSwitch).toHaveBeenCalledWith(event);
  });

  it('calls provideModifiedUtterance with the delegate return value', async () => {
    const modifyUtterance = jest.fn((req: ModifyUtteranceRequest) => `modified: ${req.utterance}`);
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn(), modifyUtterance });

    const request: ModifyUtteranceRequest = { requestId: 'req-1', utterance: 'original' };
    await getListener('onModifyUtteranceRequest')!(request);

    expect(modifyUtterance).toHaveBeenCalledWith(request);
    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith(
      'req-1',
      'modified: original',
    );
  });

  it('falls back to original utterance when modifyUtterance throws', async () => {
    const modifyUtterance = jest.fn(() => {
      throw new Error('oops');
    });
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn(), modifyUtterance });

    const request: ModifyUtteranceRequest = { requestId: 'req-2', utterance: 'keep me' };
    await getListener('onModifyUtteranceRequest')!(request);

    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('req-2', 'keep me');
  });

  it('sends original utterance when no modifyUtterance handler is provided', async () => {
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn() });

    const request: ModifyUtteranceRequest = { requestId: 'req-3', utterance: 'pass through' };
    await getListener('onModifyUtteranceRequest')!(request);

    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('req-3', 'pass through');
  });

  it('disables native forwarding and removes subscriptions on clearUIDelegate', () => {
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn() });

    const entries = getSubscriptionEntries();
    expect(entries.length).toBeGreaterThanOrEqual(4);

    AgentforceService.clearUIDelegate();

    expect(nativeModule.enableUIDelegateForwarding).toHaveBeenLastCalledWith(false);
    entries.forEach(e => expect(e.remove).toHaveBeenCalled());
  });

  it('supports async modifyUtterance handlers', async () => {
    const modifyUtterance = jest.fn(
      async (req: ModifyUtteranceRequest) => `async: ${req.utterance}`,
    );
    AgentforceService.setUIDelegate({ onAgentResponse: jest.fn(), modifyUtterance });

    const request: ModifyUtteranceRequest = { requestId: 'req-4', utterance: 'hello' };
    await getListener('onModifyUtteranceRequest')!(request);

    expect(nativeModule.provideModifiedUtterance).toHaveBeenCalledWith('req-4', 'async: hello');
  });
});
