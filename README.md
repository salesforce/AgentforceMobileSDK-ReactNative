# Agentforce SDK React Native Sample App

A lightweight React Native sample application demonstrating **Service Agent** integration with Salesforce Agentforce SDK for both **iOS** and **Android**.

## 🎯 Overview

This sample app demonstrates how to integrate the Agentforce Mobile SDK with **Service Agents** in your React Native applications for both iOS and Android.

The Agentforce Mobile SDK empowers you to integrate Salesforce's trusted AI platform directly into your mobile applications. Service Agents provide AI-powered conversational experiences for customer support scenarios.

## ✨ Features

- **Service Agent Configuration** - Configure and initialize the SDK with Service Agent settings
- **Full UI Experience** - Use the pre-built chat interface provided by the Agentforce SDK
- **Cross-Platform** - Single codebase for both iOS and Android with native SDK integration
- **Persistent Configuration** - Settings are saved and restored automatically
- **Conversation Continuity** - Conversations persist across app launches

## 🏗️ Architecture

This app uses the **AgentforceSDK-ReactNative-Bridge** (in-repo under `AgentforceSDK-ReactNative-Bridge/`) for all Agentforce functionality. The app has **no separate in-repo Agentforce native code**; the bridge provides the JS API and native modules.

### Android
- **Agentforce**: Provided by the bridge library `react-native-agentforce` (in-repo at `AgentforceSDK-ReactNative-Bridge/android`). React Native autolinking registers the package; no manual registration in the app.
- **App**: React Native shell; Agentforce conversation UI and SDK are in the bridge.

### iOS
- **Agentforce**: Provided by the bridge pod `ReactNativeAgentforce` (in-repo at `AgentforceSDK-ReactNative-Bridge/ios`).
- **App**: React Native shell; Agentforce conversation UI and SDK are in the bridge.

### JavaScript Layer (Common)
- **Framework**: React Native + TypeScript
- **Navigation**: React Navigation
- **Agentforce API**: `AgentforceService` from `react-native-agentforce` (bridge package)
- **Screens**: Home, Settings, About

## 📋 Prerequisites

