# bump-sdk-version

A Claude Code skill that checks external Agentforce SDK repos for the latest versions and bumps the iOS/Android dependencies in this project.

## What it does

1. Reads current local SDK versions from `Podfile.common.rb` (iOS) and `build.gradle` (Android)
2. Fetches the latest available versions from GitHub (specs repo + SDK READMEs)
3. Surfaces release notes and flags breaking changes or new module requirements
4. Applies version bumps after user confirmation
5. Flags any code-level integration changes needed beyond config file updates

## Usage

In a Claude Code session within this repo, invoke the skill:

```
/bump-sdk-version
```

Or simply ask Claude to check for or apply SDK version updates — the skill triggers automatically based on context.

## External sources checked

| Platform | Source | What's checked |
|----------|--------|----------------|
| iOS | [SalesforceMobileSDK-iOS-Specs](https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs) | Pod versions (AgentforceSDK, AgentforceService, AgentforceVoice) |
| iOS | [AgentforceMobileSDK-iOS](https://github.com/salesforce/AgentforceMobileSDK-iOS) | Release notes |
| Android | [AgentforceMobileSDK-Android](https://github.com/salesforce/AgentforceMobileSDK-Android) | Maven artifact versions + release notes |

## Local files modified

- `ios/Podfile.common.rb` — iOS pod version pins
- `AgentforceSDK-ReactNative-Bridge/ios/ReactNativeAgentforce.podspec` — Pod dependencies
- `AgentforceSDK-ReactNative-Bridge/android/build.gradle` — Maven dependency versions

## After running

1. `cd ios && pod install`
2. Gradle sync in Android Studio
3. Build and test both Service Agent and Employee Agent targets
4. Review `git diff` before committing
