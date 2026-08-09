# Configuring Feature Flags & Voice Options — Employee Agent

**Applies to:** `@salesforce/react-native-agentforce@0.4.0`
(iOS AgentforceSDK 18.26.8 / AgentforceVoice 2.8.2; Android agentforce-sdk 15.130.1; Agentforce Mobile SDK 262.1.2)

Both `featureFlags` and `voiceOptions` are passed to a **single**
`AgentforceService.configure(...)` call, as **top-level siblings of `type`**.

```typescript
import { AgentforceService } from '@salesforce/react-native-agentforce';
import type { FeatureFlags, VoiceOptions } from '@salesforce/react-native-agentforce';

async function startEmployeeAgent() {
  const featureFlags: FeatureFlags = {
    enableMultiAgent: false,       // route across multiple agents in the org
    enableMultiModalInput: false,  // image/attachment input
    enablePDFUpload: false,        // PDF upload
    enableVoice: true,             // REQUIRED for any voice conversation / mic UI
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
  };

  await AgentforceService.configure({
    type: 'employee',
    instanceUrl: 'https://myorg.my.salesforce.com',
    organizationId: '00Dxx0000001234',
    userId: '005xx0000001234',
    agentId: '0Xxxx0000001234',   // omit / leave undefined for multi-agent mode
    // accessToken is optional — the native SDK fetches fresh tokens from the
    // Salesforce Mobile SDK automatically when auth is wired up.
    featureFlags,                 // <-- sibling of `type`
    voiceOptions,                 // <-- sibling of `type`
  });

  await AgentforceService.launchConversation();
}
```

## What each voice field does

| Field | Type | Default | Meaning |
|---|---|---|---|
| `userSilenceTimeoutSeconds` | `number` (seconds) | `undefined` → **never auto-end** | Auto-end after this much continuous user silence. `0` or negative = disabled. |
| `autoEndWhileMuted` | `boolean` | `false` | Whether the silence timer keeps running while muted. No effect if `userSilenceTimeoutSeconds` is unset. |

## Pitfalls to flag

1. **Do not nest `voiceOptions` (or `featureFlags`) inside each other or inside
   any other object.** The bridge only reads `config.voiceOptions` and
   `config.featureFlags` at the top level. Anywhere else is silently ignored —
   no error, it just won't take effect.
2. **`enableVoice: true` is required.** `voiceOptions` only govern *how* a voice
   conversation ends; if voice itself is off, they do nothing and the mic UI
   won't appear.
3. **On v0.4.0, voice options are locked in when the voice client is first built
   for a session.** Reconfiguring an already-configured session with the **same
   `agentId`** reuses the existing client and will **not** pick up changed
   `voiceOptions`. They take effect on: the first `configure()` of a session, an
   `agentId` change, or a cold start / sign-out-and-back-in. **Practical rule:**
   set the values you want at the initial `configure()` before
   `launchConversation()`; to change them at runtime, change the `agentId` or
   have the user sign out and in again.
4. **`featureFlags` is optional but sticky.** If omitted, the SDK reuses
   previously stored flags (or defaults). Pass the full object explicitly to be
   deterministic.
