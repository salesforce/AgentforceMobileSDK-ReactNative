// Employee Agent auth helpers — only needed when the host app uses the
// Salesforce Mobile SDK for OAuth.
//
// These thin wrappers around the bridge's auth helpers are convenient for
// gating UI on `isLoggedIn` state and recovering from token expiry.

import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  refreshEmployeeAgentCredentials,
} from 'react-native-agentforce';

export async function ensureEmployeeAgentLogin(): Promise<void> {
  if (!(await isEmployeeAgentAuthSupported())) {
    throw new Error(
      'Mobile SDK not present. Add SalesforceReact (iOS Podfile / Android build.gradle).',
    );
  }
  if (await hasEmployeeAgentSession()) return;
  await loginForEmployeeAgent();
}

export async function logoutAndResetAgentforce(): Promise<void> {
  await AgentforceService.closeConversation();
  await logoutEmployeeAgent();
  await AgentforceService.resetSettings();
}

export async function refreshTokenAndReconfigure(agentId?: string): Promise<void> {
  const fresh = await refreshEmployeeAgentCredentials();
  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: fresh.instanceUrl,
    organizationId: fresh.organizationId,
    userId: fresh.userId,
    agentId,
    accessToken: fresh.accessToken,
  });
}

export { getEmployeeAgentCredentials };
