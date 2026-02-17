/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Image,
} from 'react-native';
import { AgentforceService } from 'react-native-agentforce';

interface HomeScreenProps {
  navigation: any;
}

const HomeScreen: React.FC<HomeScreenProps> = ({ navigation }) => {
  const [isConfigured, setIsConfigured] = useState(false);
  const [isChecking, setIsChecking] = useState(true);

  useEffect(() => {
    checkConfiguration();
  }, []);

  // Refresh configuration status when screen gains focus
  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      checkConfiguration();
    });
    return unsubscribe;
  }, [navigation]);

  const checkConfiguration = async () => {
    setIsChecking(true);
    try {
      const configured = await AgentforceService.isConfigured();
      setIsConfigured(configured);
    } catch (error) {
      console.error('Error checking configuration:', error);
      setIsConfigured(false);
    } finally {
      setIsChecking(false);
    }
  };

  const handleLaunchAgentforce = async () => {
    if (!isConfigured) {
      Alert.alert(
        'Configuration Required',
        'Please configure Service Agent settings before launching.',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Configure',
            onPress: () => navigation.navigate('Settings'),
          },
        ]
      );
      return;
    }

    try {
      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert(
        'Error',
        'Failed to launch Agentforce conversation. Please check your configuration.'
      );
    }
  };

  const launchButtonSubtitle = isChecking
    ? 'Checking...'
    : isConfigured
      ? 'Tap to launch'
      : 'Not configured';

  return (
    <View style={styles.container}>
      <View style={styles.centerContent}>
        <View style={styles.logoContainer}>
          <Image
            source={require('../../agentforce-icon.png')}
            style={styles.logo}
          />
        </View>

        <Text style={styles.title}>Agentforce</Text>
        <Text style={styles.subtitle}>
          Choose an agent type to launch
        </Text>

        {isChecking && (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>
              Checking configurations...
            </Text>
          </View>
        )}

        <View style={styles.buttonsContainer}>
          <TouchableOpacity
            style={[
              styles.launchButton,
              styles.serviceAgentButton,
              !isConfigured && styles.launchButtonDisabled,
              isConfigured && styles.launchButtonEnabled,
            ]}
            onPress={handleLaunchAgentforce}
            disabled={isChecking}
          >
            <Text style={styles.launchButtonIcon}>💬</Text>
            <View style={styles.launchButtonContent}>
              <Text style={styles.launchButtonTitle}>Service Agent</Text>
              <Text style={styles.launchButtonSubtitle}>
                {launchButtonSubtitle}
              </Text>
            </View>
            {isConfigured && (
              <Text style={styles.launchButtonArrow}>›</Text>
            )}
          </TouchableOpacity>
        </View>

        <TouchableOpacity
          style={styles.settingsButton}
          onPress={() => navigation.navigate('Settings')}
        >
          <Text style={styles.settingsButtonText}>⚙️ Settings</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  centerContent: {
    flex: 1,
    justifyContent: 'flex-start',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingTop: 140,
  },
  logoContainer: {
    width: 100,
    height: 100,
    borderRadius: 50,
    backgroundColor: '#ffffff',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  logo: {
    width: 64,
    height: 64,
    resizeMode: 'contain',
  },
  title: {
    fontSize: 26,
    fontWeight: 'bold',
    color: '#212529',
    textAlign: 'center',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: '#6c757d',
    textAlign: 'center',
    marginBottom: 20,
    paddingHorizontal: 16,
  },
  loadingContainer: {
    marginBottom: 16,
  },
  loadingText: {
    fontSize: 14,
    color: '#6c757d',
  },
  buttonsContainer: {
    width: '100%',
    marginBottom: 24,
  },
  launchButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  serviceAgentButton: {
    width: '100%',
  },
  launchButtonDisabled: {
    opacity: 0.7,
  },
  launchButtonEnabled: {
    borderWidth: 1,
    borderColor: '#0176D3',
  },
  launchButtonIcon: {
    fontSize: 32,
    marginRight: 16,
  },
  launchButtonContent: {
    flex: 1,
  },
  launchButtonTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 4,
  },
  launchButtonSubtitle: {
    fontSize: 14,
    color: '#6c757d',
  },
  launchButtonArrow: {
    fontSize: 24,
    color: '#0176D3',
    fontWeight: '600',
  },
  settingsButton: {
    padding: 12,
  },
  settingsButtonText: {
    fontSize: 16,
    color: '#0176D3',
    fontWeight: '600',
  },
});

export default HomeScreen;

