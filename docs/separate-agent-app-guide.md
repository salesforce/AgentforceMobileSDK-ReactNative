# Separate-App Guide: Service Agent & Employee Agent

> **Complete guide for building, installing, and deploying separate Service Agent and Employee Agent apps from a single codebase**

## Table of Contents

- [Overview](#overview)
- [App Types](#-app-types)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
  - [Selective Installation](#selective-installation-recommended)
  - [What Gets Installed](#what-gets-installed)
- [Building & Running](#-building--running)
- [Project Structure](#-project-structure)
- [How It Works](#-how-it-works)
- [Benefits](#-benefits)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)
- [Implementation Details](#-implementation-details)

---

## Overview

This repository supports building **two separate apps** from a single codebase:

1. **Service Agent** - Customer-facing, anonymous auth, no Mobile SDK
2. **Employee Agent** - Internal workforce, OAuth auth, includes Mobile SDK

Both apps share >98% of code (JavaScript/TypeScript and core native code), with only configuration files differing.

---

## 📱 App Types

### Service Agent
- **Purpose**: Customer-facing, public service app
- **Authentication**: Anonymous (URL-based configuration)
- **Display Name**: "Service Agent"
- **Mobile SDK**: NOT included

### Employee Agent
- **Purpose**: Internal workforce app
- **Authentication**: OAuth via Salesforce Mobile SDK
- **Display Name**: "Employee Agent"
- **Mobile SDK**: Included (SalesforceSDKCore 13.1.1 from CocoaPods)

---

## 🚀 Quick Start

### Prerequisites

**iOS:**
- Xcode 15.0 or later
- CocoaPods
- XcodeGen (`brew install xcodegen`)
- Node.js >= 18

**Android:**
- Android Studio or Android SDK
- Gradle
- Node.js >= 18

### Fast Setup

```bash
# Service Agent only (fastest)
node installios.js service
node installandroid.js service
npm run ios:service
npm run android:service

# Employee Agent only
node installios.js employee
node installandroid.js employee
npm run ios:employee
npm run android:employee

# Both apps (backward compatible)
node installios.js all
node installandroid.js all
```

---

## 📦 Installation

### Selective Installation (Recommended)

Choose which app to install:

```bash
# Service Agent Only (no Mobile SDK)
node installios.js service
node installandroid.js service

# Employee Agent Only (with Mobile SDK)
node installios.js employee
node installandroid.js employee

# Both Apps (backward compatible default)
node installios.js all
node installandroid.js all

# No argument = 'all' (backward compatible)
node installios.js              # Same as 'all'
node installandroid.js          # Same as 'all'
```

### What Gets Installed

| Target | Mobile SDK | CocoaPods/Gradle |
|--------|-----------|------------------|
| **service** | ❌ Not included | Service Agent only |
| **employee** | ✅ From Maven/CocoaPods | Employee Agent only |
| **all** | ✅ From Maven/CocoaPods | Both targets |

**What each script does:**

#### installios.js [service|employee|all]
1. Installs npm dependencies (always)
2. **[employee/all only]** Builds react-native-force (Mobile SDK React Native bridge)
3. Configures Node.js path for Xcode (always)
4. Generates Xcode project with xcodegen (always)
5. Installs CocoaPods (only for selected target)

#### installandroid.js [service|employee|all]
1. Installs npm dependencies (always)
2. Applies React Native Gradle plugin patches (always)
3. **[employee/all only]** Builds react-native-force (Mobile SDK React Native bridge)

### Mobile SDK Dependencies

Employee Agent uses Salesforce Mobile SDK from published artifacts:
- **iOS**: CocoaPods specs (`SalesforceSDKCore` via `ReactNativeAgentforce/WithMobileSDK`)
- **Android**: Maven Central (`com.salesforce.mobilesdk:SalesforceReact:13.1.1`)

Service Agent has no Mobile SDK dependency.

---

## 🏗️ Building & Running

### Development (on simulator/device)

```bash
# Service Agent
npm run ios:service
npm run android:service

# Employee Agent
npm run ios:employee
npm run android:employee
```

### Production Builds

```bash
# Service Agent Release
npm run build:ios:service
npm run build:android:service

# Employee Agent Release
npm run build:ios:employee
npm run build:android:employee
```

### Manual Builds

**iOS (Xcode):**
1. Open `ios/ReactAgentforce.xcworkspace` (NOT .xcodeproj)
2. Select scheme: **ServiceAgent** or **EmployeeAgent**
3. Select target device
4. Build and run (Cmd+R)

**Android (Gradle):**
```bash
cd android

# List all available build variants
./gradlew tasks | grep assemble

# Build specific variants
./gradlew assembleServiceAgentDebug
./gradlew assembleServiceAgentRelease
./gradlew assembleEmployeeAgentDebug
./gradlew assembleEmployeeAgentRelease
```

### Output Locations

**Android APKs:**
```
android/app/build/outputs/apk/
├── serviceAgent/
│   ├── debug/app-serviceAgent-debug.apk
│   └── release/app-serviceAgent-release.apk
└── employeeAgent/
    ├── debug/app-employeeAgent-debug.apk
    └── release/app-employeeAgent-release.apk
```

**iOS IPAs:**
1. Open Xcode
2. Window → Organizer
3. Select archive
4. Distribute App → Export

---

## 📂 Project Structure

### iOS

```
ios/
├── project.yml                 # XcodeGen configuration
├── Podfile                     # Default: loads Podfile.employee (run pod install via installios.js)
├── Podfile.service             # Service Agent only (subset of deps)
├── Podfile.employee            # Employee Agent / both apps (full deps)
├── Podfile.common.rb           # Shared pod list and hooks
├── Podfile.service.lock        # Lock for Service Agent
├── Podfile.employee.lock       # Lock for Employee Agent / both
├── Shared/                     # Shared code (AppDelegate, main.m)
│   ├── AppDelegate.{h,m}
│   └── main.m
├── ServiceAgent/              # Service Agent specific files
│   ├── Info.plist            # Display name: "Service Agent"
│   ├── ServiceAgent.entitlements
│   ├── LaunchScreen.storyboard
│   └── PrivacyInfo.xcprivacy
└── EmployeeAgent/            # Employee Agent specific files
    ├── Info.plist            # Display name: "Employee Agent"
    ├── EmployeeAgent.entitlements
    ├── LaunchScreen.storyboard
    └── PrivacyInfo.xcprivacy
```

### Android

```
android/app/src/
├── main/                      # Shared code
│   ├── java/.../app/
│   │   ├── MainActivity.java
│   │   └── MainApplication.java
│   ├── res/
│   └── AndroidManifest.xml
├── serviceAgent/             # Service Agent overrides
│   └── res/values/
│       └── strings.xml       # app_name="Service Agent"
└── employeeAgent/            # Employee Agent overrides
    └── res/values/
        └── strings.xml       # app_name="Employee Agent"
```

### JavaScript

All JavaScript/TypeScript code is **100% shared** between both apps. No changes needed.

---

## ⚙️ How It Works

### iOS Architecture

**Single Project, Two Targets (XcodeGen + CocoaPods):**

This project uses a **single Xcode project with two targets** approach, which provides:
- **Platform consistency**: Matches Android's product flavor architecture
- **Maximum code reuse**: >98% shared code, minimal duplication
- **Selective installation**: Install service-only or employee with Mobile SDK
- **React Native CLI compatibility**: Works seamlessly with standard RN tooling

**Alternative Considered:** Separate projects (one for each app) with independent project.yml/Podfile per app was evaluated but rejected because it would:
- Double disk space and build time (2x Pods directories)
- Break React Native CLI conventions (expects single ios/ directory)
- Create platform inconsistency (Android uses flavors, not separate projects)
- Duplicate most configuration for minimal benefit

**Architecture Details:**
- `project.yml` defines two targets (ServiceAgent, EmployeeAgent)
- `xcodegen generate` creates `.xcodeproj` with both targets
- **Two Podfiles**: `Podfile.service` (Service Agent only, subset) and `Podfile.employee` (both targets, full deps). `installios.js` copies the right one to `Podfile` and uses the matching lock (`Podfile.service.lock` or `Podfile.employee.lock`). "all" uses the employee Podfile so both apps share one dependency set.
- **Build order fix**: `Podfile.common.rb` adds explicit Pods target dependencies at the Xcode project level, ensuring Pods build before app targets (fixes "React/RCTBridgeDelegate.h file not found" errors)
- ServiceAgent uses `ReactNativeAgentforce/Core` (no Mobile SDK)
- EmployeeAgent uses `ReactNativeAgentforce/WithMobileSDK` (includes Mobile SDK)

**Mobile SDK Dependencies:**
```ruby
# EmployeeAgent target
pod 'SalesforceReact', :path => '../node_modules/react-native-force'
pod 'ReactNativeAgentforce/WithMobileSDK', :path => '../AgentforceSDK-ReactNative-Bridge/ios'
# WithMobileSDK subspec brings in SalesforceSDKCore from published specs
```

**Build Order Solution:**
The `Podfile.common.rb` includes an `add_pods_target_dependency` function that automatically adds explicit dependencies from each app target (ServiceAgent, EmployeeAgent) to its corresponding Pods target (Pods-ServiceAgent, Pods-EmployeeAgent). This ensures CocoaPods builds first, making React Native headers available during app compilation.

### Android Architecture

**Product Flavors + Gradle:**
- `build.gradle` defines two flavors: `serviceAgent`, `employeeAgent`
- Creates 4 build variants (service/employee × debug/release)
- ServiceAgent flavor: NO Mobile SDK dependency
- EmployeeAgent flavor: Mobile SDK from Maven Central

**Mobile SDK Dependency:**
```gradle
// build.gradle - Employee Agent only
employeeAgentImplementation("com.salesforce.mobilesdk:SalesforceReact:13.1.1")
```

### Bridge Runtime Detection

The bridge automatically detects Mobile SDK availability:

**Android (AgentforcePackage.kt):**
```kotlin
private fun isMobileSdkAvailable(): Boolean {
    return try {
        Class.forName("com.salesforce.androidsdk.app.SalesforceSDKManager")
        true
    } catch (e: ClassNotFoundException) {
        false
    }
}
```

**iOS (Subspecs):**
- `Core` subspec: Service Agent only, no Mobile SDK
- `WithMobileSDK` subspec: Includes `SalesforceSDKCore` dependency

### Mobile SDK Initialization

Employee Agent requires SDK initialization at app startup:

**Android (Conditional in Shared MainApplication):**
```java
// android/app/src/main/java/.../MainApplication.java
public void onCreate() {
    super.onCreate();

    // Initialize Mobile SDK for Employee Agent flavor only (uses reflection)
    if ("employeeAgent".equals(BuildConfig.FLAVOR)) {
        Class<?> sdkManagerClass = Class.forName("com.salesforce.androidsdk.app.SalesforceSDKManager");
        Method initMethod = sdkManagerClass.getMethod("initNative", Context.class, Class.class);
        initMethod.invoke(null, this, MainActivity.class);
    }
    // ... rest of initialization
}
```

**iOS (Flavor-Specific AppDelegate):**
```objc
// ios/EmployeeAgent/AppDelegate.m (overrides Shared/AppDelegate.m)
#import <SalesforceReact/SalesforceReactSDKManager.h>

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [SalesforceReactSDKManager initializeSDK];
    // ... rest of initialization
}
```

**Configuration Files:**
- Android: `android/app/src/employeeAgent/res/values/bootconfig.xml`
- iOS: `ios/EmployeeAgent/bootconfig.plist`

These files contain OAuth client configuration for Mobile SDK authentication.

---

## ✨ Benefits

### 1. Separate Apps
- Both installable side-by-side
- Independent release cycles
- Clear separation of concerns

### 2. Code Reuse
- >98% shared code
- Single codebase maintenance
- Consistent features across apps

### 3. Selective Installation
- Install only what you need (service/employee/all)
- Service Agent: No Mobile SDK required
- Employee Agent: Full Mobile SDK from published artifacts

### 4. Developer Experience
- Service Agent devs don't need to understand Mobile SDK
- Employee Agent devs get full Mobile SDK integration
- Flexible workflow for different development needs

---

## 🔍 Troubleshooting

### iOS: `'React/RCTBridgeDelegate.h' file not found` (or UIKit/Foundation modules not found)

**Cause**: The app target is not using the CocoaPods-generated xcconfig, or Pods are not building before the app target. This typically happens when:

1. **You run `xcodegen generate` after `pod install`** – XcodeGen overwrites the project and removes the `baseConfigurationReference` to the Pods xcconfig that CocoaPods added.
2. **You open the `.xcodeproj` instead of the `.xcworkspace`** – Always open `ios/ReactAgentforce.xcworkspace` so the Pods project and settings are in scope.
3. **You're building the wrong target** – If you ran `node installios.js service`, only the ServiceAgent target has Pods linked. Building EmployeeAgent will fail with missing React headers until you run `node installios.js employee` or `node installios.js all`.
4. **Pods target dependency not set** – The app target needs an explicit dependency on its Pods target to ensure correct build order.

**Solution**:

1. **Use the correct install order and do not re-run XcodeGen after Pods are installed:**
   ```bash
   node installios.js service   # or employee, or all
   ```
   This runs `xcodegen generate` then `pod install`. CocoaPods then:
   - Wires each app target to its `Pods-<Target>.(debug|release).xcconfig`
   - Runs the `post_install` hook which adds explicit Pods target dependencies

   If you need to change `project.yml`, run the full install again so that XcodeGen runs first and then CocoaPods re-applies the xcconfig references and dependencies.

2. **Always open the workspace:**
   ```bash
   open ios/ReactAgentforce.xcworkspace
   ```
   In Xcode, select the **ServiceAgent** or **EmployeeAgent** scheme (matching what you installed) and build.

3. **If you already ran XcodeGen after pod install**, re-run the installer so CocoaPods can re-attach the xcconfig and dependencies:
   ```bash
   node installios.js service   # or employee / all
   ```

4. **Verify Pods target dependencies**: After running `installios.js`, check the output for:
   ```
   ✅ Added ServiceAgent -> Pods-ServiceAgent target dependency
   ✅ Added EmployeeAgent -> Pods-EmployeeAgent target dependency
   ```
   This confirms the build order is properly configured.

5. **UIKit / CoreGraphics / Foundation “module not found”** – Often fixed by the Podfile `post_install` settings (`CLANG_ENABLE_MODULES`, `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES`). If you still see this, ensure you are building with the workspace and the correct scheme.

### iOS: Build order issues / Pods not building first

**Cause**: The app target doesn't have an explicit dependency on its Pods target.

**Solution**: This is now handled automatically by `installios.js`. The `Podfile.common.rb` post_install hook adds explicit dependencies from each app target to its Pods target. If you're still seeing issues:

```bash
# Clean and reinstall
rm -rf ios/Pods ios/Podfile.lock ios/ReactAgentforce.xcodeproj ios/ReactAgentforce.xcworkspace
node installios.js service  # or employee / all
```

### "Invalid target" error
```
❌ Invalid target: xyz
```
**Solution**: Use `service`, `employee`, or `all`:
```bash
node installios.js service   # ✅ Correct
```

### Service Agent build fails with "Mobile SDK not found"
**Cause**: Ran `node installios.js service` but trying to build Employee Agent

**Solution**: Install Employee Agent dependencies:
```bash
node installios.js employee
node installandroid.js employee
```

### Employee Agent crashes with Mobile SDK errors
**Cause**: CocoaPods or Gradle cache corruption

**Solution**: Clean and reinstall:
```bash
cd ios && pod deintegrate && pod install
cd android && ./gradlew clean
```

### iOS: "Scheme not found"
**Solution**:
```bash
cd ios
xcodegen generate
pod install
```

### iOS: "Target not found" during pod install
**Cause**: Ran `node installios.js service` but Podfile expects Employee target

**Solution**: This is expected - Service Agent install skips Employee pods:
```bash
npm run ios:service  # Build Service Agent only
```

### Android: Gradle sync fails
**Cause**: Corrupted build cache

**Solution**: Clean and reinstall:
```bash
rm -rf android/build android/app/build
node installandroid.js employee
```

### iOS: CocoaPods warnings about build settings
These warnings are cosmetic and don't affect functionality.

---

## ❓ FAQ

### Q: Can I switch between `service` and `employee` installs?

**A:** Yes! Just run the install script again with the new target:
```bash
node installios.js service    # Install Service Agent only
# ... do Service Agent work ...
node installios.js employee   # Add Employee Agent + Mobile SDK
```

### Q: Does this affect JavaScript code?

**A:** No, all JavaScript/TypeScript code is 100% shared between apps. This only affects native dependencies.

### Q: Can both apps be installed on the same device?

**A:** Yes! Both apps can be installed side-by-side on the same device.

### Q: Which install should I use for CI/CD?

**A:** Depends on your pipeline:
- Separate pipelines → Use specific targets (`service` or `employee`)
- Monolithic pipeline → Use `all`

---

## 🛠️ Implementation Details

### Architecture Decision

**Why Single Project with Two Targets?**

This project uses a **single Xcode project with two targets** approach (not separate projects). This decision was made after careful analysis:

**Advantages:**
- ✅ **Platform consistency**: Matches Android's product flavor architecture
- ✅ **Maximum code reuse**: >98% shared code between targets
- ✅ **Single build graph**: Pods installed once, shared between targets
- ✅ **React Native CLI compatibility**: Standard RN tooling expects single ios/ directory
- ✅ **Faster builds**: Single Pods directory, no duplication
- ✅ **Easier maintenance**: One project.yml, one set of build settings

**Alternative Considered (Rejected):**
Separate projects (ServiceAgent-ios/, EmployeeAgent-ios/) with independent configurations were evaluated but would introduce:
- ❌ 2x disk space (separate Pods directories)
- ❌ 2x pod install time
- ❌ Platform inconsistency (Android uses flavors, not separate gradle projects)
- ❌ React Native CLI incompatibility (expects single ios/ directory)
- ❌ Configuration duplication (most settings identical)

**The Current Issues (Now Fixed):**
1. ~~Build order problems requiring scheme patching workaround~~ → **Fixed** with proper Pods target dependencies
2. ~~Podfile switching complexity~~ → **Improved** with clear logging and validation
3. ~~Two lock files to maintain separately~~ → **Improved** with explicit lock file management
4. ~~Limited validation and unclear error messages~~ → **Fixed** with pre-flight checks and verbose logging

### What Was Implemented

1. **Multi-target iOS setup** (XcodeGen + CocoaPods)
2. **Product flavors Android setup** (Gradle)
3. **Selective installation** (service/employee/all arguments)
4. **Conditional dependency resolution** (flavor-specific dependencies)
5. **Published artifacts integration** (Maven Central & CocoaPods specs)
6. **Build order fix** (Explicit Pods target dependencies via post_install hook)
7. **Environment validation** (Pre-flight checks for required tools)
8. **Verbose logging** (Clear progress indicators and step-by-step feedback)

### Files Created

- `ios/project.yml` - XcodeGen configuration
- `ios/ServiceAgent/` - Service Agent specific files
- `ios/EmployeeAgent/` - Employee Agent specific files
  - `AppDelegate.m` - Overrides Shared/AppDelegate.m with Mobile SDK initialization
  - `bootconfig.plist` - OAuth configuration
- `ios/Shared/` - Shared iOS code (AppDelegate.m used by Service Agent)
- `android/app/src/serviceAgent/` - Service Agent flavor (uses shared MainApplication)
- `android/app/src/employeeAgent/` - Employee Agent flavor
  - `res/values/bootconfig.xml` - OAuth configuration (uses shared MainApplication with conditional init)
- `scripts/generate-app-config.js` - App mode configuration generator
- `scripts/build-react-native-force.js` - Builds react-native-force bridge

### Files Modified

- `package.json` - Added run scripts, react-native-force dependency, build:force script
- `installios.js` - Added selective installation logic + react-native-force build
- `installandroid.js` - Added selective installation logic + react-native-force build
- `ios/Podfile.service` - Service Agent only (subset of deps)
- `ios/Podfile.employee` - Both targets, full deps (used for employee and "all")
- `ios/Podfile.common.rb` - Shared pod list and post_install hooks
- **Locks**: `Podfile.service.lock` and `Podfile.employee.lock` (install script copies the active one to `Podfile.lock` and back)
- `android/settings.gradle` - Simplified project structure
- `android/app/build.gradle` - Product flavors + conditional deps
- `src/config/AppConfig.ts` - Dynamic app mode configuration
- `.gitignore` - Added generated config file

### Key Technical Decisions

**iOS:**
- **XcodeGen**: Makes project structure version-controllable (YAML)
- **Two Podfiles + locks**: Install script selects Podfile.service or Podfile.employee and the matching lock
- **Published specs**: Uses SalesforceReact from npm + CocoaPods specs

**Android:**
- **Product flavors**: Standard Android approach for app variants
- **Flavor-specific dependencies**: `employeeAgentImplementation` only for Employee Agent

**Both:**
- **Backward compatible**: No argument = `all` (same as before)
- **Idempotent scripts**: Can run multiple times safely
- **Published artifacts**: Uses Maven/CocoaPods for Mobile SDK

### Code Sharing

| Component | Shared % |
|-----------|----------|
| JavaScript/TypeScript | 100% |
| iOS native (AppDelegate, main) | 100% |
| Android native (MainActivity, Application) | 100% |
| iOS configuration (Info.plist, entitlements) | 0% (app-specific) |
| Android configuration (strings.xml) | 0% (app-specific) |
| **Overall** | **>98%** |

---

## 📊 Comparison

| Aspect | Service Agent | Employee Agent |
|--------|---------------|----------------|
| **Mobile SDK** | ❌ Not included | ✅ From Maven/CocoaPods |
| **Authentication** | Anonymous | OAuth |
| **Use case** | Customer-facing | Internal workforce |

---

## 🎯 Recommended Workflows

### Solo Developer (Service Agent only)
```bash
node installios.js service
node installandroid.js service
```

### Solo Developer (Employee Agent only)
```bash
node installios.js employee
node installandroid.js employee
```

### Full Team (both apps)
```bash
node installios.js all
node installandroid.js all
# Default, backward compatible
```

### CI/CD (separate pipelines)
```yaml
service-pipeline:
  script:
    - node installios.js service
    - npm run build:ios:service

employee-pipeline:
  script:
    - node installios.js employee
    - npm run build:ios:employee
```

### CI/CD (monolithic pipeline)
```yaml
full-pipeline:
  script:
    - node installios.js all
    - npm run build:ios:service
    - npm run build:ios:employee
```

---

## 📚 Additional Resources

- **Main README**: `../README.md` - Project overview
- **Bridge Documentation**: `../AgentforceSDK-ReactNative-Bridge/README.md`
- **Contributing**: `../CONTRIBUTING.md`

---

## Summary

This guide covered:
- ✅ Installing Service Agent and Employee Agent separately
- ✅ Building and running both apps
- ✅ Understanding the multi-app architecture
- ✅ Troubleshooting common issues
- ✅ Optimizing for time and disk space

**Choose the right install target and save time!** 🚀

---

**Last Updated**: March 3, 2026
