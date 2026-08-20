/**
 * Type exports for Agentforce SDK
 *
 * This module exports all public types used by the Agentforce SDK.
 */

// Agent configuration types
export {
  ServiceAgentConfig,
  ServiceUISettings,
  EmployeeAgentConfig,
  AgentConfig,
  FeatureFlags,
  InternalFlags,
  LegacyServiceAgentConfig,
  ConfigurationResult,
  ConfigurationInfo,
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
} from './AgentConfig';

// Logger delegate types
export { LoggerDelegate, LogLevel } from './LoggerDelegate';

// Navigation delegate types
export { NavigationDelegate, NavigationRequest } from './NavigationDelegate';

// Additional context types
export {
  AgentforceAdditionalContext,
  AgentforceContextVariable,
  AgentforceContextVariableType,
} from './AgentforceContext';

// View provider delegate types
export { ViewProviderDelegate, ViewProviderComponentData } from './ViewProviderDelegate';

// Splash screen delegate types
export type { SplashScreenDelegate, SplashScreenComponentProps } from './SplashScreenDelegate';

// Hidden prechat field types
export type { HiddenPreChatFields } from './HiddenPreChatFields';

// Voice configuration types
export type { VoiceOptions } from './VoiceOptions';

// Conversation launch option types
export type { LaunchOptions } from './LaunchOptions';

// Appearance customization types
export type {
  AgentforceAppearance,
  AgentforceThemeMode,
  AgentforceFontWeight,
  AgentforceGenericFontFamily,
  AgentforceFontFamily,
  AgentforceIconSource,
  AgentforceFontOverride,
} from './AgentforceAppearance';

// UI delegate types
export type {
  UIDelegate,
  AgentResponseEvent,
  UtteranceSentEvent,
  AgentSwitchEvent,
  ModifyUtteranceRequest,
} from './UIDelegate';
