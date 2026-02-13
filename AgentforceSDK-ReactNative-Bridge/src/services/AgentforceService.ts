/**
 * Agentforce Service
 *
 * Provides a JavaScript interface for interacting with the native Agentforce SDK.
 * Supports both Service Agent (anonymous/guest) and Employee Agent (authenticated) modes.
 */

import {
  NativeModules,
  NativeEventEmitter,
  Platform,
  EmitterSubscription,
} from 'react-native';

import {
  AgentConfig,
  ServiceAgentConfig,
  EmployeeAgentConfig,
  LegacyServiceAgentConfig,
  ConfigurationResult,
  ConfigurationInfo,
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
} from '../types/AgentConfig';

import { TokenDelegate } from '../types/TokenDelegate';

const { AgentforceModule } = NativeModules;

// Re-export types for convenience
export type { ServiceAgentConfig, EmployeeAgentConfig, AgentConfig };
export type { TokenDelegate };

/**
 * Native module event names
 */
const EVENTS = {
  TOKEN_REFRESH_NEEDED: 'onTokenRefreshNeeded',
  AUTHENTICATION_FAILURE: 'onAuthenticationFailure',
} as const;

/**
 * Service class for interacting with native Agentforce SDK.
 *
 * Supports both Service Agent (anonymous/guest access) and Employee Agent
 * (authenticated access) modes through a unified configuration API.
 *
 * @example
 * ```typescript
 * // Service Agent mode
 * await AgentforceService.configure({
 *   type: 'service',
 *   serviceApiURL: 'https://service.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   esDeveloperName: 'MyServiceAgent',
 * });
 *
 * // Employee Agent mode with direct token
 * await AgentforceService.configure({
 *   type: 'employee',
 *   instanceUrl: 'https://myorg.my.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   userId: '005xx0000001234',
 *   agentId: '0Xxxx0000001234',
 *   accessToken: 'your_token_here',
 * });
 *
 * // Launch conversation (same for both modes)
 * await AgentforceService.launchConversation();
 * ```
 */
class AgentforceService {
  /**
   * Token delegate for Employee Agent mode.
   * Set this before configuring Employee Agent without accessToken.
   */
  private tokenDelegate: TokenDelegate | null = null;

  /**
   * Native event emitter for receiving events from native layer
   */
  private eventEmitter: NativeEventEmitter | null = null;

  /**
   * Subscription for token refresh events
   */
  private tokenRefreshSubscription: EmitterSubscription | null = null;

  /**
   * Subscription for authentication failure events
   */
  private authFailureSubscription: EmitterSubscription | null = null;

  /**
   * Track if service has been initialized
   */
  private initialized: boolean = false;

  constructor() {
    this.initializeEventEmitter();
  }

  /**
   * Initialize the native event emitter and set up listeners
   */
  private initializeEventEmitter(): void {
    if (!AgentforceModule) {
      console.warn(
        '[AgentforceService] Native module not available - events will not work',
      );
      return;
    }

    try {
      this.eventEmitter = new NativeEventEmitter(AgentforceModule);
      this.setupEventListeners();
      this.initialized = true;
    } catch (error) {
      console.warn(
        '[AgentforceService] Failed to initialize event emitter:',
        error,
      );
    }
  }

  /**
   * Set up listeners for native events
   */
  private setupEventListeners(): void {
    if (!this.eventEmitter) return;

    // Listen for token refresh requests from native layer
    this.tokenRefreshSubscription = this.eventEmitter.addListener(
      EVENTS.TOKEN_REFRESH_NEEDED,
      this.handleTokenRefreshRequest.bind(this),
    );

    // Listen for authentication failure events
    this.authFailureSubscription = this.eventEmitter.addListener(
      EVENTS.AUTHENTICATION_FAILURE,
      this.handleAuthenticationFailure.bind(this),
    );
  }

