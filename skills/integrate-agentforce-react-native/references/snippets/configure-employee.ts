// Employee Agent configuration — signed-in workforce users.
//
// Two flavors below; the skill picks one based on Phase 1 follow-up:
//   A) Mobile SDK in host app  — uses EmployeeAgentAuthBridge to fetch creds
//   B) Direct token            — caller supplies accessToken from their own OAuth flow
//
// Skill writes the chosen flavor as `agentforceConfig.ts`.

import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  getEmployeeAgentCredentials,
} from 'react-native-agentforce';
import { agentforceLogger } from './agentforceLogger';
import { agentforceNavigation } from './agentforceNavigation';

// ── A) Mobile SDK flow ──────────────────────────────────────────────────
export async function configureAgentforce(): Promise<boolean> {
  AgentforceService.setLoggerDelegate(agentforceLogger);
  AgentforceService.setNavigationDelegate(agentforceNavigation);

  if (!(await isEmployeeAgentAuthSupported())) {
    throw new Error(
      'Employee Agent auth is not available. ' +
        'Add the Salesforce Mobile SDK to your iOS Podfile and Android build.gradle.',
    );
  }

  if (!(await hasEmployeeAgentSession())) {
    await loginForEmployeeAgent(); // opens native OAuth screen
  }

  const creds = await getEmployeeAgentCredentials();
  if (!creds) {
    throw new Error('Failed to fetch Employee Agent credentials after login');
  }

  return AgentforceService.configure({
    type: 'employee',
    instanceUrl: creds.instanceUrl,
    organizationId: creds.organizationId,
    userId: creds.userId,
    agentId: '{{AGENT_ID}}', // or omit for multi-agent picker
    accessToken: creds.accessToken,
  });
}

// ── B) Direct-token flow (uncomment to use; delete A above) ─────────────
//
// export async function configureAgentforce(): Promise<boolean> {
//   AgentforceService.setLoggerDelegate(agentforceLogger);
//   AgentforceService.setNavigationDelegate(agentforceNavigation);
//
//   const accessToken = await myCustomOAuth.getAccessToken();
//   // TODO: wire myCustomOAuth to your existing OAuth implementation.
//   // Caller is responsible for refreshing the token; re-call configureAgentforce()
//   // with a fresh accessToken when the existing one expires.
//
//   return AgentforceService.configure({
//     type: 'employee',
//     instanceUrl: '{{INSTANCE_URL}}',
//     organizationId: '{{ORGANIZATION_ID}}',
//     userId: '{{USER_ID}}',
//     agentId: '{{AGENT_ID}}',
//     accessToken,
//   });
// }
