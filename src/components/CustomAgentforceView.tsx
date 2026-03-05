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

/** Max nesting depth to prevent runaway recursion. */
const MAX_DEPTH = 6;

/** Check whether a value is a plain object (not an array). */
function isPlainObject(v: unknown): v is Record<string, unknown> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

/** Format a leaf value as a string. */
function formatLeaf(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  return String(value);
}

/** Whether a value will render as a nested block (table or array). */
function isNestedValue(v: unknown, depth: number): boolean {
  if (depth >= MAX_DEPTH) return false;
  if (isPlainObject(v)) return Object.keys(v).length > 0;
  if (Array.isArray(v)) return v.length > 0;
  return false;
}

/**
 * Recursively renders a value. Plain objects become nested key/value tables,
 * arrays render each element, and primitives render as text.
 */
const ValueRenderer: React.FC<{ value: unknown; depth: number }> = ({
  value,
  depth,
}) => {
  const compact = depth >= 3; // tighter padding at deeper levels

  if (isPlainObject(value) && depth < MAX_DEPTH) {
    const entries = Object.entries(value);
    if (entries.length === 0) return <Text style={styles.emptyText}>{'{ }'}</Text>;
    return (
      <View style={[styles.nestedTable, compact && styles.nestedTableCompact]}>
        {entries.map(([k, v], i) => (
          <PropertyRow key={k} label={k} value={v} depth={depth} isLast={i === entries.length - 1} />
        ))}
      </View>
    );
  }

  if (Array.isArray(value) && depth < MAX_DEPTH) {
    if (value.length === 0) return <Text style={styles.emptyText}>{'[ ]'}</Text>;
    return (
      <View style={[styles.nestedArray, compact && styles.nestedTableCompact]}>
        {value.map((item, i) => {
          const itemNested = isNestedValue(item, depth + 1);
          return (
            <View
              key={i}
              style={[
                itemNested ? styles.arrayItemVertical : styles.arrayItem,
                i < value.length - 1 && styles.arrayItemBorder,
              ]}
            >
              <Text style={styles.arrayIndex}>{i}</Text>
              <View style={itemNested ? undefined : styles.arrayValue}>
                <ValueRenderer value={item} depth={depth + 1} />
              </View>
            </View>
          );
        })}
      </View>
    );
  }

  // Leaf value (or max depth reached — fall back to JSON)
  const text =
    depth >= MAX_DEPTH && typeof value === 'object'
      ? JSON.stringify(value)
      : formatLeaf(value);

  return (
    <Text style={styles.rowValue} selectable>
      {text}
    </Text>
  );
};

/**
 * Renders a single key/value row, stacking vertically when the value is a
 * nested object/array so it can use the full width.
 */
const PropertyRow: React.FC<{
  label: string;
  value: unknown;
  depth: number;
  isLast: boolean;
}> = ({ label, value, depth, isLast }) => {
  const nested = isNestedValue(value, depth + 1);
  const compact = depth >= 2;

  return (
    <View
      style={[
        nested ? styles.rowVertical : styles.row,
        compact && styles.rowCompact,
        !isLast && styles.rowBorder,
      ]}
    >
      <Text
        style={[styles.rowKey, compact && styles.rowKeyCompact]}
        numberOfLines={1}
      >
        {label}
      </Text>
      <ValueRenderer value={value} depth={depth + 1} />
    </View>
  );
};

const CustomAgentforceView: React.FC<CustomAgentforceViewProps> = ({
  definition = 'unknown',
  properties = {},
}) => {
  const entries = Object.entries(properties);

  // If the only meaningful property is a single text-like value, show it inline
  const textKeys = ['text', 'value', 'content', 'label'];
  const singleText =
    entries.length === 1 &&
    textKeys.includes(entries[0][0]) &&
    typeof entries[0][1] === 'string'
      ? (entries[0][1] as string)
      : null;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.badge}>
          <Text style={styles.badgeText}>Custom RN View</Text>
        </View>
        <Text style={styles.definitionText}>{definition}</Text>
      </View>

      {singleText ? (
        <Text style={styles.contentText} selectable>
          {singleText}
        </Text>
      ) : entries.length > 0 ? (
        <ScrollView style={styles.contentScroll} nestedScrollEnabled>
          <View style={styles.table}>
            {entries.map(([key, val], idx) => (
              <PropertyRow
                key={key}
                label={key}
                value={val}
                depth={0}
                isLast={idx === entries.length - 1}
              />
            ))}
          </View>
        </ScrollView>
      ) : (
        <Text style={styles.emptyText}>No properties</Text>
      )}
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
  contentScroll: {
    maxHeight: 400,
  },
  table: {
    backgroundColor: '#ffffff',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#d0d7e2',
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    paddingVertical: 8,
    paddingHorizontal: 10,
  },
  rowVertical: {
    flexDirection: 'column',
    paddingVertical: 8,
    paddingHorizontal: 10,
    gap: 4,
  },
  rowCompact: {
    paddingVertical: 5,
    paddingHorizontal: 8,
  },
  rowBorder: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#d0d7e2',
  },
  rowKey: {
    width: 100,
    fontSize: 12,
    fontWeight: '600',
    color: '#4a5568',
    marginRight: 8,
  },
  rowKeyCompact: {
    width: 80,
    fontSize: 11,
  },
  rowValue: {
    flex: 1,
    fontSize: 13,
    color: '#212529',
    lineHeight: 18,
  },
  nestedTable: {
    backgroundColor: '#f8f9fb',
    borderRadius: 4,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#d0d7e2',
    overflow: 'hidden',
  },
  nestedTableCompact: {
    borderRadius: 3,
  },
  nestedArray: {
    backgroundColor: '#f8f9fb',
    borderRadius: 4,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#d0d7e2',
    overflow: 'hidden',
  },
  arrayItem: {
    flexDirection: 'row',
    paddingVertical: 6,
    paddingHorizontal: 8,
  },
  arrayItemVertical: {
    flexDirection: 'column',
    paddingVertical: 6,
    paddingHorizontal: 8,
    gap: 4,
  },
  arrayItemBorder: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#d0d7e2',
  },
  arrayIndex: {
    width: 24,
    fontSize: 11,
    fontWeight: '600',
    color: '#9ca3af',
    marginRight: 4,
  },
  arrayValue: {
    flex: 1,
  },
  contentText: {
    fontSize: 14,
    color: '#212529',
    lineHeight: 20,
  },
  emptyText: {
    fontSize: 12,
    color: '#9ca3af',
    fontStyle: 'italic',
  },
});

export default CustomAgentforceView;
