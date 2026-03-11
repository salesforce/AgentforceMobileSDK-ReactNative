# Configuration

This document covers all configuration options for the `react-native-agentforce` bridge, including Service Agent and Employee Agent modes, feature flags, legacy format migration, and config persistence.

## Table of Contents

- [Overview](#overview)
- [Service Agent Configuration](#service-agent-configuration)
- [Employee Agent Configuration](#employee-agent-configuration)
- [Legacy Configuration Format](#legacy-configuration-format)
- [Feature Flags](#feature-flags)
- [Configuration Persistence](#configuration-persistence)
- [Type Guards](#type-guards)
- [ConfigurationResult and ConfigurationInfo](#configurationresult-and-configurationinfo)
- [Configuration Lifecycle](#configuration-lifecycle)

---

## Overview

The `configure()` method accepts a discriminated union type using the `type` field as the discriminator:

```ts
import { AgentforceService } from 'react-native-agentforce';

// The type field determines which mode the SDK operates in
await AgentforceService.configure({
  type: 'service',  // or 'employee'
  // ... mode-specific fields
});
```

Both modes share the fields `organizationId` and `featureFlags?`, which appear on both `ServiceAgentConfig` and `EmployeeAgentConfig`. These are inherited from an internal (non-exported) base interface, so you always work with the concrete config types directly.

---

## Service Agent Configuration

Service Agent mode is for anonymous/guest access -- typical for customer-facing support scenarios. No OAuth authentication is required; the SDK uses empty credentials internally.

```ts
interface ServiceAgentConfig extends BaseAgentConfig {
  type: 'service';
  serviceApiURL: string;     // The Service API URL endpoint
  organizationId: string;    // Salesforce Organization ID
  esDeveloperName: string;   // Einstein Service Agent developer name
  featureFlags?: FeatureFlags;
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | `'service'` | Yes | Must be `'service'` |
| `serviceApiURL` | `string` | Yes | The Service API URL for your deployment. Found in Setup > Embedded Service Deployments > Settings. Must be a valid URL (e.g. `https://your-site.salesforce.com`). An invalid URL will result in a 400 error when launching. |
| `organizationId` | `string` | Yes | Your Salesforce Organization ID. Found in Setup > Company Information. Can be 15 or 18 characters. |
| `esDeveloperName` | `string` | Yes | The developer name of your Embedded Service deployment. Found in Setup > Embedded Service Deployments. |
| `featureFlags` | `FeatureFlags` | No | Optional feature flags. If omitted, persisted flags (or defaults) are used. |

### Example

```ts
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
  organizationId: '00Dxx0000001234EAA',
  esDeveloperName: 'My_Service_Agent',
});
```

### Validation

The native layer validates:
- All three required fields are present and non-empty.
- `serviceApiURL` is a valid URL (iOS checks via `URL(string:)`; a malformed URL produces an `INVALID_CONFIG` error).

---

## Employee Agent Configuration

Employee Agent mode is for authenticated, internal-use scenarios. Users must be authenticated with a valid Salesforce OAuth token.

```ts
interface EmployeeAgentConfig extends BaseAgentConfig {
  type: 'employee';
  instanceUrl: string;       // Salesforce instance URL
  organizationId: string;    // Salesforce Organization ID
  userId: string;            // Salesforce User ID
  agentId?: string;          // Agentforce Agent ID (optional for multi-agent)
  agentLabel?: string;       // Display label for the agent (optional)
  accessToken?: string;      // OAuth access token
  featureFlags?: FeatureFlags;
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | `'employee'` | Yes | Must be `'employee'` |
| `instanceUrl` | `string` | Yes | Your Salesforce instance URL (e.g. `https://myorg.my.salesforce.com`). |
| `organizationId` | `string` | Yes | Salesforce Organization ID. |
| `userId` | `string` | Yes | The Salesforce User ID of the authenticated user (e.g. `005xx0000001234`). |
| `agentId` | `string` | No | The Agentforce Agent ID. If omitted and `enableMultiAgent` is true, the SDK picks the first available agent. |
| `agentLabel` | `string` | No | A display label shown in the conversation UI title bar (Android). |
| `accessToken` | `string` | No | OAuth access token. Can be provided directly or obtained via Mobile SDK auth. The native SDK automatically fetches fresh tokens from the Mobile SDK when available. |
| `featureFlags` | `FeatureFlags` | No | Optional feature flags. |

### Example: Direct Token

```ts
await AgentforceService.configure({
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234EAA',
  userId: '005xx0000001234AAA',
  agentId: '0Xxxx0000001234AAA',
  accessToken: 'your_oauth_access_token',
});
```

### Example: With Mobile SDK Auth

When using the Mobile SDK for authentication, you obtain credentials first and then pass them to `configure()`:

```ts
import {
  AgentforceService,
  loginForEmployeeAgent,
  getEmployeeAgentCredentials,
} from 'react-native-agentforce';

// Login via Mobile SDK
const creds = await loginForEmployeeAgent();

// Configure with obtained credentials
await AgentforceService.configure({
  type: 'employee',
  instanceUrl: creds.instanceUrl,
  organizationId: creds.organizationId,
  userId: creds.userId,
  agentId: '0Xxxx0000001234AAA',
  accessToken: creds.accessToken,
});
```

### agentId Behavior

- If `agentId` is provided, the conversation starts with that specific agent.
- If `agentId` is omitted or empty and `enableMultiAgent` is `true` (the default), the SDK bootstraps and picks the first available agent.
- If `agentId` is omitted and `enableMultiAgent` is `false`, the conversation will likely fail at the SDK level. A warning is logged on both platforms.

The `agentId` is also persisted natively. You can read/write it independently:

```ts
const storedId = await AgentforceService.getEmployeeAgentId();
await AgentforceService.setEmployeeAgentId('0Xxxx0000005678AAA');
```

Changing the `agentId` via `setEmployeeAgentId()` clears the current conversation and client on iOS (so the next launch uses the new agent).

---

## Legacy Configuration Format

For backward compatibility, the bridge still accepts the legacy Service Agent format without a `type` field:

```ts
// Legacy format -- still works, but deprecated
interface LegacyServiceAgentConfig {
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
}

// This works but will log a warning
await AgentforceService.configure({
  serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
  organizationId: '00Dxx0000001234EAA',
  esDeveloperName: 'My_Service_Agent',
});
```

Internally, the bridge detects the missing `type` field using the `isLegacyConfig()` type guard and converts it to a `ServiceAgentConfig` with `type: 'service'`.

### Migration

Replace:
```ts
// Old
await AgentforceService.configure({
  serviceApiURL: url,
  organizationId: orgId,
  esDeveloperName: devName,
});
```

With:
```ts
// New
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: url,
  organizationId: orgId,
  esDeveloperName: devName,
});
```

---

## Feature Flags

Feature flags control optional SDK capabilities. They can be provided inline with the config, set independently, or read from native storage.

```ts
interface FeatureFlags {
  enableMultiAgent: boolean;          // default: true
  enableMultiModalInput: boolean;     // default: false
  enablePDFUpload: boolean;           // default: false
  enableVoice: boolean;               // default: false
  enableCustomViewProvider: boolean;  // default: false
}
```

### Flag Details

| Flag | Default | Description |
|---|---|---|
| `enableMultiAgent` | `true` | When true and no `agentId` is specified, the SDK bootstraps and picks from available agents. When false, an `agentId` must be provided. |
| `enableMultiModalInput` | `false` | Enables camera and image attachment capabilities in the conversation UI. Requires camera/photo permissions. |
| `enablePDFUpload` | `false` | Enables PDF file upload in the conversation. |
| `enableVoice` | `false` | Enables voice input (microphone) in the conversation UI. Requires microphone permission. |
| `enableCustomViewProvider` | `false` | Enables the custom view provider system. When true and a `ViewProviderDelegate` is registered, the SDK delegates rendering of matched component types to your React Native components. |

### Setting Feature Flags

**Inline with configure():**

```ts
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: url,
  organizationId: orgId,
  esDeveloperName: devName,
  featureFlags: {
    enableMultiAgent: true,
    enableMultiModalInput: true,
    enablePDFUpload: false,
    enableVoice: false,
    enableCustomViewProvider: false,
  },
});
```

**Independently (persisted):**

```ts
// Save flags -- they take effect the next time configure() is called
await AgentforceService.setFeatureFlags({
  enableMultiAgent: true,
  enableMultiModalInput: true,
  enablePDFUpload: true,
  enableVoice: false,
  enableCustomViewProvider: false,
});

// Read current flags
const flags = await AgentforceService.getFeatureFlags();
console.log(flags.enableMultiModalInput); // true
```

### Flag Resolution Order

1. If `featureFlags` is provided in the `configure()` call, those values are used.
2. If `featureFlags` is omitted, the bridge reads persisted flags from native storage.
3. If no persisted flags exist, hard-coded defaults are used.

**Important:** Changing feature flags via `setFeatureFlags()` does NOT take effect immediately. You must call `configure()` again (or restart the app) for changes to apply. This is because the native `AgentforceClient` reads flags at initialization time.

---

## Configuration Persistence

Configuration values are persisted in native storage and survive app restarts:

| Platform | Storage Mechanism | Details |
|---|---|---|
| iOS | `UserDefaults` | Feature flags use keys like `AgentforceFF_enableMultiAgent`. Employee Agent ID uses `EmployeeAgentId`. |
| Android | `SharedPreferences` | Feature flags use the `AgentforceFeatureFlags` preferences file. Employee Agent ID uses the `AgentforceEmployeeAgent` preferences file. |

Service Agent config fields (`serviceApiURL`, `organizationId`, `esDeveloperName`) are also persisted by the legacy `ServiceAgentManager` (iOS) and `ServiceAgentViewModel` (Android) for backward compatibility.

---

## Type Guards

The package exports three type guard functions for runtime type checking:

```ts
import {
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
} from 'react-native-agentforce';

function handleConfig(config: AgentConfig | LegacyServiceAgentConfig) {
  if (isLegacyConfig(config)) {
    // config is LegacyServiceAgentConfig (no 'type' field)
    console.log('Legacy format:', config.esDeveloperName);
  } else if (isServiceAgentConfig(config)) {
    // config is ServiceAgentConfig
    console.log('Service Agent:', config.esDeveloperName);
  } else if (isEmployeeAgentConfig(config)) {
    // config is EmployeeAgentConfig
    console.log('Employee Agent:', config.agentId);
  }
}
```

### Implementation

```ts
function isServiceAgentConfig(
  config: AgentConfig | LegacyServiceAgentConfig
): config is ServiceAgentConfig {
  return 'type' in config && config.type === 'service';
}

// Note: accepts AgentConfig only (not LegacyServiceAgentConfig)
function isEmployeeAgentConfig(config: AgentConfig): config is EmployeeAgentConfig {
  return config.type === 'employee';
}

function isLegacyConfig(
  config: AgentConfig | LegacyServiceAgentConfig
): config is LegacyServiceAgentConfig {
  return !('type' in config);
}
```

---

## ConfigurationResult and ConfigurationInfo

### ConfigurationResult

Returned by `configure()` from the native layer:

```ts
interface ConfigurationResult {
  success: boolean;             // Whether configuration succeeded
  mode: 'service' | 'employee'; // The mode that was configured
  description?: string;         // Optional description
}
```

### ConfigurationInfo

Returned by `getConfigurationInfo()`:

```ts
interface ConfigurationInfo {
  configured: boolean;                   // Whether the SDK is configured
  mode: 'service' | 'employee' | null;  // Current mode, null if not configured
  description?: string;                  // Description of the configuration
}
```

### Usage

```ts
const info = await AgentforceService.getConfigurationInfo();

if (info.configured) {
  console.log(`Configured in ${info.mode} mode`);
  if (info.description) {
    console.log(`Details: ${info.description}`);
  }
} else {
  console.log('Not configured -- call configure() first');
}
```

The deprecated `getConfiguration()` method returns a `ServiceAgentConfig | null` for backward compatibility. Use `getConfigurationInfo()` in new code.

---

## Configuration Lifecycle

A typical configuration lifecycle:

```
1. Set delegates (logger, navigation, view provider)  -- optional, but do before configure()
2. Set hidden prechat fields                           -- optional, Service Agent only, before launch
3. Call configure()                                    -- required
4. Check isConfigured()                                -- optional verification
5. Call launchConversation()                            -- opens UI
6. Call setAdditionalContext()                          -- optional, AFTER launching
7. Call closeConversation() or startNewConversation()   -- as needed
8. Call destroy()                                       -- on app shutdown
```

When switching between modes (e.g., from Service to Employee), calling `configure()` again with a different `type` automatically cleans up the previous client and conversation.

---

## Related Documentation

- [Getting Started](./getting-started.md) -- Installation and first-run guide.
- [Conversations](./conversations.md) -- Launching, lifecycle, and additional context.
- [Employee Agent Auth](./employee-agent-auth.md) -- OAuth flows and token management.
- [API Reference](./api-reference.md) -- Complete method and type reference.
