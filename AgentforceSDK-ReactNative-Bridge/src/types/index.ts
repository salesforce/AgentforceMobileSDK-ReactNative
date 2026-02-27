/**
 * Type exports for Agentforce SDK
 *
 * This module exports all public types used by the Agentforce SDK.
 */

// Agent configuration types
export {
  ServiceAgentConfig,
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
