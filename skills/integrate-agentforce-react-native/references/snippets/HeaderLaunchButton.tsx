// Nav-bar / header icon button. Drop into `headerRight` of a React
// Navigation screen so the chat is always one tap away.
//
// Usage:
//   <Stack.Screen
//     name="Home"
//     component={HomeScreen}
//     options={{ headerRight: () => <HeaderLaunchButton /> }}
//   />

import React from 'react';
import { Text, TouchableOpacity } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

export function HeaderLaunchButton() {
  return (
    <TouchableOpacity
      onPress={() => AgentforceService.launchConversation()}
      hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
      {/* Replace with your icon library (e.g. react-native-vector-icons) */}
      <Text style={{ color: '#FFFFFF', fontSize: 18 }}>💬</Text>
    </TouchableOpacity>
  );
}
