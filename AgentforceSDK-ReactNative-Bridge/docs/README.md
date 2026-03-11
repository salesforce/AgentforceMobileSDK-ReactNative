# react-native-agentforce

A React Native bridge for the [Agentforce Mobile SDK](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-sdk.html), providing a JavaScript API to configure and launch Agentforce conversations on iOS and Android.

## Features

- **Service Agent** -- Anonymous/guest customer support with zero auth required
- **Employee Agent** -- Authenticated internal-use with OAuth via Salesforce Mobile SDK or direct tokens
- **Delegates** -- Logger, navigation, and custom view provider callbacks
- **Additional Context** -- Pass contextual variables to personalize agent responses
- **Hidden Prechat Fields** -- Pre-populate hidden form data for Service Agent sessions
- **Feature Flags** -- Toggle multi-agent, voice, camera, PDF upload, and custom views

## Quick Start

```ts
import { AgentforceService } from 'react-native-agentforce';

await AgentforceService.configure({
  type: 'service',
  serviceApiURL: 'https://your-site.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'YourServiceAgent',
});

await AgentforceService.launchConversation();
```

Head to [Getting Started](getting-started.md) for full installation and setup instructions.

## Native SDKs

This bridge wraps the platform-specific Agentforce SDKs:

- [AgentforceMobileSDK-iOS](https://github.com/salesforce/AgentforceMobileSDK-iOS) (CocoaPods)
- [AgentforceMobileSDK-Android](https://github.com/salesforce/AgentforceMobileSDK-Android) (Maven)
