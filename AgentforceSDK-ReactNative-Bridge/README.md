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

### Appearance Customization

Pass an optional serializable `appearance` object to `configure()` to override Agentforce's
native colors, icons, visible labels, typography, and theme mode. Unspecified values preserve
the native SDK's defaults (or server branding when enabled).

```typescript
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://example.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  appearance: {
    themeMode: 'system',
    lightColors: { chatBackground: '#FFFFFF', accent1: '#0176D3' },
    darkColors: { chatBackground: '#181818', accent1: '#78B9FF' },
    icons: {
      aiAgent: {
        ios: { light: 'BrandAgentLight', dark: 'BrandAgentDark' },
        android: { light: 'brand_agent_light', dark: 'brand_agent_dark' },
      },
    },
    displayNames: { inputTextPlaceholder: 'Ask Acme Assistant' },
    typography: { fontFamily: { type: 'generic', family: 'serif' } },
  },
});
```

- Colors must be `#RRGGBB` or `#AARRGGBB`.
- Icon keys and display-name keys are native Agentforce token names such as `aiAgent`,
  `actionSend`, `inputTextPlaceholder`, and `preChatTitle`. Unsupported keys reject
  `configure()` with a platform-specific error.
- `aiAgent` is the SDK's avatar/logo slot. Omit it to keep the default Agentforce asset.
- iOS icon values name image assets in the host application's asset catalog. Android values name
  host `drawable` resources. Keep resources from being removed by Android resource shrinking.
- Generic fonts support `default`, `sans-serif`, `serif`, `monospace`, and `cursive`. Bundled
  fonts use a registered iOS font name and Android `font` resource names per numeric weight.
- Typography style keys are native SDK token names. For example, Android uses
  `bodyFontScaleNeg2Regular` through `displayFontScale8Light`; each accepts `size`, `weight`
  (100-900), and an optional font family. Unsupported keys reject `configure()`.
- `agentLabel` remains the Employee Agent chat-header override and takes precedence over
  appearance-managed header text.
- The installed iOS SDK cannot combine a forced `themeMode` with sparse appearance overrides;
  use one or the other on iOS. Android supports both together.

### Core Methods

**Configure and launch:**

```typescript
import { AgentforceService } from '@salesforce/react-native-agentforce';

await AgentforceService.configure(config);
await AgentforceService.launchConversation();
```

**Additional Context:**
Provide context at launch when the initial agent response needs it:

```typescript
await AgentforceService.launchConversation({
  additionalContext: {
    variables: [
      { name: 'userId', type: 'Text', value: '005xx0000001234' },
      { name: 'accountId', type: 'Text', value: '001xx0000001234' },
      { name: 'priority', type: 'Text', value: 'high' },
      { name: 'score', type: 'Number', value: 95.5 },
      { name: 'isVIP', type: 'Boolean', value: true },
      { name: 'createdDate', type: 'DateTime', value: '2026-03-06T10:00:00Z' },
    ],
  },
});
```

Call `setAdditionalContext()` after launch to update context on an active conversation.

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

### Custom Splash Screen

Supply a custom welcome ("splash") screen shown on top of the conversation before
the user has interacted with an agent. The chat UI is fully native, so the splash
content is a React Native component hosted inside the native conversation view.
The SDK asks for a splash when the chat view is first shown and again whenever the
active agent changes, so you can show a splash for only some agents.

The splash renders in the conversation content region — below the top bar and above
the input bar (both stay interactive) — and moves up with the keyboard. It is
dismissed (animated away to reveal the conversation) when the user either chooses a
starter utterance or sends text from the input bar.

```typescript
import { AppRegistry, View, Text, Button } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

// 1. A splash component. It receives { agentId } as an initial prop and reports
//    the chosen utterance back to the SDK.
function WelcomeSplash({ agentId }: { agentId: string }) {
  return (
    <View>
      <Text>Welcome! How can I help?</Text>
      <Button
        title="Track my order"
        onPress={() => AgentforceService.selectSplashScreenUtterance(agentId, 'Track my order')}
      />
    </View>
  );
}

// 2. Register it with a unique component name.
AppRegistry.registerComponent('WelcomeSplash', () => WelcomeSplash);

// 3. Map agent IDs to that component name. Use '*' for a default that applies to
//    every agent without an explicit entry.
AgentforceService.setSplashScreenDelegate({
  componentMap: {
    '0XxABC0000001234': 'WelcomeSplash',
    '*': 'WelcomeSplash',
  },
});
```

When the user taps a suggested utterance, call
`AgentforceService.selectSplashScreenUtterance(agentId, utterance)` — the SDK
animates the splash away and sends the utterance into the conversation (running it
through `modifyUtterance` if a UI delegate is set). Call
`AgentforceService.clearSplashScreenDelegate()` to remove it.

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

`InternalFlags` is a free-form `Record<string, boolean>` — a map of flag name → boolean passed
straight through to the native SDK. **The keys are the native SDK's own internal-flag names**
(e.g. `enableTokenStreaming`, `enableInlineCitation`), not bridge-defined aliases. The bridge
does not enumerate, rename, or validate them.

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

// Persist flags; applied on the next configure(). Keys are the native SDK's own flag names.
await AgentforceService.setInternalFlags({
  enableTokenStreaming: true,
  enableClosedCaptions: true,
});