### General
- **Node.js** (LTS recommended; 18+ required, 20.19.4+ preferred). Install and verify:
  - **macOS:** `brew install node` (requires [Homebrew](https://brew.sh)). Or use [nvm](https://github.com/nvm-sh/nvm): `nvm install --lts`.
  - **Windows:** Install from [nodejs.org](https://nodejs.org/) or `choco install nodejs-lts`. Or use [nvm-windows](https://github.com/coreybutler/nvm-windows).
  - **Linux:** Use your distro’s package manager or nvm. Run `node -v` to confirm.
- **Watchman** (recommended for better performance and fewer filesystem issues). Install and verify:
  - **macOS:** `brew install watchman`.
  - **Windows/Linux:** Optional; see [Watchman](https://facebook.github.io/watchman/docs/install) if needed. Run `watchman -v` to confirm.
- Git

### Android
- Android Studio
- Android SDK 24+
- Gradle 8.0+
- **JDK 17** (required for building; higher versions may cause issues). Recommended setup:
  - **macOS:** Install [Azul Zulu JDK 17](https://www.azul.com/downloads/) (e.g. `brew install --cask zulu@17`), then set in `~/.zshrc` or `~/.bash_profile`:
    ```bash
    export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
    ```
  - **Windows:** Install JDK 17 (e.g. [Microsoft OpenJDK 17](https://learn.microsoft.com/en-us/java/openjdk/download) or `choco install microsoft-openjdk17`).
  - **Linux:** Install OpenJDK 17 via your package manager.
  - Run `java -version` to confirm. Full details: [React Native – Set up your environment (Android)](https://reactnative.dev/docs/set-up-your-environment?platform=android).

### iOS
- macOS
- Xcode 15+
- CocoaPods
- iOS 17.0+

## 🚀 Quick Start

### 1. Clone and Install

```bash
# Clone the repository (bridge is in-repo; no submodules)
git clone <repository-url>
cd AgentforceSDK-ReactNative

# Install JavaScript dependencies
npm install
```

### 2. iOS Setup

```bash
# Install CocoaPods dependencies
node installios.js

# Run on iOS
npm run ios
```

### 3. Android Setup



```bash
# If using Employee Agents
node installandroid.js

# Run on Android
npx react-native run-android
```

## ⚙️ Configuration

### Service Agent Settings

Instructions for deploying [Enhanced Chat In-App available here.](https://help.salesforce.com/s/articleView?id=service.miaw_deployment_mobile.htm&type=5) This includes instructions on retrieving all these values.

When you first launch the app, navigate to **Settings** and configure:

1. **Service API URL** (required)
   - Your Salesforce Service Agent URL
   - Example: `https://your-domain.my.salesforce-scrt.com`

2. **Organization ID** (required)
   - Your 15 or 18 character Enhanced Chat Org ID
   - Example: `00D000000000000`

3. **ES Developer Name** (required)
   - The API name of your Enhanced Chat Service Agent
   - Example: `Your_Service_Agent_Name`

4. **Save** the configuration

### Testing the Conversation

1. From the Home screen, tap **Launch Agentforce**
2. The SDK will initialize with your configuration
3. Native conversation UI will appear
4. Start chatting with your Service Agent!

### Employee Agent

#### 1. Configure Salesforce Connection

##### Create Your Own Connected App

1. Follow the instructions in the [Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html#create-a-salesforce-app)
3. Set the callback URL in your bootconfig.plist
4. Update `bootconfig.plist` with your consumer key

#### 2. Configure Agent ID

Add a default agentID in the Employee Agent settings tab

#### 3. Testing the Conversation

1. From the Home screen, tap **Launch Agentforce**
2. The SDK will initialize with your configuration
3. Native conversation UI will appear
4. Start chatting with your Employee Agent!

## 📁 Project Structure

```
AgentforceSDK-ReactNative/
├── AgentforceSDK-ReactNative-Bridge/   # In-repo: JS API + native bridge
├── src/                                # React Native JavaScript/TypeScript
│   ├── screens/
│   │   ├── HomeScreen.tsx              # Home screen; uses AgentforceService from react-native-agentforce
│   │   ├── SettingsScreen.tsx          # Service Agent configuration
│   │   └── AboutScreen.tsx             # App information
│   └── types/
│       └── agentforce.types.ts         # TypeScript types
├── android/                            # Android app; Agentforce from bridge library
├── ios/                                # iOS app; Agentforce from bridge pod
└── App.tsx                             # Root component with navigation
```

## 🔧 Development

### Running on Android

```bash
# Start Metro bundler
npm start

# In another terminal, run Android
npx react-native run-android

# View logs
npx react-native log-android
```

### Running on iOS

```bash
# Start Metro bundler
npm start

# In another terminal, run iOS
npm run ios

# View logs
npx react-native log-ios
```

### Debugging

- **React Native Debugger**: Use Flipper or React Native Debugger
- **Native Android**: Use Android Studio logcat
- **Native iOS**: Use Xcode console
- **JavaScript logs**: Check Metro bundler output

## 🧪 Testing

### Manual Testing Flow

1. **Configuration Test**
   - Open Settings
   - Fill in all Service Agent fields
   - Save and verify success message

2. **Initialization Test**
   - Return to Home screen
   - Tap "Launch Agentforce"
   - Verify "Initializing..." message appears

3. **Conversation Test**
   - Wait for conversation UI to load
   - Send a test message
   - Verify response from Service Agent

4. **Error Handling Test**
   - Try launching without configuration
   - Verify appropriate error message

## 🐛 Troubleshooting

### iOS Issues

**Pod install fails**
```bash
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
```

**Build fails in Xcode**
```bash
# Clean build folder
cd ios
xcodebuild clean -workspace ReactAgentforce.xcworkspace -scheme ReactAgentforce
# Rebuild
npm run ios
```

### Android Issues

**Gradle sync fails**
```bash
cd android
./gradlew clean
./gradlew build
```

**App crashes on launch**
- Check Android logcat: `npx react-native log-android`
- Verify SDK dependencies in `build.gradle`
- Ensure minimum SDK version is 24+

### JavaScript Issues

**Metro bundler errors**
```bash
npm start -- --reset-cache
```

**Navigation not working**
- Verify `react-native-gesture-handler` is imported in `index.js`
- Check that `GestureHandlerRootView` wraps the app
