/**
 * Tests for the EmployeeAgentAuth wrappers.
 *
 * The module captures `NativeModules.EmployeeAgentAuthBridge` at import time, so
 * each scenario uses jest.isolateModules with a freshly-configured react-native
 * mock to exercise both the "bridge present" and "bridge missing" branches.
 */

type Bridge = {
  isAuthSupported?: jest.Mock;
  getAuthCredentials?: jest.Mock;
  refreshAuthCredentials?: jest.Mock;
  login?: jest.Mock;
  logout?: jest.Mock;
};

function loadWith(bridge: Bridge | undefined, os = 'ios') {
  let mod: typeof import('../EmployeeAgentAuth');
  jest.isolateModules(() => {
    jest.doMock('react-native', () => ({
      NativeModules: bridge ? { EmployeeAgentAuthBridge: bridge } : {},
      Platform: { OS: os },
    }));
    mod = require('../EmployeeAgentAuth');
  });
  // @ts-expect-error assigned inside isolateModules
  return mod;
}

const creds = {
  instanceUrl: 'https://x.my.salesforce.com',
  organizationId: '00D',
  userId: '005',
  accessToken: 'tok',
};

describe('isEmployeeAgentAuthSupported', () => {
  it('is false on unsupported platforms', async () => {
    const mod = loadWith({ isAuthSupported: jest.fn() }, 'web');
    await expect(mod.isEmployeeAgentAuthSupported()).resolves.toBe(false);
  });

  it('is false when the bridge is missing', async () => {
    const mod = loadWith(undefined);
    await expect(mod.isEmployeeAgentAuthSupported()).resolves.toBe(false);
  });

  it('is true when the bridge reports support', async () => {
    const mod = loadWith({ isAuthSupported: jest.fn().mockResolvedValue(true) });
    await expect(mod.isEmployeeAgentAuthSupported()).resolves.toBe(true);
  });

  it('is false when the bridge throws', async () => {
    const mod = loadWith({ isAuthSupported: jest.fn().mockRejectedValue(new Error('x')) });
    await expect(mod.isEmployeeAgentAuthSupported()).resolves.toBe(false);
  });
});

describe('isEmployeeAgentAuthReady / hasEmployeeAgentSession', () => {
  it('is true with credentials that have an access token', async () => {
    const mod = loadWith({ getAuthCredentials: jest.fn().mockResolvedValue(creds) });
    await expect(mod.isEmployeeAgentAuthReady()).resolves.toBe(true);
    await expect(mod.hasEmployeeAgentSession()).resolves.toBe(true);
  });

  it('is false when credentials lack an access token', async () => {
    const mod = loadWith({
      getAuthCredentials: jest.fn().mockResolvedValue({ ...creds, accessToken: '' }),
    });
    await expect(mod.isEmployeeAgentAuthReady()).resolves.toBe(false);
  });

  it('is false when credentials are null', async () => {
    const mod = loadWith({ getAuthCredentials: jest.fn().mockResolvedValue(null) });
    await expect(mod.isEmployeeAgentAuthReady()).resolves.toBe(false);
  });

  it('is false when the bridge throws', async () => {
    const mod = loadWith({ getAuthCredentials: jest.fn().mockRejectedValue(new Error('x')) });
    await expect(mod.isEmployeeAgentAuthReady()).resolves.toBe(false);
  });
});

describe('getEmployeeAgentCredentials', () => {
  it('returns credentials from the bridge', async () => {
    const mod = loadWith({ getAuthCredentials: jest.fn().mockResolvedValue(creds) });
    await expect(mod.getEmployeeAgentCredentials()).resolves.toEqual(creds);
  });

  it('returns null when the bridge throws', async () => {
    const mod = loadWith({ getAuthCredentials: jest.fn().mockRejectedValue(new Error('x')) });
    await expect(mod.getEmployeeAgentCredentials()).resolves.toBeNull();
  });

  it('returns null when the bridge is missing', async () => {
    const mod = loadWith(undefined);
    await expect(mod.getEmployeeAgentCredentials()).resolves.toBeNull();
  });
});

describe('loginForEmployeeAgent', () => {
  it('resolves credentials from the bridge', async () => {
    const mod = loadWith({ login: jest.fn().mockResolvedValue(creds) });
    await expect(mod.loginForEmployeeAgent()).resolves.toEqual(creds);
  });

  it('throws when the bridge is missing', async () => {
    const mod = loadWith(undefined);
    await expect(mod.loginForEmployeeAgent()).rejects.toThrow(/not available/);
  });
});

describe('refreshEmployeeAgentCredentials', () => {
  it('resolves refreshed credentials', async () => {
    const mod = loadWith({ refreshAuthCredentials: jest.fn().mockResolvedValue(creds) });
    await expect(mod.refreshEmployeeAgentCredentials()).resolves.toEqual(creds);
  });

  it('throws when refresh is unavailable', async () => {
    const mod = loadWith(undefined);
    await expect(mod.refreshEmployeeAgentCredentials()).rejects.toThrow(/not available/);
  });
});

describe('logoutEmployeeAgent', () => {
  it('calls the bridge logout', async () => {
    const logout = jest.fn().mockResolvedValue(undefined);
    const mod = loadWith({ logout });
    await mod.logoutEmployeeAgent();
    expect(logout).toHaveBeenCalled();
  });

  it('is a no-op when the bridge is missing', async () => {
    const mod = loadWith(undefined);
    await expect(mod.logoutEmployeeAgent()).resolves.toBeUndefined();
  });
});
