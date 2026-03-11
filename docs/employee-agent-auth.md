# Employee Agent Authentication

This document covers authentication for the Employee Agent mode, including Mobile SDK integration, auth functions, token refresh, and session management.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Mobile SDK Integration Requirements](#mobile-sdk-integration-requirements)
- [Auth Functions Reference](#auth-functions-reference)
- [Login Flow Walkthrough](#login-flow-walkthrough)
- [Token Refresh](#token-refresh)
- [Local Config Override File](#local-config-override-file)
- [Session Management](#session-management)
- [Direct Token Mode (No Mobile SDK)](#direct-token-mode-no-mobile-sdk)

---

## Architecture Overview

Employee Agent authentication in the bridge supports two approaches:

### 1. Bridge Auth (via Mobile SDK)

The Salesforce Mobile SDK handles the OAuth login flow natively. The bridge exposes an `EmployeeAgentAuthBridge` native module that wraps the Mobile SDK's auth APIs. This is the recommended approach for production apps.

Flow:
```
JS calls loginForEmployeeAgent()
  -> EmployeeAgentAuthBridge.login()
    -> SalesforceSDKManager shows OAuth login screen
      -> User logs in
    -> Returns AuthCredentials to JS
  -> JS passes credentials to AgentforceService.configure()
```

### 2. Direct Token

You provide an OAuth `accessToken` directly in the `EmployeeAgentConfig`. This is useful for development, testing, or when your app manages its own auth flow.

```ts
await AgentforceService.configure({
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: '005xx0000001234',
  accessToken: 'already_obtained_token',
});
```

---

## Mobile SDK Integration Requirements

### iOS

Use the `WithMobileSDK` subspec in your Podfile:

```ruby
pod 'ReactNativeAgentforce/WithMobileSDK', :path => '../node_modules/react-native-agentforce/ios'
```

This adds a dependency on `SalesforceSDKCore`, which provides:
- OAuth login/logout flows
- Token storage and refresh
- User account management

The native bridge uses `#if canImport(SalesforceSDKCore)` to conditionally compile Mobile SDK code. When the subspec is not included, all Mobile SDK code paths are excluded at compile time.

On iOS, when Mobile SDK is available and a user is logged in, `configureEmployeeAgent()` fetches the `userId` and `organizationId` from `UserAccountManager.shared.currentUserAccount` for extra reliability (overriding the values from config if available).

### Android

Add `SalesforceReact` as a runtime dependency in your app's `build.gradle`:

```groovy
dependencies {
    implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
}
```

The bridge library declares `SalesforceReact` as `compileOnly` -- it compiles against the Mobile SDK APIs but does not bundle them. Your host app must provide the dependency at runtime.

`AgentforcePackage` uses reflection to check if `SalesforceSDKManager` is on the classpath:

```kotlin
Class.forName("com.salesforce.androidsdk.app.SalesforceSDKManager")
```

If the class is found, `EmployeeAgentAuthBridge` is registered as a native module. If not, Employee Agent auth is gracefully disabled (no crash).

### What Happens Without Mobile SDK?

If you do not include the Mobile SDK:
- `isEmployeeAgentAuthSupported()` returns `false`.
- `loginForEmployeeAgent()` throws an error: "Employee Agent auth is not available. Add Mobile SDK or an auth bridge."
- `getEmployeeAgentCredentials()` returns `null`.
- You can still use Employee Agent mode with a direct token.

---

## Auth Functions Reference

All auth functions are exported directly from the package (not on the `AgentforceService` singleton):

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

### isEmployeeAgentAuthSupported()

```ts
async function isEmployeeAgentAuthSupported(): Promise<boolean>
```

Returns `true` if the build includes Mobile SDK (or another auth bridge) and the `EmployeeAgentAuthBridge` native module is available. Use this to conditionally show/hide Employee Agent UI in your app.

### isEmployeeAgentAuthReady()

```ts
async function isEmployeeAgentAuthReady(): Promise<boolean>
```

Returns `true` if the auth bridge is available AND the user has valid credentials (an active session). Internally checks `getAuthCredentials()` and verifies a non-empty `accessToken` exists.

### hasEmployeeAgentSession()

```ts
async function hasEmployeeAgentSession(): Promise<boolean>
```

Alias for `isEmployeeAgentAuthReady()`. Returns `true` if the user is currently logged in with valid credentials.

### loginForEmployeeAgent()

```ts
async function loginForEmployeeAgent(): Promise<AuthCredentials>
```

Launches the Mobile SDK's OAuth login flow. On iOS, this presents the login screen. On Android, it starts the login activity.

- **Resolves** with `AuthCredentials` on successful login.
- **Rejects** if the user cancels, the auth bridge is unavailable, or login fails.

Error codes (Android):
- `NO_ACTIVITY` -- No current activity available to present login.
- `NOT_AVAILABLE` -- Salesforce SDK not initialized.
- `LOGIN_FAILED` -- No credentials obtained after login.
- `ERROR` -- General error.

### logoutEmployeeAgent()

```ts
async function logoutEmployeeAgent(): Promise<void>
```

Logs out the current user via the Mobile SDK. Clears stored credentials and tokens. If the auth bridge is not available, this is a no-op.

### getEmployeeAgentCredentials()

```ts
async function getEmployeeAgentCredentials(): Promise<AuthCredentials | null>
```

Returns the current auth credentials if the user is logged in, or `null` if no session exists. Does not trigger a login flow.

### refreshEmployeeAgentCredentials()

```ts
async function refreshEmployeeAgentCredentials(): Promise<AuthCredentials>
```

Asks the Mobile SDK to refresh the current session and returns new credentials. The native SDK handles token refresh automatically in most cases, so this method is primarily for manual refresh scenarios.

- **Rejects** with `REFRESH_FAILED` if no credentials exist after refresh.
- **Rejects** with `NOT_AVAILABLE` if Mobile SDK is not initialized.
- **Rejects** with `NO_ACTIVITY` if no activity is available (Android).

### AuthCredentials

```ts
interface AuthCredentials {
  instanceUrl: string;      // Salesforce instance URL
  organizationId: string;   // Org ID
  userId: string;           // User ID
  accessToken: string;      // Current OAuth access token
  refreshToken?: string;    // Refresh token (may not be available on all platforms)
}
```

---

## Login Flow Walkthrough

Here is a complete login flow for Employee Agent with Mobile SDK:

```ts
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  getEmployeeAgentCredentials,
} from 'react-native-agentforce';

async function launchEmployeeAgent(agentId?: string) {
  // Step 1: Check if auth bridge is available
  const authSupported = await isEmployeeAgentAuthSupported();
  if (!authSupported) {
    throw new Error('Employee Agent auth is not available in this build.');
  }

  // Step 2: Check for existing session, or login
  let creds = await getEmployeeAgentCredentials();
  if (!creds) {
    // No session -- show login
    creds = await loginForEmployeeAgent();
  }

  // Step 3: Get stored agent ID (or use provided one)
  const resolvedAgentId = agentId || await AgentforceService.getEmployeeAgentId();

  // Step 4: Configure Employee Agent
  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: creds.instanceUrl,
    organizationId: creds.organizationId,
    userId: creds.userId,
    agentId: resolvedAgentId || undefined,
    accessToken: creds.accessToken,
  });

  // Step 5: Launch conversation
  await AgentforceService.launchConversation();
}
```

---

## Token Refresh

### Automatic Refresh (Recommended)

The native SDK (both iOS and Android) automatically fetches fresh tokens from the Mobile SDK when the current token expires. The `UnifiedCredentialProvider` on both platforms integrates with the Mobile SDK's user account system:

- **iOS:** `UnifiedCredentialProvider` checks `UserAccountManager.shared.currentUserAccount.credentials` for the latest token.
- **Android:** `UnifiedCredentialProvider` retrieves fresh credentials from `UserAccountManager.getInstance()`.

This means you generally do not need to handle token refresh yourself.

### Manual Refresh

For scenarios where you need explicit control:

```ts
import { refreshEmployeeAgentCredentials } from 'react-native-agentforce';

try {
  const newCreds = await refreshEmployeeAgentCredentials();
  console.log('New access token:', newCreds.accessToken);

  // Optionally reconfigure with new token
  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: newCreds.instanceUrl,
    organizationId: newCreds.organizationId,
    userId: newCreds.userId,
    accessToken: newCreds.accessToken,
  });
} catch (error) {
  // Token refresh failed -- may need to re-login
  console.error('Refresh failed:', error);
}
```

---

## Local Config Override File

For development and testing, you can create a local configuration file that is not committed to source control:

```
src/config/employeeAgentConfig.local.ts
```

This file is loaded dynamically by `src/config/employeeAgentConfig.ts`. If it exists, its exports override the defaults.

### Creating the Override File

Create `src/config/employeeAgentConfig.local.ts` (relative to the bridge package root):

```ts
import type { EmployeeAgentConfig } from '../types/AgentConfig';

export const EMPLOYEE_AGENT_ENABLED = true;

export const EMPLOYEE_AGENT_CONFIG: EmployeeAgentConfig = {
  type: 'employee',
  instanceUrl: 'https://my-dev-org.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: '005xx0000001234',
  accessToken: 'dev_access_token_here',
};

export function isEmployeeAgentConfigValid(): boolean {
  return (
    !!EMPLOYEE_AGENT_CONFIG.instanceUrl &&
    !!EMPLOYEE_AGENT_CONFIG.organizationId &&
    !!EMPLOYEE_AGENT_CONFIG.userId
  );
}
```

### Exported Constants

The config module exports:

```ts
import {
  EMPLOYEE_AGENT_ENABLED,       // boolean -- whether Employee Agent is enabled
  EMPLOYEE_AGENT_CONFIG,         // EmployeeAgentConfig -- the config object
  isEmployeeAgentConfigValid,    // () => boolean -- validation function
} from 'react-native-agentforce';
```

### Default Values (No Override File)

```ts
{
  EMPLOYEE_AGENT_ENABLED: false,
  EMPLOYEE_AGENT_CONFIG: {
    type: 'employee',
    instanceUrl: '',
    organizationId: '',
    userId: '',
    accessToken: undefined,
  },
  isEmployeeAgentConfigValid: () => false,
}
```

### .gitignore

Add the local override to your `.gitignore`:

```
# Employee Agent local config (contains tokens)
**/employeeAgentConfig.local.ts
```

---

## Session Management

### Checking Session State

```ts
import {
  isEmployeeAgentAuthSupported,
  isEmployeeAgentAuthReady,
  hasEmployeeAgentSession,
  getEmployeeAgentCredentials,
} from 'react-native-agentforce';

// Is auth available in this build?
const supported = await isEmployeeAgentAuthSupported();

// Is the user currently logged in?
const loggedIn = await hasEmployeeAgentSession();

// Get full credentials (or null)
const creds = await getEmployeeAgentCredentials();
if (creds) {
  console.log(`Logged in as ${creds.userId} at ${creds.instanceUrl}`);
}
```

### Logout

```ts
import { logoutEmployeeAgent, AgentforceService } from 'react-native-agentforce';

async function handleLogout() {
  // Close any active conversation
  await AgentforceService.closeConversation();

  // Logout via Mobile SDK
  await logoutEmployeeAgent();

  // Reset SDK state
  await AgentforceService.resetSettings();
}
```

### Session Persistence

The Mobile SDK handles session persistence natively. Tokens are stored securely and survive app restarts. The `EmployeeAgentAuthBridge` delegates all storage to the Mobile SDK -- the bridge itself does not store tokens.

---

## Direct Token Mode (No Mobile SDK)

If you do not want to integrate the Mobile SDK but still need Employee Agent functionality, you can provide tokens directly:

```ts
// Obtain token through your own auth mechanism
const token = await myAuthService.getAccessToken();

await AgentforceService.configure({
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: '005xx0000001234',
  agentId: '0Xxxx0000001234',
  accessToken: token,
});

await AgentforceService.launchConversation();
```

In this mode:
- `isEmployeeAgentAuthSupported()` returns `false`.
- You are responsible for obtaining, storing, and refreshing tokens.
- The native SDK will not automatically refresh the token.
- When the token expires, the conversation may fail. You will need to obtain a new token and call `configure()` again.

---

## Related Documentation

- [Configuration](./configuration.md) -- Employee Agent config fields and feature flags.
- [Getting Started](./getting-started.md) -- iOS and Android setup for Mobile SDK.
- [Conversations](./conversations.md) -- Launching conversations after auth.
- [API Reference](./api-reference.md) -- Complete auth function signatures.
- [Troubleshooting](./troubleshooting.md) -- Common auth issues.
