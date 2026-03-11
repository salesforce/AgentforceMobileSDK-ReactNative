# Delegates

This document covers the delegate/callback patterns in the `react-native-agentforce` bridge: Logger, Navigation, and View Provider delegates.

## Table of Contents

- [Overview](#overview)
- [Logger Delegate](#logger-delegate)
- [Navigation Delegate](#navigation-delegate)
- [View Provider Delegate](#view-provider-delegate)
- [Registration Timing](#registration-timing)

---

## Overview

Delegates allow your JavaScript code to receive events and override behavior from the native Agentforce SDK. The bridge supports three delegate types:

| Delegate | Purpose | Direction |
|---|---|---|
| `LoggerDelegate` | Receive SDK log messages | Native -> JS |
| `NavigationDelegate` | Handle navigation requests from the agent | Native -> JS |
| `ViewProviderDelegate` | Override native SDK views with React Native components | JS -> Native (registration) + Native -> JS (rendering) |

All delegates use a NativeEventEmitter on the JS side to receive events from the native layer. The bridge manages the subscription lifecycle internally.

---

## Logger Delegate

The Logger delegate forwards log messages from the native Agentforce SDK to your JavaScript code. This is useful for debugging, analytics, and monitoring.

### Interface

```ts
type LogLevel = 'error' | 'warn' | 'info' | 'debug';

interface LoggerDelegate {
  onLog(level: LogLevel, message: string, error?: string): void;
}
```

### Parameters

| Parameter | Type | Description |
|---|---|---|
| `level` | `LogLevel` | The severity level of the log message. |
| `message` | `string` | The log message from the SDK. |
| `error` | `string` (optional) | Stringified exception, present only for error/warn levels that include an exception. |

### Setup

```ts
import { AgentforceService } from 'react-native-agentforce';

AgentforceService.setLoggerDelegate({
  onLog(level, message, error) {
    const prefix = `[Agentforce ${level.toUpperCase()}]`;
    if (error) {
      console.log(`${prefix} ${message} | Error: ${error}`);
    } else {
      console.log(`${prefix} ${message}`);
    }
  },
});
```

### Clearing

```ts
AgentforceService.clearLoggerDelegate();
```

This removes the event listener and tells the native layer to stop forwarding logs.

### Platform Differences

| Platform | Log Levels Emitted |
|---|---|
| iOS | `error`, `warn`, `info`, `debug` |
| Android | `error`, `warn`, `info` |

iOS emits the `debug` level; Android does not. Plan your log filtering accordingly.

### How It Works Internally

1. `setLoggerDelegate()` stores the delegate reference and calls `AgentforceModule.enableLogForwarding(true)` on the native side.
2. The native `BridgeLogger` (which implements the SDK's logger protocol) receives log calls from the SDK.
3. When `forwardingEnabled` is `true` and JS listeners are active, `BridgeLogger` calls `emitLogEvent()` on `AgentforceModule`, which sends an `onLogMessage` event via `NativeEventEmitter`.
4. The JS-side listener invokes `delegate.onLog()`.

### Example: Analytics Forwarding

```ts
import analytics from '@segment/analytics-react-native';

AgentforceService.setLoggerDelegate({
  onLog(level, message, error) {
    if (level === 'error') {
      analytics.track('Agentforce Error', {
        message,
        error: error || undefined,
      });
    }
  },
});
```

### Example: Debug Console

```ts
const logBuffer: Array<{ level: string; message: string; timestamp: Date }> = [];

AgentforceService.setLoggerDelegate({
  onLog(level, message) {
    logBuffer.push({ level, message, timestamp: new Date() });
    // Keep only last 200 entries
    if (logBuffer.length > 200) logBuffer.shift();
  },
});

// Later: display logBuffer in a debug screen
```

---

## Navigation Delegate

The Navigation delegate lets your app handle navigation requests from the Agentforce SDK. When the agent presents a link, record reference, quick action, or other navigable element that the user taps, the SDK emits a navigation event.

### Interface

```ts
interface NavigationRequest {
  type: string;
  [key: string]: string | boolean | undefined;
}

interface NavigationDelegate {
  onNavigate(request: NavigationRequest): void;
}
```

### Navigation Request Types

The `type` field indicates the kind of navigation. Known types and their fields:

#### `record`

Navigate to a Salesforce record.

| Field | Type | Description |
|---|---|---|
| `type` | `'record'` | |
| `recordId` | `string` | The Salesforce record ID |
| `objectType` | `string` | The SObject type (e.g. `'Account'`, `'Case'`) |
| `pageReference` | `string` (optional) | Serialized page reference |

#### `link`

Open an external or internal URL.

| Field | Type | Description |
|---|---|---|
| `type` | `'link'` | |
| `uri` | `string` | The URL to open |
| `pageReference` | `string` (optional) | Serialized page reference |

#### `quickAction`

Execute a Salesforce quick action.

| Field | Type | Description |
|---|---|---|
| `type` | `'quickAction'` | |
| `actionName` | `string` | The quick action API name |
| `recordId` | `string` (optional) | Associated record ID |
| `objectType` | `string` (optional) | Associated object type |

#### `pageReference`

Navigate to a Lightning page reference.

| Field | Type | Description |
|---|---|---|
| `type` | `'pageReference'` | |
| `pageReference` | `string` | Serialized Lightning PageReference object |

#### `objectHome`

Navigate to an object's home/list page.

| Field | Type | Description |
|---|---|---|
| `type` | `'objectHome'` | |
| `objectType` | `string` | The SObject type |
| `pageReference` | `string` (optional) | Serialized page reference |

#### `app`

Navigate to an app or external package.

| Field | Type | Description |
|---|---|---|
| `type` | `'app'` | |
| `packageName` | `string` | The app package/bundle identifier |
| `uri` | `string` (optional) | Deep link URI |

#### `unknown`

Catch-all for unrecognized navigation types.

| Field | Type | Description |
|---|---|---|
| `type` | `'unknown'` | |
| `raw` | `string` | Raw serialized navigation data |

### Setup

```ts
import { Linking } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

AgentforceService.setNavigationDelegate({
  onNavigate(request) {
    switch (request.type) {
      case 'link':
        if (request.uri) {
          Linking.openURL(request.uri as string);
        }
        break;

      case 'record':
        // Navigate to a record detail screen in your app
        navigation.navigate('RecordDetail', {
          recordId: request.recordId,
          objectType: request.objectType,
        });
        break;

      case 'quickAction':
        console.log(`Quick action requested: ${request.actionName}`);
        break;

      case 'objectHome':
        navigation.navigate('ObjectList', {
          objectType: request.objectType,
        });
        break;

      default:
        console.log('Unhandled navigation:', JSON.stringify(request));
    }
  },
});
```

### Clearing

```ts
AgentforceService.clearNavigationDelegate();
```

### Forward Compatibility

The `NavigationRequest` interface uses an index signature (`[key: string]: string | boolean | undefined`) so that new fields added by future SDK versions are automatically passed through without requiring bridge updates.

### Example: Deep Linking with React Navigation

```ts
import { useNavigation } from '@react-navigation/native';
import { Linking } from 'react-native';

function useAgentforceNavigation() {
  const navigation = useNavigation();

  React.useEffect(() => {
    AgentforceService.setNavigationDelegate({
      onNavigate(request) {
        switch (request.type) {
          case 'record':
            navigation.navigate('SalesforceRecord', {
              id: request.recordId,
              type: request.objectType,
            });
            break;

          case 'link':
            if (request.uri) {
              // Check if it's an internal deep link or external URL
              const uri = request.uri as string;
              if (uri.startsWith('myapp://')) {
                Linking.openURL(uri);
              } else {
                navigation.navigate('WebView', { url: uri });
              }
            }
            break;

          case 'objectHome':
            navigation.navigate('ObjectList', {
              objectType: request.objectType,
            });
            break;

          default:
            console.warn('Unhandled Agentforce navigation:', request.type);
        }
      },
    });

    return () => {
      AgentforceService.clearNavigationDelegate();
    };
  }, [navigation]);
}
```

---

## View Provider Delegate

The View Provider delegate allows you to replace native SDK output views with custom React Native components. When the SDK renders a component type that matches your registered map, your React Native component is rendered instead.

### Interface

```ts
interface ViewProviderDelegate {
  componentMap: Record<string, string>;
}

interface ViewProviderComponentData {
  definition: string;                       // Component definition (e.g. 'copilot/richText')
  name?: string;                            // Component name from SDK (may be null)
  properties: Record<string, unknown>;      // Key-value properties
  subComponents?: ViewProviderComponentData[]; // Nested sub-components
}
```

### Known Component Definition Strings

Component definitions follow the pattern `copilot/<type>` or `agentforce/<type>`. Known examples:

- `copilot/richText`
- `copilot/markdown`
- `copilot/recordInfo`
- `copilot/list`

The exact set of definitions depends on your agent's configuration and the SDK version. New definitions may be added in future SDK releases.

### Setup

There are two parts to registering a custom view:

**Part 1: Register the React Native component with AppRegistry**

```ts
import { AppRegistry } from 'react-native';

// Define your custom component
function CustomRichTextView({ componentData }: { componentData: ViewProviderComponentData }) {
  // componentData.properties contains the data from the SDK
  const text = componentData.properties.text as string;
  return (
    <View style={{ padding: 12 }}>
      <Text style={{ fontSize: 16 }}>{text}</Text>
    </View>
  );
}

// Register it with AppRegistry
AppRegistry.registerComponent('CustomRichTextView', () => CustomRichTextView);
```

**Part 2: Register the component map with the bridge**

```ts
import { AgentforceService } from 'react-native-agentforce';

await AgentforceService.setViewProviderDelegate({
  componentMap: {
    'copilot/richText': 'CustomRichTextView',
    'copilot/markdown': 'CustomMarkdownView',
  },
});
```

The keys are SDK component definition strings. The values are the names you registered with `AppRegistry.registerComponent()`.

### How It Works

1. You register a `componentMap` mapping SDK definition strings to RN component names.
2. The native bridge stores this map in `BridgeViewProvider`.
3. When the SDK needs to render a view, it calls `canHandle(definition)` on the view provider.
4. If the definition matches a key in the map, the provider returns `true`.
5. The SDK then calls `view()` (iOS) or `GetView()` (Android), which creates an `RCTRootView` (iOS) or `ReactRootView` (Android) rendering the registered React Native component.
6. The component receives `componentData` as initial props, containing the `definition`, `name`, `properties`, and any `subComponents`.

### Feature Flag Requirement

The `enableCustomViewProvider` feature flag must be set to `true` for the view provider to take effect:

```ts
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: url,
  organizationId: orgId,
  esDeveloperName: devName,
  featureFlags: {
    enableMultiAgent: true,
    enableMultiModalInput: false,
    enablePDFUpload: false,
    enableVoice: false,
    enableCustomViewProvider: true,  // Required
  },
});
```

### Clearing

```ts
await AgentforceService.clearViewProviderDelegate();
```

After clearing, the SDK reverts to rendering its built-in views for all component types.

### Timing

The view provider can be registered **before or after** `configure()`. The native provider is always attached to the `AgentforceClient`, and `canHandle()` checks the component map dynamically. However, the feature flag must be set at configuration time.

### Example: Complete Custom View Setup

```ts
import React from 'react';
import { View, Text, StyleSheet, AppRegistry } from 'react-native';
import { AgentforceService, ViewProviderComponentData } from 'react-native-agentforce';

// Custom component for rich text
function CustomAgentforceView(props: { componentData: ViewProviderComponentData }) {
  const { definition, properties, subComponents } = props.componentData;

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Custom View: {definition}</Text>
      <Text style={styles.content}>
        {JSON.stringify(properties, null, 2)}
      </Text>
      {subComponents?.map((sub, index) => (
        <View key={index} style={styles.subComponent}>
          <Text style={styles.subLabel}>{sub.definition}</Text>
          <Text>{JSON.stringify(sub.properties)}</Text>
        </View>
      ))}
    </View>
  );
}

// Register with AppRegistry
AppRegistry.registerComponent('CustomAgentforceView', () => CustomAgentforceView);

// Register with the bridge
async function setupViewProvider() {
  await AgentforceService.setViewProviderDelegate({
    componentMap: {
      'copilot/richText': 'CustomAgentforceView',
      'copilot/markdown': 'CustomAgentforceView',
    },
  });
}

const styles = StyleSheet.create({
  container: { padding: 12, backgroundColor: '#f5f5f5', borderRadius: 8, margin: 4 },
  label: { fontWeight: 'bold', marginBottom: 8 },
  content: { fontFamily: 'monospace', fontSize: 12 },
  subComponent: { marginTop: 8, paddingLeft: 12, borderLeftWidth: 2, borderLeftColor: '#ccc' },
  subLabel: { fontWeight: '600', fontSize: 12 },
});
```

---

## Registration Timing

### Recommended Order

Register delegates **before** calling `configure()` to ensure they are active when the SDK initializes:

```ts
// 1. Set up delegates
AgentforceService.setLoggerDelegate({ onLog: handleLog });
AgentforceService.setNavigationDelegate({ onNavigate: handleNavigation });
await AgentforceService.setViewProviderDelegate({ componentMap: { /* ... */ } });

// 2. Configure
await AgentforceService.configure({ /* ... */ });

// 3. Launch
await AgentforceService.launchConversation();
```

### Why Before configure()?

- **Logger:** The SDK may emit log messages during initialization. If the logger is registered after `configure()`, those early messages are lost.
- **Navigation:** The navigation bridge is passed to the `AgentforceConfiguration` during `configure()`. Registering afterward still works because the bridge checks dynamically, but registering before is cleaner.
- **View Provider:** Can be registered before or after `configure()` without issue. The native view provider checks the component map dynamically.

### Cleanup

Always clean up delegates when they are no longer needed to avoid memory leaks:

```ts
// In a React component:
React.useEffect(() => {
  AgentforceService.setLoggerDelegate({ onLog: handleLog });
  AgentforceService.setNavigationDelegate({ onNavigate: handleNav });

  return () => {
    AgentforceService.clearLoggerDelegate();
    AgentforceService.clearNavigationDelegate();
  };
}, []);
```

Or call `destroy()` on app shutdown to clean up everything:

```ts
AgentforceService.destroy();
```

This removes all event subscriptions, clears all delegates, and resets internal state.

---

## Related Documentation

- [Configuration](./configuration.md) -- Configuration settings (register delegates before calling `configure()`).
- [Conversations](./conversations.md) -- Launching conversations after delegates are set.
- [API Reference](./api-reference.md) -- Complete method signatures for all delegate methods.
- [Platform Notes](./platform-notes.md) -- Platform-specific delegate behavior.
- [Examples](./examples.md) -- Full working examples with all delegates.
