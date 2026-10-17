# Configuring Feature Flags & Voice Options — Employee Agent

**Applies to:** `@salesforce/react-native-agentforce@0.8.0`
(Agentforce Mobile SDK 264.0.0; see the bridge `package.json` / podspec for platform pins)

Both `featureFlags` and `voiceOptions` are passed to a **single**
`AgentforceService.configure(...)` call, as **top-level siblings of `type`**.

```typescript
import { AgentforceService } from '@salesforce/react-native-agentforce';
import type { FeatureFlags, VoiceOptions } from '@salesforce/react-native-agentforce';

async function startEmployeeAgent() {
  const featureFlags: FeatureFlags = {
    enableMultiAgent: false, // route across multiple agents in the org
    enableMultiModalInput: false, // image/attachment input
    enablePDFUpload: false, // PDF upload
    enableVoice: true, // REQUIRED for any voice conversation / mic UI
    enableCustomViewProvider: false,
  };

  const voiceOptions: VoiceOptions = {
    // Auto-end the voice conversation after this many seconds of continuous
    // user silence. Omit (or use 0 / a negative value) to never auto-end.
    userSilenceTimeoutSeconds: 30,

    // false (default): muting pauses the silence timer, so a muted user is
    //   never auto-ended.
    // true: muted time counts as silence, so the conversation still auto-ends
    //   after the timeout even if the user muted and walked away.
    autoEndWhileMuted: false,

    // Start closed captions on for first-time voice users. A user's saved
    // caption preference always overrides this value on later sessions.
    defaultClosedCaptionsEnabled: true,
  };

  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: 'https://myorg.my.salesforce.com',
    organizationId: '00Dxx0000001234',
    userId: '005xx0000001234',
    agentId: '0Xxxx0000001234', // omit / leave undefined for multi-agent mode
    // accessToken is optional — the native SDK fetches fresh tokens from the
    // Salesforce Mobile SDK automatically when auth is wired up.
    featureFlags, // <-- sibling of `type`
    voiceOptions, // <-- sibling of `type`
  });

  // Chat (default), combined voice, or dedicated voice-only (requires enableVoice)
  await AgentforceService.launchConversation({ initialMode: 'chat' });
  // await AgentforceService.launchConversation({ initialMode: 'voice' });
  // await AgentforceService.launchConversation({ initialMode: 'voiceOnly' });
}
```

## What each voice field does

| Field                          | Type               | Default                          | Meaning                                                                                                 |
| ------------------------------ | ------------------ | -------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `userSilenceTimeoutSeconds`    | `number` (seconds) | `undefined` → **never auto-end** | Auto-end after this much continuous user silence. `0` or negative = disabled.                           |
| `autoEndWhileMuted`            | `boolean`          | `false`                          | Whether the silence timer keeps running while muted. No effect if `userSilenceTimeoutSeconds` is unset. |
| `defaultClosedCaptionsEnabled` | `boolean`          | `false`                          | Initial closed-caption state for a user with no saved caption preference.                               |

## Pitfalls to flag

1. **Do not nest `voiceOptions` (or `featureFlags`) inside each other or inside
   any other object.** The bridge only reads `config.voiceOptions` and
   `config.featureFlags` at the top level. Anywhere else is silently ignored —
   no error, it just won't take effect.
2. **`enableVoice: true` is required.** `voiceOptions` only govern _how_ a voice
   conversation ends; if voice itself is off, they do nothing and the mic UI
   won't appear.
3. **Voice options are locked in when the voice client is built.** Reconfigure
   with changed voice options before launching the next conversation; the bridge
   rebuilds the client so the next voice session uses them. An active voice
   session always keeps its original options.
4. **`featureFlags` is optional but sticky.** If omitted, the SDK reuses
   previously stored flags (or defaults). Pass the full object explicitly to be
   deterministic.
5. **Caption defaults only affect first-time users.** Once a user enables or
   disables captions in the native Voice UI, the SDK persists that choice and
   ignores later `defaultClosedCaptionsEnabled` values for that user. The native
   SDK's closed-caption feature gate must also be enabled.


## Launch modes (`initialMode`)

Pass `initialMode` to `launchConversation`:

| Mode | Behavior |
| ---- | -------- |
| `'chat'` (default) | Opens the conversation in Chat (text) mode. |
| `'voice'` | Opens in Voice. On iOS this is the combined voice + text experience; on Android it opens the dedicated Voice view. |
| `'voiceOnly'` | Opens the dedicated Voice-only view with no text interaction content (`AgentforceVoiceView` / `AgentforceVoiceContainer`). Added in bridge **0.8.0**. |

Both `'voice'` and `'voiceOnly'` require `enableVoice: true`. When Voice is disabled or unavailable, launch fails with an error.

```typescript
await AgentforceService.launchConversation({
  initialMode: 'voiceOnly',
  voiceCloseBehavior: 'dismissContainer', // iOS only
});
```

## iOS Voice Close Behavior

Use `launchConversation` to select what closing Voice does on iOS:

```typescript
await AgentforceService.launchConversation({
  initialMode: 'voice',
  voiceCloseBehavior: 'dismissContainer',
});
```

`'returnToChat'` is the default and returns the user to the chat transcript.
`'dismissContainer'` dismisses the complete Agentforce presentation when Voice
ends or the user closes it. Android retains its existing Voice close behavior.

## Testing in the sample app

Both options are wired into the Employee tab of the sample app's Settings
screen (`src/screens/SettingsScreen.tsx`):

- **Voice Options** section — toggles `autoEndWhileMuted` and
  `defaultClosedCaptionsEnabled` (persisted in `src/store/VoiceTimeoutStore.ts`,
  applied on the next `configure()` call from Home).
- **Voice Close Behavior** section — a segmented control for
  `voiceCloseBehavior` (persisted in `src/store/VoiceCloseBehaviorStore.ts`,
  applied on the next `launchConversation()` call from Home).


- **Home screen launch picker** — tapping **Employee Agent** prompts for Chat /
  Voice / Voice only when `enableVoice` is on (`src/screens/HomeScreen.tsx`).
- **Session helpers** — Home also exposes `startNewConversation`,
  `closeConversation` (discard history), and `dismissConversation` (keep history).
  Prefer these after End Chat instead of `destroyStorage` or a custom `sessionId`
  (see issue #156).

Both stores are in-memory only and reset on process restart, matching the
existing Voice Timeout settings pattern.
