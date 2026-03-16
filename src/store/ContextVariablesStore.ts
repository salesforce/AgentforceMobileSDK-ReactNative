import type { AgentforceContextVariable } from 'react-native-agentforce';

type AgentType = 'service' | 'employee';

const store: Record<AgentType, AgentforceContextVariable[]> = {
  service: [],
  employee: [],
};

export function getContextVariables(agentType: AgentType): AgentforceContextVariable[] {
  return [...store[agentType]];
}

export function setContextVariables(
  agentType: AgentType,
  variables: AgentforceContextVariable[],
): void {
  store[agentType] = [...variables];
}

export function clearContextVariables(agentType: AgentType): void {
  store[agentType] = [];
}
