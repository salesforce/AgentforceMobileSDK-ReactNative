// Prominent launch button for a Home screen.
//
// Disables itself until configureAgentforce() has resolved.

import React, { useEffect, useState } from 'react';
import { Alert, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

export function ChatLaunchButton() {
  const [configured, setConfigured] = useState(false);

  useEffect(() => {
    AgentforceService.isConfigured().then(setConfigured);
  }, []);

  const onPress = async () => {
    try {
      await AgentforceService.launchConversation();
    } catch (e) {
      Alert.alert('Failed to launch Agentforce', String(e));
    }
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[styles.button, !configured && styles.buttonDisabled]}
        onPress={onPress}
        disabled={!configured}>
        <Text style={styles.buttonText}>
          {configured ? 'Ask the agent' : 'Configuring…'}
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  button: {
    backgroundColor: '#0176D3',
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonDisabled: { backgroundColor: '#A8B7C7' },
  buttonText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
});
