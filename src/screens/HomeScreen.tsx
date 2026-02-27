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
  Linking,
  Platform,
  ScrollView,
} from 'react-native';
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  getEmployeeAgentCredentials,
  EMPLOYEE_AGENT_CONFIG,
  isEmployeeAgentConfigValid,
  LoggerDelegate,
  LogLevel,
  NavigationDelegate,
  NavigationRequest,
} from 'react-native-agentforce';
import { UI_FEATURES } from '../config/UIFeatures';

interface HomeScreenProps {
  navigation: any;
}

// Sample logger delegate — forwards Agentforce SDK logs to console
const agentforceLogger: LoggerDelegate = {
  onLog(level: LogLevel, message: string, error?: string) {
    const timestamp = new Date().toISOString();
    const prefix = `[${timestamp}][Agentforce ${level.toUpperCase()}]`;
    if (error) {
      console.log(`${prefix} ${message} | ERROR: ${error}`);
    } else {
      console.log(`${prefix} ${message}`);
    }
  },
};

// Sample navigation delegate — handles Agentforce SDK navigation requests.
// Modify this to add your own navigation handling logic.
// The request.type indicates the destination kind ('record', 'link',
// 'quickAction', 'pageReference', 'objectHome', 'app').
// Access fields like request.recordId, request.uri, request.actionName, etc.
// See NavigationDelegate.ts for the full list of known fields per type.
const agentforceNavigation: NavigationDelegate = {
  onNavigate(request: NavigationRequest) {
    // For debugging — replace with your own navigation handling
    Alert.alert('Navigation Request', JSON.stringify(request, null, 2));
    console.log(`[Agentforce Nav] ${request.type}:`, request);
  },
};

