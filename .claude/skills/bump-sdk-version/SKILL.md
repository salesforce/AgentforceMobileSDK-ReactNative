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

### 7. Remind the user of next steps

After applying:
1. `cd ios && pod install` (iOS)
2. Gradle sync (Android)
3. Build and test both Service Agent and Employee Agent targets
4. Review `git diff` before committing
5. Never commit bootconfig files

## Important Constraints

- iOS and Android SDK version numbers use different schemes — they won't match. That's expected.
- The `AgentforceService` pod is a transitive dependency (pulled in by `AgentforceSDK`). Don't add it explicitly unless the release notes say otherwise.
- Never commit or push changes to bootconfig files (`ios/EmployeeAgent/bootconfig.plist`, `android/app/src/employeeAgent/res/values/bootconfig.xml`).
- Always show the user what will change before modifying files.
