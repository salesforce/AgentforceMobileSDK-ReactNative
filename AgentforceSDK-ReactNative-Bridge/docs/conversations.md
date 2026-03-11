# Conversations

This document covers how to launch, manage, and enrich Agentforce conversations using the `react-native-agentforce` bridge.

## Table of Contents

- [Launching Conversations](#launching-conversations)
- [Conversation Lifecycle and Persistence](#conversation-lifecycle-and-persistence)
- [Closing Conversations](#closing-conversations)
- [Additional Context](#additional-context)
- [Hidden Prechat Fields](#hidden-prechat-fields)
- [Platform Presentation Differences](#platform-presentation-differences)

---

## Launching Conversations

There are two methods for opening the conversation UI:

### launchConversation()

Opens the conversation UI. If an existing conversation is available, it is preserved and the user can continue where they left off.

```ts
import { AgentforceService } from 'react-native-agentforce';

// Must configure first
await AgentforceService.configure({ /* ... */ });

// Launch -- resumes existing conversation if available
await AgentforceService.launchConversation();
```

This is the recommended method for most use cases. It avoids discarding conversation history and provides a smoother user experience.

### startNewConversation()

Closes any existing conversation and starts fresh. The previous conversation is terminated and a new one is created.

```ts
// Force a fresh conversation
await AgentforceService.startNewConversation();
```

Use this when you explicitly want to discard the previous conversation -- for example, when the user switches accounts, resolves an issue, or navigates to a different context.

### Preconditions

Both methods require:
1. The SDK must be configured via `configure()`. If not, the native module rejects with `NOT_CONFIGURED`.
2. On Android, a current Activity must be available. If not, the promise rejects with `ERROR: Activity not available`.

### Error Handling

```ts
try {
  await AgentforceService.launchConversation();
} catch (error) {
  // error.code can be:
  //   'NOT_CONFIGURED' -- configure() was not called
  //   'LAUNCH_ERROR'   -- SDK failed to start session (iOS)
  //   'ERROR'          -- general error (Android)
  //   'START_NEW_ERROR' -- startNewConversation-specific failure (iOS)
  console.error('Launch failed:', error.message);
}
```

On iOS, if the launch error relates to session creation (e.g. a 400 from an incorrect `serviceApiURL`), the error message includes a hint pointing to configuration documentation.

---

## Conversation Lifecycle and Persistence

### How Conversations are Managed

The bridge maintains a reference to the current conversation on the native side:

- **iOS:** `AgentforceModule` holds `currentConversation: AgentConversation?`. When `launchConversation()` is called, `getOrCreateConversation()` returns the existing conversation if available, or starts a new one.
- **Android:** `AgentforceClientHolder` stores the current conversation as a static field. The `AgentforceConversationActivity` checks this holder first, then falls back to the legacy ViewModel.

### Conversation Reuse

Calling `launchConversation()` multiple times reuses the same conversation object. This means:
- The user sees their previous messages when re-opening the chat.
- The agent retains context from the ongoing session.
- Additional context set earlier is still active.

### When Conversations are Cleared

Conversations are cleared when:
- `startNewConversation()` is called.
- `closeConversation()` is called.
- `resetSettings()` is called (clears everything).
- `setEmployeeAgentId()` is called with a different agent ID than the current one (iOS only).
- Switching modes (e.g. calling `configure()` with `type: 'employee'` after previously configuring `type: 'service'`).

---

## Closing Conversations

### closeConversation()

Terminates the current conversation and dismisses the conversation UI.

```ts
const success = await AgentforceService.closeConversation();
// success is true if the conversation was closed
```

On iOS, this calls `closeConversation()` on the native `AgentConversation` object and then dismisses the presented `UIHostingController`. On Android, the `AgentforceConversationActivity` finishes.

### User-Initiated Close

The user can also close the conversation by:
- **iOS:** Tapping the close button in the chat view's top bar, which triggers the `onContainerClose` callback.
- **Android:** Tapping the back arrow in the `AgentforceConversationActivity` toolbar.

---

## Additional Context

Additional context provides contextual information to the Agentforce agent during a conversation. This helps the agent deliver more personalized and relevant responses.

### Important: Call After Launching

`setAdditionalContext()` **must be called after `launchConversation()` or `startNewConversation()`**. The context is set on the active conversation object, which does not exist until a conversation is launched. If called without an active conversation, the native module rejects with `NO_CONVERSATION`.

### Basic Usage

```ts
// Step 1: Launch conversation
await AgentforceService.launchConversation();

// Step 2: Set context
await AgentforceService.setAdditionalContext({
  variables: [
    { name: 'userId', type: 'Text', value: '005xx0000001234' },
    { name: 'accountId', type: 'Text', value: '001xx0000001234' },
    { name: 'priority', type: 'Text', value: 'high' },
  ],
});
```

### Context Variable Types

```ts
type AgentforceContextVariableType =
  | 'Text'      // string value
  | 'Number'    // numeric value (double on iOS)
  | 'Boolean'   // true/false
  | 'Date'      // ISO date string (e.g. '2026-03-11')
  | 'DateTime'  // ISO datetime string (e.g. '2026-03-11T15:30:00.000Z')
  | 'Json'      // JSON string or object
  | 'List'      // array value
  | 'Money'     // numeric monetary value
  | 'Object'    // key-value object
  | 'Ref'       // reference value
  | 'Variable'; // generic variable
```

### AgentforceContextVariable Interface

```ts
interface AgentforceContextVariable {
  name: string;                    // Variable name/key
  type: AgentforceContextVariableType; // Type (case-sensitive)
  description?: string;            // Optional description (Android only, ignored on iOS)
  value?: string | number | boolean | Record<string, unknown> | unknown[] | null;
}
```

### Full Type Examples

```ts
await AgentforceService.setAdditionalContext({
  variables: [
    // Text
    { name: 'customerName', type: 'Text', value: 'Jane Smith' },

    // Number
    { name: 'accountBalance', type: 'Number', value: 15234.56 },

    // Boolean
    { name: 'isVIP', type: 'Boolean', value: true },

    // Date (ISO format)
    { name: 'memberSince', type: 'Date', value: '2024-01-15' },

    // DateTime (ISO format with time)
    { name: 'lastLogin', type: 'DateTime', value: '2026-03-11T10:30:00.000Z' },

    // Object (key-value map)
    {
      name: 'shippingAddress',
      type: 'Object',
      value: {
        street: '123 Main St',
        city: 'San Francisco',
        state: 'CA',
        zip: '94105',
      },
    },

    // List (array)
    {
      name: 'recentOrderIds',
      type: 'List',
      value: ['ORD-001', 'ORD-002', 'ORD-003'],
    },

    // Money
    { name: 'creditLimit', type: 'Money', value: 50000 },

    // With description (Android only)
    {
      name: 'caseId',
      type: 'Text',
      value: '500xx0000001234',
      description: 'The current support case ID',
    },
  ],
});
```

### Validation

The bridge performs client-side validation before sending to native:

1. The `context` object must have a `variables` array.
2. Each variable must have a non-empty `name` (string) and `type` (string).
3. The `type` must be one of the known types listed above.

If validation fails, a synchronous `Error` is thrown (before the native call).

### Platform Differences

| Aspect | iOS | Android |
|---|---|---|
| Native type | `AgentforceVariable` with `JSEncodableValue` enum | `CopilotContextVariable` / `CopilotAdditionalContext` |
| Type names | Case-sensitive (passed as string) | Case-sensitive (must match SDK enum) |
| `description` field | Ignored (not in iOS `AgentforceVariable`) | Supported |
| Value conversion | Recursive `convertToJSEncodableValue()` handles string, number, boolean, array, dict | ReadableMap/ReadableArray conversion |

### Error Codes

| Code | Meaning |
|---|---|
| `INVALID_CONTEXT` | Missing or invalid `variables` array, or a variable is missing `name`/`type` |
| `NO_CONVERSATION` | No active conversation -- call `launchConversation()` first |
| `CONTEXT_ERROR` | The native SDK rejected the context (e.g. network error, invalid variable) |

---

## Hidden Prechat Fields

Hidden prechat fields let you pass values to the Service Agent prechat form without displaying them to the user. Common use cases include pre-populating a `ContactId`, `AccountId`, or session token.

### Important: Service Agent Only

Hidden prechat fields only apply to Service Agent conversations. They have no effect for Employee Agent conversations.

### Important: Call Before Launch

Register hidden prechat fields **before** calling `launchConversation()`. The native hidden prechat delegate reads these fields when the SDK initializes a session.

### Usage

```ts
// Step 1: Register hidden prechat fields
await AgentforceService.registerHiddenPreChatFields({
  ContactId: '003xx0000001234AAA',
  AccountId: '001xx0000005678AAA',
  Subject: 'Mobile App Support Request',
});

// Step 2: Launch conversation
await AgentforceService.launchConversation();
```

### Reading Current Fields

```ts
const fields = await AgentforceService.getHiddenPreChatFields();
console.log(fields); // { ContactId: '003xx...', AccountId: '001xx...', Subject: 'Mobile...' }
```

### Clearing Fields

```ts
await AgentforceService.clearHiddenPreChatFields();
// Equivalent to: await AgentforceService.registerHiddenPreChatFields({});
```

### How It Works

- **iOS:** The bridge holds a `BridgeHiddenPreChat` instance that implements `AgentforceHiddenPreChatFieldDelegate`. When the SDK asks for hidden field values, the delegate returns only the fields that the SDK requests (filtering stored fields by the requested field names). The delegate is set on the `AgentforceClient` as `hiddenPreChatFieldDelegate`.
- **Android:** The `BridgeHiddenPreChat` class stores the fields but is **not yet wired to the SDK delegate** (marked as TODO in the source). Fields are stored and retrievable via `getHiddenPreChatFields()`, but they will not be sent to the native SDK until the delegate integration is complete.

### Platform Status

| Platform | Status |
|---|---|
| iOS | Fully functional -- delegate wired to AgentforceClient |
| Android | Fields stored but NOT sent to SDK (TODO: implement delegate) |

---

## Platform Presentation Differences

### iOS

The conversation UI is presented as a **full-screen modal** using `UIHostingController`:

```swift
let hostingController = UIHostingController(rootView: chatView)
hostingController.modalPresentationStyle = .fullScreen
hostingController.modalTransitionStyle = .coverVertical
rootViewController.present(hostingController, animated: true)
```

- The chat view is a SwiftUI view created by `AgentforceClient.createAgentforceChatView()`.
- The SDK's built-in top bar is shown (`showTopBar: true`).
- Dismissal triggers `onContainerClose`, which calls `dismiss(animated: true)` on the root view controller.

### Android

The conversation UI is launched as a **separate Activity**:

```kotlin
val intent = Intent(activity, AgentforceConversationActivity::class.java)
activity.startActivity(intent)
```

- `AgentforceConversationActivity` is a `ComponentActivity` that uses Jetpack Compose.
- It displays a Material 3 `Scaffold` with a Salesforce-blue top app bar.
- The Agentforce SDK's `AgentforceConversationContainer` composable is rendered inside the scaffold.
- The user closes the conversation by tapping the back arrow, which calls `finish()`.

### Visual Differences

| Aspect | iOS | Android |
|---|---|---|
| Presentation | Full-screen modal | New Activity |
| Top bar | SDK-provided | Custom Material 3 TopAppBar (Salesforce blue) |
| Close mechanism | `onContainerClose` callback | Back arrow / system back |
| Transition | Cover vertical animation | Standard activity transition |

---

## Related Documentation

- [Configuration](./configuration.md) -- Setting up Service and Employee Agent configs.
- [Delegates](./delegates.md) -- Logger, navigation, and view provider delegates.
- [API Reference](./api-reference.md) -- Complete method signatures.
- [Platform Notes](./platform-notes.md) -- iOS and Android specifics.
- [Examples](./examples.md) -- Full working code examples.
