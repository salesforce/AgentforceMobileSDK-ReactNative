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

import { NativeModules, Platform } from 'react-native';

const { AgentforceModule } = NativeModules;

export interface ServiceAgentConfig {
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
}

/**
 * Service class for interacting with native Agentforce SDK
 * Provides a simple JavaScript interface for Service Agent functionality
 */
class AgentforceService {
  /**
   * Configure Service Agent with required parameters
   * @param config Service Agent configuration object
   * @returns Promise<boolean> indicating success
   */
  async configure(config: ServiceAgentConfig): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      console.warn('Agentforce only supported on Android and iOS');
      return false;
    }

    if (!AgentforceModule) {
      console.error('AgentforceModule native module not found');
      return false;
    }

    try {
      const result = await AgentforceModule.configure(
        config.serviceApiURL,
        config.organizationId,
        config.esDeveloperName
      );
      console.log('Agentforce configured successfully');
      return result;
    } catch (error) {
      console.error('Failed to configure Agentforce:', error);
      throw error;
    }
  }

  /**
   * Launch the Agentforce conversation UI
   * Preserves existing conversation if available, allowing users to continue where they left off
   * @returns Promise<boolean> indicating success
   */
  async launchConversation(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      console.warn('Agentforce only supported on Android and iOS');
      return false;
    }

    if (!AgentforceModule) {
      console.error('AgentforceModule native module not found');
      return false;
    }

    try {
      const result = await AgentforceModule.launchConversation();
      console.log('Agentforce conversation launched successfully');
      return result;
    } catch (error) {
      console.error('Failed to launch conversation:', error);
      throw error;
    }
  }

  /**
   * Start a new conversation (closes existing conversation if present)
   * Use this when you want to start fresh instead of continuing an existing conversation
   * @returns Promise<boolean> indicating success
   */
  async startNewConversation(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      console.warn('Agentforce only supported on Android and iOS');
      return false;
    }

    if (!AgentforceModule) {
      console.error('AgentforceModule native module not found');
      return false;
    }

    try {
      const result = await AgentforceModule.startNewConversation();
      console.log('New Agentforce conversation started successfully');
      return result;
    } catch (error) {
      console.error('Failed to start new conversation:', error);
      throw error;
    }
  }

  /**
   * Check if Agentforce SDK is configured and ready
   * @returns Promise<boolean> indicating if configured
   */
  async isConfigured(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return false;
    }

    if (!AgentforceModule) {
      return false;
    }

    try {
      return await AgentforceModule.isConfigured();
    } catch (error) {
      console.error('Failed to check configuration:', error);
      return false;
    }
  }

  /**
   * Get the current saved configuration
   * @returns Promise<ServiceAgentConfig | null> with saved configuration values
   */
  async getConfiguration(): Promise<ServiceAgentConfig | null> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return null;
    }

    if (!AgentforceModule) {
      return null;
    }

    try {
      const config = await AgentforceModule.getConfiguration();
      // Return null if all fields are empty (no saved config)
      if (!config.serviceApiURL && !config.organizationId && !config.esDeveloperName) {
        return null;
      }
      return config;
    } catch (error) {
      console.error('Failed to get configuration:', error);
      return null;
    }
  }
}

export default new AgentforceService();

