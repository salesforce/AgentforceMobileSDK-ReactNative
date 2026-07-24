/**
 * Package-contract tests for @salesforce/react-native-agentforce (W-23159346).
 *
 * These lock in the publishable shape of the package (SC1) and the runtime
 * public-API surface exported from the barrel (SC2). They are intentionally
 * decoupled from behavior — they fail if the package stops being publishable
 * or if a public export is dropped/renamed.
 */

// The barrel imports native modules at require-time; mock react-native so the
// public surface can be introspected in the JVM-less jest environment.
jest.mock('react-native', () => {
  class NativeEventEmitter {
    addListener() {
      return { remove: jest.fn() };
    }
    removeAllListeners() {}
  }
  return {
    NativeModules: { AgentforceModule: new Proxy({}, { get: () => jest.fn() }) },
    NativeEventEmitter,
    Platform: { OS: 'ios', select: (o: Record<string, unknown>) => o.ios ?? o.default },
  };
});

const pkg = require('../../package.json');

describe('package.json is a publishable scoped npm package (SC1)', () => {
  it('uses the scoped public name', () => {
    expect(pkg.name).toBe('@salesforce/react-native-agentforce');
  });

  it('points entry + types at the compiled lib/ output', () => {
    expect(pkg.main).toBe('lib/index.js');
    expect(pkg.types).toBe('lib/index.d.ts');
    // react-native metro entry stays on source for fast local iteration
    expect(pkg['react-native']).toBe('src/index.ts');
  });

  it('publishes the scoped package publicly', () => {
    expect(pkg.publishConfig).toBeDefined();
    expect(pkg.publishConfig.access).toBe('public');
  });

  it('declares a files allowlist that ships sources + native code', () => {
    expect(Array.isArray(pkg.files)).toBe(true);
    const files: string[] = pkg.files;
    for (const entry of ['lib', 'src', 'ios', 'android']) {
      expect(files.some(f => f === entry || f.startsWith(entry + '/'))).toBe(true);
    }
  });

  it('excludes native build artifacts and tests from the tarball', () => {
    const files: string[] = pkg.files;
    // Negation entries keep build junk / tests out of the published package (SC3).
    expect(files).toContain('!android/build');
    expect(files).toContain('!android/src/test');
    expect(files).toContain('!ios/build');
    expect(files.some(f => f === '!**/__tests__')).toBe(true);
  });

  it('builds before publish via tsc', () => {
    expect(pkg.scripts).toBeDefined();
    expect(pkg.scripts.build).toMatch(/tsc/);
    // prepublishOnly (and/or prepare) must run the build so lib/ is never stale
    const buildsOnPublish =
      /build/.test(pkg.scripts.prepublishOnly || '') || /build/.test(pkg.scripts.prepare || '');
    expect(buildsOnPublish).toBe(true);
  });

  it('declares license, repository, and peer deps for consumers', () => {
    expect(pkg.license).toBe('Apache-2.0');
    expect(pkg.repository).toBeDefined();
    expect(pkg.peerDependencies).toMatchObject({
      react: expect.any(String),
      'react-native': expect.any(String),
    });
  });
});

describe('public API barrel exposes the documented runtime surface (SC2)', () => {
  const api = require('../index');

  it('default-exports AgentforceService as the primary entry', () => {
    expect(api.AgentforceService).toBeDefined();
  });

  it('exports the Employee Agent auth functions', () => {
    for (const fn of [
      'isEmployeeAgentAuthSupported',
      'hasEmployeeAgentSession',
      'loginForEmployeeAgent',
      'logoutEmployeeAgent',
      'getEmployeeAgentCredentials',
      'refreshEmployeeAgentCredentials',
      'isEmployeeAgentAuthReady',
    ]) {
      expect(typeof api[fn]).toBe('function');
    }
  });

  it('exports the config type-guards and employee-agent config values', () => {
    for (const fn of ['isServiceAgentConfig', 'isEmployeeAgentConfig', 'isLegacyConfig']) {
      expect(typeof api[fn]).toBe('function');
    }
    expect(typeof api.isEmployeeAgentConfigValid).toBe('function');
    expect('EMPLOYEE_AGENT_ENABLED' in api).toBe(true);
    expect('EMPLOYEE_AGENT_CONFIG' in api).toBe(true);
  });
});
