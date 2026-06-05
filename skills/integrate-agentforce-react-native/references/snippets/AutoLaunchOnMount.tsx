// Auto-launch on first app open. Use only if the chat IS the product —
// otherwise it's a heavy interruption.
//
// Wraps your root component so the chat opens automatically once
// configuration resolves. Remove the auto-launch effect if you only
// want the configure() call.

import React, { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { AgentforceService } from 'react-native-agentforce';
import { configureAgentforce } from './agentforceConfig';

export function AutoLaunchOnMount({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    configureAgentforce()
      .then(() => AgentforceService.launchConversation())
      .finally(() => setReady(true));

    return () => {
      AgentforceService.destroy();
    };
  }, []);

  if (!ready) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator />
      </View>
    );
  }

  return <>{children}</>;
}
