# Agentforce SDK React Native Sample App

A React Native sample application demonstrating **two separate apps** built from a single codebase: **Service Agent** (customer-facing, anonymous auth) and **Employee Agent** (workforce, OAuth auth) using Salesforce Agentforce SDK for both **iOS** and **Android**.

## 🎯 Overview

This sample app demonstrates how to build **two distinct apps** from one codebase:

- **Service Agent App**: Customer-facing service with anonymous authentication, no Mobile SDK dependency (~smaller binary)
- **Employee Agent App**: Internal workforce app with OAuth authentication via Salesforce Mobile SDK

Both apps share >98% of code while maintaining separate identities, bundle IDs, and can be installed side-by-side on the same device.

The Agentforce Mobile SDK empowers you to integrate Salesforce's trusted AI platform directly into your mobile applications. Service Agents provide AI-powered conversational experiences for customer support scenarios, while Employee Agents enable authenticated workforce interactions.

📖 **[Complete Multi-App Guide](docs/separate-agent-app-guide.md)** - Comprehensive guide for building, installing, and deploying both apps

## ✨ Features

### Multi-App Architecture
- **Two Separate Apps** - Service Agent and Employee Agent from one codebase
- **Selective Installation** - Install only what you need
- **Independent Releases** - Deploy Service Agent and Employee Agent separately
- **Side-by-Side Installation** - Both apps on same device (different bundle IDs)

### Service Agent App
- **Anonymous Authentication** - URL-based configuration, no login required
- **Lightweight** - No Mobile SDK dependency (~5-10MB smaller)
- **Customer-Facing** - Optimized for public service scenarios

### Employee Agent App
- **OAuth Authentication** - Salesforce Mobile SDK integration
- **Full SDK Access** - Complete Mobile SDK features for workforce apps
- **Published Artifacts** - Uses Mobile SDK from Maven Central & CocoaPods

### Shared Features
- **Service Agent Configuration** - Configure and initialize the SDK with Service Agent settings
- **Employee Agent Configuration** - OAuth-based authenticated sessions
- **Full UI Experience** - Use the pre-built chat interface provided by the Agentforce SDK
- **Cross-Platform** - Single codebase for both iOS and Android with native SDK integration
- **Persistent Configuration** - Settings are saved and restored automatically
- **Conversation Continuity** - Conversations persist across app launches
- **98% Code Reuse** - Maximum code sharing between apps

## 🏗️ Architecture

This repository uses a **multi-target/multi-flavor** approach to build two separate apps from a single codebase.

### Multi-App Structure

**iOS (XcodeGen + CocoaPods):**
- Two Xcode targets: `ServiceAgent` and `EmployeeAgent`
- Conditional pod installation based on target
- Service Agent: Uses `ReactNativeAgentforce/Core` (no Mobile SDK)
- Employee Agent: Uses `ReactNativeAgentforce/WithMobileSDK` (with Mobile SDK)

**Android (Product Flavors + Gradle):**
- Two flavors: `serviceAgent` and `employeeAgent`
- Creates 4 build variants (service/employee × debug/release)
- Service Agent: No Mobile SDK dependency
- Employee Agent: Mobile SDK via `employeeAgentImplementation`

### Bridge Layer

This app uses the **AgentforceSDK-ReactNative-Bridge** (in-repo under `AgentforceSDK-ReactNative-Bridge/`) for all Agentforce functionality. The bridge provides:
- **JS API**: `AgentforceService` from `react-native-agentforce`
- **Native modules**: Android (auto-linked) and iOS (CocoaPods)
- **Runtime detection**: Automatically detects Mobile SDK availability
- **Subspecs/Variants**: Core (Service Agent) and WithMobileSDK (Employee Agent)

### JavaScript Layer (100% Shared)
- **Framework**: React Native + TypeScript
- **Navigation**: React Navigation
- **Agentforce API**: `AgentforceService` from `react-native-agentforce` (bridge package)
- **Screens**: Home, Settings, About
- **No app-specific code**: Same JavaScript for both apps

### App Identity

| Aspect | Service Agent | Employee Agent |
|--------|---------------|----------------|
| **Bundle ID (iOS)** | `com.salesforce.android.reactagentforce.service` | `com.salesforce.android.reactagentforce.employee` |
| **Package (Android)** | `com.salesforce.android.reactagentforce.service` | `com.salesforce.android.reactagentforce.employee` |
| **Display Name** | "Service Agent" | "Employee Agent" |
| **Mobile SDK** | ❌ Not included | ✅ Included (13.1.1) |
| **Binary Size** | ~15-20 MB | ~20-30 MB |

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
- **XcodeGen** (`brew install xcodegen`)
- iOS 17.0+

## 🚀 Quick Start

### Choose Your App

This repository supports building **two separate apps**. Choose which one to install:

```bash
# Service Agent only (no Mobile SDK)
node installios.js service
node installandroid.js service
npm run ios:service
npm run android:service

# Employee Agent only (with Mobile SDK)
node installios.js employee
node installandroid.js employee
npm run ios:employee
npm run android:employee

# Both apps (backward compatible)
node installios.js all
node installandroid.js all
npm run ios:service    # or ios:employee
npm run android:service  # or android:employee
```

