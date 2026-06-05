# Chat presentation reference (React Native)

**The chat UI is native, not a React Native component.** When you call `AgentforceService.launchConversation()`, the iOS/Android SDK presents its own chat surface (modally on iOS, as a fragment/activity on Android). You **cannot** embed `AgentforceConversationContainer` (iOS SwiftUI) or its Android Compose equivalent inside a React Native view tree.

That means presentation choices on RN are limited to **where the launch trigger lives** in your app.

## Patterns

### Prominent button on the Home screen (recommended default)

Best for "open the assistant" CTAs. Visible, discoverable, easy to gate on configuration state.

```tsx
import { AgentforceService } from 'react-native-agentforce';

function HomeScreen() {
  const onLaunch = async () => {
    if (!(await AgentforceService.isConfigured())) {
      Alert.alert('Configure Agentforce in Settings first');
      return;
    }
    await AgentforceService.launchConversation();
  };

  return (
    <View>
      {/* ...your home content */}
      <TouchableOpacity onPress={onLaunch}>
        <Text>Ask the agent</Text>
      </TouchableOpacity>
    </View>
  );
}
```

### Header / nav bar icon button

Tucked into a `headerRight` so the chat is always one tap away regardless of which screen the user is on.

```tsx
<Stack.Screen
  name="Home"
  component={HomeScreen}
  options={({ navigation }) => ({
    headerRight: () => (
      <TouchableOpacity onPress={() => AgentforceService.launchConversation()}>
        <Icon name="chat" />
      </TouchableOpacity>
    ),
  })}
/>
```

### Auto-launch on first app open

Useful for assistant-first apps where the chat IS the product. Launch immediately after `configure()` resolves.

```tsx
useEffect(() => {
  configureAgentforce().then(() => AgentforceService.launchConversation());
}, []);
```

Avoid this pattern in apps that have other primary content — auto-launch is a heavy interruption if the user opened the app for something else.

### Programmatic launch from a deep link

If the consumer has deep linking via `react-native-deep-linking` or React Navigation's `linking` config:

```tsx
const linking = {
  prefixes: ['myapp://'],
  config: { screens: { Home: 'home' } },
  subscribe(listener) {
    return Linking.addEventListener('url', async ({ url }) => {
      if (url.endsWith('/agent')) {
        await AgentforceService.launchConversation();
      }
      listener(url);
    });
  },
};
```

## What about embedding the chat inline?

Not supported by the current bridge. If you need the chat to live inside a tab or panel within your RN UI:

- iOS: would require exposing the SwiftUI `AgentforceChatView` via a `RCTViewManager` and bridging Compose views on Android. Neither is currently in the bridge.
- Workaround: launch the conversation modally via `launchConversation()` and use `closeConversation()` to dismiss it programmatically. Not as smooth as inline embedding.

If the consumer specifically asks for inline embedding, surface this as a known limitation and ask whether they want to:

1. Use the modal launch trigger instead.
2. Build their own custom view manager (out of scope for this skill).
3. File a feature request in the SDK repo.

## Gating the launch on configuration state

Always check `isConfigured()` before launching. The first launch will fail otherwise:

```tsx
const [configured, setConfigured] = useState(false);

useEffect(() => {
  AgentforceService.isConfigured().then(setConfigured);
}, []);

return (
  <Button
    title="Ask the agent"
    disabled={!configured}
    onPress={() => AgentforceService.launchConversation()}
  />
);
```

## Closing programmatically

Rare, but if you need to dismiss the chat from JS (e.g. on logout):

```ts
await AgentforceService.closeConversation();
```

The SDK's built-in close button is the normal user-initiated path; `closeConversation()` is for cleanup scenarios.
