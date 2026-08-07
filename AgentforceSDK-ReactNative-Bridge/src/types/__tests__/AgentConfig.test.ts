import {
  isServiceAgentConfig,
  isEmployeeAgentConfig,
  isLegacyConfig,
  ServiceAgentConfig,
  EmployeeAgentConfig,
  LegacyServiceAgentConfig,
} from '../AgentConfig';
import type { AgentforceAppearance } from '../AgentforceAppearance';

const appearance: AgentforceAppearance = {
  themeMode: 'system',
  lightColors: { chatBackground: '#FFFFFF' },
  darkColors: { chatBackground: '#181818' },
  icons: {
    aiAgent: {
      ios: { light: 'BrandAgent' },
      android: { light: 'brand_agent' },
    },
  },
  typography: {
    fontFamily: { type: 'generic', family: 'serif' },
    styles: { bodyScale1Regular: { size: 14, weight: 400 } },
  },
};

const serviceConfig: ServiceAgentConfig = {
  type: 'service',
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
};

const employeeConfig: EmployeeAgentConfig = {
  type: 'employee',
  instanceUrl: 'https://myorg.my.salesforce.com',
  organizationId: '00Dxx0000001234',
  userId: '005xx0000001234',
  agentId: '0Xxxx0000001234',
  accessToken: 'token',
};

const legacyConfig: LegacyServiceAgentConfig = {
  serviceApiURL: 'https://service.salesforce.com',
  organizationId: '00Dxx0000001234',
  esDeveloperName: 'MyServiceAgent',
};

describe('AgentConfig type guards', () => {
  describe('isServiceAgentConfig', () => {
    it('returns true for a service config', () => {
      expect(isServiceAgentConfig(serviceConfig)).toBe(true);
    });

    it('returns false for an employee config', () => {
      expect(isServiceAgentConfig(employeeConfig)).toBe(false);
    });

    it('returns false for a legacy config (no type field)', () => {
      expect(isServiceAgentConfig(legacyConfig)).toBe(false);
    });
  });

  describe('isEmployeeAgentConfig', () => {
    it('returns true for an employee config', () => {
      expect(isEmployeeAgentConfig(employeeConfig)).toBe(true);
    });

    it('returns false for a service config', () => {
      expect(isEmployeeAgentConfig(serviceConfig)).toBe(false);
    });
  });

  describe('isLegacyConfig', () => {
    it('returns true for a config without a type field', () => {
      expect(isLegacyConfig(legacyConfig)).toBe(true);
    });

    it('returns false for a service config', () => {
      expect(isLegacyConfig(serviceConfig)).toBe(false);
    });

    it('returns false for an employee config', () => {
      expect(isLegacyConfig(employeeConfig)).toBe(false);
    });
  });

  it('permits appearance configuration in both agent modes', () => {
    expect({ ...serviceConfig, appearance }.appearance?.icons?.aiAgent.android.light).toBe(
      'brand_agent',
    );
    expect({ ...employeeConfig, appearance }.appearance?.typography?.fontFamily).toEqual({
      type: 'generic',
      family: 'serif',
    });
  });
});
