# Agentforce React Native Bridge

This directory contains the Agentforce bridge module: JavaScript API layer, sample app, and native iOS/Android code. It has **no Mobile SDK dependency**; a host app that adds the Mobile SDK can use the included auth bridge for Employee Agent.

## Installation

Install the package from npm:

```sh
npm install @salesforce/react-native-agentforce
```

The native module autolinks via the shipped `ReactNativeAgentforce` podspec (iOS) and Gradle library (Android). The npm package name is `@salesforce/react-native-agentforce`; the native module names (`ReactNativeAgentforce` pod, `react-native-agentforce` Gradle module) are unchanged.

### iOS (CocoaPods)

In your app’s `Podfile`:

```ruby
pod 'ReactNativeAgentforce', :path => '../node_modules/@salesforce/react-native-agentforce/ios'
```

Your app must also include the Agentforce iOS SDK in the Podfile so the bridge can link. For **Employee Agent**, the host app must additionally include the Salesforce Mobile SDK and perform bootconfig + SDK initialization.

### Android

- Link the Android library and register `AgentforcePackage` in your app.
- For **Employee Agent** (see below), the host app must add the Salesforce React dependency and bootconfig + SDK init.

### JavaScript

Import the API from this package when the native module is linked:

```ts
import { AgentforceService } from '@salesforce/react-native-agentforce';
```

Use the sample app in `app/` as reference or replace with your own UI.

---

## Employee Agent: host app requirements

For **Employee Agent** (authenticated) mode, the host app must provide the Salesforce Mobile SDK and initialize it. This bridge does not bundle the SDK.

### Android

Add the Salesforce React dependency in your app’s `build.gradle` (e.g. `app/build.gradle`):

```gradle
implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
```

You must also configure **bootconfig** and perform **SDK initialization** (e.g. via react-native-force or your existing Salesforce Mobile SDK setup). Without these, Employee Agent auth will not work.

### iOS

Include the Salesforce Mobile SDK pods in your Podfile and perform **bootconfig** and **SDK initialization** as required for your app. The bridge’s Employee Agent auth layer relies on the SDK being initialized at runtime.

---

## API Reference

### Core Methods

**Configure and launch:**

```typescript
import { AgentforceService } from '@salesforce/react-native-agentforce';

await AgentforceService.configure(config);
await AgentforceService.launchConversation();
```

**Additional Context:**
Provide contextual data to personalize agent responses (must be called after launching conversation):

```typescript
await AgentforceService.setAdditionalContext({
  variables: [
    { name: ‘userId’, type: ‘Text’, value: ‘005xx0000001234’ },
    { name: ‘accountId’, type: ‘Text’, value: ‘001xx0000001234’ },
    { name: ‘priority’, type: ‘Text’, value: ‘high’ },
    { name: ‘score’, type: ‘Number’, value: 95.5 },
    { name: ‘isVIP’, type: ‘Boolean’, value: true },
    { name: ‘createdDate’, type: ‘DateTime’, value: ‘2026-03-06T10:00:00Z’ }
  ]
});
```

**Supported types:**

- `Text` - String values
- `Number` - Numeric values
- `Boolean` - Boolean values
- `Date`, `DateTime` - ISO date strings
- `Object` - Object/map values
- `List` - Array values
- `Json`, `Money`, `Ref`, `Variable` - Additional Android SDK types

**Platform notes:**

- Android: Uses `AgentforceContextVariable` with case-sensitive type names
- iOS: Uses `AgentforceVariable` with `JSEncodableValue` enum; type is just a label
- Context persists for the current conversation session

---

### Dismissing the conversation

There are two ways to programmatically dismiss the chat UI, and they differ in what happens to the conversation:

```typescript
// Hide the chat but KEEP the conversation and its history.
// This is the programmatic equivalent of the in-chat close (X) button.
// A subsequent launchConversation() resumes where the user left off.
await AgentforceService.dismissConversation();

// End the conversation and DISCARD its history.
// The next launchConversation() starts a fresh conversation.
await AgentforceService.closeConversation();
```

Use `dismissConversation()` when you need to hide the chat on an event such as a
navigation request without losing history:

```typescript
AgentforceService.setNavigationDelegate({
  async onNavigate(request) {
    await AgentforceService.dismissConversation();
    if (request.type === 'link' && request.uri) {
      Linking.openURL(request.uri);
    }
  },
});
```

**Platform note (Android):** if the app navigates to a _different Android Activity_
and then reconfigures the agent, conversation state may still be rebuilt on the next
launch — a platform constraint independent of `dismissConversation()`. Staying within a
single Activity preserves history across dismiss/relaunch.

---