  /**
   * Handle token refresh request from native layer
   */
  private async handleTokenRefreshRequest(): Promise<void> {
    console.log('[AgentforceService] Token refresh requested by native layer');

    if (!this.tokenDelegate) {
      console.error(
        '[AgentforceService] Token refresh requested but no delegate registered',
      );
      return;
    }

    try {
      const newToken = await this.tokenDelegate.refreshToken();
      console.log('[AgentforceService] Token refreshed successfully');

      // Provide the new token back to native layer
      await AgentforceModule.provideRefreshedToken(newToken);
    } catch (error) {
      console.error('[AgentforceService] Token refresh failed:', error);

      // Notify delegate of authentication failure
      this.tokenDelegate.onAuthenticationFailure?.();
    }
  }

  /**
   * Handle authentication failure event from native layer
   */
  private handleAuthenticationFailure(event: { error?: string }): void {
    console.error(
      '[AgentforceService] Authentication failure:',
      event?.error || 'Unknown error',
    );

    // Notify delegate if registered
    this.tokenDelegate?.onAuthenticationFailure?.();
  }

  /**
   * Register a token delegate for Employee Agent mode.
   *
   * The delegate is used to obtain and refresh OAuth tokens for authenticated
   * access. Must be set before configuring an Employee Agent without a direct
   * accessToken.
   *
   * @param delegate - Token delegate implementation
   *
   * @example
   * ```typescript
   * AgentforceService.setTokenDelegate({
   *   getAccessToken: async () => myAuthService.getToken(),
   *   refreshToken: async () => myAuthService.refreshToken(),
   *   onAuthenticationFailure: () => navigation.navigate('Login'),
   * });
   * ```
   */
  setTokenDelegate(delegate: TokenDelegate): void {
    this.tokenDelegate = delegate;
    console.log('[AgentforceService] Token delegate registered');
  }

  /**
   * Clear the registered token delegate
   */
  clearTokenDelegate(): void {
    this.tokenDelegate = null;
    console.log('[AgentforceService] Token delegate cleared');
  }

  /**
   * Check if a token delegate is registered
   */
  hasTokenDelegate(): boolean {
    return this.tokenDelegate !== null;
  }

