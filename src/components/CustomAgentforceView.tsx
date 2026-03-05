/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Example custom view provider component for Agentforce SDK.
 *
 * When the Custom View Provider feature flag is enabled and this component
 * is registered, the native SDK delegates rendering of specified component
 * types to this React Native view instead of the built-in native views.
 *
 * Register with AppRegistry and configure via AgentforceService:
 *   AppRegistry.registerComponent('CustomAgentforceView', () => CustomAgentforceView);
 *   AgentforceService.setViewProviderDelegate({
 *     componentTypes: ['copilot/richText', 'copilot/markdown'],
 *     reactComponentName: 'CustomAgentforceView',
 *   });
 */

import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import type { ViewProviderComponentData } from 'react-native-agentforce';

/**
 * Props passed from the native BridgeViewProvider via RCTRootView / ReactRootView.
 * Matches the ViewProviderComponentData type.
 */
interface CustomAgentforceViewProps {
  definition?: string;
  name?: string;
  properties?: Record<string, unknown>;
  subComponents?: ViewProviderComponentData[];
}

const CustomAgentforceView: React.FC<CustomAgentforceViewProps> = ({
  definition = 'unknown',
  properties = {},
}) => {
  // Extract text content from common property patterns
  const textContent =
    (properties.text as string) ??
    (properties.value as string) ??
    (properties.content as string) ??
    (properties.label as string) ??
    JSON.stringify(properties, null, 2);

  return (
    <View style={styles.container}>
      <View style={styles.badge}>
        <Text style={styles.badgeText}>Custom RN View</Text>
      </View>
      <Text style={styles.definitionText}>{definition}</Text>
      <ScrollView style={styles.contentScroll} nestedScrollEnabled>
        <Text style={styles.contentText}>{textContent}</Text>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#f0f4ff',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#4a90d9',
    padding: 12,
    margin: 4,
  },
  badge: {
    backgroundColor: '#4a90d9',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
    alignSelf: 'flex-start',
    marginBottom: 6,
  },
  badgeText: {
    color: '#ffffff',
    fontSize: 10,
    fontWeight: '700',
  },
  definitionText: {
    fontSize: 11,
    color: '#6c757d',
    marginBottom: 4,
    fontFamily: 'monospace',
  },
  contentScroll: {
    maxHeight: 200,
  },
  contentText: {
    fontSize: 14,
    color: '#212529',
    lineHeight: 20,
  },
});

export default CustomAgentforceView;
