/**
 * Tests for AppConfig feature-flag derivation.
 *
 * APP_MODE comes from the generated AppConfig.generated module, so each case
 * mocks that module and re-imports AppConfig via jest.isolateModules.
 */

function loadFeatures(mode: 'service' | 'employee' | 'all') {
  let mod: typeof import('../AppConfig');
  jest.isolateModules(() => {
    jest.doMock('../AppConfig.generated', () => ({ APP_MODE: mode }));
    mod = require('../AppConfig');
  });
  // @ts-expect-error assigned inside isolateModules
  return mod;
}

describe('AppConfig FEATURES', () => {
  it("enables both agents for 'all'", () => {
    const { FEATURES, UI_FEATURES } = loadFeatures('all');
    expect(FEATURES.SHOW_SERVICE_AGENT).toBe(true);
    expect(FEATURES.SHOW_EMPLOYEE_AGENT).toBe(true);
    expect(UI_FEATURES.SHOW_SERVICE_AGENT).toBe(true);
    expect(UI_FEATURES.SHOW_EMPLOYEE_AGENT).toBe(true);
  });

  it("enables only the service agent for 'service'", () => {
    const { FEATURES } = loadFeatures('service');
    expect(FEATURES.SHOW_SERVICE_AGENT).toBe(true);
    expect(FEATURES.SHOW_EMPLOYEE_AGENT).toBe(false);
  });

  it("enables only the employee agent for 'employee'", () => {
    const { FEATURES } = loadFeatures('employee');
    expect(FEATURES.SHOW_SERVICE_AGENT).toBe(false);
    expect(FEATURES.SHOW_EMPLOYEE_AGENT).toBe(true);
  });

  it('mirrors FEATURES into UI_FEATURES', () => {
    const { FEATURES, UI_FEATURES } = loadFeatures('service');
    expect(UI_FEATURES.SHOW_SERVICE_AGENT).toBe(FEATURES.SHOW_SERVICE_AGENT);
    expect(UI_FEATURES.SHOW_EMPLOYEE_AGENT).toBe(FEATURES.SHOW_EMPLOYEE_AGENT);
  });
});
