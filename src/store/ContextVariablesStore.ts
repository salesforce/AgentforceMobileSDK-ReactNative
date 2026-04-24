import type { AgentforceContextVariable } from 'react-native-agentforce';

let store: AgentforceContextVariable[] = [];

export function getContextVariables(): AgentforceContextVariable[] {
  return [...store];
}

export function setContextVariables(variables: AgentforceContextVariable[]): void {
  store = [...variables];
}

export function clearContextVariables(): void {
  store = [];
}
