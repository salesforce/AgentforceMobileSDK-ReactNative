# Platform Notes

This document covers platform-specific details for iOS and Android, including build setup, native architecture, feature parity, and known limitations.

## Table of Contents

- [iOS Specifics](#ios-specifics)
- [Android Specifics](#android-specifics)
- [Feature Parity Table](#feature-parity-table)
- [Known Limitations and TODOs](#known-limitations-and-todos)

---

## iOS Specifics

### CocoaPods Setup

The bridge is distributed as a CocoaPods podspec (`ReactNativeAgentforce.podspec`) with two subspecs:

| Subspec | Dependencies | Use Case |
|---|---|---|
| `Core` (default) | `React-Core`, `AgentforceSDK` | Service Agent only |
| `WithMobileSDK` | `Core` + `SalesforceSDKCore` | Service Agent + Employee Agent auth |

```ruby
# Service Agent only
pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'

# With Employee Agent auth
pod 'ReactNativeAgentforce/WithMobileSDK', :path => '../node_modules/react-native-agentforce/ios'
```

Requirements:
- iOS deployment target: 15.0+
- Swift 5.0+
- `use_frameworks! :linkage => :static` (required by AgentforceSDK)

### Source File Layout

```
ios/
  ReactNativeAgentforce.podspec
  Agentforce/
    AgentforceModule.swift          -- Main native module (RCTEventEmitter subclass)
    AgentforceUICoordinator.swift   -- UI coordination helpers
    AgentforceVoiceDelegate.swift   -- Voice interaction delegate
    BridgeLogger.swift              -- Log forwarding bridge
    BridgeNavigation.swift          -- Navigation event bridge
    BridgeHiddenPreChat.swift       -- Hidden prechat field delegate
    ServiceAgentManager.swift       -- Legacy Service Agent manager
    ServiceAgentCredentialProvider.swift
    Models/
      AgentMode.swift               -- Service/Employee mode enum
    Providers/
      UnifiedCredentialProvider.swift -- Credential provider for both modes
      BridgeViewProvider.swift       -- Custom view provider bridge
```

### Swift Interop and Conditional Compilation

The bridge uses `#if canImport(SalesforceSDKCore)` to conditionally include Mobile SDK code:

```swift
#if canImport(SalesforceSDKCore)
import SalesforceSDKCore
// Mobile SDK-specific code (e.g., reading current user credentials)
#endif
```

This allows the same source files to compile with or without the `WithMobileSDK` subspec.

### Native Module Registration

`AgentforceModule` is a subclass of `RCTEventEmitter`:

```swift
@objc(AgentforceModule)
class AgentforceModule: RCTEventEmitter {
    override static func requiresMainQueueSetup() -> Bool { return true }
    override func supportedEvents() -> [String]! {
        return ["onLogMessage", "onNavigationRequest"]
    }
}
```

### UI Presentation

Conversations are presented as full-screen modals:

```swift
let hostingController = UIHostingController(rootView: chatView)
hostingController.modalPresentationStyle = .fullScreen
hostingController.modalTransitionStyle = .coverVertical
rootViewController.present(hostingController, animated: true)
```

The chat view is a SwiftUI view created by the SDK's `AgentforceClient.createAgentforceChatView()`. The `showTopBar: true` parameter includes the SDK's built-in navigation bar.

### UserDefaults Keys

| Key | Type | Purpose |
|---|---|---|
| `AgentforceFF_enableMultiAgent` | `Bool` | Multi-agent feature flag |
| `AgentforceFF_enableMultiModalInput` | `Bool` | Multi-modal input feature flag |
| `AgentforceFF_enablePDFUpload` | `Bool` | PDF upload feature flag |
| `AgentforceFF_enableVoice` | `Bool` | Voice feature flag |
| `EmployeeAgentId` | `String` | Stored Employee Agent ID |

Note: If a UserDefaults key does not exist (never been set), the bridge uses the hard-coded default (e.g., `enableMultiAgent` defaults to `true`, all others to `false`).

### Context Variable Handling

iOS uses the SDK's `AgentforceVariable` type with `JSEncodableValue` enum for values:

```swift
let variable = AgentforceVariable(
    name: name,   // String
    type: type,   // String (e.g. "Text", "Number")
    value: value  // JSEncodableValue? (.string, .number, .boolean, .array, .object)
)
```

The `description` field from the JS config is ignored on iOS -- `AgentforceVariable` does not have a description parameter.

### Hidden Prechat Delegate

`BridgeHiddenPreChat` implements the SDK's `AgentforceHiddenPreChatFieldDelegate` protocol. When the SDK requests hidden field values, the delegate filters the stored fields by the requested field names and returns only matching values. The delegate is set as `agentforceClient?.hiddenPreChatFieldDelegate = bridgeHiddenPreChat` and must be strongly retained (the client holds a weak reference).

---

## Android Specifics

### Gradle Setup

The bridge is an Android library module. Key settings from `android/build.gradle`:

```groovy
android {
    namespace = "com.salesforce.android.reactagentforce"
    compileSdk 36
    defaultConfig {
        minSdkVersion 29
        targetSdkVersion 36
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }
    buildFeatures {
        buildConfig = true
        compose = true
    }
}
```

### Maven Repositories

The following repositories must be available (added in the bridge's `build.gradle` and potentially needed in your app's `build.gradle`):

```groovy
repositories {
    google()
    mavenCentral()
    maven { url 'https://jitpack.io' }
    maven { url 'https://opensource.salesforce.com/AgentforceMobileSDK-Android/agentforce-sdk-repository' }
    maven { url 'https://s3.amazonaws.com/inapp.salesforce.com/public/android' }
    maven { url 'https://s3.amazonaws.com/salesforce-async-messaging-experimental/public/android' }
}
```

### Key Dependencies

| Dependency | Scope | Version | Purpose |
|---|---|---|---|
| `agentforce-sdk` | api | 14.97.1 | Core Agentforce SDK |
| `SalesforceReact` | compileOnly | 13.1.1 | Mobile SDK (host app provides at runtime) |
| `react-android` | implementation | (from RN) | React Native Android |
| `compose-bom` | implementation | 2024.02.00 | Jetpack Compose BOM |
| `desugar_jdk_libs` | coreLibraryDesugaring | 2.1.5 | Java 8+ API desugaring |

### Source File Layout

```
android/src/main/java/com/salesforce/android/reactagentforce/
  AgentforcePackage.kt              -- ReactPackage registration
  AgentforceModule.kt               -- Main native module (@ReactMethod)
  AgentforceConversationActivity.kt -- Compose Activity for conversation UI
  AgentforceClientHolder.kt         -- Static holder for client/conversation
  AgentforceClientCameraUriProvider.kt -- Camera URI provider
  AgentforceClientPermissions.kt    -- Runtime permission helpers
  ServiceAgentViewModel.kt          -- Legacy ViewModel
  EmployeeAgentAuthBridge.kt        -- Mobile SDK auth bridge
  BridgeLogger.kt                   -- Log forwarding
  BridgeNavigation.kt               -- Navigation event forwarding
  BridgeHiddenPreChat.kt            -- Hidden prechat field storage (TODO: wire delegate)
  models/
    AgentMode.kt                    -- Service/Employee mode sealed class
  providers/
    UnifiedCredentialProvider.kt    -- Credential provider for both modes
    BridgeViewProvider.kt           -- Custom view provider bridge
```

### Native Package Registration

`AgentforcePackage` registers native modules dynamically:

```kotlin
class AgentforcePackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        val modules = mutableListOf<NativeModule>(AgentforceModule(reactContext))
        if (isMobileSdkAvailable()) {
            modules.add(EmployeeAgentAuthBridge(reactContext))
        }
        return modules
    }
}
```

The Mobile SDK check uses reflection: `Class.forName("com.salesforce.androidsdk.app.SalesforceSDKManager")`. If the class is not found, `EmployeeAgentAuthBridge` is not registered (Employee Agent auth is disabled gracefully).

### Conversation Activity

`AgentforceConversationActivity` is a `ComponentActivity` using Jetpack Compose:

```kotlin
class AgentforceConversationActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startConversationIfNeeded()
        setContent {
            MaterialTheme {
                AgentforceConversationScreen(viewModel, onClose = { finish() })
            }
        }
    }
}
```

The conversation is started by calling `client.startAgentforceConversation(agentId)` on `AgentforceClientHolder`. The SDK's `AgentforceConversationContainer` composable is rendered inside a Material 3 Scaffold with a Salesforce-blue top app bar.

You must declare this Activity in your `AndroidManifest.xml`:

```xml
<activity
    android:name="com.salesforce.android.reactagentforce.AgentforceConversationActivity"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"
    android:windowSoftInputMode="adjustResize" />
```

### SharedPreferences

| Preferences File | Keys | Purpose |
|---|---|---|
| `AgentforceFeatureFlags` | `enableMultiAgent`, `enableMultiModalInput`, `enablePDFUpload`, `enableVoice`, `enableCustomViewProvider` | Feature flags |
| `AgentforceEmployeeAgent` | `employee_agent_id` | Stored Employee Agent ID |

### Camera and Permissions

The bridge includes helper classes for Android-specific concerns:

- **`AgentforceClientCameraUriProvider`** -- Provides `content://` URIs for camera captures via `FileProvider`.
- **`AgentforceClientPermissions`** -- Handles runtime permission requests for camera and microphone.

These are used internally when `enableMultiModalInput` or `enableVoice` flags are enabled.

### Context Variable Handling

Android uses the SDK's `CopilotContextVariable` and `CopilotAdditionalContext` types. Type names are case-sensitive strings matching the SDK's enum values (e.g., `"Text"`, `"Number"`).

The `description` field on context variables is supported on Android (passed to `CopilotContextVariable`).

---

## Feature Parity Table

| Feature | iOS | Android | Notes |
|---|---|---|---|
| Service Agent | Yes | Yes | |
| Employee Agent | Yes | Yes | |
| configure() | Yes | Yes | iOS uses `configureWithConfig()`, Android uses `configure()` |
| launchConversation() | Yes | Yes | |
| startNewConversation() | Yes | Yes | |
| closeConversation() | Yes | Yes | |
| Logger delegate | Yes | Yes | iOS emits 'debug' level; Android does not |
| Navigation delegate | Yes | Yes | |
| View provider delegate | Yes | Yes | |
| Additional context | Yes | Yes | `description` field supported on Android only |
| Hidden prechat fields | Yes (functional) | Stored only | Android: TODO -- delegate not wired to SDK |
| Feature flags | Yes | Yes | Android also has `enableCustomViewProvider` in SharedPreferences |
| Employee Agent auth (Mobile SDK) | Yes (WithMobileSDK subspec) | Yes (SalesforceReact dep) | |
| Voice input | Yes | Yes | Requires `enableVoice` flag and mic permission |
| Multi-modal input | Yes | Yes | Requires `enableMultiModalInput` flag and camera permission |
| PDF upload | Yes | Yes | Requires `enablePDFUpload` flag |

---

## Known Limitations and TODOs

### Android: Hidden Prechat Fields Not Wired

The `BridgeHiddenPreChat` class on Android stores fields set via `registerHiddenPreChatFields()` but does **not** implement the SDK's `AgentforceHiddenPreChatFieldDelegate` interface. The fields are stored in memory and can be retrieved via `getHiddenPreChatFields()`, but they are not passed to the native SDK during session initialization.

The source code contains this TODO:

```
TODO: Implement AgentforceHiddenPreChatFieldDelegate interface.
See BridgeHiddenPreChat.swift (iOS) for the reference implementation.
```

**Workaround:** None currently. If you need hidden prechat fields, iOS is the only fully supported platform.

### iOS: enableCustomViewProvider Not in UserDefaults

On iOS, the `enableCustomViewProvider` feature flag is not persisted in UserDefaults (it is not included in the `featureFlagKeys` tuple). It is only read from the config's `featureFlags` dictionary. On Android, it is persisted in SharedPreferences.

### Mode Switching Cleanup

When switching between Service Agent and Employee Agent modes (calling `configure()` with a different `type`), the previous client is cleaned up. However, this does not reset persisted config values from the other mode. For a complete reset, call `resetSettings()` before reconfiguring.

### Legacy Code Paths

Both platforms maintain legacy code paths (`ServiceAgentManager` on iOS, `ServiceAgentViewModel` on Android) for backward compatibility with the old configuration API. These paths are triggered when the unified `AgentforceClient` is not initialized. New code should always use the `type`-based configuration.

### Log Level Differences

iOS emits `debug`, `info`, `warn`, and `error` log levels. Android emits only `info`, `warn`, and `error`. If you filter or process logs by level, account for this difference.

### Thread Safety

- **iOS:** `BridgeLogger` and `BridgeNavigation` use the module's `listenerLock` (NSLock) for thread-safe event emission. The `_hasListeners` flag is protected.
- **Android:** `BridgeHiddenPreChat` uses `@Volatile` for thread-safe field reads. `BridgeLogger` uses a similar pattern.

### setEmployeeAgentId Side Effects

On iOS, calling `setEmployeeAgentId()` with a different agent ID than the current one triggers conversation close and client cleanup. On Android, it only persists the value. This behavioral difference means that on Android, a changed agent ID takes effect on the next `configure()` or `launchConversation()` call, while on iOS it takes effect immediately.

---

## Related Documentation

- [Getting Started](./getting-started.md) -- Installation for both platforms.
- [Configuration](./configuration.md) -- Config persistence and feature flags.
- [API Reference](./api-reference.md) -- Complete method reference with platform notes.
- [Troubleshooting](./troubleshooting.md) -- Platform-specific build errors and fixes.
