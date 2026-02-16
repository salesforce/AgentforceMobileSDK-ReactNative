# Agentforce React Native Bridge

This directory contains the Agentforce bridge module: JavaScript API layer, sample app, and native iOS/Android code. It has **no Mobile SDK dependency**; a host app that adds the Mobile SDK can use the included auth bridge for Employee Agent.

## Installation

### iOS (CocoaPods)

In your app’s `Podfile`:

```ruby
pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
```

Your app must also include the Agentforce iOS SDK in the Podfile so the bridge can link. For **Employee Agent**, the host app must additionally include the Salesforce Mobile SDK and perform bootconfig + SDK initialization.

### Android

- Link the Android library and register `AgentforcePackage` in your app.
- For **Employee Agent** (see below), the host app must add the Salesforce React dependency and bootconfig + SDK init.

### JavaScript

Import the API from this package when the native module is linked:

```ts
import { AgentforceService } from 'react-native-agentforce';
```

Use the sample app in `app/` as reference or replace with your own UI.

---

## Employee Agent: host app requirements

For **Employee Agent** (authenticated) mode, the host app must provide the Salesforce Mobile SDK and initialize it. This bridge does not bundle the SDK.

### Android

Add the Salesforce React dependency in your app’s `build.gradle` (e.g. `app/build.gradle`):

```gradle
implementation "com.salesforce.mobilesdk:SalesforceReact:13.1.1"
```

You must also configure **bootconfig** and perform **SDK initialization** (e.g. via react-native-force or your existing Salesforce Mobile SDK setup). Without these, Employee Agent auth will not work.

### iOS

Include the Salesforce Mobile SDK pods in your Podfile and perform **bootconfig** and **SDK initialization** as required for your app. The bridge’s Employee Agent auth layer relies on the SDK being initialized at runtime.

---