// Or pass them inline on the config object
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  internalFlags: { enableTokenStreaming: true },
});
```

**Semantics:**

- Values are booleans. An omitted flag falls back to the SDK's own default — a missing key is
  **not** the same as `false`.
- `getInternalFlags()` returns only the flags that were explicitly set (an empty object if none).
  It reflects stored values, not the running SDK's live state.
- Keys are the native SDK's own flag names, and the iOS and Android SDKs each recognize a
  **different set**. Setting a key the running platform's SDK doesn't recognize is a silent
  no-op — the value is stored and forwarded, but that SDK ignores unknown keys. Consult the
  native AgentforceSDK's internal-flag documentation for the keys valid on each platform.

## Voice Options

Configure voice-session behavior alongside the agent configuration:

```typescript
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
  voiceOptions: {
    userSilenceTimeoutSeconds: 30,
    autoEndWhileMuted: false,
    defaultClosedCaptionsEnabled: true,
  },
});
```

`defaultClosedCaptionsEnabled` applies only when the user has not previously
chosen a closed-caption state. The native SDK persists a user's explicit caption
choice, which always takes precedence over the configured default.

On iOS, `launchConversation` also accepts `voiceCloseBehavior: 'returnToChat' |
'dismissContainer'`. The default, `'returnToChat'`, preserves the existing
integrated Voice behavior. `'dismissContainer'` dismisses the entire Agentforce
presentation when Voice closes. Android retains its existing Voice close behavior.

---

### Custom Voice Transcription (Speech-to-Text / Whisper)

The Agentforce bridge supports custom voice recording and third-party Speech-to-Text (STT) services (such as OpenAI Whisper, Azure Speech, or Google Cloud Speech) via a clean, decoupled callback architecture.

#### Background & Architecture
- **iOS:** In recent releases of the Agentforce iOS SDK, the microphone button is hidden unless a custom `speechRecognizer` conforming to `AgentforceSpeechTranscriber` is provided.
- **Android:** Built-in speech recognition can be unavailable or unreliable across diverse OEM Android devices. To display the microphone button and capture speech, a custom `AgentforceVoiceManaging` implementation and `enableSpeechToText(true)` are required.
- **Decoupled Architecture:** Instead of hardcoding third-party API keys, networking, and multipart requests deep inside native Swift and Kotlin code:
  1. **Native recording layer:** Uses native platform audio recording (`AVAudioRecorder` on iOS, `MediaRecorder` on Android) to capture speech locally into a compact `.m4a` file (AAC 16kHz mono) when the user taps the microphone button.
  2. **React Native callback events:** Emits `onSpeechRecordingStarted` when recording begins and `onSpeechAudioRecorded({ audioUri, filePath, requestId })` when the user finishes speaking.
  3. **React Native transcription:** The consuming React Native app receives the audio file URI, executes the transcription request (e.g. OpenAI Whisper API) using standard `fetch` / `FormData` in TypeScript/JavaScript, and passes the transcript back into Agentforce via `AgentforceService.setSpeechTranscript(transcript)`.
  4. **Zero Impact on Default Behavior:** Governed by `customVoiceTranscribe: true`. When omitted or `false`, the SDK remains on 100% original code.

#### Enabling Custom Voice Transcription

Specify `customVoiceTranscribe: true` either at the top-level of `AgentforceService.configure({...})` or inside `voiceOptions: {...}`:

```typescript
await AgentforceService.configure({
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: credentials.userId,
  agentId: '0Xx...',
  accessToken: credentials.accessToken,
  customVoiceTranscribe: true, // <-- Activates custom voice transcriber
});
```

#### Required App Permissions

- **Android:**
  Ensure `RECORD_AUDIO` permission is declared in your app's `android/app/src/main/AndroidManifest.xml` (the bridge's library manifest also merges it automatically):
  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  ```

- **iOS:**
  Ensure `NSMicrophoneUsageDescription` is present in your app's `ios/<App>/Info.plist`:
  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>Need microphone access for Voice to Text functionality</string>
  ```

#### React Native Integration Example

In your React Native component, subscribe to `onSpeechAudioRecorded` and inject the transcript via `AgentforceService.setSpeechTranscript`:

```typescript
import React, { useEffect } from 'react';
import {
  AgentforceService,
  SpeechAudioRecordedEvent,
} from '@salesforce/react-native-agentforce';

export function AgentforceChatScreen() {
  useEffect(() => {
    // 1. Listen for audio recording completion event
    const subscription = AgentforceService.onSpeechAudioRecorded(
      async ({ audioUri, requestId }: SpeechAudioRecordedEvent) => {
        try {
          console.log('[Agentforce] Audio recording received:', audioUri);

          // 2. Prepare FormData for Whisper API or any custom STT endpoint
          const formData = new FormData();
          formData.append('file', {
            uri: audioUri,
            type: 'audio/m4a',
            name: 'agentforce_speech.m4a',
          } as any);
          formData.append('model', 'whisper-1');

          const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${OPENAI_API_KEY}`,
            },
            body: formData,
          });

          const data = await response.json();
          const transcript = data?.text || '';

          // 3. Inject transcript directly into the Agentforce chat input prompt
          await AgentforceService.setSpeechTranscript(transcript, requestId);
          console.log('[Agentforce] Transcript populated successfully:', transcript);
        } catch (error) {
          console.error('[Agentforce] Speech transcription error:', error);
          // Pass empty string on failure to release the transcribing UI state
          await AgentforceService.setSpeechTranscript('', requestId);
        }
      },
    );

    // Optional: Listen for recording start to trigger UI feedback or haptics
    const recordingStartedSub = AgentforceService.onSpeechRecordingStarted(() => {
      console.log('[Agentforce] Speech recording started');
    });

    return () => {
      subscription?.remove();
      recordingStartedSub?.remove();
    };
  }, []);

  return null;
}
```

---
