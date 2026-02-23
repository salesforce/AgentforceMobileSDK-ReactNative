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
} from 'react-native';
import {
  AgentforceService,
  isEmployeeAgentAuthSupported,
  hasEmployeeAgentSession,
  loginForEmployeeAgent,
  logoutEmployeeAgent,
  getEmployeeAgentCredentials,
} from '../../src';
// Employee Agent tab uses Mobile SDK login only; file-based config is a dev backdoor (no UI here).

interface SettingsScreenProps {
  navigation: any;
  route?: { params?: { tab?: 'service' | 'employee' } };
}

type TabType = 'service' | 'employee';

const SettingsScreen: React.FC<SettingsScreenProps> = ({ navigation, route }) => {
  const [activeTab, setActiveTab] = useState<TabType>(
    route?.params?.tab || 'service'
  );

  // Service Agent state
  const [serviceApiURL, setServiceApiURL] = useState('');
  const [organizationId, setOrganizationId] = useState('');
  const [esDeveloperName, setEsDeveloperName] = useState('');
  const [loading, setLoading] = useState(false);
  const [loadingConfig, setLoadingConfig] = useState(true);

  // Employee Agent state
  const [employeeAgentId, setEmployeeAgentId] = useState('');
  const [authSupported, setAuthSupported] = useState(false);
  const [employeeLoggedIn, setEmployeeLoggedIn] = useState(false);

  // Load saved configuration on mount
  useEffect(() => {
    loadSavedConfiguration();
    loadStoredEmployeeAgentId();
    checkAuthStatus();
  }, []);

  // Refresh auth status when Employee tab is focused
  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      if (activeTab === 'employee') {
        checkAuthStatus();
      }
    });
    return unsubscribe;
  }, [navigation, activeTab]);

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
      setEmployeeAgentId(stored || '');
    } catch {
      setEmployeeAgentId('');
    }
  };

  // Update tab if route params change
  useEffect(() => {
    if (route?.params?.tab) {
      setActiveTab(route.params.tab);
    }
  }, [route?.params?.tab]);

  const loadSavedConfiguration = async () => {
    try {
      setLoadingConfig(true);
      const savedConfig = await AgentforceService.getConfiguration();
      if (savedConfig) {
        setServiceApiURL(savedConfig.serviceApiURL || '');
        setOrganizationId(savedConfig.organizationId || '');
        setEsDeveloperName(savedConfig.esDeveloperName || '');
      }
    } catch (error) {
      console.error('Failed to load saved configuration:', error);
    } finally {
      setLoadingConfig(false);
    }
  };

  // Service Agent handlers
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
    if (!validateServiceInputs()) {
      return;
    }

    setLoading(true);
    try {
      await AgentforceService.configure({
        type: 'service',
        serviceApiURL: serviceApiURL.trim(),
        organizationId: organizationId.trim(),
        esDeveloperName: esDeveloperName.trim(),
      });

      Alert.alert('Success', 'Service Agent configured successfully!', [
        { text: 'OK', onPress: () => navigation.goBack() },
      ]);
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

  // Employee Agent handlers
  const handleLoginForEmployeeAgent = async () => {
    if (!authSupported) return;
    setLoading(true);
    try {
      const creds = await loginForEmployeeAgent();
      const agentIdToUse = employeeAgentId.trim();
      await AgentforceService.setEmployeeAgentId(agentIdToUse);
      await AgentforceService.configure({
        type: 'employee',
        instanceUrl: creds.instanceUrl,
        organizationId: creds.organizationId,
        userId: creds.userId,
        agentId: agentIdToUse || undefined,
        accessToken: creds.accessToken,
      });
      setEmployeeLoggedIn(true);
      Alert.alert('Success', 'You are signed in. You can launch Employee Agent from the Home screen.', [
        { text: 'OK' },
      ]);
    } catch (error: any) {
      if (error?.message?.includes('cancel') || error?.code === 'USER_CANCEL') {
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
          💬 Service Agent
        </Text>
      </TouchableOpacity>
      <TouchableOpacity
        style={[styles.tab, activeTab === 'employee' && styles.activeTabEmployee]}
        onPress={() => setActiveTab('employee')}
      >
        <Text
          style={[
            styles.tabText,
            activeTab === 'employee' && styles.activeTabTextEmployee,
          ]}
        >
          👤 Employee Agent
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
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Service Agent Configuration</Text>
        <Text style={styles.description}>
          Configure your Salesforce Service Agent with the required credentials.
        </Text>
      </View>

      {loadingConfig && (
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading saved configuration...</Text>
        </View>
      )}

      {/* Form */}
      <View style={styles.formContainer}>
        <View style={styles.fieldContainer}>
          <Text style={styles.label}>Service API URL</Text>
          <Text style={styles.hint}>
            Your Salesforce instance URL
          </Text>
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
          <Text style={styles.hint}>Your 15 or 18 character Salesforce Org ID</Text>
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
          <Text style={styles.hint}>The API name of your Einstein Service Agent</Text>
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

      {/* Buttons */}
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
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Employee Agent Configuration</Text>
        <Text style={styles.description}>
          Sign in with Mobile SDK to use Employee Agent. Set Agent ID below, or leave blank for multi-agent.
        </Text>
      </View>

      {/* No auth flow: tell user they need an auth source */}
      {!authSupported && (
        <View style={styles.authNotAvailableCard}>
          <Text style={styles.authNotAvailableTitle}>Auth flow required</Text>
          <Text style={styles.authNotAvailableText}>
            To use Employee Agent, this app must have an auth source (e.g. Salesforce Mobile SDK) configured. Add and configure an auth flow in this build to enable sign-in and launch.
          </Text>
        </View>
      )}

      {/* Login to access the employee agent - shown when auth is supported */}
      {authSupported && (
        <View style={styles.loginCard}>
          {employeeLoggedIn ? (
            <>
              <Text style={styles.loginCardTitle}>✓ Signed in</Text>
              <Text style={styles.loginCardDescription}>
                You can launch Employee Agent from the Home screen.
              </Text>
              <TouchableOpacity
                style={[styles.logoutButton, loading && styles.buttonDisabled]}
                onPress={handleLogoutEmployeeAgent}
                disabled={loading}
              >
                <Text style={styles.logoutButtonText}>Log out</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <Text style={styles.loginCardTitle}>Login to access the employee agent</Text>
              <Text style={styles.loginCardDescription}>
                Sign in with your Salesforce account to use Employee Agent.
              </Text>
              <TouchableOpacity
                style={[styles.loginButton, loading && styles.buttonDisabled]}
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

      {/* Agent ID input - only when auth is supported */}
      {authSupported && (
        <View style={[styles.formContainer, { marginBottom: 16 }]}>
          <Text style={styles.label}>Agent ID</Text>
          <Text style={styles.hint}>
            Optional. Leave blank for multi-agent (SDK uses first available agent from org).
          </Text>
          <TextInput
            style={styles.input}
            value={employeeAgentId}
            onChangeText={setEmployeeAgentId}
            placeholder="0Xxx000000000000"
            placeholderTextColor="#999"
            autoCapitalize="none"
            autoCorrect={false}
            editable={!loading}
            onBlur={() => AgentforceService.setEmployeeAgentId(employeeAgentId.trim())}
          />
        </View>
      )}
    </ScrollView>
  );

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {renderTabs()}
      {activeTab === 'service' ? renderServiceAgentTab() : renderEmployeeAgentTab()}
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
  // Employee Agent styles
  instructionsContainer: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  instructionsTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 16,
  },
  step: {
    flexDirection: 'row',
    marginBottom: 20,
  },
  stepNumber: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#0176D3',
    color: '#ffffff',
    fontSize: 14,
    fontWeight: 'bold',
    textAlign: 'center',
    lineHeight: 28,
    marginRight: 12,
    overflow: 'hidden',
  },
  stepContent: {
    flex: 1,
  },
  stepTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 8,
  },
  stepHint: {
    fontSize: 13,
    color: '#6c757d',
    marginTop: 4,
  },
  codeBlock: {
    backgroundColor: '#f8f9fa',
    padding: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#e9ecef',
  },
  codeText: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 13,
    color: '#495057',
  },
});

export default SettingsScreen;
