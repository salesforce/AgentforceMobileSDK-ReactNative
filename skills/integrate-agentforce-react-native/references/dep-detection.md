# Dependency setup (React Native)

## Project type detection

Look for these in the working directory:

1. `package.json` with `react-native` in `dependencies` or `peerDependencies` → React Native project.
2. `ios/` and `android/` folders → bare React Native (required — the bridge needs native code).
3. `app.json` with `"expo"` key + no `ios/` or `android/` → **Expo managed workflow**. Refuse and tell the user to `expo prebuild` first or migrate to a bare workflow. The bridge cannot autolink into a managed Expo app.

Common false positives:

- A monorepo where `package.json` is at the root but the RN app is in `apps/mobile/`. Walk into the RN app dir before continuing.

## Refusing to run inside the SDK repo

If the working directory contains `AgentforceSDK-ReactNative-Bridge/` as a sibling of the root `package.json` and the package name is `react-native-agentforce-sample` (or similar), this is the SDK's own repo. Refuse and tell the user to `cd` into their consuming app.

## Install the bridge package

### Option 1: Public npm package (recommended)

Install the scoped bridge package:

```bash
npm install @salesforce/react-native-agentforce
```

The package uses standard React Native autolinking. Do **not** run `installios.js` or `installandroid.js`; those scripts belong to SDK repository/sample development workflows, not normal consumer integration.

### Option 2: Local file dependency (forks/patches)

Clone or vendor `AgentforceSDK-ReactNative-Bridge/` into the consumer's repo, then:

```json
{
  "dependencies": {
    "@salesforce/react-native-agentforce": "file:./AgentforceSDK-ReactNative-Bridge"
  }
}
```

Then run `npm install`, `cd ios && pod install`, and rebuild both native apps.

## iOS native setup

### Prerequisites

- macOS, Xcode 16+, iOS 17+ deployment target.
- CocoaPods (`brew install cocoapods` or `gem install cocoapods`).

### Podfile

The host must include the native Agentforce SDK and its spec sources. The bridge pod is usually discovered by autolinking; the public bridge README also supports declaring it explicitly:

```ruby
source 'https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs.git'
source 'https://github.com/Salesforce-Async-Messaging/podspecs.git'
source 'https://github.com/livekit/podspecs.git'
source 'https://cdn.cocoapods.org/'

platform :ios, '17.0'

target 'YourApp' do
  use_frameworks!
  pod 'AgentforceSDK'
  pod 'Messaging-InApp-Core', '> 1.10.0'
  pod 'ReactNativeAgentforce', :path => '../node_modules/@salesforce/react-native-agentforce/ios'
  # ...rest of your Podfile
end
```

For Employee Agent, the host app must also include compatible Salesforce Mobile SDK pods:

```ruby
target 'YourApp' do
  use_frameworks!
  pod 'AgentforceSDK'
  pod 'Messaging-InApp-Core', '> 1.10.0'
  pod 'ReactNativeAgentforce', :path => '../node_modules/@salesforce/react-native-agentforce/ios'
  pod 'SalesforceReact'
  pod 'SalesforceSDKCore'
  pod 'SmartStore'
  pod 'MobileSync'
  # ...rest of your Podfile
end
```

After editing the Podfile, run:

```bash
cd ios
pod install --repo-update
```

Merge `config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'` for every pod target into the app's existing `post_install` block. Do not create a second `post_install` block or remove React Native's `react_native_post_install(...)` call.

Although the native iOS SDK now supports Swift Package Manager, the public React Native bridge's documented consumer path is CocoaPods. Keep `AgentforceSDK` and `ReactNativeAgentforce` together in the Podfile for a bridge-based app; do not also add the Agentforce SPM package to the same target.

If `pod install` fails with version conflicts, check that your `Podfile.lock` versions of `SalesforceReact` and `ReactNativeAgentforce` are compatible.

## Android native setup

### Prerequisites

- Android Studio, JDK 17 (higher versions cause build failures).
- AGP 8.9.1 or newer and Kotlin 1.9.22 or newer, while staying compatible with the selected React Native version.
- Min SDK 29 or newer. The native Agentforce Android SDK sets the effective platform floor.

### `android/app/build.gradle` (or `.kts`)

For Employee Agent, add:

```gradle
implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
```

Autolinking handles `@salesforce/react-native-agentforce` itself — no manual `implementation` line is needed for the bridge.

### Sync

```bash
cd android
./gradlew :app:dependencies
```

…or just rebuild from Android Studio.

## Verifying the install

```bash
# JS side
npm ls @salesforce/react-native-agentforce

# iOS — pod is linked
grep -i ReactNativeAgentforce ios/Podfile.lock

# Android — autolinking picked it up
./gradlew :app:dependencies | grep -i agentforce
```

If any of these come up empty, reinstall the package, rerun `pod install`, confirm `react-native.config.js` has not disabled the package, and rebuild rather than relying on Metro hot reload.
