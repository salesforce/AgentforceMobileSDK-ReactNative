/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

jest.mock('react-native', () => {
  class NativeEventEmitter {}

  return {
    NativeModules: {
      AgentforceModule: {
        launchConversation: jest.fn(),
      },
    },
    NativeEventEmitter,
    Platform: { OS: 'ios' },
  };
});

import { NativeModules } from 'react-native';
import AgentforceService from '../AgentforceService';

const mockAgentforceModule = NativeModules.AgentforceModule;

describe('AgentforceService.launchConversation with initialMode', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockAgentforceModule.launchConversation.mockResolvedValue({ success: true });
  });

  describe('SC-1: initialMode parameter accepts chat and voice', () => {
    it('accepts chat mode', async () => {
      await AgentforceService.launchConversation({ initialMode: 'chat' });

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'returnToChat',
      });
    });

    it('accepts voice mode', async () => {
      await AgentforceService.launchConversation({ initialMode: 'voice' });

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'voice',
        voiceCloseBehavior: 'returnToChat',
      });
    });
  });

  describe('SC-2: Chat remains default when initialMode omitted', () => {
    it('defaults to chat when no options provided', async () => {
      await AgentforceService.launchConversation();

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'returnToChat',
      });
    });

    it('defaults to chat when empty options object provided', async () => {
      await AgentforceService.launchConversation({});

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'returnToChat',
      });
    });
  });

  describe('voiceCloseBehavior', () => {
    it('forwards dismissContainer to the native module', async () => {
      await AgentforceService.launchConversation({ voiceCloseBehavior: 'dismissContainer' });

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'dismissContainer',
      });
    });
  });

  describe('additionalContext', () => {
    it('forwards context with the launch request', async () => {
      const additionalContext = {
        variables: [{ name: 'userId', type: 'Text' as const, value: '005' }],
      };

      await AgentforceService.launchConversation({ additionalContext });

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'returnToChat',
        additionalContext,
      });
    });

    it('validates context before launching', async () => {
      await expect(
        AgentforceService.launchConversation({ additionalContext: { variables: [] } }),
      ).resolves.toBe(true);

      await expect(
        AgentforceService.launchConversation({
          additionalContext: { variables: [{ name: 'userId', type: 'Unknown' as any }] },
        }),
      ).rejects.toThrow(/unknown type/);
    });
  });

  describe('SC-6: Error returned when Voice disabled/unavailable', () => {
    it('throws when Voice mode launch fails', async () => {
      const error = new Error('Voice is not enabled');
      mockAgentforceModule.launchConversation.mockRejectedValue(error);

      await expect(AgentforceService.launchConversation({ initialMode: 'voice' })).rejects.toThrow(
        'Voice is not enabled',
      );
    });

    it('propagates native error message', async () => {
      mockAgentforceModule.launchConversation.mockRejectedValue(
        new Error('Voice feature is disabled'),
      );

      await expect(AgentforceService.launchConversation({ initialMode: 'voice' })).rejects.toThrow(
        'Voice feature is disabled',
      );
    });
  });

  describe('backward compatibility', () => {
    it('maintains existing behavior when called without arguments', async () => {
      await AgentforceService.launchConversation();

      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledTimes(1);
      expect(mockAgentforceModule.launchConversation).toHaveBeenCalledWith({
        initialMode: 'chat',
        voiceCloseBehavior: 'returnToChat',
      });
    });
  });
});
