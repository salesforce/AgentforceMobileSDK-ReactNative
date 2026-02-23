/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  ActivityIndicator,
} from 'react-native';
import { AgentforceService } from 'react-native-agentforce';
import type { FeatureFlags } from 'react-native-agentforce';

const FLAG_KEYS: (keyof FeatureFlags)[] = [
  'enableMultiAgent',
  'enableMultiModalInput',
  'enablePDFUpload',
  'enableVoice',
];

const FLAG_LABELS: Record<keyof FeatureFlags, string> = {
  enableMultiAgent: 'Multi-agent',
  enableMultiModalInput: 'Multi-modal input',
  enablePDFUpload: 'PDF upload',
  enableVoice: 'Voice',
};

const FLAG_HINTS: Record<keyof FeatureFlags, string> = {
  enableMultiAgent: 'Allow switching between multiple agents',
  enableMultiModalInput: 'Enable image/file input in addition to text',
  enablePDFUpload: 'Allow PDF file uploads',
  enableVoice: 'Enable immersive voice',
};

const FeatureFlagsScreen: React.FC = () => {
  const [flags, setFlags] = useState<FeatureFlags | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadFlags();
  }, []);

  const loadFlags = async () => {
    setLoading(true);
    try {
      const stored = await AgentforceService.getFeatureFlags();
      setFlags(stored);
    } catch (e) {
      console.error('Failed to load feature flags:', e);
      setFlags({
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: false,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleToggle = async (key: keyof FeatureFlags, value: boolean) => {
    if (flags == null) return;
    const next = { ...flags, [key]: value };
    setFlags(next);
    setSaving(true);
    try {
      await AgentforceService.setFeatureFlags(next);
    } catch (e) {
      console.error('Failed to save feature flags:', e);
      setFlags(flags);
    } finally {
      setSaving(false);
    }
  };

  if (loading || flags == null) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" color="#0176D3" />
        <Text style={styles.loadingText}>Loading feature flags...</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.scrollContent}
    >
      <View style={styles.header}>
        <Text style={styles.title}>Feature Flags</Text>
        <Text style={styles.description}>
          Toggle SDK features. Changes are saved immediately and apply the next
          time you configure Service or Employee Agent (e.g. after saving in
          Configuration or signing in).
        </Text>
        {saving && (
          <Text style={styles.savingText}>Saving…</Text>
        )}
      </View>

      <View style={styles.card}>
        {FLAG_KEYS.map((key) => (
          <View key={key} style={styles.row}>
            <View style={styles.labelBlock}>
              <Text style={styles.label}>{FLAG_LABELS[key]}</Text>
              <Text style={styles.hint}>{FLAG_HINTS[key]}</Text>
            </View>
            <Switch
              value={flags[key]}
              onValueChange={(value) => handleToggle(key, value)}
              trackColor={{ false: '#ced4da', true: '#0176D3' }}
              thumbColor="#ffffff"
            />
          </View>
        ))}
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 14,
    color: '#6c757d',
  },
  savingText: {
    marginTop: 8,
    fontSize: 13,
    color: '#0176D3',
  },
  header: {
    marginBottom: 20,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#212529',
    marginBottom: 8,
  },
  description: {
    fontSize: 14,
    color: '#6c757d',
    lineHeight: 20,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f3f4',
  },
  labelBlock: {
    flex: 1,
    marginRight: 16,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
  },
  hint: {
    fontSize: 12,
    color: '#6c757d',
    marginTop: 2,
  },
});

export default FeatureFlagsScreen;
