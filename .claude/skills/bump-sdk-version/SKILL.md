---
name: bump-sdk-version
description: Bump Agentforce SDK versions for iOS and Android in this React Native project. Checks external repos for the latest releases, compares against local versions, surfaces release notes and breaking changes, and applies the updates. Use this skill when the user mentions upgrading, bumping, or updating the SDK version, checking for new SDK releases, or when they reference AgentforceSDK versioning. Also trigger when the user asks about the latest available SDK version or what changed in the newest release.
---

# Bump Agentforce SDK Versions

This skill checks external Agentforce SDK repos for the latest versions, compares them against what's configured locally, shows release notes (especially breaking changes or new module requirements), and applies the version bumps to local config files.

## Why this skill exists

The Agentforce SDK ships independently for iOS and Android with different versioning schemes. A version bump isn't just changing a number — new releases may decouple modules (like the voice module split), add required dependencies, or change API surfaces. This skill handles the research, comparison, and mechanical updates so you can focus on integration-level changes that require judgment.

## External Sources to Check

### iOS

Versions live in the CocoaPods specs repo. Each pod has a directory per version:

- **AgentforceSDK** (main UI SDK): https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs/tree/master/AgentforceSDK
- **AgentforceService** (headless/API layer, transitive): https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs/tree/master/AgentforceService
- **AgentforceVoice** (voice module, opt-in): https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs/tree/master/AgentforceVoice

Release notes: https://github.com/salesforce/AgentforceMobileSDK-iOS/releases/latest

### Android

Versions are published to Maven and documented in the SDK README:

- **Repo:** https://github.com/salesforce/AgentforceMobileSDK-Android
- **Maven repository:** `https://opensource.salesforce.com/AgentforceMobileSDK-Android/agentforce-sdk-repository`
- **Artifacts:**
  - `com.salesforce.android.agentforcesdk:agentforce-sdk` — core SDK
  - `com.salesforce.android.agentforcesdk:agentforce-sdk-voice` — voice module (opt-in)

Release notes: https://github.com/salesforce/AgentforceMobileSDK-Android/releases/latest

## Local Files That Hold Version Declarations

### iOS
- **`ios/Podfile.common.rb`** — Pod version pins (e.g., `pod 'AgentforceSDK', '15.2.6'`)
- **`AgentforceSDK-ReactNative-Bridge/ios/ReactNativeAgentforce.podspec`** — Pod dependencies in the `Core` subspec

### Android
- **`AgentforceSDK-ReactNative-Bridge/android/build.gradle`** — Maven dependency versions (e.g., `api "com.salesforce.android.agentforcesdk:agentforce-sdk:14.177.0"`)

## Workflow

### 1. Read current local versions

Read the files above and extract:
- iOS: `AgentforceSDK` version from `Podfile.common.rb`, whether `AgentforceVoice` pod exists
- Android: `agentforce-sdk` version from bridge `build.gradle`, whether `agentforce-sdk-voice` exists

### 2. Fetch latest remote versions

Use web fetch or the GitHub API to determine the latest available versions:

- **iOS pods:** Fetch directory listings from the specs repo (each subfolder name is a version). The highest semver directory is the latest.
- **Android:** Fetch the README from the Android SDK repo — it contains the canonical dependency declarations with current versions. Alternatively check the latest GitHub release tag.

### 3. Fetch and summarize release notes

Get the latest release from both SDK repos. Focus on:
- Breaking changes or migration steps
- New modules that need explicit import
- API surface changes (renamed classes, new required configuration calls)
- Deprecated APIs being removed

### 4. Present findings to the user

Show a clear comparison:
```
Platform        | Dependency             | Current  | Latest   | Status
iOS             | AgentforceSDK          | 15.2.6   | 15.7.6   | Update available
iOS             | AgentforceVoice        | —        | 1.2.0    | New module (needs import)
Android         | agentforce-sdk         | 14.177.0 | 15.0.2   | Update available
Android         | agentforce-sdk-voice   | —        | 15.0.2   | New module (needs import)
```

Summarize release notes highlights and flag anything that requires code changes beyond version strings.

### 5. Apply updates (only after user confirms)

**iOS — `Podfile.common.rb`:**
- Update the `AgentforceSDK` version string
- Add `AgentforceVoice` pod if it's a new module (insert after the `AgentforceSDK` line)

**iOS — `ReactNativeAgentforce.podspec`:**
- Add `core.dependency "AgentforceVoice"` in the Core subspec if the voice module is new

**Android — bridge `build.gradle`:**
- Update the `agentforce-sdk` version
- Add `agentforce-sdk-voice` dependency if it's a new module (insert after the `agentforce-sdk` line)

### 6. Flag code-level integration changes

Some version bumps require code changes beyond config files. Call these out explicitly so the user can handle them. Examples:

- **Voice module (Android):** When adding `agentforce-sdk-voice`, the builder in `AgentforceModule.kt` needs:
  ```kotlin
  .setAgentforceVoiceModule(AgentforceVoiceProviderFactory(), AgentforceVoiceUIProvider())
  ```
  This goes in the `AgentforceConfiguration.builder(...)` chain.

- **New pod sources (iOS):** Some pods require additional sources in the Podfile (already handled — `livekit/podspecs.git` is present).

### 7. Offer a verification build

After applying the version changes, ask the user if they'd like to run a local build on both platforms to catch compilation errors early.

If the user accepts, run the setup scripts first (these handle pod install, xcodegen, gradle sync, etc.) and then the builds. Run iOS and Android in parallel where possible.

#### Setup + Build Commands

The install scripts must run before the build commands — they handle platform-specific dependency resolution (pod install, xcodegen, gradle setup).

**iOS (Service Agent):**
```bash
node installios.js service
npm run build:ios:service
```

**iOS (Employee Agent):**
```bash
node installios.js employee
npm run build:ios:employee
```

**Android (Service Agent):**
```bash
node installandroid.js service
npm run build:android:service
```

**Android (Employee Agent):**
```bash
node installandroid.js employee
npm run build:android:employee
```

At minimum, build one variant per platform (Service Agent is lighter since it skips Mobile SDK). If the user wants thorough validation, build all four.

#### Handling build failures

If builds fail:
- Read the error output and identify whether the failure is related to the version bump (e.g., missing import, renamed API, incompatible dependency).
- If the fix is straightforward (missing import, updated class name from release notes), offer to apply it.
- If the failure is unrelated to the bump (pre-existing issue, environment problem), let the user know so they can decide how to proceed.
- If the fix requires code-level changes (like the voice module `.setAgentforceVoiceModule(...)` call), apply them and re-run the build.

### 8. Remind the user of final steps

After a successful build (or if the user skips the build step):
1. Review `git diff` before committing
2. Never commit bootconfig files

## Important Constraints

- iOS and Android SDK version numbers use different schemes — they won't match. That's expected.
- The `AgentforceService` pod is a transitive dependency (pulled in by `AgentforceSDK`). Don't add it explicitly unless the release notes say otherwise.
- Never commit or push changes to bootconfig files (`ios/EmployeeAgent/bootconfig.plist`, `android/app/src/employeeAgent/res/values/bootconfig.xml`).
- Always show the user what will change before modifying files.
