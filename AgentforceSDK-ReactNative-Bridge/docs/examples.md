# Examples

Full working examples for every major feature of the `react-native-agentforce` bridge.

## Table of Contents

- [Minimal Service Agent Setup](#minimal-service-agent-setup)
- [Employee Agent with Mobile SDK Auth](#employee-agent-with-mobile-sdk-auth)
- [Employee Agent with Direct Token](#employee-agent-with-direct-token)
- [Using All Delegates Together](#using-all-delegates-together)
- [Custom View Provider with AppRegistry](#custom-view-provider-with-appregistry)
- [Additional Context Variables (All Types)](#additional-context-variables-all-types)
- [Hidden Prechat Fields](#hidden-prechat-fields)
- [Feature Flag Management](#feature-flag-management)
- [Complete HomeScreen Integration](#complete-homescreen-integration)

---

## Minimal Service Agent Setup

The simplest possible integration -- configure and launch a Service Agent conversation.

```tsx
import React from 'react';
import { View, Button, Alert, StyleSheet } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

const SERVICE_CONFIG = {
  type: 'service' as const,
  serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
  organizationId: '00Dxx0000001234EAA',
  esDeveloperName: 'My_Service_Agent',
};

export default function MinimalServiceAgent() {
  const handleLaunch = async () => {
    try {
      await AgentforceService.configure(SERVICE_CONFIG);
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  return (
    <View style={styles.center}>
      <Button title="Chat with Support" onPress={handleLaunch} />
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
});
```

---

## Employee Agent with Mobile SDK Auth

Full Employee Agent flow using the Salesforce Mobile SDK for OAuth authentication.

```tsx
import React, { useState, useEffect } from 'react';
import { View, Button, Text, Alert, ActivityIndicator, StyleSheet } from 'react-native';
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  AuthCredentials,
} from 'react-native-agentforce';

const AGENT_ID = '0Xxxx0000001234AAA';

export default function EmployeeAgentWithAuth() {
  const [authSupported, setAuthSupported] = useState(false);
  const [loggedIn, setLoggedIn] = useState(false);
  const [loading, setLoading] = useState(true);
  const [credentials, setCredentials] = useState<AuthCredentials | null>(null);

  useEffect(() => {
    checkAuthState();
  }, []);

  const checkAuthState = async () => {
    setLoading(true);
    try {
      const supported = await isEmployeeAgentAuthSupported();
      setAuthSupported(supported);

      if (supported) {
        const session = await hasEmployeeAgentSession();
        setLoggedIn(session);
        if (session) {
          const creds = await getEmployeeAgentCredentials();
          setCredentials(creds);
        }
      }
    } catch (error) {
      console.error('Auth check failed:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async () => {
    try {
      setLoading(true);
      const creds = await loginForEmployeeAgent();
      setCredentials(creds);
      setLoggedIn(true);
    } catch (error) {
      Alert.alert('Login Failed', String(error));
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      await AgentforceService.closeConversation();
      await logoutEmployeeAgent();
      await AgentforceService.resetSettings();
      setCredentials(null);
      setLoggedIn(false);
    } catch (error) {
      Alert.alert('Logout Failed', String(error));
    }
  };

  const handleLaunch = async () => {
    if (!credentials) {
      Alert.alert('Error', 'Not logged in');
      return;
    }

    try {
      await AgentforceService.configure({
        type: 'employee',
        instanceUrl: credentials.instanceUrl,
        organizationId: credentials.organizationId,
        userId: credentials.userId,
        agentId: AGENT_ID,
        accessToken: credentials.accessToken,
      });

      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Launch Failed', String(error));
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  if (!authSupported) {
    return (
      <View style={styles.center}>
        <Text>Employee Agent auth is not available in this build.</Text>
        <Text style={styles.hint}>Include the Mobile SDK to enable it.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Employee Agent</Text>

      {loggedIn ? (
        <>
          <Text style={styles.status}>Logged in as: {credentials?.userId}</Text>
          <Text style={styles.status}>Org: {credentials?.organizationId}</Text>
          <View style={styles.buttonRow}>
            <Button title="Launch Agent" onPress={handleLaunch} />
            <Button title="Logout" onPress={handleLogout} color="red" />
          </View>
        </>
      ) : (
        <>
          <Text style={styles.status}>Not logged in</Text>
          <Button title="Login with Salesforce" onPress={handleLogin} />
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  container: { flex: 1, padding: 24, justifyContent: 'center' },
  title: { fontSize: 24, fontWeight: 'bold', marginBottom: 16 },
  status: { fontSize: 14, color: '#666', marginBottom: 8 },
  hint: { fontSize: 12, color: '#999', marginTop: 8 },
  buttonRow: { flexDirection: 'row', gap: 16, marginTop: 16 },
});
```

---

## Employee Agent with Direct Token

Use Employee Agent without the Mobile SDK by providing a token directly.

```tsx
import React from 'react';
import { View, Button, Alert, StyleSheet } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

// In production, obtain this token from your auth system
const DIRECT_TOKEN_CONFIG = {
  type: 'employee' as const,
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234EAA',
  userId: '005xx0000001234AAA',
  agentId: '0Xxxx0000001234AAA',
  agentLabel: 'My Assistant',
  accessToken: 'your_oauth_access_token_here',
};

export default function EmployeeAgentDirect() {
  const handleLaunch = async () => {
    try {
      await AgentforceService.configure(DIRECT_TOKEN_CONFIG);
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  return (
    <View style={styles.center}>
      <Button title="Launch Employee Agent" onPress={handleLaunch} />
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
});
```

---

## Using All Delegates Together

Register logger, navigation, and view provider delegates in a single component.

```tsx
import React, { useEffect, useRef } from 'react';
import { View, Button, Linking, Alert, StyleSheet } from 'react-native';
import {
  AgentforceService,
  LogLevel,
  NavigationRequest,
} from 'react-native-agentforce';

export default function AllDelegatesExample() {
  const logBufferRef = useRef<Array<{ level: LogLevel; message: string; time: Date }>>([]);

  useEffect(() => {
    // 1. Logger Delegate
    AgentforceService.setLoggerDelegate({
      onLog(level, message, error) {
        logBufferRef.current.push({ level, message, time: new Date() });
        // Keep buffer manageable
        if (logBufferRef.current.length > 500) {
          logBufferRef.current = logBufferRef.current.slice(-250);
        }

        // Forward errors to your analytics
        if (level === 'error') {
          console.error(`[Agentforce ERROR] ${message}`, error);
        }
      },
    });

    // 2. Navigation Delegate
    AgentforceService.setNavigationDelegate({
      onNavigate(request: NavigationRequest) {
        console.log('Navigation request:', JSON.stringify(request));

        switch (request.type) {
          case 'link':
            if (request.uri) {
              Linking.openURL(request.uri as string).catch(err =>
                console.error('Failed to open URL:', err)
              );
            }
            break;

          case 'record':
            Alert.alert(
              'Record Navigation',
              `Open ${request.objectType} record: ${request.recordId}`
            );
            break;

          case 'quickAction':
            Alert.alert(
              'Quick Action',
              `Execute action: ${request.actionName}`
            );
            break;

          case 'objectHome':
            Alert.alert(
              'Object Home',
              `Navigate to ${request.objectType} list`
            );
            break;

          default:
            console.log('Unhandled navigation type:', request.type);
        }
      },
    });

    // 3. View Provider Delegate (async)
    AgentforceService.setViewProviderDelegate({
      componentMap: {
        'copilot/richText': 'CustomAgentforceView',
      },
    }).catch(err => console.error('View provider registration failed:', err));

    // Cleanup on unmount
    return () => {
      AgentforceService.clearLoggerDelegate();
      AgentforceService.clearNavigationDelegate();
      AgentforceService.clearViewProviderDelegate();
    };
  }, []);

  const handleConfigure = async () => {
    try {
      await AgentforceService.configure({
        type: 'service',
        serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
        organizationId: '00Dxx0000001234EAA',
        esDeveloperName: 'My_Service_Agent',
        featureFlags: {
          enableMultiAgent: true,
          enableMultiModalInput: false,
          enablePDFUpload: false,
          enableVoice: false,
          enableCustomViewProvider: true,
        },
      });
      Alert.alert('Success', 'SDK configured');
    } catch (error) {
      Alert.alert('Config Error', String(error));
    }
  };

  const handleLaunch = async () => {
    try {
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Launch Error', String(error));
    }
  };

  const handleShowLogs = () => {
    const recent = logBufferRef.current.slice(-10);
    const text = recent
      .map(l => `[${l.level}] ${l.message}`)
      .join('\n');
    Alert.alert(`Last ${recent.length} Logs`, text || 'No logs yet');
  };

  return (
    <View style={styles.container}>
      <Button title="1. Configure" onPress={handleConfigure} />
      <View style={styles.spacer} />
      <Button title="2. Launch Conversation" onPress={handleLaunch} />
      <View style={styles.spacer} />
      <Button title="Show Recent Logs" onPress={handleShowLogs} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24 },
  spacer: { height: 16 },
});
```

---

## Custom View Provider with AppRegistry

Complete example of registering a custom React Native component to handle SDK view output.

```tsx
// file: CustomAgentforceView.tsx
import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import type { ViewProviderComponentData } from 'react-native-agentforce';

interface Props {
  componentData: ViewProviderComponentData;
}

function CustomAgentforceView({ componentData }: Props) {
  const { definition, name, properties, subComponents } = componentData;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.defLabel}>{definition}</Text>
        {name && <Text style={styles.nameLabel}>{name}</Text>}
      </View>

      <ScrollView style={styles.propsContainer}>
        {Object.entries(properties).map(([key, value]) => (
          <View key={key} style={styles.propRow}>
            <Text style={styles.propKey}>{key}:</Text>
            <Text style={styles.propValue}>
              {typeof value === 'object' ? JSON.stringify(value) : String(value)}
            </Text>
          </View>
        ))}
      </ScrollView>

      {subComponents && subComponents.length > 0 && (
        <View style={styles.subSection}>
          <Text style={styles.subTitle}>Sub-Components ({subComponents.length})</Text>
          {subComponents.map((sub, index) => (
            <View key={index} style={styles.subItem}>
              <Text style={styles.subDef}>{sub.definition}</Text>
              <Text style={styles.subProps}>
                {JSON.stringify(sub.properties, null, 2)}
              </Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    margin: 8,
    padding: 12,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#dee2e6',
  },
  header: { marginBottom: 8 },
  defLabel: { fontSize: 14, fontWeight: 'bold', color: '#0176D3' },
  nameLabel: { fontSize: 12, color: '#666', marginTop: 2 },
  propsContainer: { maxHeight: 200 },
  propRow: { flexDirection: 'row', marginBottom: 4 },
  propKey: { fontWeight: '600', marginRight: 8, color: '#333' },
  propValue: { flex: 1, color: '#555' },
  subSection: { marginTop: 12, paddingTop: 8, borderTopWidth: 1, borderTopColor: '#eee' },
  subTitle: { fontWeight: 'bold', marginBottom: 4 },
  subItem: { marginLeft: 12, marginBottom: 8 },
  subDef: { fontWeight: '600', fontSize: 12 },
  subProps: { fontFamily: 'monospace', fontSize: 10, color: '#666' },
});

export default CustomAgentforceView;
```

```tsx
// file: App.tsx (registration)
import { AppRegistry } from 'react-native';
import CustomAgentforceView from './CustomAgentforceView';
import { AgentforceService } from 'react-native-agentforce';

// Register the component with AppRegistry -- this makes it available
// for the native bridge to render via RCTRootView / ReactRootView.
AppRegistry.registerComponent('CustomAgentforceView', () => CustomAgentforceView);

// Then register the mapping with the bridge
async function setupCustomViews() {
  await AgentforceService.setViewProviderDelegate({
    componentMap: {
      'copilot/richText': 'CustomAgentforceView',
      'copilot/markdown': 'CustomAgentforceView',
      'copilot/recordInfo': 'CustomAgentforceView',
      'copilot/list': 'CustomAgentforceView',
    },
  });
}

// Call during app initialization
setupCustomViews();
```

---

## Additional Context Variables (All Types)

Demonstrates every context variable type supported by the SDK.

```tsx
import React from 'react';
import { View, Button, Alert, StyleSheet } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

export default function ContextVariablesExample() {
  const handleSetContext = async () => {
    try {
      // Must have a conversation active first
      await AgentforceService.launchConversation();

      // Set all variable types
      await AgentforceService.setAdditionalContext({
        variables: [
          // Text -- simple string value
          {
            name: 'customerName',
            type: 'Text',
            value: 'Jane Smith',
          },

          // Number -- numeric value (double precision)
          {
            name: 'accountBalance',
            type: 'Number',
            value: 15234.56,
          },

          // Boolean -- true/false
          {
            name: 'isVIPCustomer',
            type: 'Boolean',
            value: true,
          },

          // Date -- ISO date string
          {
            name: 'memberSince',
            type: 'Date',
            value: '2024-01-15',
          },

          // DateTime -- ISO datetime string with timezone
          {
            name: 'lastInteraction',
            type: 'DateTime',
            value: '2026-03-11T10:30:00.000Z',
          },

          // Json -- JSON data (can be string or object)
          {
            name: 'preferences',
            type: 'Json',
            value: {
              language: 'en',
              timezone: 'America/Los_Angeles',
              notifications: true,
            },
          },

          // List -- array of values
          {
            name: 'recentOrderIds',
            type: 'List',
            value: ['ORD-2026-001', 'ORD-2026-002', 'ORD-2026-003'],
          },

          // Money -- monetary value
          {
            name: 'creditLimit',
            type: 'Money',
            value: 50000,
          },

          // Object -- key-value map
          {
            name: 'shippingAddress',
            type: 'Object',
            value: {
              street: '123 Market Street',
              city: 'San Francisco',
              state: 'CA',
              zip: '94105',
              country: 'US',
            },
          },

          // Ref -- reference to another record
          {
            name: 'primaryContactId',
            type: 'Ref',
            value: '003xx0000001234AAA',
          },

          // Variable -- generic variable
          {
            name: 'sessionToken',
            type: 'Variable',
            value: 'sess_abc123def456',
          },

          // With description (Android only, ignored on iOS)
          {
            name: 'currentCaseId',
            type: 'Text',
            value: '500xx0000009876AAA',
            description: 'The active support case for this customer',
          },
        ],
      });

      Alert.alert('Success', 'Context variables set (12 variables)');
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  return (
    <View style={styles.center}>
      <Button title="Set All Context Variable Types" onPress={handleSetContext} />
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
});
```

---

## Hidden Prechat Fields

Pre-populate hidden form fields for Service Agent conversations.

```tsx
import React, { useState } from 'react';
import { View, Button, Text, Alert, StyleSheet } from 'react-native';
import { AgentforceService, HiddenPreChatFields } from 'react-native-agentforce';

export default function HiddenPreChatExample() {
  const [currentFields, setCurrentFields] = useState<HiddenPreChatFields>({});

  const handleRegisterFields = async () => {
    try {
      // Register fields BEFORE launching
      await AgentforceService.registerHiddenPreChatFields({
        ContactId: '003xx0000001234AAA',
        AccountId: '001xx0000005678AAA',
        Subject: 'Mobile App Support',
        Origin: 'Mobile',
        Priority: 'High',
      });

      // Read back to verify
      const fields = await AgentforceService.getHiddenPreChatFields();
      setCurrentFields(fields);

      Alert.alert('Success', `${Object.keys(fields).length} fields registered`);
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  const handleLaunchWithFields = async () => {
    try {
      // Configure
      await AgentforceService.configure({
        type: 'service',
        serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
        organizationId: '00Dxx0000001234EAA',
        esDeveloperName: 'My_Service_Agent',
      });

      // Register hidden fields (before launch)
      await AgentforceService.registerHiddenPreChatFields({
        ContactId: '003xx0000001234AAA',
        AccountId: '001xx0000005678AAA',
      });

      // Launch -- hidden fields will be sent during session initialization
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  const handleClearFields = async () => {
    await AgentforceService.clearHiddenPreChatFields();
    setCurrentFields({});
    Alert.alert('Cleared', 'All hidden prechat fields cleared');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Hidden Prechat Fields</Text>
      <Text style={styles.note}>Service Agent only. Call before launch.</Text>

      <View style={styles.fieldList}>
        {Object.entries(currentFields).map(([key, value]) => (
          <Text key={key} style={styles.field}>
            {key}: {value}
          </Text>
        ))}
        {Object.keys(currentFields).length === 0 && (
          <Text style={styles.empty}>No fields registered</Text>
        )}
      </View>

      <Button title="Register Fields" onPress={handleRegisterFields} />
      <View style={styles.spacer} />
      <Button title="Launch with Fields" onPress={handleLaunchWithFields} />
      <View style={styles.spacer} />
      <Button title="Clear Fields" onPress={handleClearFields} color="red" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24 },
  title: { fontSize: 20, fontWeight: 'bold', marginBottom: 4 },
  note: { fontSize: 12, color: '#666', marginBottom: 16 },
  fieldList: { marginBottom: 24, padding: 12, backgroundColor: '#f5f5f5', borderRadius: 8 },
  field: { fontSize: 14, marginBottom: 4, fontFamily: 'monospace' },
  empty: { color: '#999', fontStyle: 'italic' },
  spacer: { height: 12 },
});
```

---

## Feature Flag Management

Read, modify, and apply feature flags.

```tsx
import React, { useState, useEffect } from 'react';
import { View, Text, Switch, Button, Alert, StyleSheet } from 'react-native';
import { AgentforceService, FeatureFlags } from 'react-native-agentforce';

const DEFAULT_FLAGS: FeatureFlags = {
  enableMultiAgent: true,
  enableMultiModalInput: false,
  enablePDFUpload: false,
  enableVoice: false,
  enableCustomViewProvider: false,
};

export default function FeatureFlagManager() {
  const [flags, setFlags] = useState<FeatureFlags>(DEFAULT_FLAGS);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    loadFlags();
  }, []);

  const loadFlags = async () => {
    const stored = await AgentforceService.getFeatureFlags();
    setFlags(stored);
    setDirty(false);
  };

  const toggleFlag = (key: keyof FeatureFlags) => {
    setFlags(prev => ({ ...prev, [key]: !prev[key] }));
    setDirty(true);
  };

  const handleSave = async () => {
    await AgentforceService.setFeatureFlags(flags);
    setDirty(false);
    Alert.alert(
      'Flags Saved',
      'Feature flags have been saved. They will take effect the next time configure() is called.'
    );
  };

  const handleSaveAndReconfigure = async () => {
    try {
      await AgentforceService.setFeatureFlags(flags);

      // Reconfigure to apply immediately.
      // NOTE: getConfiguration() returns Service Agent config only.
      // For Employee Agent mode, rebuild the config from your auth
      // credentials (see employee-agent-auth.md).
      const info = await AgentforceService.getConfigurationInfo();
      if (info.configured && info.mode === 'service') {
        const config = await AgentforceService.getConfiguration();
        if (config) {
          await AgentforceService.configure({
            ...config,
            featureFlags: flags,
          });
          Alert.alert('Applied', 'Feature flags saved and applied immediately.');
        }
      } else if (info.configured && info.mode === 'employee') {
        // For Employee Agent, flags are saved and will apply on next configure().
        Alert.alert('Saved', 'Feature flags saved. Restart the conversation to apply.');
      } else {
        Alert.alert('Saved', 'Flags saved. Configure the SDK to apply them.');
      }
      setDirty(false);
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  const flagEntries: Array<{ key: keyof FeatureFlags; label: string; description: string }> = [
    {
      key: 'enableMultiAgent',
      label: 'Multi-Agent',
      description: 'Allow SDK to pick from available agents when no agentId is set',
    },
    {
      key: 'enableMultiModalInput',
      label: 'Multi-Modal Input',
      description: 'Enable camera and image attachments',
    },
    {
      key: 'enablePDFUpload',
      label: 'PDF Upload',
      description: 'Enable PDF file upload in conversations',
    },
    {
      key: 'enableVoice',
      label: 'Voice Input',
      description: 'Enable microphone for voice input',
    },
    {
      key: 'enableCustomViewProvider',
      label: 'Custom View Provider',
      description: 'Enable custom React Native views for SDK output',
    },
  ];

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Feature Flags</Text>

      {flagEntries.map(({ key, label, description }) => (
        <View key={key} style={styles.flagRow}>
          <View style={styles.flagInfo}>
            <Text style={styles.flagLabel}>{label}</Text>
            <Text style={styles.flagDesc}>{description}</Text>
          </View>
          <Switch
            value={flags[key]}
            onValueChange={() => toggleFlag(key)}
          />
        </View>
      ))}

      {dirty && (
        <View style={styles.actions}>
          <Button title="Save (Apply on Next Configure)" onPress={handleSave} />
          <View style={styles.spacer} />
          <Button title="Save and Apply Now" onPress={handleSaveAndReconfigure} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  title: { fontSize: 22, fontWeight: 'bold', marginBottom: 16 },
  flagRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  flagInfo: { flex: 1 },
  flagLabel: { fontSize: 16, fontWeight: '600' },
  flagDesc: { fontSize: 12, color: '#666', marginTop: 2 },
  actions: { marginTop: 24 },
  spacer: { height: 12 },
});
```

---

## Complete HomeScreen Integration

A comprehensive example showing a complete app screen that integrates all major features.

```tsx
import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  Button,
  Alert,
  ScrollView,
  Linking,
  StyleSheet,
  AppRegistry,
} from 'react-native';
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  AuthCredentials,
  FeatureFlags,
  LogLevel,
  NavigationRequest,
  ViewProviderComponentData,
} from 'react-native-agentforce';

// ---------- Custom View Component ----------

function CustomAgentforceView({ componentData }: { componentData: ViewProviderComponentData }) {
  return (
    <View style={{ padding: 8, backgroundColor: '#e8f0fe', borderRadius: 6, margin: 4 }}>
      <Text style={{ fontWeight: 'bold' }}>[Custom] {componentData.definition}</Text>
      <Text>{JSON.stringify(componentData.properties, null, 2)}</Text>
    </View>
  );
}

AppRegistry.registerComponent('CustomAgentforceView', () => CustomAgentforceView);

// ---------- Config ----------

const SERVICE_CONFIG = {
  type: 'service' as const,
  serviceApiURL: 'https://mycompany-support.my.salesforce-scrt.com',
  organizationId: '00Dxx0000001234EAA',
  esDeveloperName: 'My_Service_Agent',
};

// ---------- Main Screen ----------

export default function HomeScreen() {
  // State
  const [configured, setConfigured] = useState(false);
  const [mode, setMode] = useState<'service' | 'employee' | null>(null);
  const [authSupported, setAuthSupported] = useState(false);
  const [loggedIn, setLoggedIn] = useState(false);
  const [credentials, setCredentials] = useState<AuthCredentials | null>(null);
  const [flags, setFlags] = useState<FeatureFlags | null>(null);
  const logCount = useRef(0);

  // ---------- Initialize ----------

  useEffect(() => {
    initializeApp();
    return () => {
      AgentforceService.clearLoggerDelegate();
      AgentforceService.clearNavigationDelegate();
    };
  }, []);

  const initializeApp = async () => {
    // Set up delegates first
    setupDelegates();

    // Check current state
    const info = await AgentforceService.getConfigurationInfo();
    setConfigured(info.configured);
    setMode(info.mode);

    const storedFlags = await AgentforceService.getFeatureFlags();
    setFlags(storedFlags);

    // Check Employee Agent auth
    const supported = await isEmployeeAgentAuthSupported();
    setAuthSupported(supported);
    if (supported) {
      const session = await hasEmployeeAgentSession();
      setLoggedIn(session);
      if (session) {
        setCredentials(await getEmployeeAgentCredentials());
      }
    }
  };

  // ---------- Delegates ----------

  const setupDelegates = () => {
    // Logger
    AgentforceService.setLoggerDelegate({
      onLog(level: LogLevel, message: string, error?: string) {
        logCount.current++;
        if (level === 'error') {
          console.error(`[SDK ERROR] ${message}`, error || '');
        }
      },
    });

    // Navigation
    AgentforceService.setNavigationDelegate({
      onNavigate(request: NavigationRequest) {
        switch (request.type) {
          case 'link':
            if (request.uri) Linking.openURL(request.uri as string);
            break;
          case 'record':
            Alert.alert('Record', `${request.objectType}: ${request.recordId}`);
            break;
          default:
            console.log('Navigation:', request.type, request);
        }
      },
    });

    // View Provider
    AgentforceService.setViewProviderDelegate({
      componentMap: {
        'copilot/richText': 'CustomAgentforceView',
      },
    }).catch(console.error);
  };

  // ---------- Service Agent ----------

  const handleConfigureService = async () => {
    try {
      await AgentforceService.configure({
        ...SERVICE_CONFIG,
        featureFlags: flags || undefined,
      });
      setConfigured(true);
      setMode('service');
      Alert.alert('Configured', 'Service Agent ready');
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  // ---------- Employee Agent ----------

  const handleLogin = async () => {
    try {
      const creds = await loginForEmployeeAgent();
      setCredentials(creds);
      setLoggedIn(true);
    } catch (error) {
      Alert.alert('Login Failed', String(error));
    }
  };

  const handleConfigureEmployee = async () => {
    if (!credentials) {
      Alert.alert('Error', 'Login first');
      return;
    }
    try {
      const agentId = await AgentforceService.getEmployeeAgentId();
      await AgentforceService.configure({
        type: 'employee',
        instanceUrl: credentials.instanceUrl,
        organizationId: credentials.organizationId,
        userId: credentials.userId,
        agentId: agentId || undefined,
        accessToken: credentials.accessToken,
        featureFlags: flags || undefined,
      });
      setConfigured(true);
      setMode('employee');
      Alert.alert('Configured', 'Employee Agent ready');
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  // ---------- Conversations ----------

  const handleLaunch = async () => {
    try {
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert('Launch Error', String(error));
    }
  };

  const handleNewConversation = async () => {
    try {
      await AgentforceService.startNewConversation();
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  const handleSetContext = async () => {
    try {
      await AgentforceService.setAdditionalContext({
        variables: [
          { name: 'screen', type: 'Text', value: 'HomeScreen' },
          { name: 'timestamp', type: 'DateTime', value: new Date().toISOString() },
          { name: 'userAgent', type: 'Text', value: 'react-native-agentforce-example' },
        ],
      });
      Alert.alert('Context Set', '3 variables sent to the agent');
    } catch (error) {
      Alert.alert('Error', String(error));
    }
  };

  // ---------- Cleanup ----------

  const handleReset = async () => {
    if (loggedIn) {
      await logoutEmployeeAgent();
    }
    await AgentforceService.resetSettings();
    setConfigured(false);
    setMode(null);
    setLoggedIn(false);
    setCredentials(null);
    Alert.alert('Reset', 'All settings cleared');
  };

  // ---------- Render ----------

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Agentforce Demo</Text>

      {/* Status */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Status</Text>
        <Text>Configured: {configured ? 'Yes' : 'No'}</Text>
        <Text>Mode: {mode || 'None'}</Text>
        <Text>Log messages received: {logCount.current}</Text>
      </View>

      {/* Service Agent */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Service Agent</Text>
        <Button title="Configure Service Agent" onPress={handleConfigureService} />
      </View>

      {/* Employee Agent */}
      {authSupported && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Employee Agent</Text>
          <Text>Logged in: {loggedIn ? 'Yes' : 'No'}</Text>
          {!loggedIn ? (
            <Button title="Login" onPress={handleLogin} />
          ) : (
            <Button title="Configure Employee Agent" onPress={handleConfigureEmployee} />
          )}
        </View>
      )}

      {/* Conversation Actions */}
      {configured && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Conversation</Text>
          <Button title="Launch Conversation" onPress={handleLaunch} />
          <View style={styles.spacer} />
          <Button title="New Conversation" onPress={handleNewConversation} />
          <View style={styles.spacer} />
          <Button title="Set Context Variables" onPress={handleSetContext} />
        </View>
      )}

      {/* Reset */}
      <View style={styles.section}>
        <Button title="Reset Everything" onPress={handleReset} color="red" />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: 16, paddingBottom: 48 },
  title: { fontSize: 28, fontWeight: 'bold', marginBottom: 24 },
  section: { marginBottom: 24 },
  sectionTitle: { fontSize: 18, fontWeight: '600', marginBottom: 8 },
  spacer: { height: 8 },
});
```

---

## Related Documentation

- [Getting Started](./getting-started.md) -- Installation and prerequisites.
- [Configuration](./configuration.md) -- Config options and feature flags.
- [Conversations](./conversations.md) -- Conversation lifecycle and context.
- [Delegates](./delegates.md) -- Delegate patterns and registration.
- [Employee Agent Auth](./employee-agent-auth.md) -- Auth flow details.
- [API Reference](./api-reference.md) -- Complete method reference.
- [Platform Notes](./platform-notes.md) -- Platform-specific behavior.
- [Troubleshooting](./troubleshooting.md) -- Common issues.