### Traditional Setup (Installs Both)

```bash
# Clone the repository (bridge is in-repo; no submodules)
git clone <repository-url>
cd AgentforceMobileSDK-ReactNative

# Install dependencies (no argument = 'all')
node installios.js
node installandroid.js

# Run either app
npm run ios:service     # or ios:employee
npm run android:service # or android:employee
```

📖 **For detailed installation guide, see [docs/separate-agent-app-guide.md](docs/separate-agent-app-guide.md)**

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
├── docs/
│   └── separate-agent-app-guide.md     # Complete multi-app guide
├── AgentforceSDK-ReactNative-Bridge/   # In-repo: JS API + native bridge
├── src/                                # React Native JavaScript/TypeScript (100% shared)
│   ├── screens/
│   │   ├── HomeScreen.tsx              # Home screen; uses AgentforceService
│   │   ├── SettingsScreen.tsx          # Configuration screen
│   │   └── AboutScreen.tsx             # App information
│   └── types/
│       └── agentforce.types.ts         # TypeScript types
├── android/                            # Android app with product flavors
│   └── app/src/
│       ├── main/                       # Shared Android code
│       ├── serviceAgent/               # Service Agent overrides
│       └── employeeAgent/              # Employee Agent overrides
├── ios/                                # iOS app with multiple targets
│   ├── project.yml                     # XcodeGen configuration
│   ├── Podfile                         # Multi-target CocoaPods
│   ├── Shared/                         # Shared iOS code
│   ├── ServiceAgent/                   # Service Agent specific
│   └── EmployeeAgent/                  # Employee Agent specific
├── installios.js                       # iOS installation script (supports service/employee/all)
├── installandroid.js                   # Android installation script (supports service/employee/all)
└── App.tsx                             # Root component with navigation (shared)
```

### Employee Agent Settings

#### Configure an External Client App
Follow the instructions in the [Developer Guide](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-api-get-started.html#create-a-salesforce-app)

#### Building the Employee Agent App
The Employee Agent app is built from this repository using selective installation:

```bash
# Install Employee Agent with Mobile SDK
node installios.js employee
node installandroid.js employee

# Run Employee Agent
npm run ios:employee
npm run android:employee
```

📖 See [docs/separate-agent-app-guide.md](docs/separate-agent-app-guide.md) for complete instructions

## 🔧 Development

### Running on Android

```bash
# Start Metro bundler
npm start

# In another terminal, run specific app
npm run android:service   # Service Agent
npm run android:employee  # Employee Agent

# Or use React Native CLI directly
npx react-native run-android --mode=serviceAgentDebug
npx react-native run-android --mode=employeeAgentDebug

# View logs
npx react-native log-android
```

### Running on iOS

```bash
# Start Metro bundler
npm start

# In another terminal, run specific app
npm run ios:service   # Service Agent
npm run ios:employee  # Employee Agent

# Or use React Native CLI directly
npx react-native run-ios --scheme ServiceAgent
npx react-native run-ios --scheme EmployeeAgent

# View logs
npx react-native log-ios
```

### Production Builds

```bash
# Build Service Agent
npm run build:ios:service
npm run build:android:service

# Build Employee Agent
npm run build:ios:employee
npm run build:android:employee
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

### Installation Issues

**"Invalid target" error**
```bash
# Use service, employee, or all
node installios.js service   # ✅ Correct
node installios.js xyz       # ❌ Wrong
```

**Service Agent build fails with "Mobile SDK not found"**
```bash
# You tried to build Employee Agent after installing Service Agent only
# Solution: Install Employee Agent dependencies
node installios.js employee
node installandroid.js employee
```

### iOS Issues

**Pod install fails**
```bash
cd ios
xcodegen generate
pod deintegrate
pod cache clean --all
pod install --repo-update
```

**Build fails in Xcode**
```bash
# Clean build folder
cd ios
xcodebuild clean -workspace ReactAgentforce.xcworkspace -scheme ServiceAgent
# Rebuild
npm run ios:service
```

**"Scheme not found"**
```bash
# Regenerate Xcode project
cd ios
xcodegen generate
pod install
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

📖 **For more troubleshooting, see [docs/separate-agent-app-guide.md](docs/separate-agent-app-guide.md#-troubleshooting)**

## 📚 Documentation

### Complete Multi-App Guide
**[docs/separate-agent-app-guide.md](docs/separate-agent-app-guide.md)** - Comprehensive guide covering:
- Detailed installation instructions (selective install)
- Building and running both apps
- Project structure and architecture
- How the multi-app system works
- Troubleshooting and FAQ
- Implementation details

### Quick Reference

| Topic | Command |
|-------|---------|
| **Install Service Agent only** | `node installios.js service` |
| **Install Employee Agent only** | `node installios.js employee` |
| **Install both apps** | `node installios.js all` |
| **Run Service Agent** | `npm run ios:service` or `npm run android:service` |
| **Run Employee Agent** | `npm run ios:employee` or `npm run android:employee` |
| **Build Service Agent** | `npm run build:ios:service` or `npm run build:android:service` |
| **Build Employee Agent** | `npm run build:ios:employee` or `npm run build:android:employee` |

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.
