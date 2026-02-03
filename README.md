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

### Android
- **Native Layer**: Kotlin + Jetpack Compose
- **Pattern**: Singleton `AgentforceClientHolder` for lifecycle management
- **UI**: Native `ServiceAgentConversationActivity` with Compose
- **SDK Integration**: Service Agent mode with simplified credential provider

### iOS
- **Native Layer**: Swift + SwiftUI
- **Pattern**: Singleton `ServiceAgentManager` for lifecycle management
- **UI**: Native `AgentforceConversationContainer` with SwiftUI
- **SDK Integration**: Service Agent mode with simplified credential provider

### JavaScript Layer (Common)
- **Framework**: React Native + TypeScript
- **Navigation**: React Navigation
- **Bridge**: Native modules for SDK initialization and conversation launch
- **Screens**: Home, Settings, About

## 📋 Prerequisites

### General
- Node.js 18+ and npm/yarn
- Git

### Android
- Android Studio
- Android SDK 24+
- Gradle 8.0+

### iOS
- macOS
- Xcode 15+
- CocoaPods
- iOS 17.0+

## 🚀 Quick Start

### 1. Clone and Install

```bash
# Clone the repository
git clone <repository-url>
cd AgentforceSDK-ReactNative

# Install JavaScript dependencies
npm install
```

### 2. iOS Setup

```bash
# Run iOS setup script (installs pods)
node installios.js

# Run on iOS
npm run ios
```

### 3. Android Setup

```bash
# Android setup is automatic with Gradle
# Just run the app directly
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

## 📁 Project Structure

```
AgentforceSDK-ReactNative/
├── src/                           # React Native JavaScript/TypeScript
│   ├── screens/
│   │   ├── HomeScreen.tsx         # Home screen with launch button
│   │   ├── SettingsScreen.tsx    # Service Agent configuration
│   │   └── AboutScreen.tsx        # App information
│   ├── services/
│   │   └── AgentforceService.ts  # Bridge wrapper for native modules
│   └── types/
│       └── agentforce.types.ts   # TypeScript types
├── android/                       # Android native code
│   └── app/src/main/
│       ├── java/.../agentforce/
│       │   ├── AgentforceModule.kt              # RN bridge
│       │   ├── AgentforceClientHolder.kt        # Singleton manager
│       │   ├── ServiceAgentConversationActivity.kt  # Compose UI
│       │   └── ServiceAgentCredentialProvider.kt    # Auth
│       └── AndroidManifest.xml
├── ios/                           # iOS native code
│   └── ReactAgentforce/
│       ├── Agentforce/
│       │   ├── AgentforceModule.swift           # RN bridge
│       │   ├── AgentforceModule.m               # ObjC bridge
│       │   ├── ServiceAgentManager.swift        # Singleton manager
│       │   └── ServiceAgentCredentialProvider.swift # Auth
│       ├── AppDelegate.h
│       └── AppDelegate.m
└── App.tsx                        # Root component with navigation
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