  /**
   * Configure the SDK with either Service or Employee agent settings.
   *
   * For backward compatibility, configurations without a 'type' field are
   * treated as Service Agent configurations.
   *
   * @param config - Agent configuration (ServiceAgentConfig or EmployeeAgentConfig)
   * @returns Promise<boolean> indicating success
   * @throws Error if configuration fails or Employee Agent lacks token source
   *
   * @example
   * ```typescript
   * // Service Agent (new format)
   * await AgentforceService.configure({
   *   type: 'service',
   *   serviceApiURL: 'https://service.salesforce.com',
   *   organizationId: '00Dxx0000001234',
   *   esDeveloperName: 'MyServiceAgent',
   * });
   *
   * // Service Agent (legacy format - still supported)
   * await AgentforceService.configure({
   *   serviceApiURL: 'https://service.salesforce.com',
   *   organizationId: '00Dxx0000001234',
   *   esDeveloperName: 'MyServiceAgent',
   * });
   *
   * // Employee Agent
   * await AgentforceService.configure({
   *   type: 'employee',
   *   instanceUrl: 'https://myorg.my.salesforce.com',
   *   organizationId: '00Dxx0000001234',
   *   userId: '005xx0000001234',
   *   agentId: '0Xxxx0000001234',
   *   accessToken: 'your_token_here',
   * });
   * ```
   */
  async configure(
    config: AgentConfig | LegacyServiceAgentConfig,
  ): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      console.warn('Agentforce only supported on Android and iOS');
      return false;
    }

    if (!AgentforceModule) {
      console.error('AgentforceModule native module not found');
      return false;
    }

    try {
      // Normalize config to ensure it has a type field
      const normalizedConfig = this.normalizeConfig(config);

      // Handle Employee Agent token requirements
      if (isEmployeeAgentConfig(normalizedConfig)) {
        await this.prepareEmployeeAgentConfig(normalizedConfig);
      }

      // Call native module with the unified config object
      // iOS uses configureWithConfig, Android uses configure with object
      let result: ConfigurationResult;
      
      if (Platform.OS === 'ios') {
        // iOS: Use the new unified method that accepts NSDictionary
        result = await AgentforceModule.configureWithConfig(normalizedConfig);
      } else {
        // Android: Use configure with ReadableMap
        result = await AgentforceModule.configure(normalizedConfig);
      }

      console.log(
        `[AgentforceService] Configured successfully (mode: ${normalizedConfig.type})`,
      );
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Configuration failed:', error);
      throw error;
    }
  }

  /**
   * Normalize configuration to ensure it has a type field.
   * Handles backward compatibility with legacy Service Agent config format.
   */
  private normalizeConfig(
    config: AgentConfig | LegacyServiceAgentConfig,
  ): AgentConfig {
    // If it's a legacy config (no type field), convert to new format
    if (isLegacyConfig(config)) {
      console.log(
        '[AgentforceService] Converting legacy config to new format',
      );
      return {
        type: 'service',
        serviceApiURL: config.serviceApiURL,
        organizationId: config.organizationId,
        esDeveloperName: config.esDeveloperName,
      } as ServiceAgentConfig;
    }

    // Already has type field
    return config;
  }

  /**
   * Prepare Employee Agent config by obtaining token if needed
   */
  private async prepareEmployeeAgentConfig(
    config: EmployeeAgentConfig,
  ): Promise<void> {
    // If token is already provided, nothing to do
    if (config.accessToken) {
      return;
    }

    // Token must come from delegate
    if (!this.tokenDelegate) {
      throw new Error(
        'Employee Agent requires either accessToken or a registered tokenDelegate. ' +
          'Call setTokenDelegate() first or provide accessToken in config.',
      );
    }

    // Get token from delegate
    console.log('[AgentforceService] Getting token from delegate');
    const token = await this.tokenDelegate.getAccessToken();

    if (!token) {
      throw new Error('Token delegate returned empty token');
    }

    // Mutate config to include the token
    config.accessToken = token;
  }

  /**
   * Launch the Agentforce conversation UI.
   *
   * Preserves existing conversation if available, allowing users to continue
   * where they left off. Works for both Service Agent and Employee Agent modes.
   *
   * @returns Promise<boolean> indicating success
   * @throws Error if SDK is not configured or launch fails
   *
   * @example
   * ```typescript
   * try {
   *   await AgentforceService.launchConversation();
   *   console.log('Conversation launched');
   * } catch (error) {
   *   console.error('Failed to launch:', error);
   * }
   * ```
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
      console.log('[AgentforceService] Conversation launched successfully');
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Failed to launch conversation:', error);
      throw error;
    }
  }

  /**
   * Start a new conversation (closes existing conversation if present).
   *
   * Use this when you want to start fresh instead of continuing an existing
   * conversation. Works for both Service Agent and Employee Agent modes.
   *
   * @returns Promise<boolean> indicating success
   * @throws Error if SDK is not configured or start fails
   *
   * @example
   * ```typescript
   * // Start fresh conversation
   * await AgentforceService.startNewConversation();
   * ```
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
      console.log('[AgentforceService] New conversation started successfully');
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Failed to start new conversation:', error);
      throw error;
    }
  }

  /**
   * Check if Agentforce SDK is configured and ready.
   *
   * @returns Promise<boolean> indicating if configured
   *
   * @example
   * ```typescript
   * const ready = await AgentforceService.isConfigured();
   * if (ready) {
   *   // Safe to launch conversation
   * }
   * ```
   */
  async isConfigured(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return false;
    }

    if (!AgentforceModule) {
      return false;
    }

    try {
      const result = await AgentforceModule.isConfigured();
      // Handle both boolean and object return types
      return typeof result === 'boolean' ? result : result?.configured ?? false;
    } catch (error) {
      console.error('[AgentforceService] Failed to check configuration:', error);
      return false;
    }
  }

  /**
   * Get the current saved configuration.
   *
   * Returns the Service Agent configuration fields for backward compatibility.
   * For full configuration info including mode, use getConfigurationInfo().
   *
   * @returns Promise<ServiceAgentConfig | null> with saved configuration values
   * @deprecated Use getConfigurationInfo() for new code
   *
   * @example
   * ```typescript
   * const config = await AgentforceService.getConfiguration();
   * if (config) {
   *   console.log('Configured with:', config.esDeveloperName);
   * }
   * ```
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
      if (
        !config?.serviceApiURL &&
        !config?.organizationId &&
        !config?.esDeveloperName
      ) {
        return null;
      }

      return {
        type: 'service',
        ...config,
      } as ServiceAgentConfig;
    } catch (error) {
      console.error('[AgentforceService] Failed to get configuration:', error);
      return null;
    }
  }

  /**
   * Get detailed configuration information including mode.
   *
   * @returns Promise<ConfigurationInfo> with configuration details
   *
   * @example
   * ```typescript
   * const info = await AgentforceService.getConfigurationInfo();
   * if (info.configured) {
   *   console.log(`Mode: ${info.mode}`);
   *   console.log(`Description: ${info.description}`);
   * }
   * ```
   */
  async getConfigurationInfo(): Promise<ConfigurationInfo> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return { configured: false, mode: null };
    }

    if (!AgentforceModule) {
      return { configured: false, mode: null };
    }

    try {
      // Try new method first
      if (typeof AgentforceModule.getConfigurationInfo === 'function') {
        return await AgentforceModule.getConfigurationInfo();
      }

      // Fall back to legacy method
      const configured = await this.isConfigured();
      return {
        configured,
        mode: configured ? 'service' : null, // Assume service for legacy
      };
    } catch (error) {
      console.error(
        '[AgentforceService] Failed to get configuration info:',
        error,
      );
      return { configured: false, mode: null };
    }
  }

  /**
   * Get the stored Employee Agent ID (persisted in native storage, editable in Settings > Employee Agent tab).
   * Same pattern as Service Agent config: native stores the value so it survives app restarts.
   */
  async getEmployeeAgentId(): Promise<string> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return '';
    }
    if (!AgentforceModule?.getEmployeeAgentId) {
      return '';
    }
    try {
      const id = await AgentforceModule.getEmployeeAgentId();
      return typeof id === 'string' ? id : '';
    } catch {
      return '';
    }
  }

  /**
   * Set the Employee Agent ID (persisted in native storage). Call from Settings tab when user edits the field.
   */
  async setEmployeeAgentId(agentId: string): Promise<void> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return;
    }
    if (!AgentforceModule?.setEmployeeAgentId) {
      return;
    }
    try {
      await AgentforceModule.setEmployeeAgentId(agentId ?? '');
    } catch (error) {
      console.warn('[AgentforceService] Failed to save employee agentId:', error);
    }
  }

  /**
   * Close the current conversation.
   *
   * @returns Promise<boolean> indicating success
   */
  async closeConversation(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return false;
    }

    if (!AgentforceModule) {
      return false;
    }

    try {
      const result = await AgentforceModule.closeConversation();
      console.log('[AgentforceService] Conversation closed');
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Failed to close conversation:', error);
      return false;
    }
  }

  /**
   * Reset all settings and clear the SDK state.
   *
   * @returns Promise<boolean> indicating success
   */
  async resetSettings(): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return false;
    }

    if (!AgentforceModule) {
      return false;
    }

    try {
      const result = await AgentforceModule.resetSettings();
      console.log('[AgentforceService] Settings reset');
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Failed to reset settings:', error);
      return false;
    }
  }

  /**
   * Clean up event listeners and resources.
   *
   * Call this when the service is no longer needed (e.g., app shutdown).
   */
  destroy(): void {
    this.tokenRefreshSubscription?.remove();
    this.tokenRefreshSubscription = null;

    this.authFailureSubscription?.remove();
    this.authFailureSubscription = null;

    this.tokenDelegate = null;
    this.eventEmitter = null;
    this.initialized = false;

    console.log('[AgentforceService] Service destroyed');
  }
}

// Export singleton instance
export default new AgentforceService();
