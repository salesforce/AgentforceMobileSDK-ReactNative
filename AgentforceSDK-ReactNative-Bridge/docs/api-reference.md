# API Reference

Complete reference for all public APIs exported by the `react-native-agentforce` package.

## Table of Contents

- [AgentforceService (Singleton)](#agentforceservice-singleton)
  - [Configuration Methods](#configuration-methods)
  - [Conversation Methods](#conversation-methods)
  - [Delegate Methods](#delegate-methods)
  - [Context and Prechat Methods](#context-and-prechat-methods)
  - [Feature Flags and Settings Methods](#feature-flags-and-settings-methods)
  - [Lifecycle Methods](#lifecycle-methods)
- [Employee Agent Auth Functions](#employee-agent-auth-functions)
- [Type Guards](#type-guards)
- [Employee Agent Config Exports](#employee-agent-config-exports)
- [Types](#types)
  - [Configuration Types](#configuration-types)
  - [Delegate Types](#delegate-types)
  - [Context Types](#context-types)
  - [Auth Types](#auth-types)
- [Error Codes](#error-codes)

---

## AgentforceService (Singleton)

Imported as:

```ts
import { AgentforceService } from 'react-native-agentforce';
```

`AgentforceService` is a singleton instance (not a class to instantiate). All methods are called directly on this object.

---

### Configuration Methods

#### configure()

```ts
configure(config: AgentConfig | LegacyServiceAgentConfig): Promise<boolean>
```

Configure the SDK with either Service or Employee agent settings.

| Parameter | Type | Description |
|---|---|---|
| `config` | `AgentConfig \| LegacyServiceAgentConfig` | Configuration object with `type: 'service'` or `type: 'employee'` (or legacy format without `type`) |

**Returns:** `Promise<boolean>` -- `true` on success.

**Throws:** Error with codes `INVALID_CONFIG` or `CONFIG_ERROR` on failure.

**Behavior:**
- Normalizes legacy configs to the new format.
- Merges persisted feature flags if `featureFlags` is not provided.
- On iOS, calls `configureWithConfig()` on the native module.
- On Android, calls `configure()` with a ReadableMap.
- When switching modes (service -> employee or vice versa), automatically cleans up the previous client.

**Platform:** iOS, Android.

---

#### isConfigured()

```ts
isConfigured(): Promise<boolean>
```

Check if the SDK is configured and ready.

**Returns:** `Promise<boolean>` -- `true` if configured.

**Platform:** iOS, Android. Returns `false` on other platforms.

---

#### getConfiguration()

```ts
getConfiguration(): Promise<ServiceAgentConfig | null>
```

Get the current saved configuration in legacy format.

**Returns:** `Promise<ServiceAgentConfig | null>` -- The saved config, or `null` if not configured.

**Deprecated:** Use `getConfigurationInfo()` instead.

**Platform:** iOS, Android.

---

#### getConfigurationInfo()

```ts
getConfigurationInfo(): Promise<ConfigurationInfo>
```

Get detailed configuration information including mode.

**Returns:** `Promise<ConfigurationInfo>` with `configured`, `mode`, and optional `description`.

**Platform:** iOS, Android. Returns `{ configured: false, mode: null }` on other platforms.

---

### Conversation Methods

#### launchConversation()

```ts
launchConversation(): Promise<boolean>
```

Open the conversation UI. Preserves existing conversation if available.

**Returns:** `Promise<boolean>` -- `true` on success.

**Throws:** Error with codes `NOT_CONFIGURED`, `LAUNCH_ERROR` (iOS), or `ERROR` (Android).

**Platform:** iOS (presents modal), Android (starts Activity).

---

#### startNewConversation()

```ts
startNewConversation(): Promise<boolean>
```

Close any existing conversation and start a fresh one.

**Returns:** `Promise<boolean>` -- `true` on success.

**Throws:** Error with codes `NOT_CONFIGURED`, `START_NEW_ERROR` (iOS), or `ERROR` (Android).

**Platform:** iOS, Android.

---

#### closeConversation()

```ts
closeConversation(): Promise<boolean>
```

Close the current conversation and dismiss the UI.

**Returns:** `Promise<boolean>` -- `true` on success.

**Platform:** iOS, Android.

---

### Delegate Methods

#### setLoggerDelegate()

```ts
setLoggerDelegate(delegate: LoggerDelegate): void
```

Register a logger delegate to receive SDK log messages.

| Parameter | Type | Description |
|---|---|---|
| `delegate` | `LoggerDelegate` | Object with `onLog(level, message, error?)` method |

**Returns:** `void` (synchronous).

**Side effects:** Calls `enableLogForwarding(true)` on the native module. Sets up a NativeEventEmitter listener for `onLogMessage` events.

**Recommended timing:** Before `configure()`.

---

#### clearLoggerDelegate()

```ts
clearLoggerDelegate(): void
```

Remove the logger delegate and stop receiving log messages.

**Returns:** `void` (synchronous).

---

#### setNavigationDelegate()

```ts
setNavigationDelegate(delegate: NavigationDelegate): void
```

Register a navigation delegate to handle navigation requests from the SDK.

| Parameter | Type | Description |
|---|---|---|
| `delegate` | `NavigationDelegate` | Object with `onNavigate(request)` method |

**Returns:** `void` (synchronous).

**Side effects:** Calls `enableNavigationForwarding(true)` on the native module.

**Recommended timing:** Before `configure()`.

---

#### clearNavigationDelegate()

```ts
clearNavigationDelegate(): void
```

Remove the navigation delegate and stop receiving navigation events.

**Returns:** `void` (synchronous).

---

#### setViewProviderDelegate()

```ts
setViewProviderDelegate(delegate: ViewProviderDelegate): Promise<void>
```

Register a view provider delegate to override SDK views with React Native components.

| Parameter | Type | Description |
|---|---|---|
| `delegate` | `ViewProviderDelegate` | Object with `componentMap` mapping definition strings to RN component names |

**Returns:** `Promise<void>`.

**Throws:** Error with code `INVALID_CONFIG` if `componentMap` is empty.

**Timing:** Can be called before or after `configure()`.

---

#### clearViewProviderDelegate()

```ts
clearViewProviderDelegate(): Promise<void>
```

Clear the view provider delegate. SDK reverts to built-in views.

**Returns:** `Promise<void>`.

---

### Context and Prechat Methods

#### setAdditionalContext()

```ts
setAdditionalContext(context: AgentforceAdditionalContext): Promise<boolean>
```

Set additional context for the current conversation.

| Parameter | Type | Description |
|---|---|---|
| `context` | `AgentforceAdditionalContext` | Object with `variables` array of context variables |

**Returns:** `Promise<boolean>` -- `true` on success.

**Throws:**
- Synchronous `Error` if validation fails (missing `variables` array, invalid variable name/type, unknown type).
- Promise rejection with `INVALID_CONTEXT`, `NO_CONVERSATION`, or `CONTEXT_ERROR` from native.

**Precondition:** Must be called AFTER `launchConversation()` or `startNewConversation()`.

**Platform:** iOS, Android.

---

#### registerHiddenPreChatFields()

```ts
registerHiddenPreChatFields(fields: HiddenPreChatFields): Promise<void>
```

Pre-register hidden prechat field values for Service Agent conversations.

| Parameter | Type | Description |
|---|---|---|
| `fields` | `HiddenPreChatFields` (`Record<string, string>`) | Map of field developer names to string values |

**Precondition:** Call BEFORE `launchConversation()`.

**Note:** Service Agent only. No effect for Employee Agent. On Android, fields are stored but not yet wired to the SDK delegate.

**Throws:** Error with code `INVALID_FIELDS` if fields are not a valid string-to-string map.

**Platform:** iOS (fully functional), Android (stored but not yet wired).

---

#### clearHiddenPreChatFields()

```ts
clearHiddenPreChatFields(): Promise<void>
```

Clear all hidden prechat fields. Equivalent to `registerHiddenPreChatFields({})`.

**Platform:** iOS, Android.

---

#### getHiddenPreChatFields()

```ts
getHiddenPreChatFields(): Promise<HiddenPreChatFields>
```

Get the currently registered hidden prechat field values.

**Returns:** `Promise<HiddenPreChatFields>` -- The stored field map, or `{}` if none.

**Platform:** iOS, Android.

---

### Feature Flags and Settings Methods

#### getFeatureFlags()

```ts
getFeatureFlags(): Promise<FeatureFlags>
```

Read persisted feature flags from native storage.

**Returns:** `Promise<FeatureFlags>` with all flag values.

**Platform:** iOS, Android. Returns defaults on other platforms.

---

#### setFeatureFlags()

```ts
setFeatureFlags(flags: FeatureFlags): Promise<void>
```

Save feature flags to native storage. Changes take effect the next time `configure()` is called.

| Parameter | Type | Description |
|---|---|---|
| `flags` | `FeatureFlags` | All feature flag values to persist |

**Platform:** iOS, Android.

---

#### getEmployeeAgentId()

```ts
getEmployeeAgentId(): Promise<string>
```

Get the stored Employee Agent ID from native storage.

**Returns:** `Promise<string>` -- The agent ID, or empty string if not set.

**Platform:** iOS (UserDefaults), Android (SharedPreferences).

---

#### setEmployeeAgentId()

```ts
setEmployeeAgentId(agentId: string): Promise<void>
```

Set the Employee Agent ID in native storage.

| Parameter | Type | Description |
|---|---|---|
| `agentId` | `string` | The agent ID to store |

**Side effects (iOS):** If the agent ID changes, the current conversation is closed and the client is cleaned up.

**Platform:** iOS, Android.

---

#### resetSettings()

```ts
resetSettings(): Promise<boolean>
```

Clear all SDK state: conversations, client, config, feature flags, view provider, hidden prechat fields, and Employee Agent ID.

**Returns:** `Promise<boolean>` -- `true` on success.

**Platform:** iOS, Android.

---

### Lifecycle Methods

#### destroy()

```ts
destroy(): void
```

Clean up all resources. Call on app shutdown.

**Returns:** `void` (synchronous).

**Behavior:**
- Removes all event subscriptions.
- Clears all delegates (logger, navigation, view provider).
- Resets internal state.
- Calls `clearViewProviderDelegate()` on native (fire-and-forget).

---

## Employee Agent Auth Functions

These are standalone functions, not methods on `AgentforceService`:

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

#### isEmployeeAgentAuthSupported()

```ts
async function isEmployeeAgentAuthSupported(): Promise<boolean>
```

Returns `true` if Mobile SDK auth bridge is available in this build.

---

#### isEmployeeAgentAuthReady()

```ts
async function isEmployeeAgentAuthReady(): Promise<boolean>
```

Returns `true` if the user has valid credentials (active session).

---

#### hasEmployeeAgentSession()

```ts
async function hasEmployeeAgentSession(): Promise<boolean>
```

Alias for `isEmployeeAgentAuthReady()`.

---

#### loginForEmployeeAgent()

```ts
async function loginForEmployeeAgent(): Promise<AuthCredentials>
```

Launch the Mobile SDK OAuth login flow. Resolves with credentials on success.

**Throws:** Error if auth bridge unavailable, user cancels, or login fails.

---

#### logoutEmployeeAgent()

```ts
async function logoutEmployeeAgent(): Promise<void>
```

Log out the current user via Mobile SDK. No-op if bridge unavailable.

---

#### getEmployeeAgentCredentials()

```ts
async function getEmployeeAgentCredentials(): Promise<AuthCredentials | null>
```

Get current credentials if logged in; `null` otherwise.

---

#### refreshEmployeeAgentCredentials()

```ts
async function refreshEmployeeAgentCredentials(): Promise<AuthCredentials>
```

Force a token refresh via Mobile SDK.

**Throws:** Error with `REFRESH_FAILED`, `NOT_AVAILABLE`, or `NO_ACTIVITY`.

---

## Type Guards

```ts
import {
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
} from 'react-native-agentforce';
```

#### isServiceAgentConfig()

```ts
function isServiceAgentConfig(config: AgentConfig | LegacyServiceAgentConfig): config is ServiceAgentConfig
```

Returns `true` if `config.type === 'service'`.

---

#### isEmployeeAgentConfig()

```ts
function isEmployeeAgentConfig(config: AgentConfig): config is EmployeeAgentConfig
```

Returns `true` if `config.type === 'employee'`.

---

#### isLegacyConfig()

```ts
function isLegacyConfig(config: AgentConfig | LegacyServiceAgentConfig): config is LegacyServiceAgentConfig
```

Returns `true` if `config` has no `type` field.

---

## Employee Agent Config Exports

```ts
import {
  EMPLOYEE_AGENT_ENABLED,
  EMPLOYEE_AGENT_CONFIG,
  isEmployeeAgentConfigValid,
} from 'react-native-agentforce';
```

| Export | Type | Description |
|---|---|---|
| `EMPLOYEE_AGENT_ENABLED` | `boolean` | Whether Employee Agent is enabled (from local override or defaults to `false`) |
| `EMPLOYEE_AGENT_CONFIG` | `EmployeeAgentConfig` | The Employee Agent configuration (from local override or empty defaults) |
| `isEmployeeAgentConfigValid` | `() => boolean` | Returns `true` if the config has required fields |

These values are loaded from `src/config/employeeAgentConfig.local.ts` if it exists, otherwise from hard-coded defaults. See [Employee Agent Auth](./employee-agent-auth.md#local-config-override-file).

---

## Types

### Configuration Types

#### ServiceAgentConfig

```ts
interface ServiceAgentConfig {
  type: 'service';
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
  featureFlags?: FeatureFlags;
}
```

#### EmployeeAgentConfig

```ts
interface EmployeeAgentConfig {
  type: 'employee';
  instanceUrl: string;
  organizationId: string;
  userId: string;
  agentId?: string;
  agentLabel?: string;
  accessToken?: string;
  featureFlags?: FeatureFlags;
}
```

#### AgentConfig

```ts
type AgentConfig = ServiceAgentConfig | EmployeeAgentConfig;
```

#### LegacyServiceAgentConfig

```ts
interface LegacyServiceAgentConfig {
  serviceApiURL: string;
  organizationId: string;
  esDeveloperName: string;
}
```

**Deprecated.** Use `ServiceAgentConfig` with `type: 'service'`.

#### FeatureFlags

```ts
interface FeatureFlags {
  enableMultiAgent: boolean;          // default: true
  enableMultiModalInput: boolean;     // default: false
  enablePDFUpload: boolean;           // default: false
  enableVoice: boolean;               // default: false
  enableCustomViewProvider: boolean;  // default: false
}
```

#### ConfigurationResult

```ts
interface ConfigurationResult {
  success: boolean;
  mode: 'service' | 'employee';
  description?: string;
}
```

#### ConfigurationInfo

```ts
interface ConfigurationInfo {
  configured: boolean;
  mode: 'service' | 'employee' | null;
  description?: string;
}
```

---

### Delegate Types

#### LogLevel

```ts
type LogLevel = 'error' | 'warn' | 'info' | 'debug';
```

#### LoggerDelegate

```ts
interface LoggerDelegate {
  onLog(level: LogLevel, message: string, error?: string): void;
}
```

#### NavigationRequest

```ts
interface NavigationRequest {
  type: string;
  [key: string]: string | boolean | undefined;
}
```

Known `type` values: `'record'`, `'link'`, `'quickAction'`, `'pageReference'`, `'objectHome'`, `'app'`, `'unknown'`.

#### NavigationDelegate

```ts
interface NavigationDelegate {
  onNavigate(request: NavigationRequest): void;
}
```

#### ViewProviderDelegate

```ts
interface ViewProviderDelegate {
  componentMap: Record<string, string>;
}
```

#### ViewProviderComponentData

```ts
interface ViewProviderComponentData {
  definition: string;
  name?: string;
  properties: Record<string, unknown>;
  subComponents?: ViewProviderComponentData[];
}
```

#### HiddenPreChatFields

```ts
type HiddenPreChatFields = Record<string, string>;
```

---

### Context Types

#### AgentforceContextVariableType

```ts
type AgentforceContextVariableType =
  | 'Text' | 'Number' | 'Boolean' | 'Date' | 'DateTime'
  | 'Json' | 'List' | 'Money' | 'Object' | 'Ref' | 'Variable';
```

#### AgentforceContextVariable

```ts
interface AgentforceContextVariable {
  name: string;
  type: AgentforceContextVariableType;
  description?: string;
  value?: string | number | boolean | Record<string, unknown> | unknown[] | null;
}
```

#### AgentforceAdditionalContext

```ts
interface AgentforceAdditionalContext {
  variables: AgentforceContextVariable[];
}
```

---

### Auth Types

#### AuthCredentials

```ts
interface AuthCredentials {
  instanceUrl: string;
  organizationId: string;
  userId: string;
  accessToken: string;
  refreshToken?: string;
}
```

---

## Error Codes

Error codes thrown by the native modules. Catch these in Promise rejections:

```ts
try {
  await AgentforceService.configure(config);
} catch (error) {
  console.log(error.code);    // e.g. 'INVALID_CONFIG'
  console.log(error.message); // Human-readable description
}
```

### AgentforceModule Error Codes

| Code | Source | Description |
|---|---|---|
| `INVALID_CONFIG` | configure, registerViewProvider | Missing or invalid configuration fields. Missing `type` field, invalid type value, missing required fields, or empty componentMap. |
| `CONFIG_ERROR` | configure | Configuration failed at the native SDK level (e.g. network error, invalid credentials). |
| `NOT_CONFIGURED` | launchConversation, startNewConversation | `configure()` was not called before attempting to launch. |
| `LAUNCH_ERROR` | launchConversation (iOS) | Failed to start the conversation session. Often indicates wrong `serviceApiURL` (400) or server error (500). |
| `START_NEW_ERROR` | startNewConversation (iOS) | Failed to start a new conversation. |
| `ERROR` | launchConversation, startNewConversation (Android) | General Android error (Activity not available, initialization failure). |
| `INVALID_CONTEXT` | setAdditionalContext | Missing `variables` array or a variable lacks `name`/`type`. |
| `NO_CONVERSATION` | setAdditionalContext | No active conversation. Must call `launchConversation()` first. |
| `CONTEXT_ERROR` | setAdditionalContext | The native SDK rejected the context. |
| `INVALID_FIELDS` | registerHiddenPreChatFields (iOS) | Fields are not a valid string-to-string map. |

### EmployeeAgentAuthBridge Error Codes

| Code | Source | Description |
|---|---|---|
| `NO_ACTIVITY` | login, refreshAuthCredentials (Android) | No current Activity available. |
| `NOT_AVAILABLE` | login, refreshAuthCredentials (Android) | Salesforce SDK not initialized. |
| `LOGIN_FAILED` | login (Android) | No credentials obtained after login flow. |
| `REFRESH_FAILED` | refreshAuthCredentials (Android) | No credentials available after refresh. |
| `ERROR` | Various (Android) | General error with message. |

### Platform Availability

| Method | iOS | Android |
|---|---|---|
| `configure()` | Yes | Yes |
| `launchConversation()` | Yes | Yes |
| `startNewConversation()` | Yes | Yes |
| `closeConversation()` | Yes | Yes |
| `isConfigured()` | Yes | Yes |
| `getConfiguration()` | Yes | Yes |
| `getConfigurationInfo()` | Yes | Yes |
| `setLoggerDelegate()` | Yes | Yes |
| `setNavigationDelegate()` | Yes | Yes |
| `setViewProviderDelegate()` | Yes | Yes |
| `setAdditionalContext()` | Yes | Yes |
| `registerHiddenPreChatFields()` | Yes (functional) | Yes (stored, not wired) |
| `getFeatureFlags()` | Yes | Yes |
| `setFeatureFlags()` | Yes | Yes |
| `getEmployeeAgentId()` | Yes | Yes |
| `setEmployeeAgentId()` | Yes | Yes |
| `resetSettings()` | Yes | Yes |
| `destroy()` | Yes | Yes |
| Auth functions | Yes (with WithMobileSDK) | Yes (with SalesforceReact) |

---

## Related Documentation

- [Configuration](./configuration.md) -- Deep dive into config options.
- [Conversations](./conversations.md) -- Conversation lifecycle and context.
- [Delegates](./delegates.md) -- Delegate patterns and examples.
- [Employee Agent Auth](./employee-agent-auth.md) -- Auth flow details.
- [Platform Notes](./platform-notes.md) -- Platform-specific behavior.
