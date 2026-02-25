/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 */

import React, { useEffect } from 'react';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';

type Props = NativeStackScreenProps<any, 'FeatureFlags'>;

/**
 * Redirects to the Settings screen's Flags tab.
 * Kept as a navigation target for backward compatibility.
 */
const FeatureFlagsScreen: React.FC<Props> = ({ navigation }) => {
  useEffect(() => {
    navigation.replace('Settings', { tab: 'features' });
  }, [navigation]);

  return null;
};

export default FeatureFlagsScreen;
