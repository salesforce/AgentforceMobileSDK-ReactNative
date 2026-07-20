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

### Voice Options

Optionally configure per-session voice behaviors when calling `configure()`.
All fields are optional and default to "off"; omitting `voiceOptions`
preserves existing behavior.

```typescript
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://example.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  voiceOptions: {
    // Auto-end the voice conversation after this many seconds
    // of continuous user silence. Omit to keep the session open.
    userSilenceTimeoutSeconds: 30,
  },
});
```

**Fields**

- `userSilenceTimeoutSeconds` _(number, optional)_ — Seconds of continuous
  user silence before the voice session auto-ends. Omit or pass `undefined`
  to disable. Non-positive values are treated as disabled by the native
  layer.

**Platform support:**

- Honored on both Service and Employee Agent paths on iOS and Android.

Voice options are immutable for the lifetime of a configured session;
re-configure to change them.

---

### Internal Flags (experimental)

Internal flags are SDK-managed toggles for experimental or in-development behavior. They are
distinct from the five app-facing feature flags (`enableMultiAgent`, `enableMultiModalInput`,
`enablePDFUpload`, `enableVoice`, `enableCustomViewProvider`) and are surfaced here so
integrators can opt into or out of specific SDK behaviors.

> ⚠️ **Not covered by API stability guarantees.** Any internal flag may be renamed, change its
> default, or be removed in a future SDK release without a semver-major bump. Do not build
> load-bearing product behavior on them.

**Reading and writing:**

Internal flags follow the same read/deferred-write pattern as feature flags — a value set via
`setInternalFlags` (or passed on the `internalFlags` config field) is persisted and applied the
next time `configure()` is called.

```typescript
import { AgentforceService, InternalFlags } from '@salesforce/react-native-agentforce';

// Read the flags that have been explicitly set (missing key = "use SDK default")
const flags: InternalFlags = await AgentforceService.getInternalFlags();

// Persist flags; applied on the next configure()
await AgentforceService.setInternalFlags({
  tokenStreaming: true,
  enableClosedCaptions: true,
});

// Or pass them inline on the config object
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  internalFlags: { tokenStreaming: true },
});
```

**Semantics:**

- All flags are optional booleans. An omitted flag falls back to the SDK's own default —
  a missing key is **not** the same as `false`.
- `getInternalFlags()` returns only the flags that were explicitly set (an empty object if none).
  It reflects stored values, not the running SDK's live state.
- The canonical flag set below is the **union** of the iOS and Android internal flags. Setting a
  flag on a platform that doesn't support it is a silent no-op — the value is stored and
  forwarded, but that platform's SDK ignores it.

**Flags and platform support:**

| Flag                                  | iOS | Android | Meaning                                                                         |
| ------------------------------------- | :-: | :-----: | ------------------------------------------------------------------------------- |
| `endConversation`                     | ✅  |   ✅    | Show the end-conversation affordance                                            |
| `downloadTranscript`                  | ✅  |   ✅    | Show the download-transcript affordance                                         |
| `useMobileTypesApi`                   | ✅  |   ✅    | Use the Mobile Types API for message rendering                                  |
| `enableHybridComponents`              | ✅  |   ✅    | Enable hybrid (native + Lightning) component rendering                          |
| `enableClosedCaptions`                | ✅  |   ✅    | Enable closed captions in voice conversations                                   |
| `tokenStreaming`                      | ✅  |   ✅    | Stream response tokens as they arrive                                           |
| `lightningTypeStreaming`              | ✅  |   ✅    | Stream Lightning-type responses incrementally                                   |
| `inlineCitations`                     | ✅  |   ✅    | Render inline citations within message text                                     |
| `selectSingleTextTransform`           | ✅  |   ✅    | Use the select-single text transform                                            |
| `secureForms`                         | ✅  |   ✅    | Enable secure forms during conversations                                        |
| `enableVideoUpload`                   | ✅  |   ✅    | Allow video attachments/upload                                                  |
| `enableAudioUpload`                   | ✅  |   ✅    | Allow audio attachments/upload                                                  |
| `recommendedUtterancesApi`            | ✅  |   ✅    | Use the recommended-utterances API                                              |
| `useWelcomeUtterances`                | ✅  |   ✅    | Use welcome utterances instead of a static welcome message                      |
| `enableLightningOut`                  | ✅  |   ✅    | Enable the Lightning Out provider                                               |
| `validationFailureChunk`              | ✅  |   ✅    | Enable handling/display of validation-failure chunks                            |
| `citations`                           | ✅  |    —    | Render citations (iOS citation model; distinct from `inlineCitations`)          |
| `compressImage`                       | ✅  |    —    | Compress images before upload                                                   |
| `quickActions`                        | ✅  |    —    | Enable quick actions                                                            |
| `showQueueStatus`                     | ✅  |    —    | Show the queue-status indicator                                                 |
| `voiceContinuesOnBackground`          | ✅  |    —    | Keep voice sessions running when backgrounded                                   |
| `enableVoiceCallKit`                  | ✅  |    —    | Route voice calls through CallKit                                               |
| `enableMocking`                       |  —  |   ✅    | Enable mock responses for testing                                               |
| `enableIterativeCompression`          |  —  |   ✅    | Iteratively compress images before upload (distinct from iOS `compressImage`)   |
| `useFollowUpActionsApi`               |  —  |   ✅    | Use the follow-up-actions API                                                   |
| `enableCopyAndViewMoreFollowUpAction` |  —  |   ✅    | Enable the copy / view-more follow-up action                                    |
| `enableNavAndQuickFollowUpAction`     |  —  |   ✅    | Enable the navigation / quick follow-up action                                  |
| `enableSimpleCitation`                |  —  |   ✅    | Render simple citations (Android citation model; distinct from iOS `citations`) |
| `enableAgentforceCard`                |  —  |   ✅    | Enable the Agentforce card surface                                              |
| `enablePushNotifications`             |  —  |   ✅    | Enable push notifications                                                       |
| `enableClearChat`                     |  —  |   ✅    | Enable the clear-chat affordance                                                |
| `showVoiceBetaBanner`                 |  —  |   ✅    | Show the voice beta banner                                                      |
| `enableMobileBranding`                |  —  |   ✅    | Enable mobile branding                                                          |

> **Semantic pairs kept separate:** iOS `citations` and Android `enableSimpleCitation` address
> related citation behavior but map to distinct native flags, as do iOS `compressImage` and
> Android `enableIterativeCompression`. They are intentionally _not_ merged into one canonical
> flag so each platform's exact behavior stays addressable.

---
