# Auth flow reference (React Native)

The bridge exposes **two** configuration modes via the `type` discriminator on `AgentConfig`:

```ts
type AgentConfig = ServiceAgentConfig | EmployeeAgentConfig;

interface ServiceAgentConfig {
  type: 'service';
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
  featureFlags?: FeatureFlags;
}

interface EmployeeAgentConfig {
  type: 'employee';
  instanceUrl: string;
  organizationId: string;
  userId: string;
  agentId?: string;        // omit for multi-agent
  agentLabel?: string;
  accessToken?: string;    // optional; native SDK can refresh from Mobile SDK
  featureFlags?: FeatureFlags;
}
```

A legacy fallback (`LegacyServiceAgentConfig` — no `type` field) is also accepted for backward compatibility, but new integrations should always set `type`.

## Decision tree

```
Is the agent customer-facing (anyone can chat without signing in)?
├── Yes → ServiceAgentConfig (type: 'service') + MIAW deployment
│         No Mobile SDK needed.
│         Prerequisites: serviceApiURL, organizationId, esDeveloperName.
│         Setup: https://help.salesforce.com/s/articleView?id=service.miaw_deployment_mobile.htm&type=5
│
└── No (signed-in employees / workforce users)
     │
     └── EmployeeAgentConfig (type: 'employee')
         │
         └── How are credentials supplied?
             │
             ├── Salesforce Mobile SDK already in the host app
             │   → Use EmployeeAgentAuthBridge from the bridge:
             │     loginForEmployeeAgent() / getEmployeeAgentCredentials() / logoutEmployeeAgent()
             │   → configure() with type: 'employee' and omit accessToken;
             │     the native SDK fetches fresh tokens from the Mobile SDK on demand.
             │
             ├── Custom OAuth flow (no Mobile SDK)
             │   → Pass accessToken directly to configure().
             │   → Caller is responsible for token refresh — re-call configure() with
             │     a fresh accessToken when the existing one expires.
             │
             └── No auth at all
                 → Don't use Employee Agent. Use Service Agent instead.
```

## Service Agent — what's actually happening under the hood

When you `configure({ type: 'service', ... })`:
- The bridge sets up an unauthenticated session against the MIAW deployment identified by `esDeveloperName`.
- Internally the SDKs use empty OAuth credentials (Guest mode).
- The conversation UI doesn't show any sign-in affordance.

You don't need to write any auth provider — the bridge handles it.

## Employee Agent — Mobile SDK flow

The bridge exposes `EmployeeAgentAuthBridge` (only present in builds that include the Mobile SDK). Surfaced via these JS helpers from `react-native-agentforce`:

```ts
import {
  isEmployeeAgentAuthSupported,
  isEmployeeAgentAuthReady,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  refreshEmployeeAgentCredentials,
} from 'react-native-agentforce';
```

Typical flow:

```ts
// On app start
if (await isEmployeeAgentAuthSupported()) {
  if (!(await hasEmployeeAgentSession())) {
    await loginForEmployeeAgent();   // shows native OAuth screen
  }
  const creds = await getEmployeeAgentCredentials();
  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: creds!.instanceUrl,
    organizationId: creds!.organizationId,
    userId: creds!.userId,
    agentId: '0Xxxx0000001234',       // or omit for multi-agent
    accessToken: creds!.accessToken,  // optional but recommended
  });
}
```

`isEmployeeAgentAuthSupported()` returns `false` if:
- The host app didn't include the Mobile SDK (e.g. iOS pod `SalesforceReact` not in Podfile).
- The bridge's `EmployeeAgentAuthBridge` native module isn't registered.

If `false`, hide the Employee Agent UI in the consuming app — the user has no way to sign in.

## Employee Agent — direct token flow (no Mobile SDK)

If the consumer has their own OAuth implementation:

```ts
const accessToken = await myCustomOAuthFlow.getAccessToken();
await AgentforceService.configure({
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: '005xx0000001234',
  agentId: '0Xxxx0000001234',
  accessToken,
});
```

In this case the consumer is fully responsible for token refresh. If the token expires mid-conversation, the SDK will surface auth errors via the logger delegate; re-`configure()` with a fresh token to recover.

## Why there's no `Guest(url)` or `OrgJWT` mode in the bridge

The native iOS/Android SDKs expose four credential cases (`OAuth`, `OrgJWT`, `Guest`, `PassThroughAuth`). The RN bridge consolidates these into the two modes above for simplicity:

- `service` → maps to `Guest(url)` natively.
- `employee` with `accessToken` → maps to `OAuth(authToken, orgId, userId)`.
- `employee` without `accessToken` (Mobile SDK present) → bridge fetches `OAuth` credentials on demand.
- `OrgJWT` and `PassThroughAuth` are not currently exposed via the JS bridge.

If the consumer needs `OrgJWT` or `PassThroughAuth`, they currently have to fork the bridge and add the case manually — surface this as a known limitation.

## Prerequisites checklist

Before scaffolding, confirm the user has:

| Branch | Prerequisites |
|---|---|
| Service Agent | MIAW mobile deployment configured; `serviceApiURL`, `organizationId`, `esDeveloperName` |
| Employee + Mobile SDK | Mobile SDK in iOS Podfile and Android `app/build.gradle`; bootconfig.plist / bootconfig.xml configured; `instanceUrl`, `organizationId`, `userId`, `agentId` (optional) |
| Employee + direct token | Existing OAuth flow that returns Salesforce access tokens; same instanceUrl/orgId/userId values; refresh strategy |
