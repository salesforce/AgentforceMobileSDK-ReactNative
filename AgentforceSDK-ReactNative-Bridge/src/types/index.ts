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

// Hidden prechat field types
export type { HiddenPreChatFields } from './HiddenPreChatFields';

// UI delegate types
export type {
  UIDelegate,
  AgentResponseEvent,
  UtteranceSentEvent,
  AgentSwitchEvent,
  ModifyUtteranceRequest,
} from './UIDelegate';
