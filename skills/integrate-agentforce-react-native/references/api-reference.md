# `AgentforceService` API reference

The bridge exports a singleton `AgentforceService` from `react-native-agentforce`. All methods return Promises and are no-ops on web/desktop (return `false` or empty values).

## Lifecycle

```ts
import { AgentforceService } from 'react-native-agentforce';

// 1. Register delegates first (so they catch init-time SDK output)
AgentforceService.setLoggerDelegate(myLogger);
AgentforceService.setNavigationDelegate(myNavigation);

// 2. Configure
await AgentforceService.configure({ type: 'service', ... });

// 3. Launch the native conversation UI
await AgentforceService.launchConversation();

// 4. (Optional) attach context to the live conversation
await AgentforceService.setAdditionalContext({ variables: [...] });

// 5. On app shutdown — clean up event listeners
AgentforceService.destroy();
```

## Methods

### `configure(config)`

Initialize the SDK with a `ServiceAgentConfig` or `EmployeeAgentConfig`. Idempotent — re-call to switch modes or update tokens.

```ts
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
});
```

### `launchConversation()`

Open the native chat UI. **Preserves** any existing conversation — users continue where they left off. Throws if `configure()` hasn't been called.

### `startNewConversation()`

Like `launchConversation()` but discards any existing conversation first.

### `closeConversation()`

Programmatically close the chat UI. Usually unnecessary — the SDK's built-in close button handles this.

### `isConfigured()` / `getConfigurationInfo()`

Check current state. `getConfigurationInfo()` returns `{ configured, mode, description? }` — use it to gate UI on whether `configure()` has run.

### `setAdditionalContext({ variables })`

Attach contextual data to the **current** conversation. Must be called **after** `launchConversation()`.

```ts
await AgentforceService.setAdditionalContext({
  variables: [
    { name: 'userId', type: 'Text', value: '005xx0000001234' },
    { name: 'accountId', type: 'Text', value: '001xx0000001234' },
    { name: 'score', type: 'Number', value: 95.5 },
    { name: 'isVIP', type: 'Boolean', value: true },
    { name: 'createdDate', type: 'DateTime', value: '2026-03-06T10:00:00Z' },
  ],
});
```

Supported variable types: `Text`, `Number`, `Boolean`, `Date`, `DateTime`, `Json`, `List`, `Money`, `Object`, `Ref`, `Variable`.

### `registerHiddenPreChatFields(fields)`

Service Agent only. Pre-populate hidden prechat field values **before** `launchConversation()`:

```ts
await AgentforceService.registerHiddenPreChatFields({
  ContactId: '003xx0000001234',
  AccountId: '001xx0000005678',
});
await AgentforceService.launchConversation();
```

### `setLoggerDelegate(delegate)` / `clearLoggerDelegate()`

Forward SDK logs to JS:

```ts
AgentforceService.setLoggerDelegate({
  onLog(level, message, error) {
    console.log(`[Agentforce ${level.toUpperCase()}] ${message}`, error);
  },
});
```

Levels: `'error' | 'warn' | 'info' | 'debug'` (debug is iOS-only).

### `setNavigationDelegate(delegate)` / `clearNavigationDelegate()`

Handle SDK navigation requests (record opens, link taps, quick actions) in JS rather than letting the SDK handle them natively:

```ts
import { Linking } from 'react-native';

AgentforceService.setNavigationDelegate({
  onNavigate(request) {
    switch (request.type) {
      case 'link':
        if (request.uri) Linking.openURL(request.uri as string);
        break;
      case 'record':
        navigation.navigate('RecordDetail', {
          recordId: request.recordId,
          objectType: request.objectType,
        });
        break;
      // ...
    }
  },
});
```

### `setViewProviderDelegate(delegate)` / `clearViewProviderDelegate()`

Replace native rendering for specific component types with React Native components:

```ts
await AgentforceService.setViewProviderDelegate({
  componentMap: {
    'copilot/richText': 'CustomRichTextView',
    'copilot/markdown': 'CustomMarkdownView',
  },
});
```

The component name on the right must be registered with React Native's component registry. This is an advanced feature — most consumers don't need it.

### `getFeatureFlags()` / `setFeatureFlags(flags)`

Read or persist feature flags. Flags take effect on the next `configure()`:

```ts
type FeatureFlags = {
  enableMultiAgent: boolean;
  enableMultiModalInput: boolean;
  enablePDFUpload: boolean;
  enableVoice: boolean;
  enableCustomViewProvider: boolean;
};
```

If the consumer doesn't pass `featureFlags` to `configure()`, the bridge merges the persisted ones in.

### `destroy()`

Clear all event listeners and delegate references. Call on app shutdown.

## Employee Agent auth helpers

Separate from `AgentforceService`, the bridge exports auth helpers tied to the Mobile SDK:

```ts
import {
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  refreshEmployeeAgentCredentials,
} from 'react-native-agentforce';
```

See `auth-flows.md` for the full flow.
