/**
 * Agentforce Service
 *
 * Provides a JavaScript interface for interacting with the native Agentforce SDK.
 * Supports both Service Agent (anonymous/guest) and Employee Agent (authenticated) modes.
 */

import { NativeModules, NativeEventEmitter, Platform, EmitterSubscription } from 'react-native';

import {
  AgentConfig,
  ServiceAgentConfig,
  EmployeeAgentConfig,
  LegacyServiceAgentConfig,
  ConfigurationResult,
  ConfigurationInfo,
  FeatureFlags,
  isLegacyConfig,
} from '../types/AgentConfig';

import { LoggerDelegate, LogLevel } from '../types/LoggerDelegate';
import { NavigationDelegate, NavigationRequest } from '../types/NavigationDelegate';
import type {
  AgentforceAdditionalContext,
  AgentforceContextVariable,
  AgentforceContextVariableType,
} from '../types/AgentforceContext';
import { ViewProviderDelegate } from '../types/ViewProviderDelegate';
import type { HiddenPreChatFields } from '../types/HiddenPreChatFields';

const { AgentforceModule } = NativeModules;

// Re-export types for convenience
export type { ServiceAgentConfig, EmployeeAgentConfig, AgentConfig, FeatureFlags };
export type { LoggerDelegate, LogLevel };
export type { NavigationDelegate, NavigationRequest };
export type { AgentforceAdditionalContext, AgentforceContextVariable };
export type { ViewProviderDelegate };
export type { HiddenPreChatFields };

/**
 * Native module event names
 */
const EVENTS = {
  LOG_MESSAGE: 'onLogMessage',
  NAVIGATION_REQUEST: 'onNavigationRequest',
} as const;

/**
 * Valid context variable types for runtime validation
 */
