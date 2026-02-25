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
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Switch,
  ActivityIndicator,
} from 'react-native';
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
  refreshEmployeeAgentCredentials,
} from 'react-native-agentforce';
import type { FeatureFlags } from 'react-native-agentforce';

type TabType = 'service' | 'employee' | 'features';

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

interface SettingsScreenProps {
  navigation: any;
  route?: { params?: { tab?: TabType } };
}

const SettingsScreen: React.FC<SettingsScreenProps> = ({
  navigation,
  route,
}) => {
  const [activeTab, setActiveTab] = useState<TabType>(
    route?.params?.tab ?? 'service'
  );

  const [serviceApiURL, setServiceApiURL] = useState('');
  const [organizationId, setOrganizationId] = useState('');
  const [esDeveloperName, setEsDeveloperName] = useState('');
  const [loading, setLoading] = useState(false);
  const [loadingConfig, setLoadingConfig] = useState(true);

  const [employeeAgentId, setEmployeeAgentId] = useState('');
  const [authSupported, setAuthSupported] = useState(false);
  const [employeeLoggedIn, setEmployeeLoggedIn] = useState(false);

  const [featureFlags, setFeatureFlags] = useState<FeatureFlags | null>(null);
  const [savingFlags, setSavingFlags] = useState(false);

  useEffect(() => {
    loadSavedConfiguration();
    loadStoredEmployeeAgentId();
    checkAuthStatus();
    loadFeatureFlags();
  }, []);

  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      if (activeTab === 'employee') {
        checkAuthStatus();
      }
    });
    return unsubscribe;
  }, [navigation, activeTab]);

  useEffect(() => {
    if (route?.params?.tab) {
      setActiveTab(route.params.tab);
    }
  }, [route?.params?.tab]);

  const checkAuthStatus = async () => {
    const supported = await isEmployeeAgentAuthSupported();
    setAuthSupported(supported);
    if (supported) {
      const loggedIn = await hasEmployeeAgentSession();
      setEmployeeLoggedIn(loggedIn);
    }
  };

  const loadStoredEmployeeAgentId = async () => {
    try {
      const stored = await AgentforceService.getEmployeeAgentId();
      setEmployeeAgentId(stored ?? '');
    } catch {
      setEmployeeAgentId('');
    }
  };

  const loadSavedConfiguration = async () => {
    try {
      setLoadingConfig(true);
      const savedConfig = await AgentforceService.getConfiguration();
      if (savedConfig) {
        setServiceApiURL(savedConfig.serviceApiURL ?? '');
        setOrganizationId(savedConfig.organizationId ?? '');
        setEsDeveloperName(savedConfig.esDeveloperName ?? '');
      }
    } catch (error) {
      console.error('Failed to load saved configuration:', error);
    } finally {
      setLoadingConfig(false);
    }
  };

  const validateServiceInputs = (): boolean => {
    if (!serviceApiURL.trim()) {
      Alert.alert('Validation Error', 'Service API URL is required');
      return false;
    }
    if (!organizationId.trim()) {
      Alert.alert('Validation Error', 'Organization ID is required');
      return false;
    }
    if (!esDeveloperName.trim()) {
      Alert.alert('Validation Error', 'ES Developer Name is required');
      return false;
    }
    try {
      new URL(serviceApiURL);
    } catch {
      Alert.alert('Validation Error', 'Please enter a valid URL');
      return false;
    }
    return true;
  };

  const handleSaveServiceConfig = async () => {
    if (!validateServiceInputs()) return;
    setLoading(true);
    try {
      // Get current feature flags to preserve user settings
      const featureFlags = await AgentforceService.getFeatureFlags();

      await AgentforceService.configure({
        type: 'service',
        serviceApiURL: serviceApiURL.trim(),
        organizationId: organizationId.trim(),
        esDeveloperName: esDeveloperName.trim(),
        featureFlags,
      });
      Alert.alert(
        'Success',
        'Service Agent configured successfully!',
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error) {
      Alert.alert(
        'Configuration Failed',
        'Failed to configure Service Agent. Please check your settings.'
      );
      console.error('Configuration error:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleClearServiceConfig = () => {
    Alert.alert('Clear Settings', 'Are you sure you want to clear all fields?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: () => {
          setServiceApiURL('');
          setOrganizationId('');
          setEsDeveloperName('');
        },
      },
    ]);
  };

  const handleLoginForEmployeeAgent = async () => {
    if (!authSupported) return;
    setLoading(true);
    try {
      const creds = await loginForEmployeeAgent();
      const agentIdToUse = employeeAgentId.trim();
      await AgentforceService.setEmployeeAgentId(agentIdToUse);

      // Get current feature flags to preserve user settings
      const featureFlags = await AgentforceService.getFeatureFlags();

      await AgentforceService.configure({
        type: 'employee',
        instanceUrl: creds.instanceUrl,
        organizationId: creds.organizationId,
        userId: creds.userId,
        agentId: agentIdToUse || undefined,
        accessToken: creds.accessToken,
        featureFlags,
      });
      setEmployeeLoggedIn(true);
      Alert.alert(
        'Success',
        'You are signed in. You can launch Employee Agent from the Home screen.',
        [{ text: 'OK' }]
      );
    } catch (error: any) {
      if (
        error?.message?.includes('cancel') ||
        error?.code === 'USER_CANCEL'
      ) {
        return;
      }
      Alert.alert(
        'Login Failed',
        error?.message || 'Could not complete sign-in.'
      );
      console.error('Login error:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogoutEmployeeAgent = async () => {
    try {
      await logoutEmployeeAgent();
      setEmployeeLoggedIn(false);
      Alert.alert('Signed Out', 'You have been signed out.');
    } catch (e) {
      console.error('Logout error:', e);
    }
  };

  const loadFeatureFlags = async () => {
    try {
      const stored = await AgentforceService.getFeatureFlags();
      setFeatureFlags(stored);
    } catch (e) {
      console.error('Failed to load feature flags:', e);
      setFeatureFlags({
        enableMultiAgent: true,
        enableMultiModalInput: false,
        enablePDFUpload: false,
        enableVoice: false,
      });
    }
  };

  const handleToggleFeatureFlag = async (
    key: keyof FeatureFlags,
    value: boolean
  ) => {
    if (featureFlags == null) return;
    const next = { ...featureFlags, [key]: value };
    setFeatureFlags(next);
    setSavingFlags(true);
    try {
      await AgentforceService.setFeatureFlags(next);
    } catch (e) {
      console.error('Failed to save feature flags:', e);
      setFeatureFlags(featureFlags);
    } finally {
      setSavingFlags(false);
    }
  };


  const renderTabs = () => (
    <View style={styles.tabContainer}>
      <TouchableOpacity
        style={[styles.tab, activeTab === 'service' && styles.activeTab]}
        onPress={() => setActiveTab('service')}
      >
        <Text
          style={[
            styles.tabText,
            activeTab === 'service' && styles.activeTabText,
          ]}
        >
          Service
        </Text>
      </TouchableOpacity>
      <TouchableOpacity
        style={[
          styles.tab,
          activeTab === 'employee' && styles.activeTabEmployee,
        ]}
        onPress={() => setActiveTab('employee')}
      >
        <Text
          style={[
            styles.tabText,
            activeTab === 'employee' && styles.activeTabTextEmployee,
          ]}
        >
          Employee
        </Text>
      </TouchableOpacity>
      <TouchableOpacity
        style={[
          styles.tab,
          activeTab === 'features' && styles.activeTabFeatures,
        ]}
        onPress={() => setActiveTab('features')}
      >
        <Text
          style={[
            styles.tabText,
            activeTab === 'features' && styles.activeTabTextFeatures,
          ]}
        >
          Flags
        </Text>
      </TouchableOpacity>
    </View>
  );

  const renderServiceAgentTab = () => (
    <ScrollView
      style={styles.tabContent}
      contentContainerStyle={styles.scrollContent}
      keyboardShouldPersistTaps="handled"
    >
      <View style={styles.header}>
        <Text style={styles.title}>Service Agent Configuration</Text>
        <Text style={styles.description}>
          Configure your Salesforce Service Agent with the required
          credentials.
        </Text>
      </View>

      {loadingConfig && (
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>
            Loading saved configuration...
          </Text>
        </View>
      )}

      <View style={styles.formContainer}>
        <View style={styles.fieldContainer}>
          <Text style={styles.label}>Service API URL</Text>
          <Text style={styles.hint}>Your Salesforce instance URL</Text>
          <TextInput
            style={styles.input}
            value={serviceApiURL}
            onChangeText={setServiceApiURL}
            placeholder="https://your-domain.my.salesforce.com"
            placeholderTextColor="#999"
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            editable={!loading}
          />
        </View>
        <View style={styles.fieldContainer}>
          <Text style={styles.label}>Organization ID</Text>
          <Text style={styles.hint}>
            Your 15 or 18 character Salesforce Org ID
          </Text>
          <TextInput
            style={styles.input}
            value={organizationId}
            onChangeText={setOrganizationId}
            placeholder="00D000000000000"
            placeholderTextColor="#999"
            autoCapitalize="none"
            autoCorrect={false}
            editable={!loading}
          />
        </View>
        <View style={styles.fieldContainer}>
          <Text style={styles.label}>ES Developer Name</Text>
          <Text style={styles.hint}>
            The API name of your Einstein Service Agent
          </Text>
          <TextInput
            style={styles.input}
            value={esDeveloperName}
            onChangeText={setEsDeveloperName}
            placeholder="Your_Service_Agent_Name"
            placeholderTextColor="#999"
            autoCapitalize="none"
            autoCorrect={false}
            editable={!loading}
          />
        </View>
      </View>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.saveButton, loading && styles.buttonDisabled]}
          onPress={handleSaveServiceConfig}
          disabled={loading}
        >
          <Text style={styles.saveButtonText}>
            {loading ? 'Configuring...' : 'Save Configuration'}
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.clearButton, loading && styles.buttonDisabled]}
          onPress={handleClearServiceConfig}
          disabled={loading}
        >
          <Text style={styles.clearButtonText}>Clear All</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );

  const renderEmployeeAgentTab = () => (
    <ScrollView
      style={styles.tabContent}
      contentContainerStyle={styles.scrollContent}
      keyboardShouldPersistTaps="handled"
    >
      <View style={styles.header}>
        <Text style={styles.title}>Employee Agent Configuration</Text>
        <Text style={styles.description}>
          Sign in with Mobile SDK to use Employee Agent. Set Agent ID below, or
          leave blank for multi-agent.
        </Text>
      </View>

      {!authSupported && (
        <View style={styles.authNotAvailableCard}>
          <Text style={styles.authNotAvailableTitle}>
            Auth flow required
          </Text>
          <Text style={styles.authNotAvailableText}>
            To use Employee Agent, this app must have an auth source (e.g.
            Salesforce Mobile SDK) configured. Add and configure an auth flow in
            this build to enable sign-in and launch.
          </Text>
        </View>
      )}

      {authSupported && (
        <View style={styles.loginCard}>
          {employeeLoggedIn ? (
            <>
              <Text style={styles.loginCardTitle}>✓ Signed in</Text>
              <Text style={styles.loginCardDescription}>
                You can launch Employee Agent from the Home screen.
              </Text>
              <TouchableOpacity
                style={[
                  styles.logoutButton,
                  loading && styles.buttonDisabled,
                ]}
                onPress={handleLogoutEmployeeAgent}
                disabled={loading}
              >
                <Text style={styles.logoutButtonText}>Log out</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <Text style={styles.loginCardTitle}>
                Login to access the employee agent
              </Text>
              <Text style={styles.loginCardDescription}>
                Sign in with your Salesforce account to use Employee Agent.
              </Text>
              <TouchableOpacity
                style={[
                  styles.loginButton,
                  loading && styles.buttonDisabled,
                ]}
                onPress={handleLoginForEmployeeAgent}
                disabled={loading}
              >
                <Text style={styles.loginButtonText}>
                  {loading ? 'Signing in...' : 'Sign in'}
                </Text>
              </TouchableOpacity>
            </>
          )}
        </View>
      )}

      {authSupported && (
        <View style={[styles.formContainer, { marginBottom: 16 }]}>
          <Text style={styles.label}>Agent ID</Text>
          <Text style={styles.hint}>
            Optional. Leave blank for multi-agent (SDK uses first available
            agent from org). Changes apply when you next launch Employee Agent.
          </Text>
          <TextInput
            style={styles.input}
            value={employeeAgentId}
            onChangeText={setEmployeeAgentId}
            placeholder="0Xxxx0000000000"
            placeholderTextColor="#999"
            autoCapitalize="none"
            autoCorrect={false}
            editable={!loading}
            onBlur={() =>
              AgentforceService.setEmployeeAgentId(employeeAgentId.trim())
            }
          />
        </View>
      )}
    </ScrollView>
  );

  const renderFeatureFlagsTab = () => {
    if (featureFlags == null) {
      return (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color="#28a745" />
          <Text style={styles.loadingText}>Loading feature flags...</Text>
        </View>
      );
    }

    return (
      <ScrollView
        style={styles.tabContent}
        contentContainerStyle={styles.scrollContent}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Feature Flags</Text>
          <Text style={styles.description}>
            Toggle SDK features. Changes are saved immediately and apply to new conversations.
          </Text>
          {savingFlags && <Text style={styles.savingText}>Saving…</Text>}
        </View>

        <View style={styles.formContainer}>
          {FLAG_KEYS.map((key, index) => (
            <View
              key={key}
              style={[
                styles.flagRow,
                index < FLAG_KEYS.length - 1 && styles.flagRowBorder,
              ]}
            >
              <View style={styles.flagLabelBlock}>
                <Text style={styles.label}>{FLAG_LABELS[key]}</Text>
                <Text style={styles.hint}>{FLAG_HINTS[key]}</Text>
              </View>
              <Switch
                value={featureFlags[key]}
                onValueChange={(value) => handleToggleFeatureFlag(key, value)}
                trackColor={{ false: '#ced4da', true: '#28a745' }}
                thumbColor="#ffffff"
                disabled={savingFlags}
              />
            </View>
          ))}
        </View>
      </ScrollView>
    );
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {renderTabs()}
      {activeTab === 'service' && renderServiceAgentTab()}
      {activeTab === 'employee' && renderEmployeeAgentTab()}
      {activeTab === 'features' && renderFeatureFlagsTab()}
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#e9ecef',
  },
  tab: {
    flex: 1,
    paddingVertical: 14,
    alignItems: 'center',
    borderBottomWidth: 3,
    borderBottomColor: 'transparent',
  },
  activeTab: {
    borderBottomColor: '#7B1FA2',
    backgroundColor: '#f3e5f5',
  },
  activeTabEmployee: {
    borderBottomColor: '#0176D3',
    backgroundColor: '#e7f3ff',
  },
  activeTabFeatures: {
    borderBottomColor: '#28a745',
    backgroundColor: '#e8f5e9',
  },
  tabText: {
    fontSize: 15,
    fontWeight: '500',
    color: '#6c757d',
  },
  activeTabText: {
    color: '#7B1FA2',
    fontWeight: '600',
  },
  activeTabTextEmployee: {
    color: '#0176D3',
    fontWeight: '600',
  },
  activeTabTextFeatures: {
    color: '#28a745',
    fontWeight: '600',
  },
  tabContent: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
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
  authNotAvailableCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#dee2e6',
  },
  authNotAvailableTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#495057',
    marginBottom: 6,
  },
  authNotAvailableText: {
    fontSize: 14,
    color: '#6c757d',
    lineHeight: 20,
  },
  loginCard: {
    backgroundColor: '#e7f3ff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#0176D3',
  },
  loginCardTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 6,
  },
  loginCardDescription: {
    fontSize: 14,
    color: '#495057',
    lineHeight: 20,
    marginBottom: 12,
  },
  loginButton: {
    backgroundColor: '#0176D3',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  loginButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  logoutButton: {
    backgroundColor: '#ffffff',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#6c757d',
  },
  logoutButtonText: {
    color: '#6c757d',
    fontSize: 16,
    fontWeight: '500',
  },
  loadingContainer: {
    padding: 12,
    backgroundColor: '#e7f3ff',
    borderRadius: 8,
    marginBottom: 16,
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 14,
    color: '#0070f3',
  },
  formContainer: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
  fieldContainer: {
    marginBottom: 20,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 4,
  },
  hint: {
    fontSize: 12,
    color: '#6c757d',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ced4da',
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    color: '#212529',
    backgroundColor: '#ffffff',
  },
  buttonContainer: {
    gap: 12,
    marginBottom: 20,
  },
  saveButton: {
    backgroundColor: '#7B1FA2',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  saveButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  clearButton: {
    backgroundColor: '#ffffff',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#dc3545',
  },
  clearButtonText: {
    color: '#dc3545',
    fontSize: 16,
    fontWeight: '600',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
  },
  savingText: {
    marginTop: 8,
    fontSize: 13,
    color: '#28a745',
  },
  flagRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
  },
  flagRowBorder: {
    borderBottomWidth: 1,
    borderBottomColor: '#f1f3f4',
  },
  flagLabelBlock: {
    flex: 1,
    marginRight: 16,
  },
});

export default SettingsScreen;
