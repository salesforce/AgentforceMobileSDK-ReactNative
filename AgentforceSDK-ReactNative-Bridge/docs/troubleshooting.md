# Troubleshooting

Common issues and solutions when working with the `react-native-agentforce` bridge.

## Table of Contents

- [Native Module Not Found](#native-module-not-found)
- [Configuration Errors](#configuration-errors)
- [Conversation Not Launching](#conversation-not-launching)
- [Employee Agent Token Issues](#employee-agent-token-issues)
- [Log Forwarding Not Working](#log-forwarding-not-working)
- [Navigation Events Not Received](#navigation-events-not-received)
- [View Provider Not Rendering Custom Views](#view-provider-not-rendering-custom-views)
- [Feature Flag Changes Not Taking Effect](#feature-flag-changes-not-taking-effect)
- [Platform-Specific Build Errors](#platform-specific-build-errors)
- [Hidden Prechat Fields Not Working](#hidden-prechat-fields-not-working)
- [Additional Context Errors](#additional-context-errors)

---

## Native Module Not Found

### Symptom

```
Error: Cannot read property 'configure' of undefined
Warning: [AgentforceService] Native module not available - events will not work
```

Or at runtime:

```
Invariant Violation: TurboModuleRegistry.getEnforcing(...): 'AgentforceModule' could not be found.
```

### Causes and Solutions

**iOS -- Pod not installed or linked:**

1. Verify the pod is in your Podfile:
   ```ruby
   pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
   ```
2. Run `cd ios && pod install`.
3. Open the `.xcworkspace` (not `.xcodeproj`).
4. Clean build: Product > Clean Build Folder (Cmd+Shift+K).

**Android -- Package not registered:**

1. Verify `AgentforcePackage()` is added in `MainApplication`:
   ```kotlin
   override fun getPackages(): List<ReactPackage> = listOf(
       MainReactPackage(),
       AgentforcePackage(),
   )
   ```
2. Verify the library module is included in `settings.gradle`:
   ```groovy
   include ':react-native-agentforce'
   project(':react-native-agentforce').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-agentforce/android')
   ```
3. Verify the dependency in `app/build.gradle`:
   ```groovy
   implementation project(':react-native-agentforce')
   ```
4. Clean build: `cd android && ./gradlew clean`.

**Both platforms -- Metro cache:**

```bash
npx react-native start --reset-cache
```

---

## Configuration Errors

### INVALID_CONFIG: Missing 'type' field

```
Error: Missing 'type' field (must be 'service' or 'employee')
```

**Cause:** The config object passed to `configure()` does not have a `type` field, and the native layer could not parse it.

**Solution:** Add `type: 'service'` or `type: 'employee'` to your config:

```ts
await AgentforceService.configure({
  type: 'service',  // <-- Add this
  serviceApiURL: '...',
  organizationId: '...',
  esDeveloperName: '...',
});
```

Note: The JS bridge normalizes legacy configs (without `type`) automatically, but if the normalization somehow fails, the native layer returns this error.

### INVALID_CONFIG: Missing required fields

```
Error: Missing required Service Agent configuration fields
Error: Missing required Employee Agent configuration fields
```

**Cause:** One or more required fields are missing or empty.

**Solution:** Verify all required fields are present:

- Service Agent: `serviceApiURL`, `organizationId`, `esDeveloperName`
- Employee Agent: `instanceUrl`, `organizationId`, `userId`

### CONFIG_ERROR: 400 from wrong serviceApiURL

```
Error: Start session failed
```

**Cause:** The `serviceApiURL` is incorrect, malformed, or points to the wrong endpoint.

**Solution:**
1. Verify the URL in Setup > Embedded Service Deployments > your deployment > Settings.
2. Ensure the URL starts with `https://`.
3. Check that the URL is the Service API endpoint, not your org's login URL.
4. Common mistake: using `https://myorg.my.salesforce.com` instead of the Service API URL (which often looks like `https://myorg-support.my.salesforce-scrt.com`).

### CONFIG_ERROR: 500 from server

**Cause:** Server-side issue in the Salesforce org.

**Solution:**
1. Verify the agent is active in your org.
2. Check Salesforce Status for outages.
3. Verify the `esDeveloperName` matches exactly (case-sensitive).
4. Check that your org's Agentforce entitlement is active.

---

## Conversation Not Launching

### NOT_CONFIGURED

```
Error: Agent not configured. Call configure() first.
```

**Cause:** `launchConversation()` or `startNewConversation()` was called before `configure()`.

**Solution:** Always call `configure()` first and await its result:

```ts
await AgentforceService.configure({ /* ... */ });
// Now safe to launch
await AgentforceService.launchConversation();
```

### ERROR: Activity not available (Android)

```
Error: Activity not available
```

**Cause:** On Android, there is no current React Activity. This can happen if the app is in the background or the Activity was destroyed.

**Solution:** Only call `launchConversation()` when the app is in the foreground with an active Activity. This typically means calling it from a button press handler, not from a background task.

### LAUNCH_ERROR with session hint (iOS)

```
Error: ... Session start failed (400 = config; 500 = server/org). See docs/TROUBLESHOOTING.md.
```

**Cause:** The SDK could not establish a session. A 400 usually means configuration error; a 500 means server error.

**Solution:** See [Configuration Errors](#configuration-errors) above.

### Blank/Loading Screen

If the conversation Activity/modal opens but shows a loading spinner indefinitely:

1. Check the logger delegate for error messages.
2. Verify network connectivity.
3. On Android, verify `AgentforceConversationActivity` is declared in `AndroidManifest.xml`.
4. Verify the agent is active and deployed in your Salesforce org.

---

## Employee Agent Token Issues

### Token Expired

**Symptom:** Conversation fails to load or shows an auth error after working previously.

**Solution (with Mobile SDK):** The native SDK handles token refresh automatically. If it fails:
1. Check if the user's session is still valid in Salesforce.
2. Call `refreshEmployeeAgentCredentials()` explicitly.
3. If refresh fails, call `logoutEmployeeAgent()` and `loginForEmployeeAgent()` to re-authenticate.

**Solution (direct token):** Obtain a new token from your auth system and call `configure()` again with the new `accessToken`.

### Login Flow Not Appearing (Android)

```
Error: Salesforce SDK not initialized
```

**Cause:** The Mobile SDK's `SalesforceSDKManager` was not initialized before calling `loginForEmployeeAgent()`.

**Solution:** Initialize the Mobile SDK in your Application class before any React Native bridge calls:

```kotlin
SalesforceSDKManager.getInstance().init(this, ...);
```

### Employee Agent Auth Not Supported

```
isEmployeeAgentAuthSupported() returns false
```

**Cause:** Mobile SDK is not included in the build.

**Solution:**
- iOS: Use `pod 'ReactNativeAgentforce/WithMobileSDK'` instead of the default subspec.
- Android: Add `implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"` to your app's `build.gradle`.

---

## Log Forwarding Not Working

### No Logs Received

**Possible causes:**

1. **Delegate set after configure():** The logger should be registered before `configure()` to catch initialization logs.
   ```ts
   // Correct order
   AgentforceService.setLoggerDelegate({ onLog: handleLog });
   await AgentforceService.configure({ /* ... */ });
   ```

2. **NativeEventEmitter not initialized:** If the native module was not found, the event emitter cannot be created. Check for the warning: `[AgentforceService] Native module not available - events will not work`.

3. **Listener timing:** The native module requires JS listeners to be active (`startObserving()` must have been called). The `NativeEventEmitter.addListener()` call triggers this. There can be a brief window after `setLoggerDelegate()` where events are not yet flowing.

4. **Platform-specific:** On Android, the `debug` log level is not emitted. If you are only checking for debug logs, you will see nothing on Android.

### Logs Stop After a While

**Cause:** If `clearLoggerDelegate()` was called (or `destroy()`), log forwarding is disabled.

**Solution:** Ensure the delegate is not being cleared prematurely, e.g., by a React component unmounting.

---

## Navigation Events Not Received

### No Navigation Callbacks

**Possible causes:**

1. **Delegate not registered:** Ensure `setNavigationDelegate()` was called.
2. **Agent does not produce navigation events:** Not all conversations trigger navigation. Test with an agent that includes record links or URLs in its responses.
3. **Forwarding disabled:** Check that `enableNavigationForwarding(true)` was called (this happens automatically when you call `setNavigationDelegate()`).

### Navigation Request Has Unknown Type

**Cause:** The SDK sent a navigation type that is not in the known set.

**Solution:** Always include a `default` case in your navigation handler:

```ts
AgentforceService.setNavigationDelegate({
  onNavigate(request) {
    switch (request.type) {
      case 'record': /* ... */ break;
      case 'link': /* ... */ break;
      default:
        console.log('Unhandled navigation type:', request.type, request);
    }
  },
});
```

The `NavigationRequest` interface uses an index signature for forward compatibility.

---

## View Provider Not Rendering Custom Views

### Custom Component Not Showing

**Possible causes:**

1. **`enableCustomViewProvider` flag not set:** The feature flag must be `true`:
   ```ts
   await AgentforceService.configure({
     type: 'service',
     // ...
     featureFlags: { enableCustomViewProvider: true, /* ... */ },
   });
   ```

2. **Component not registered with AppRegistry:** You must register each component:
   ```ts
   AppRegistry.registerComponent('CustomRichTextView', () => CustomRichTextView);
   ```

3. **Definition string mismatch:** The keys in `componentMap` must exactly match what the SDK sends (e.g., `'copilot/richText'`, not `'richText'`). Use the logger delegate to inspect what definitions the SDK is using.

4. **Empty componentMap:** The native module rejects with `INVALID_CONFIG` if the map is empty.

---

## Feature Flag Changes Not Taking Effect

### Flags Changed But Behavior Unchanged

**Cause:** Feature flags are read at `configure()` time. Changing them via `setFeatureFlags()` only persists them to native storage; the current client does not pick up the changes.

**Solution:** After changing flags, call `configure()` again:

```ts
await AgentforceService.setFeatureFlags({
  enableMultiAgent: true,
  enableMultiModalInput: true,
  enablePDFUpload: true,
  enableVoice: false,
  enableCustomViewProvider: false,
});

// Must reconfigure for changes to take effect
await AgentforceService.configure({ /* same config as before */ });
```

Or, pass the flags inline with `configure()`:

```ts
await AgentforceService.configure({
  type: 'service',
  serviceApiURL: url,
  organizationId: orgId,
  esDeveloperName: devName,
  featureFlags: {
    enableMultiAgent: true,
    enableMultiModalInput: true,
    enablePDFUpload: true,
    enableVoice: false,
    enableCustomViewProvider: false,
  },
});
```

---

## Platform-Specific Build Errors

### iOS: Module 'AgentforceSDK' Not Found

```
No such module 'AgentforceSDK'
```

**Solution:**
1. Run `pod install` in the `ios` directory.
2. Ensure you are using `use_frameworks! :linkage => :static`.
3. Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`.
4. Verify the `AgentforceSDK` pod is resolved in `Podfile.lock`.

### iOS: Bridging Header Issues

If your app is Objective-C only and you get Swift bridging errors:

1. Create an empty Swift file in your project. Xcode will prompt to create a bridging header.
2. Accept the prompt.
3. Build again.

### Android: Maven Repository Not Found

```
Could not resolve com.salesforce.android.agentforcesdk:agentforce-sdk:14.97.1
```

**Solution:** Add the Maven repositories to your **app-level** `build.gradle` (not just the library):

```groovy
repositories {
    maven { url 'https://opensource.salesforce.com/AgentforceMobileSDK-Android/agentforce-sdk-repository' }
    maven { url 'https://s3.amazonaws.com/inapp.salesforce.com/public/android' }
    maven { url 'https://s3.amazonaws.com/salesforce-async-messaging-experimental/public/android' }
}
```

### Android: Desugaring Error

```
Error: coreLibraryDesugaringEnabled is not set
```

**Solution:** Add to your app's `android/app/build.gradle`:

```groovy
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"
}
```

### Android: Compose Version Conflict

If you get Compose version conflicts:

**Solution:** Align the Compose BOM version. The bridge uses `compose-bom:2024.02.00`. If your app uses a different BOM, you may need to exclude the bridge's BOM and rely on your app's.

### Android: Kotlin Version Mismatch

The bridge uses Kotlin 2.2.0. If your app uses a different Kotlin version:

**Solution:** Align the Kotlin version in your project-level `build.gradle`:

```groovy
buildscript {
    ext.kotlin_version = '2.2.0'
}
```

---

## Hidden Prechat Fields Not Working

### Fields Not Sent to Agent (Android)

**Cause:** On Android, the `BridgeHiddenPreChat` class stores fields but does not implement the SDK's delegate interface. This is a known limitation (see [Platform Notes](./platform-notes.md#known-limitations-and-todos)).

**Workaround:** There is currently no workaround on Android. Use iOS for full hidden prechat field support.

### Fields Not Applied (iOS)

**Possible causes:**

1. **Fields registered after launch:** Register fields BEFORE calling `launchConversation()`:
   ```ts
   await AgentforceService.registerHiddenPreChatFields({ ContactId: '003...' });
   await AgentforceService.launchConversation(); // Fields are read during session init
   ```

2. **Field names do not match:** The field developer names must match exactly what the SDK requests. Check your Embedded Service deployment's prechat configuration for the correct field names.

3. **Employee Agent mode:** Hidden prechat fields only apply to Service Agent conversations. They have no effect in Employee Agent mode.

---

## Additional Context Errors

### NO_CONVERSATION

```
Error: No active conversation. Launch conversation first, then set context.
```

**Cause:** `setAdditionalContext()` was called before `launchConversation()`.

**Solution:** Always launch first:

```ts
await AgentforceService.launchConversation();
await AgentforceService.setAdditionalContext({ variables: [...] });
```

### INVALID_CONTEXT

```
Error: Missing or invalid 'variables' array
Error: Variable at index 0 missing 'name' or 'type'
```

**Cause:** The context object is malformed.

**Solution:** Ensure:
- The top-level object has a `variables` key containing an array.
- Each variable has a non-empty `name` (string) and `type` (string).
- The `type` is one of: `Text`, `Number`, `Boolean`, `Date`, `DateTime`, `Json`, `List`, `Money`, `Object`, `Ref`, `Variable`.

### Invalid Type

```
Error: Invalid context variable at index 0: unknown type "text". Valid types: Text, Number, ...
```

**Cause:** Type names are case-sensitive.

**Solution:** Use the exact casing: `'Text'` not `'text'`, `'Boolean'` not `'boolean'`.

---

## Related Documentation

- [Getting Started](./getting-started.md) -- Initial setup guide.
- [Configuration](./configuration.md) -- Config fields and validation.
- [API Reference](./api-reference.md) -- Error codes and method signatures.
- [Platform Notes](./platform-notes.md) -- Known limitations and platform differences.
