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
} from 'react-native';
import AgentforceService from '../services/AgentforceService';

interface SettingsScreenProps {
  navigation: any;
}

const SettingsScreen: React.FC<SettingsScreenProps> = ({ navigation }) => {
  const [serviceApiURL, setServiceApiURL] = useState('');
  const [organizationId, setOrganizationId] = useState('');
  const [esDeveloperName, setEsDeveloperName] = useState('');
  const [loading, setLoading] = useState(false);
  const [loadingConfig, setLoadingConfig] = useState(true);

  // Load saved configuration on mount
  useEffect(() => {
    loadSavedConfiguration();
  }, []);

  const loadSavedConfiguration = async () => {
    try {
      setLoadingConfig(true);
      const savedConfig = await AgentforceService.getConfiguration();
      if (savedConfig) {
        setServiceApiURL(savedConfig.serviceApiURL);
        setOrganizationId(savedConfig.organizationId);
        setEsDeveloperName(savedConfig.esDeveloperName);
        console.log('Loaded saved configuration');
      }
    } catch (error) {
      console.error('Failed to load saved configuration:', error);
    } finally {
      setLoadingConfig(false);
    }
  };

  const validateInputs = (): boolean => {
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

    // Basic URL validation
    try {
      new URL(serviceApiURL);
    } catch (error) {
      Alert.alert('Validation Error', 'Please enter a valid URL');
      return false;
    }

    return true;
  };

  const handleSave = async () => {
    if (!validateInputs()) {
      return;
    }

    setLoading(true);
    try {
      await AgentforceService.configure({
        serviceApiURL: serviceApiURL.trim(),
        organizationId: organizationId.trim(),
        esDeveloperName: esDeveloperName.trim(),
      });

      Alert.alert(
        'Success',
        'Agentforce Service Agent configured successfully!',
        [
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      Alert.alert(
        'Configuration Failed',
        'Failed to configure Agentforce. Please check your settings and try again.'
      );
      console.error('Configuration error:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    Alert.alert(
      'Clear Settings',
      'Are you sure you want to clear all fields?',
      [
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
      ]
    );
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Service Agent Configuration</Text>
          <Text style={styles.description}>
            Configure your Salesforce Service Agent with the required
            credentials. All three fields are required.
          </Text>
        </View>

        {/* Loading Indicator */}
        {loadingConfig && (
          <View style={styles.loadingContainer}>
            <Text style={styles.loadingText}>Loading saved configuration...</Text>
          </View>
        )}

        {/* Form Fields */}
        <View style={styles.formContainer}>
          {/* Service API URL */}
          <View style={styles.fieldContainer}>
            <Text style={styles.label}>Service API URL</Text>
            <Text style={styles.hint}>
              Your Salesforce instance URL (e.g., https://your-domain.my.salesforce.com)
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

          {/* Organization ID */}
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

          {/* ES Developer Name */}
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

        {/* Info Box */}
        <View style={styles.infoBox}>
          <Text style={styles.infoIcon}>ℹ️</Text>
          <Text style={styles.infoText}>
            You can find these values in your Salesforce Setup under Einstein
            Service Agent configuration.
          </Text>
        </View>

        {/* Action Buttons */}
        <View style={styles.buttonContainer}>
          <TouchableOpacity
            style={[styles.saveButton, loading && styles.buttonDisabled]}
            onPress={handleSave}
            disabled={loading}
          >
            <Text style={styles.saveButtonText}>
              {loading ? 'Configuring...' : 'Save Configuration'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.clearButton, loading && styles.buttonDisabled]}
            onPress={handleClear}
            disabled={loading}
          >
            <Text style={styles.clearButtonText}>Clear All</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
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
  scrollContent: {
    padding: 20,
    paddingBottom: 40,
  },
  header: {
    marginBottom: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212529',
    marginBottom: 8,
  },
  description: {
    fontSize: 14,
    color: '#6c757d',
    lineHeight: 20,
  },
  loadingContainer: {
    padding: 16,
    alignItems: 'center',
    backgroundColor: '#e7f3ff',
    borderRadius: 8,
    marginBottom: 16,
  },
  loadingText: {
    fontSize: 14,
    color: '#0070f3',
    fontWeight: '500',
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
    lineHeight: 16,
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
  infoBox: {
    flexDirection: 'row',
    backgroundColor: '#e7f3ff',
    borderRadius: 8,
    padding: 12,
    marginBottom: 24,
  },
  infoIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  infoText: {
    flex: 1,
    fontSize: 13,
    color: '#0070f3',
    lineHeight: 18,
  },
  buttonContainer: {
    gap: 12,
  },
  saveButton: {
    backgroundColor: '#0176D3',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 4,
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
});

export default SettingsScreen;

