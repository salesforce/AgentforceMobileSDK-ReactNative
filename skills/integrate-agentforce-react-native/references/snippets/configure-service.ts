// Service Agent configuration — public, customer-facing, no auth.
//
// Skill writes this as `agentforceConfig.ts`. Call `configureAgentforce()`
// once at app startup, then `AgentforceService.launchConversation()`
// when the user opens the chat.

import { AgentforceService } from 'react-native-agentforce';
import { agentforceLogger } from './agentforceLogger';
import { agentforceNavigation } from './agentforceNavigation';

export async function configureAgentforce(): Promise<boolean> {
  // Register delegates BEFORE configure() so init-time SDK output is captured
  AgentforceService.setLoggerDelegate(agentforceLogger);
  AgentforceService.setNavigationDelegate(agentforceNavigation);

  return AgentforceService.configure({
    type: 'service',
    serviceApiURL: '{{SERVICE_API_URL}}',     // e.g. 'https://your-domain.my.salesforce-scrt.com'
    organizationId: '{{ORGANIZATION_ID}}',     // 15 or 18 char Org ID
    esDeveloperName: '{{ES_DEVELOPER_NAME}}',  // Einstein Service Agent dev name
  });
}