const HomeScreen: React.FC<HomeScreenProps> = ({ navigation }) => {
  const [isServiceAgentConfigured, setIsServiceAgentConfigured] =
    useState(false);
  const [isEmployeeAgentConfigured, setIsEmployeeAgentConfigured] =
    useState(false);
  const [isEmployeeAgentAuthAvailable, setIsEmployeeAgentAuthAvailable] =
    useState(false);
  const [isChecking, setIsChecking] = useState(true);
  const [activeMode, setActiveMode] = useState<
    'none' | 'service' | 'employee'
  >('none');

  useEffect(() => {
    // Register logger delegate so SDK logs are forwarded to JS
    AgentforceService.setLoggerDelegate(agentforceLogger);
    // Register navigation delegate so SDK navigation requests are forwarded to JS
    AgentforceService.setNavigationDelegate(agentforceNavigation);
    checkConfigurations();

    return () => {
      AgentforceService.clearLoggerDelegate();
      AgentforceService.clearNavigationDelegate();
    };
  }, []);

  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      checkConfigurations();
    });
    return unsubscribe;
  }, [navigation]);

  const checkConfigurations = async () => {
    setIsChecking(true);
    try {
      const serviceConfig = await AgentforceService.getConfiguration();
      const serviceConfigured = !!(
        serviceConfig?.serviceApiURL &&
        serviceConfig?.organizationId &&
        serviceConfig?.esDeveloperName
      );
      setIsServiceAgentConfigured(serviceConfigured);

      const authSupported = await isEmployeeAgentAuthSupported();
      const fileConfigValid = isEmployeeAgentConfigValid();
      setIsEmployeeAgentAuthAvailable(authSupported || fileConfigValid);

      const hasSession = authSupported
        ? await hasEmployeeAgentSession()
        : false;
      const employeeConfigured = hasSession || fileConfigValid;
      setIsEmployeeAgentConfigured(employeeConfigured);

      const configInfo = await AgentforceService.getConfigurationInfo();
      if (configInfo?.configured && configInfo?.mode) {
        setActiveMode(configInfo.mode as 'service' | 'employee');
      } else {
        setActiveMode('none');
      }
    } catch (error) {
      console.error('Error checking configuration:', error);
    } finally {
      setIsChecking(false);
    }
  };

  const handleLaunchServiceAgent = async () => {
    if (!isServiceAgentConfigured) {
      Alert.alert(
        'Configuration Required',
        'Please configure Service Agent settings first.',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Configure',
            onPress: () => navigation.navigate('Settings', { tab: 'service' }),
          },
        ]
      );
      return;
    }

    try {
      // Only reconfigure if switching from another mode or first launch
      if (activeMode !== 'service') {
        const config = await AgentforceService.getConfiguration();
        if (config) {
          // Get current feature flags to preserve user settings
          const featureFlags = await AgentforceService.getFeatureFlags();

          await AgentforceService.configure({
            type: 'service',
            serviceApiURL: config.serviceApiURL,
            organizationId: config.organizationId,
            esDeveloperName: config.esDeveloperName,
            featureFlags,
          });
          setActiveMode('service');
        }
      }

      await AgentforceService.launchConversation();
    } catch (error) {
      Alert.alert(
        'Error',
        'Failed to launch Service Agent. Please check your configuration.'
      );
      console.error('Launch error:', error);
    }
  };

  const handleLaunchEmployeeAgent = async () => {
    if (!isEmployeeAgentConfigured) {
      Alert.alert(
        'Configuration Required',
        'Please sign in via Settings > Employee Agent to use Employee Agent.',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'View Settings',
            onPress: () => navigation.navigate('Settings', { tab: 'employee' }),
          },
        ]
      );
      return;
    }

    try {
      // Always read the latest agentID from settings
      const storedAgentId = await AgentforceService.getEmployeeAgentId();
      const agentId = storedAgentId?.trim() ?? '';
      const creds = await getEmployeeAgentCredentials();

      // Get current feature flags to preserve user settings
      const featureFlags = await AgentforceService.getFeatureFlags();

      // Always reconfigure to pick up latest agentID and credentials
      const config = creds
        ? {
            type: 'employee' as const,
            instanceUrl: creds.instanceUrl,
            organizationId: creds.organizationId,
            userId: creds.userId,
            agentId: agentId || undefined,
            accessToken: creds.accessToken,
            featureFlags,
          }
        : { ...EMPLOYEE_AGENT_CONFIG, agentId: agentId || undefined, featureFlags };
      await AgentforceService.configure(config);
      setActiveMode('employee');

      await AgentforceService.launchConversation();
    } catch (error: any) {
      Alert.alert(
        'Error',
        error?.message ||
          'Failed to launch Employee Agent. Token may be expired.'
      );
      console.error('Launch error:', error);
    }
  };

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.logoContainer}>
          <Image
            source={require('../../agentforce-icon.png')}
            style={styles.logo}
          />
        </View>

        <Text style={styles.title}>Agentforce</Text>
        <Text style={styles.subtitle}>
          {UI_FEATURES.SHOW_EMPLOYEE_AGENT
            ? 'Choose an agent type to launch'
            : 'Service Agent'}
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
              !isServiceAgentConfigured && styles.launchButtonDisabled,
              activeMode === 'service' && styles.activeButton,
            ]}
            onPress={handleLaunchServiceAgent}
            disabled={isChecking}
          >
            <View style={styles.launchButtonContent}>
              <Text style={styles.launchButtonTitle}>Service Agent</Text>
              <Text style={styles.launchButtonSubtitle}>
                {isServiceAgentConfigured
                  ? activeMode === 'service'
                    ? 'Active - Tap to launch'
                    : 'Configured - Tap to launch'
                  : 'Not configured'}
              </Text>
            </View>
            {isServiceAgentConfigured && (
              <Text style={styles.launchButtonArrow}>›</Text>
            )}
          </TouchableOpacity>

          {UI_FEATURES.SHOW_EMPLOYEE_AGENT && (
            <TouchableOpacity
              style={[
                styles.launchButton,
                styles.employeeAgentButton,
                !isEmployeeAgentConfigured && styles.launchButtonDisabled,
                activeMode === 'employee' && styles.activeButtonEmployee,
              ]}
              onPress={handleLaunchEmployeeAgent}
              disabled={isChecking}
            >
              <View style={styles.launchButtonContent}>
                <Text style={styles.launchButtonTitle}>Employee Agent</Text>
                <Text style={styles.launchButtonSubtitle}>
                  {isEmployeeAgentConfigured
                    ? activeMode === 'employee'
                      ? 'Active - Tap to launch'
                      : 'Configured - Tap to launch'
                    : 'Sign in in Settings to configure'}
                </Text>
              </View>
              {isEmployeeAgentConfigured && (
                <Text style={styles.launchButtonArrow}>›</Text>
              )}
            </TouchableOpacity>
          )}
        </View>

        <TouchableOpacity
          style={styles.settingsButton}
          onPress={() => navigation.navigate('Settings')}
        >
          <Text style={styles.settingsButtonText}>Settings</Text>
        </TouchableOpacity>

        <Text style={styles.platformText}>
          Running on {Platform.OS === 'ios' ? 'iOS' : 'Android'}
        </Text>
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  scrollView: {
    flex: 1,
  },
  content: {
    padding: 20,
    alignItems: 'center',
    paddingBottom: 40,
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
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 5,
  },
  logo: {
    width: 70,
    height: 70,
    resizeMode: 'contain',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#212529',
    textAlign: 'center',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#6c757d',
    textAlign: 'center',
    marginBottom: 24,
  },
  loadingContainer: {
    padding: 12,
    backgroundColor: '#e7f3ff',
    borderRadius: 8,
    marginBottom: 16,
    width: '100%',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 14,
    color: '#0070f3',
  },
  buttonsContainer: {
    width: '100%',
    gap: 16,
    marginBottom: 24,
  },
  launchButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    borderRadius: 12,
    backgroundColor: '#ffffff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  serviceAgentButton: {
    borderLeftWidth: 4,
    borderLeftColor: '#7B1FA2',
  },
  employeeAgentButton: {
    borderLeftWidth: 4,
    borderLeftColor: '#0176D3',
  },
  launchButtonDisabled: {
    opacity: 0.5,
    borderLeftColor: '#adb5bd',
  },
  activeButton: {
    backgroundColor: '#f3e5f5',
    borderLeftColor: '#7B1FA2',
  },
  activeButtonEmployee: {
    backgroundColor: '#e7f3ff',
    borderLeftColor: '#0176D3',
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
    color: '#7B1FA2',
    fontWeight: '300',
  },
  settingsButton: {
    padding: 16,
    backgroundColor: '#ffffff',
    borderRadius: 8,
    width: '100%',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#e9ecef',
  },
  settingsButtonText: {
    fontSize: 16,
    color: '#495057',
    fontWeight: '500',
  },
  platformText: {
    marginTop: 20,
    fontSize: 12,
    color: '#adb5bd',
  },
});

export default HomeScreen;
