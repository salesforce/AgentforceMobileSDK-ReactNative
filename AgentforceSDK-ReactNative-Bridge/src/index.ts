/**
 * React Native Agentforce bridge – public API
 *
 * Import from this package in your app when the bridge is linked.
 * Host app adds Mobile SDK separately for Employee Agent auth; this bridge hooks in.
 */

export { default as AgentforceService } from './services/AgentforceService';
export {
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  refreshEmployeeAgentCredentials,
  isEmployeeAgentAuthReady,
} from './services/EmployeeAgentAuth';
export type { AuthCredentials } from './services/EmployeeAgentAuth';

export type { ServiceAgentConfig, EmployeeAgentConfig, AgentConfig, LegacyServiceAgentConfig, ConfigurationResult, ConfigurationInfo, TokenDelegate, TokenRefreshEvent, AuthenticationFailureEvent } from './types';
export { isServiceAgentConfig, isEmployeeAgentConfig, isLegacyConfig } from './types';

export {
  EMPLOYEE_AGENT_ENABLED,
  EMPLOYEE_AGENT_CONFIG,
  isEmployeeAgentConfigValid,
} from './config/employeeAgentConfig';
