# Getting Started with react-native-agentforce

This guide walks you through installing and configuring the `react-native-agentforce` package -- a React Native bridge for the Agentforce Mobile SDK on iOS and Android. By the end, you will have a minimal Service Agent running in your app.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [iOS Setup](#ios-setup)
- [Android Setup](#android-setup)
- [Salesforce Org Configuration](#salesforce-org-configuration)
- [First Run: Minimal Service Agent](#first-run-minimal-service-agent)
- [Next Steps](#next-steps)

---

## Prerequisites

| Requirement | Minimum Version |
|---|---|
| Node.js | 18+ |
| React Native | 0.72+ |
| iOS deployment target | 15.0 |
| Android minSdk | 29 |
| Android compileSdk | 36 |
| Xcode | 15+ |
| CocoaPods | 1.14+ |
| JDK | 17 |
| Kotlin | 2.2+ |

You also need a Salesforce org with an Agentforce agent configured. See [Salesforce Org Configuration](#salesforce-org-configuration) below for details.

---

## Installation

Install the package using npm or yarn:

```bash
# npm
npm install react-native-agentforce

# yarn
yarn add react-native-agentforce
```

The package exposes TypeScript types out of the box. All public exports are available from `'react-native-agentforce'`.

---

## iOS Setup

### 1. Podfile Configuration

In your app's `ios/Podfile`, add the bridge pod. The bridge depends on `React-Core` and `AgentforceSDK` (the native iOS SDK distributed via CocoaPods).

**Service Agent only (default):**

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks! :linkage => :static

  # React Native pods (from your standard RN template)
  # ...

  # Agentforce React Native bridge -- Service Agent (default subspec)
  pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
end
```

**Service Agent + Employee Agent (with Mobile SDK auth):**

If you also need Employee Agent support with OAuth authentication via the Salesforce Mobile SDK, use the `WithMobileSDK` subspec:

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks! :linkage => :static

  # React Native pods
  # ...

  # Agentforce bridge with Mobile SDK for Employee Agent auth
  pod 'ReactNativeAgentforce/WithMobileSDK', :path => '../node_modules/react-native-agentforce/ios'
end
```

The `WithMobileSDK` subspec adds a dependency on `SalesforceSDKCore`, which provides OAuth login flows. See [Employee Agent Auth](./employee-agent-auth.md) for details.

### 2. Install Pods

```bash
cd ios && pod install
```

### 3. Swift Compatibility

The bridge is written in Swift 5.0+. Your Xcode project must support Swift -- if your app is Objective-C only, Xcode will prompt you to create a bridging header on first build.

### 4. Permissions (Optional)

If you enable voice features (`enableVoice: true`), add the microphone usage description to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used for voice input with Agentforce</string>
```

If you enable camera/photo features (`enableMultiModalInput: true`), add:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to capture images for Agentforce</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach images to Agentforce conversations</string>
```

---

## Android Setup

### 1. build.gradle (App Level)

Add the Agentforce Maven repositories and dependencies. In your app's `android/app/build.gradle`:

```groovy
android {
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
        compose = true
    }
}

repositories {
    google()
    mavenCentral()
    maven { url 'https://jitpack.io' }
    maven { url 'https://opensource.salesforce.com/AgentforceMobileSDK-Android/agentforce-sdk-repository' }
    maven { url 'https://s3.amazonaws.com/inapp.salesforce.com/public/android' }
    maven { url 'https://s3.amazonaws.com/salesforce-async-messaging-experimental/public/android' }
}

dependencies {
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.5"

    // The bridge library (react-native-agentforce) includes agentforce-sdk as an api dependency.
    // If you need Employee Agent, also add SalesforceReact:
    // implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
}
```

The bridge library module (`android/build.gradle`) already declares `agentforce-sdk:14.97.1` as an `api` dependency and `SalesforceReact:13.1.1` as `compileOnly`. Your host app must provide `SalesforceReact` at runtime if you use Employee Agent auth.

### 2. Register the Native Package

In your `MainApplication.kt` (or `.java`), register `AgentforcePackage`:

```kotlin
import com.salesforce.android.reactagentforce.AgentforcePackage

class MainApplication : Application(), ReactApplication {
    override val reactNativeHost = object : DefaultReactNativeHost(this) {
        override fun getPackages(): List<ReactPackage> = listOf(
            MainReactPackage(),
            AgentforcePackage(),
            // ... other packages
        )
    }
}
```

`AgentforcePackage` automatically registers `AgentforceModule`. It also registers `EmployeeAgentAuthBridge` if the Salesforce Mobile SDK is detected on the runtime classpath (via reflection). If the Mobile SDK is not present, Employee Agent auth is gracefully disabled.

### 3. AndroidManifest.xml

Register the conversation activity in your `AndroidManifest.xml`:

```xml
<activity
    android:name="com.salesforce.android.reactagentforce.AgentforceConversationActivity"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"
    android:windowSoftInputMode="adjustResize" />
```

### 4. Permissions (Optional)

For camera/multi-modal input support, add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

The bridge includes `AgentforceClientCameraUriProvider` and `AgentforceClientPermissions` helpers for handling camera URIs and runtime permissions on Android.

---

## Salesforce Org Configuration

Before using the SDK in your app, configure your Salesforce org:

1. **Enable Agentforce** in your org (Setup > Agentforce).
2. **Create an Agent** -- either a Service Agent (for anonymous customer-facing use) or an Employee Agent (for authenticated internal use).
3. **Note the following values** (you will need them for SDK configuration):

| Value | Where to Find | Used By |
|---|---|---|
| `serviceApiURL` | Setup > Embedded Service Deployments > your deployment > Settings | Service Agent |
| `organizationId` | Setup > Company Information > Organization ID | Both |
| `esDeveloperName` | Setup > Embedded Service Deployments > your deployment > Developer Name | Service Agent |
| `instanceUrl` | Your Salesforce instance URL (e.g. `https://myorg.my.salesforce.com`) | Employee Agent |
| `userId` | Your Salesforce User ID (from user profile) | Employee Agent |
| `agentId` | Setup > Agentforce > your agent > Agent ID | Employee Agent |

For complete Salesforce setup instructions, refer to the official documentation:
- [Agentforce SDK Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-sdk.html)
- [iOS Native SDK](https://github.com/salesforce/AgentforceMobileSDK-iOS)
- [Android Native SDK](https://github.com/salesforce/AgentforceMobileSDK-Android)

---

## First Run: Minimal Service Agent

Here is a complete minimal example that configures and launches a Service Agent conversation:

```tsx
import React from 'react';
import { View, Button, Alert, StyleSheet } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

export default function App() {
  const handleLaunch = async () => {
    try {
      // Step 1: Configure the SDK with your Service Agent settings
      await AgentforceService.configure({
        type: 'service',
        serviceApiURL: 'https://your-site.salesforce.com',
        organizationId: '00Dxx0000001234',
        esDeveloperName: 'YourServiceAgentDeveloperName',
      });

      // Step 2: Launch the conversation UI
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  return (
    <View style={styles.container}>
      <Button title="Chat with Agent" onPress={handleLaunch} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
});
```

When the user taps "Chat with Agent":
1. The SDK is configured with your org details.
2. A full-screen conversation UI is presented (iOS: modal via `UIHostingController`; Android: `AgentforceConversationActivity`).
3. The user can chat with the Service Agent.

---

## Next Steps

- **[Configuration](./configuration.md)** -- Deep dive into Service Agent, Employee Agent, feature flags, and config persistence.
- **[Conversations](./conversations.md)** -- Launching, lifecycle, additional context, and hidden prechat fields.
- **[Delegates](./delegates.md)** -- Logger, navigation, and view provider delegates.
- **[Employee Agent Auth](./employee-agent-auth.md)** -- OAuth flows, token management, and Mobile SDK integration.
- **[API Reference](./api-reference.md)** -- Complete method signatures and type definitions.
- **[Platform Notes](./platform-notes.md)** -- iOS and Android specifics, feature parity, and known limitations.
- **[Troubleshooting](./troubleshooting.md)** -- Common issues and solutions.
- **[Examples](./examples.md)** -- Full working code examples for every feature.
