/**
 * Employee Agent configuration.
 * Loads from employeeAgentConfig.local.ts when present (same directory); otherwise uses defaults.
 */

import type { EmployeeAgentConfig } from '../types/AgentConfig';

const defaults = {
  EMPLOYEE_AGENT_ENABLED: false,
  EMPLOYEE_AGENT_CONFIG: {
    type: 'employee' as const,
    instanceUrl: '',
    organizationId: '',
    userId: '',
    accessToken: undefined as string | undefined,
  } satisfies EmployeeAgentConfig,
  isEmployeeAgentConfigValid: (): boolean => false,
};

function loadLocalOverrides(): typeof defaults | null {
  try {
    const localModuleName = 'employeeAgentConfig.local';
    return require('./' + localModuleName);
  } catch {
    return null;
  }
}

const local = loadLocalOverrides();
const resolved = local
  ? {
      EMPLOYEE_AGENT_ENABLED: local.EMPLOYEE_AGENT_ENABLED ?? defaults.EMPLOYEE_AGENT_ENABLED,
      EMPLOYEE_AGENT_CONFIG: {
        ...defaults.EMPLOYEE_AGENT_CONFIG,
        ...local.EMPLOYEE_AGENT_CONFIG,
      } as EmployeeAgentConfig,
      isEmployeeAgentConfigValid:
        typeof local.isEmployeeAgentConfigValid === 'function'
          ? local.isEmployeeAgentConfigValid
          : defaults.isEmployeeAgentConfigValid,
    }
  : defaults;

export const EMPLOYEE_AGENT_ENABLED = resolved.EMPLOYEE_AGENT_ENABLED;
export const EMPLOYEE_AGENT_CONFIG = resolved.EMPLOYEE_AGENT_CONFIG;
export const isEmployeeAgentConfigValid = resolved.isEmployeeAgentConfigValid;
