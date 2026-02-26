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
  LegacyServiceAgentConfig,
  ConfigurationResult,
  ConfigurationInfo,
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
} from './AgentConfig';

// Token delegate types
export {
  TokenDelegate,
  TokenRefreshEvent,
  AuthenticationFailureEvent,
} from './TokenDelegate';

// Logger delegate types
export { LoggerDelegate, LogLevel } from './LoggerDelegate';
