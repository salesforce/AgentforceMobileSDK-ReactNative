/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * Minimal custom view provider component for Agentforce SDK.
 *
 * HOW VIEW PROVIDER WIRING WORKS (3 steps):
 *
 * 1. Register this component with AppRegistry (see index.js):
 *      AppRegistry.registerComponent('CustomAgentforceView', () => CustomAgentforceView);
 *
 * 2. Tell the SDK which component types to delegate (see HomeScreen.tsx):
 *      AgentforceService.setViewProviderDelegate({
 *        componentMap: {
 *          'copilot/richText': 'CustomAgentforceView',
 *          'copilot/markdown': 'CustomAgentforceView',
 *        },
 *      });
 *
 * 3. This component receives ViewProviderComponentData as props (below).
 *    The native SDK calls canHandle(definition) -> true, then renders a
 *    RCTRootView / ReactRootView with the matching component name.
 *
 * For a richer version with nested key/value tables, see ComplexAgentforceDataView.
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { ViewProviderComponentData } from 'react-native-agentforce';

/** Props passed from the native BridgeViewProvider via RCTRootView / ReactRootView. */
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
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>Custom RN View</Text>
        </View>
        <Text style={styles.definitionText}>{definition}</Text>
      </View>
      <Text style={styles.json} selectable>
        {JSON.stringify(properties, null, 2)}
      </Text>
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
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8,
  },
  badge: {
    backgroundColor: '#4a90d9',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  badgeText: {
    color: '#ffffff',
    fontSize: 10,
    fontWeight: '700',
  },
  definitionText: {
    fontSize: 11,
    color: '#6c757d',
    fontFamily: 'monospace',
  },
  json: {
    fontSize: 12,
    color: '#212529',
    fontFamily: 'monospace',
    lineHeight: 18,
  },
});

export default CustomAgentforceView;