const VALID_CONTEXT_TYPES: Set<AgentforceContextVariableType> = new Set([
  'Text',
  'Number',
  'Boolean',
  'Date',
  'DateTime',
  'Json',
  'List',
  'Money',
  'Object',
  'Ref',
  'Variable',
]);

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
   * Native event emitter for receiving events from native layer
   */
  private eventEmitter: NativeEventEmitter | null = null;

  /**
   * Logger delegate for receiving SDK log messages
   */
  private loggerDelegate: LoggerDelegate | null = null;

  /**
   * Subscription for log message events
   */
  private loggerSubscription: EmitterSubscription | null = null;

  /**
   * Navigation delegate for receiving SDK navigation requests
   */
  private navigationDelegate: NavigationDelegate | null = null;

  /**
   * Subscription for navigation request events
   */
  private navigationSubscription: EmitterSubscription | null = null;

  /**
   * View provider delegate configuration (registered component types + React component name)
   */
  private viewProviderDelegate: ViewProviderDelegate | null = null;

  /**
   * Track if service has been initialized
   */
  private initialized: boolean = false;

  constructor() {
    this.initializeEventEmitter();
  }

  /**
   * Initialize the native event emitter
   */
  private initializeEventEmitter(): void {
    if (!AgentforceModule) {
      console.warn('[AgentforceService] Native module not available - events will not work');
      return;
    }

    try {
      this.eventEmitter = new NativeEventEmitter(AgentforceModule);
      this.initialized = true;
    } catch (error) {
      console.warn('[AgentforceService] Failed to initialize event emitter:', error);
    }
  }

  /**
   * Register a logger delegate to receive log messages from the native Agentforce SDK.
   *
   * Register before calling `configure()` so the logger is attached when the SDK initializes.
   *
   * @param delegate - Logger delegate implementation
   *
   * @example
   * ```typescript
   * AgentforceService.setLoggerDelegate({
   *   onLog(level, message, error) {
   *     console.log(`[Agentforce ${level.toUpperCase()}] ${message}`);
   *   },
   * });
   * ```
   */
  setLoggerDelegate(delegate: LoggerDelegate): void {
    this.loggerDelegate = delegate;
    this.setupLoggerListener();
    AgentforceModule?.enableLogForwarding(true);
    console.log('[AgentforceService] Logger delegate registered');
  }

  /**
   * Clear the registered logger delegate and stop receiving log messages.
   */
  clearLoggerDelegate(): void {
    this.loggerDelegate = null;
    this.loggerSubscription?.remove();
    this.loggerSubscription = null;
    AgentforceModule?.enableLogForwarding(false);
    console.log('[AgentforceService] Logger delegate cleared');
  }

  /**
   * Set up listener for log message events from native layer
   */
  private setupLoggerListener(): void {
    this.loggerSubscription?.remove();
    if (!this.eventEmitter) {
      return;
    }

    this.loggerSubscription = this.eventEmitter.addListener(
      EVENTS.LOG_MESSAGE,
      (event: { level: LogLevel; message: string; error?: string }) => {
        this.loggerDelegate?.onLog(event.level, event.message, event.error);
      },
    );
  }

  /**
   * Register a navigation delegate to receive navigation requests from the native Agentforce SDK.
   *
   * Register before calling `configure()` so the navigation handler is attached when the SDK initializes.
   *
   * @param delegate - Navigation delegate implementation
   *
   * @example
   * ```typescript
   * AgentforceService.setNavigationDelegate({
   *   onNavigate(request) {
   *     switch (request.type) {
   *       case 'link':
   *         if (request.uri) Linking.openURL(request.uri);
   *         break;
   *       case 'record':
   *         console.log(`Open record: ${request.objectType} ${request.recordId}`);
   *         break;
   *     }
   *   },
   * });
   * ```
   */
  setNavigationDelegate(delegate: NavigationDelegate): void {
    this.navigationDelegate = delegate;
    this.setupNavigationListener();
    AgentforceModule?.enableNavigationForwarding(true);
    console.log('[AgentforceService] Navigation delegate registered');
  }

  /**
   * Clear the registered navigation delegate and stop receiving navigation requests.
   */
  clearNavigationDelegate(): void {
    this.navigationDelegate = null;
    this.navigationSubscription?.remove();
    this.navigationSubscription = null;
    AgentforceModule?.enableNavigationForwarding(false);
    console.log('[AgentforceService] Navigation delegate cleared');
  }

  /**
   * Set up listener for navigation request events from native layer
   */
  private setupNavigationListener(): void {
    this.navigationSubscription?.remove();
    if (!this.eventEmitter) {
      return;
    }

    this.navigationSubscription = this.eventEmitter.addListener(
      EVENTS.NAVIGATION_REQUEST,
      (event: NavigationRequest) => {
        this.navigationDelegate?.onNavigate(event);
      },
    );
  }

  /**
   * Register a view provider delegate to override native SDK output views
   * with custom React Native components.
   *
   * Can be called before or after `configure()` — the native provider is
   * always attached to the client and checks the component map dynamically.
   *
   * @param delegate - View provider delegate configuration
   *
   * @example
   * ```typescript
   * AgentforceService.setViewProviderDelegate({
   *   componentMap: {
   *     'copilot/richText': 'CustomRichTextView',
   *     'copilot/markdown': 'CustomMarkdownView',
   *   },
   * });
   * ```
   */
  async setViewProviderDelegate(delegate: ViewProviderDelegate): Promise<void> {
    this.viewProviderDelegate = delegate;

    if (!AgentforceModule?.registerViewProvider) {
      console.warn('[AgentforceService] registerViewProvider not available on native module');
      return;
    }

    try {
      await AgentforceModule.registerViewProvider({
        componentMap: delegate.componentMap,
      });
      console.log(
        `[AgentforceService] View provider registered for ${
          Object.keys(delegate.componentMap).length
        } types`,
      );
    } catch (error) {
      console.error('[AgentforceService] Failed to register view provider:', error);
      throw error;
    }
  }

  /**
   * Clear the registered view provider delegate.
   * After clearing, the native SDK will render its built-in views for all types.
   */
  async clearViewProviderDelegate(): Promise<void> {
    this.viewProviderDelegate = null;

    if (!AgentforceModule?.clearViewProvider) {
      return;
    }

    try {
      await AgentforceModule.clearViewProvider();
      console.log('[AgentforceService] View provider delegate cleared');
    } catch (error) {
      console.warn('[AgentforceService] Failed to clear view provider:', error);
    }
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
  async configure(config: AgentConfig | LegacyServiceAgentConfig): Promise<boolean> {
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

      // Merge stored feature flags into config if not provided (so native uses same defaults/stored)
      const configWithFlags = await this.mergeFeatureFlagsIntoConfig(normalizedConfig);

      // Call native module with the unified config object
      // iOS uses configureWithConfig, Android uses configure with object
      let result: ConfigurationResult;

      if (Platform.OS === 'ios') {
        // iOS: Use the new unified method that accepts NSDictionary
        result = await AgentforceModule.configureWithConfig(configWithFlags);
      } else {
        // Android: Use configure with ReadableMap
        result = await AgentforceModule.configure(configWithFlags);
      }

      console.log(`[AgentforceService] Configured successfully (mode: ${configWithFlags.type})`);
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Configuration failed:', error);
      throw error;
    }
  }

  /**
   * Merge stored feature flags into config if config does not already have featureFlags.
   * So the native layer receives a single source of truth (config.featureFlags or stored).
   */
  private async mergeFeatureFlagsIntoConfig(config: AgentConfig): Promise<AgentConfig> {
    if (config.featureFlags != null) {
      return config;
    }
    const stored = await this.getFeatureFlags();
    return { ...config, featureFlags: stored };
  }

  /**
   * Get the current feature flags (from native storage).
   * Used by the Feature Flags screen and when configuring without explicit featureFlags.
   */
  async getFeatureFlags(): Promise<FeatureFlags> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return {
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: false,
        enableCustomViewProvider: false,
      };
    }
    if (!AgentforceModule?.getFeatureFlags) {
      return {
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: false,
        enableCustomViewProvider: false,
      };
    }
    try {
      const flags = await AgentforceModule.getFeatureFlags();
      return {
        enableMultiAgent: flags?.enableMultiAgent ?? true,
        enableMultiModalInput: flags?.enableMultiModalInput ?? false,
        enablePDFUpload: flags?.enablePDFUpload ?? false,
        enableVoice: flags?.enableVoice ?? false,
        enableCustomViewProvider: flags?.enableCustomViewProvider ?? false,
      };
    } catch {
      return {
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: false,
        enableCustomViewProvider: false,
      };
    }
  }

  /**
   * Save feature flags (persisted in native storage).
   * Takes effect the next time configure() is called.
   */
  async setFeatureFlags(flags: FeatureFlags): Promise<void> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return;
    }
    if (!AgentforceModule?.setFeatureFlags) {
      return;
    }
    try {
      await AgentforceModule.setFeatureFlags(flags);
    } catch (error) {
      console.warn('[AgentforceService] Failed to save feature flags:', error);
    }
  }

  /**
   * Normalize configuration to ensure it has a type field.
   * Handles backward compatibility with legacy Service Agent config format.
   */
  private normalizeConfig(config: AgentConfig | LegacyServiceAgentConfig): AgentConfig {
    // If it's a legacy config (no type field), convert to new format
    if (isLegacyConfig(config)) {
      console.log('[AgentforceService] Converting legacy config to new format');
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
      if (!config?.serviceApiURL && !config?.organizationId && !config?.esDeveloperName) {
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
      console.error('[AgentforceService] Failed to get configuration info:', error);
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
   * Set additional context for the conversation.
   *
   * Provides contextual information to the Agentforce conversation,
   * such as user ID, account ID, case number, or any other relevant data.
   * This helps the agent provide more personalized and relevant responses.
   *
   * **Must be called after launching a conversation.**
   *
   * @param context - The additional context with variables to set
   * @returns Promise<boolean> indicating success
   * @throws Error if no conversation exists or context is invalid
   *
   * @example
   * ```typescript
   * await AgentforceService.launchConversation();
   *
   * await AgentforceService.setAdditionalContext({
   *   variables: [
   *     { name: 'userId', type: 'Text', value: '005xx0000001234' },
   *     { name: 'accountId', type: 'Text', value: '001xx0000001234' },
   *     { name: 'priority', type: 'Text', value: 'high' }
   *   ]
   * });
   * ```
   */
  async setAdditionalContext(context: AgentforceAdditionalContext): Promise<boolean> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      console.warn('Agentforce only supported on Android and iOS');
      return false;
    }

    if (!AgentforceModule) {
      console.error('AgentforceModule native module not found');
      return false;
    }

    // Validate context structure
    if (!context || !Array.isArray(context.variables)) {
      throw new Error('Invalid context: must have "variables" array');
    }

    // Validate each variable
    for (let i = 0; i < context.variables.length; i++) {
      const variable = context.variables[i];
      if (!variable.name || typeof variable.name !== 'string') {
        throw new Error(`Invalid context variable at index ${i}: missing or invalid "name"`);
      }
      if (!variable.type || typeof variable.type !== 'string') {
        throw new Error(`Invalid context variable at index ${i}: missing or invalid "type"`);
      }
      // Validate type against known types
      if (!VALID_CONTEXT_TYPES.has(variable.type as AgentforceContextVariableType)) {
        throw new Error(
          `Invalid context variable at index ${i}: unknown type "${variable.type}". ` +
            `Valid types: ${Array.from(VALID_CONTEXT_TYPES).join(', ')}`,
        );
      }
    }

    try {
      const result = await AgentforceModule.setAdditionalContext(context);
      console.log(
        `[AgentforceService] Additional context set: ${context.variables.length} variables`,
      );
      return result?.success ?? true;
    } catch (error) {
      console.error('[AgentforceService] Failed to set additional context:', error);
      throw error;
    }
  }

  /**
   * Pre-register hidden prechat field values for Service Agent conversations.
   *
   * Call this before `launchConversation()` to supply values for prechat fields
   * hidden from the end user (e.g. ContactId, AccountId, session tokens).
   * When the SDK initializes a Service Agent session, these values are returned
   * to the native delegate automatically.
   *
   * Fields not present in the provided map are omitted (not sent as empty strings),
   * so the SDK treats them as unset.
   *
   * @remarks Service Agent only. Has no effect for Employee Agent conversations.
   *
   * @param fields - Map of field developer names to string values
   *
   * @example
   * ```typescript
   * await AgentforceService.registerHiddenPreChatFields({
   *   ContactId: '003xx0000001234',
   *   AccountId: '001xx0000005678',
   * });
   * await AgentforceService.launchConversation();
   * ```
   */
  async registerHiddenPreChatFields(fields: HiddenPreChatFields): Promise<void> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return;
    }

    if (!AgentforceModule) {
      console.warn('[AgentforceService] Native module not available');
      return;
    }

    try {
      await AgentforceModule.registerHiddenPreChatFields(fields);
      const count = Object.keys(fields).length;
      console.log(`[AgentforceService] Hidden prechat fields registered: ${count} field(s)`);
    } catch (error) {
      console.error('[AgentforceService] Failed to register hidden prechat fields:', error);
      throw error;
    }
  }

  /**
   * Clear all pre-registered hidden prechat field values.
   *
   * @remarks Service Agent only.
   */
  async clearHiddenPreChatFields(): Promise<void> {
    await this.registerHiddenPreChatFields({});
  }

  /**
   * Get the currently registered hidden prechat field values.
   *
   * @returns The stored field map, or an empty object if none registered.
   */
  async getHiddenPreChatFields(): Promise<HiddenPreChatFields> {
    if (Platform.OS !== 'android' && Platform.OS !== 'ios') {
      return {};
    }

    if (!AgentforceModule?.getHiddenPreChatFields) {
      return {};
    }

    try {
      const fields = await AgentforceModule.getHiddenPreChatFields();
      return (fields as HiddenPreChatFields) ?? {};
    } catch {
      return {};
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
   * Clean up resources.
   *
   * Call this when the service is no longer needed (e.g., app shutdown).
   */
  destroy(): void {
    this.loggerSubscription?.remove();
    this.loggerSubscription = null;
    this.loggerDelegate = null;

    this.navigationSubscription?.remove();
    this.navigationSubscription = null;
    this.navigationDelegate = null;

    // Clear native view provider registration before nulling the JS reference
    if (this.viewProviderDelegate) {
      this.clearViewProviderDelegate().catch(() => {});
    }
    this.viewProviderDelegate = null;

    this.eventEmitter = null;
    this.initialized = false;
    console.log('[AgentforceService] Service destroyed');
  }
}

// Export singleton instance
export default new AgentforceService();
