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

### Option 1: From this repo (current state)

The bridge isn't published to npm yet. Install from GitHub:

```bash
npm install salesforce/AgentforceMobileSDK-ReactNative#dev --save
```

…or pin to a specific commit/tag. Then run the platform install scripts that ship with the bridge:

```bash
node node_modules/react-native-agentforce/installios.js service     # or 'employee' / 'all'
node node_modules/react-native-agentforce/installandroid.js service
```

These scripts:
- Install Boost via Homebrew (or surface a clear error if it's missing).
- Patch `boost.podspec` (iOS) or set `REACT_NATIVE_BOOST_PATH` (Android) so React Native uses the local Homebrew install instead of downloading ~100MB during builds.
- Run `xcodegen generate` (iOS) to (re)build `*.xcodeproj` from `project.yml`.
- Run `pod install` (iOS) and Gradle sync (Android).

### Option 2: Local file dependency (forks/patches)

Clone or vendor `AgentforceSDK-ReactNative-Bridge/` into the consumer's repo, then:

```json
{
  "dependencies": {
    "react-native-agentforce": "file:./AgentforceSDK-ReactNative-Bridge"
  }
}
```

Then `npm install` and run the install scripts as above.

## iOS native setup

### Prerequisites

- macOS, Xcode 15+, iOS 17+ deployment target.
- CocoaPods (`brew install cocoapods` or `gem install cocoapods`).
- **XcodeGen** (`brew install xcodegen`) — the bridge generates `*.xcodeproj` from `ios/project.yml`.
- **Boost** (`brew install boost`) — avoids React Native downloading Boost during builds.

### Podfile

For Service Agent only:

```ruby
target 'YourApp' do
  pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
  # ...rest of your Podfile
end
```

For Employee Agent (host app must include Mobile SDK pods):

```ruby
target 'YourApp' do
  pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
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

If `pod install` fails with version conflicts, check that your `Podfile.lock` versions of `SalesforceReact` and `ReactNativeAgentforce` are compatible.

## Android native setup

### Prerequisites

- Android Studio, JDK 17 (higher versions cause build failures).
- Gradle 8.0+, AGP that matches your RN version.
- Min SDK 24+ (the bridge supports Android 7+; the underlying Agentforce SDK requires 29+ on its own — but the bridge itself loads later).

### `android/build.gradle` (project-level)

Verify the React Native gradle plugin and Boost path are wired up. The install script does this automatically; if you're doing it by hand:

```gradle
ext {
    REACT_NATIVE_BOOST_PATH = "/opt/homebrew/Cellar/boost/<version>"  // or wherever brew installed it
}
```

### `android/app/build.gradle` (or `.kts`)

For Employee Agent, add:

```gradle
implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
```

Autolinking handles `react-native-agentforce` itself — no manual `implementation` line needed for the bridge.

### Sync

```bash
cd android
./gradlew :app:dependencies
```

…or just rebuild from Android Studio.

## Boost — why everyone hits this

React Native 0.71+ pulls Boost during builds from `archives.boost.io`. CI environments and corporate networks often block this. The bridge's install scripts work around it:

- **Install Homebrew Boost first**: `brew install boost`
- **Run the install script**: it patches `boost.podspec` and exports `REACT_NATIVE_BOOST_PATH` so both platforms use the local copy.

If the user is on Linux or Windows (no Homebrew), point them at `docs/ci-guide.md` in the SDK repo for alternative Boost setups.

## Verifying the install

```bash
# JS side
npm ls react-native-agentforce

# iOS — pod is linked
grep -i ReactNativeAgentforce ios/Podfile.lock

# Android — autolinking picked it up
./gradlew :app:dependencies | grep -i agentforce
```

If any of these come up empty, the install didn't take — re-run the install script and watch for errors.
