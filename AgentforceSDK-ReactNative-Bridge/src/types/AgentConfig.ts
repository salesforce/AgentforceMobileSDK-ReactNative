/**
 * Agent Configuration Types
 *
 * Defines the configuration interfaces for both Service Agent and Employee Agent modes.
 * Uses a discriminated union pattern with the 'type' field as the discriminator.
 */

import type { VoiceOptions } from './VoiceOptions';

/**
 * Feature flags for the Agentforce SDK (can be set in-app via Feature Flags screen).
 */
export interface FeatureFlags {
  enableMultiAgent: boolean;
  enableMultiModalInput: boolean;
  enablePDFUpload: boolean;
  enableVoice: boolean;
  enableCustomViewProvider: boolean;
}

/**
 * Internal (experimental) SDK flags.
 *
 * A free-form map of SDK internal-flag name → boolean. These are SDK-managed toggles for
 * experimental or in-development behavior — distinct from the five app-facing
 * {@link FeatureFlags}. They are passed straight through to the native SDK using its own
 * flag key names; the bridge does not enumerate, rename, or validate them.
 *
 * ⚠️ **Stability**: internal flags are NOT covered by the SDK's public API stability
 * guarantees. Any flag may be renamed, change default, or be removed in a future SDK
 * release without a semver-major bump. Do not build load-bearing product behavior on them.
 *
 * **Keys are the native SDK's own flag names** (e.g. `enableTokenStreaming`,
 * `enableInlineCitation`), and the iOS and Android SDKs each recognize a different set.
 * Setting a key the running platform's SDK doesn't recognize is a silent no-op — the value
 * is stored and forwarded, but that SDK ignores unknown keys. Consult the native SDK's
 * internal-flag documentation for the keys valid on each platform.
 *
 * Values are booleans; an omitted key falls back to the SDK's own default.
 */
export type InternalFlags = Record<string, boolean>;

/**
 * Base configuration shared by all agent types
 */
interface BaseAgentConfig {
  /** Salesforce Organization ID (15 or 18 character format) */
  organizationId: string;

  /** Optional feature flags. If omitted, stored flags (or defaults) are used. */
  featureFlags?: FeatureFlags;

  /**
   * Optional behavioral configuration for voice conversations.
   *
   * Applies to voice sessions started after this configuration is applied;
   * sessions already in progress keep their original options. Omit to
   * preserve the SDK's default voice behavior on both platforms.
   */
  voiceOptions?: VoiceOptions;

  /**
   * Optional internal (experimental) SDK flags. If omitted, stored flags (or SDK
   * defaults) are used. See {@link InternalFlags} for the caveats — these are not
   * covered by API stability guarantees.
   */
  internalFlags?: InternalFlags;
}

/**
 * UI-specific settings for Service Agent conversations.
 *
 * Controls visibility and behavior of conversation UI features.
 * All fields are optional — omitted fields use SDK defaults.
 */
export interface ServiceUISettings {
  /** Show the download transcript option (default: true) */
  downloadTranscript?: boolean;
  /** Show the end conversation option (default: true) */
  endConversation?: boolean;
  /** Enable validation failure chunk display (default: true, iOS only) */
  validationFailureChunkEnabled?: boolean;
  /** Use welcome utterances instead of a static welcome message (default: false, iOS only) */
  useWelcomeUtterances?: boolean;
  /** Show queue status indicator (default: false, iOS only) */
  showQueueStatus?: boolean;
  /** Enable video upload in conversations (default: false, iOS only) */
  enableVideoUpload?: boolean;
  /** Enable secure forms during conversations (default: false, iOS only) */
  secureForms?: boolean;
  /** Enable audio upload in conversations (default: false, iOS only) */
  enableAudioUpload?: boolean;
}

/**
 * UI-specific settings for Service Agent conversations.
 *
 * Controls visibility and behavior of conversation UI features.
 * All fields are optional — omitted fields use SDK defaults.
 */
export interface ServiceUISettings {
  /** Show the download transcript option (default: true) */
  downloadTranscript?: boolean;
  /** Show the end conversation option (default: true) */
  endConversation?: boolean;
  /** Enable validation failure chunk display (default: true, iOS only) */
  validationFailureChunkEnabled?: boolean;
  /** Use welcome utterances instead of a static welcome message (default: false, iOS only) */
  useWelcomeUtterances?: boolean;
  /** Show queue status indicator (default: false, iOS only) */
  showQueueStatus?: boolean;
  /** Enable video upload in conversations (default: false, iOS only) */
  enableVideoUpload?: boolean;
  /** Enable Lightning Type mapping for experience model types (default: false) */
  enableLightningType?: boolean;
  /** Enable secure forms during conversations (default: false, iOS only) */
  secureForms?: boolean;
  /** Enable audio upload in conversations (default: false, iOS only) */
  enableAudioUpload?: boolean;
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
 *   serviceUISettings: {
 *     downloadTranscript: false,
 *   },
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

  /** Optional UI settings for the service agent conversation */
  serviceUISettings?: ServiceUISettings;
}

/**
 * Employee Agent configuration (authenticated access)
 *
 * Used for internal employee apps where users are authenticated with Salesforce.
 * Requires a valid OAuth token provided directly in the config.
 *
 * @example
 * ```typescript
 * const config: EmployeeAgentConfig = {
 *   type: 'employee',
 *   instanceUrl: 'https://myorg.my.salesforce.com',
 *   organizationId: '00Dxx0000001234',
 *   userId: '005xx0000001234',
 *   agentId: '0Xxxx0000001234',
 *   accessToken: 'your_oauth_token_here',
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
   * The native SDK will fetch fresh tokens from the Mobile SDK automatically.
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
export function isEmployeeAgentConfig(config: AgentConfig): config is EmployeeAgentConfig {
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
