/**
 * Agent Configuration Types
 *
 * Defines the configuration interfaces for both Service Agent and Employee Agent modes.
 * Uses a discriminated union pattern with the 'type' field as the discriminator.
 */

/**
 * Feature flags for the Agentforce SDK (can be set in-app via Feature Flags screen).
 */
export interface FeatureFlags {
  enableMultiAgent: boolean;
  enableMultiModalInput: boolean;
  enablePDFUpload: boolean;
  enableVoice: boolean;
}

/**
 * Base configuration shared by all agent types
 */
interface BaseAgentConfig {
  /** Salesforce Organization ID (15 or 18 character format) */
  organizationId: string;

  /** Optional feature flags. If omitted, stored flags (or defaults) are used. */
  featureFlags?: FeatureFlags;
}

/**
 * Service Agent configuration (anonymous/guest access)
 *
 * Used for customer-facing support scenarios where no authentication is required.
 * The SDK uses empty OAuth credentials internally.
 *
 * @example
 * ```typescript
 * const config: ServiceAgentConfig = {
 *   type: 'service',
 *   serviceApiURL: 'https://service.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   esDeveloperName: 'MyServiceAgent',
 * };
 * ```
 */
export interface ServiceAgentConfig extends BaseAgentConfig {
  /** Discriminator field - must be 'service' for Service Agent */
  type: 'service';

  /** The Service API URL endpoint */
  serviceApiURL: string;

  /** The Einstein Service Agent developer name */
  esDeveloperName: string;
}

/**
 * Employee Agent configuration (authenticated access)
 *
 * Used for internal employee apps where users are authenticated with Salesforce.
 * Requires a valid OAuth token provided either directly or via TokenDelegate.
 *
 * @example
 * ```typescript
 * // With direct token
 * const config: EmployeeAgentConfig = {
 *   type: 'employee',
 *   instanceUrl: 'https://myorg.my.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   userId: '005xx0000001234',
 *   agentId: '0Xxxx0000001234',
 *   accessToken: 'your_oauth_token_here',
 * };
 *
 * // With token delegate (set delegate first)
 * AgentforceService.setTokenDelegate(myDelegate);
 * const config: EmployeeAgentConfig = {
 *   type: 'employee',
 *   instanceUrl: 'https://myorg.my.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   userId: '005xx0000001234',
 *   agentId: '0Xxxx0000001234',
 *   // accessToken not needed - delegate provides it
 * };
 * ```
 */
export interface EmployeeAgentConfig extends BaseAgentConfig {
  /** Discriminator field - must be 'employee' for Employee Agent */
  type: 'employee';

  /** Salesforce instance URL (e.g., "https://myorg.my.salesforce.com") */
  instanceUrl: string;

  /** Salesforce User ID (e.g., "005xx0000001234") */
  userId: string;

  /** Agentforce Agent ID (optional; set in Settings > Employee Agent tab, or leave blank for multi-agent) */
  agentId?: string;

  /** Optional display label for the agent */
  agentLabel?: string;

  /**
   * OAuth access token for authentication.
   * Either provide this directly or register a TokenDelegate before configuring.
   */
  accessToken?: string;
}

/**
 * Union type for all agent configurations.
 *
 * Use the 'type' field to discriminate between Service Agent and Employee Agent.
 *
 * @example
 * ```typescript
 * function handleConfig(config: AgentConfig) {
 *   if (config.type === 'service') {
 *     // TypeScript knows this is ServiceAgentConfig
 *     console.log(config.esDeveloperName);
 *   } else {
 *     // TypeScript knows this is EmployeeAgentConfig
 *     console.log(config.agentId);
 *   }
 * }
 * ```
 */
export type AgentConfig = ServiceAgentConfig | EmployeeAgentConfig;

/**
 * Legacy Service Agent configuration (without type field).
 * Used for backward compatibility with existing code.
 *
 * @deprecated Use ServiceAgentConfig with type: 'service' instead
 */
export interface LegacyServiceAgentConfig {
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
}

/**
 * Type guard to check if a config is a Service Agent configuration
 *
 * @param config - The configuration to check
 * @returns true if the config is a ServiceAgentConfig
 *
 * @example
 * ```typescript
 * if (isServiceAgentConfig(config)) {
 *   console.log(config.esDeveloperName); // TypeScript knows this is safe
 * }
 * ```
 */
export function isServiceAgentConfig(
  config: AgentConfig | LegacyServiceAgentConfig,
): config is ServiceAgentConfig {
  return 'type' in config && config.type === 'service';
}

/**
 * Type guard to check if a config is an Employee Agent configuration
 *
 * @param config - The configuration to check
 * @returns true if the config is an EmployeeAgentConfig
 *
 * @example
 * ```typescript
 * if (isEmployeeAgentConfig(config)) {
 *   console.log(config.agentId); // TypeScript knows this is safe
 * }
 * ```
 */
export function isEmployeeAgentConfig(
  config: AgentConfig,
): config is EmployeeAgentConfig {
  return config.type === 'employee';
}

/**
 * Type guard to check if a config is a legacy configuration (without type field)
 *
 * @param config - The configuration to check
 * @returns true if the config is a LegacyServiceAgentConfig
 */
export function isLegacyConfig(
  config: AgentConfig | LegacyServiceAgentConfig,
): config is LegacyServiceAgentConfig {
  return !('type' in config);
}

/**
 * Configuration result returned by native module after successful configuration
 */
export interface ConfigurationResult {
  /** Whether configuration was successful */
  success: boolean;

  /** The mode that was configured ('service' or 'employee') */
  mode: 'service' | 'employee';

  /** Optional description of the configuration */
  description?: string;
}

/**
 * Configuration info returned by getConfigurationInfo()
 */
export interface ConfigurationInfo {
  /** Whether the SDK is configured */
  configured: boolean;

  /** The current mode (null if not configured) */
  mode: 'service' | 'employee' | null;

  /** Description of the current configuration */
  description?: string;
}
