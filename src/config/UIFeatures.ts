/**
 * UI Feature Configuration
 *
 * This file controls the visibility of UI elements in the app.
 * All underlying code and infrastructure remains available for programmatic use.
 *
 * To enable employee agent UI features, set the corresponding flags to `true`.
 * Consumers can modify these settings to expose additional functionality.
 */

export const UI_FEATURES = {
  /**
   * Show Employee Agent UI elements (launch button, settings tab, etc.)
   *
   * When `false` (default):
   * - Employee Agent launch button is hidden from HomeScreen
   * - Employee Agent settings tab is hidden from SettingsScreen
   * - All employee agent code and APIs remain available for programmatic use
   *
   * When `true`:
   * - Full employee agent UI is shown
   * - Users can configure and launch employee agents through the UI
   *
   * Note: Employee agent features require proper authentication setup.
   * See README.md for integration details.
   */
  SHOW_EMPLOYEE_AGENT: false,

  /**
   * Show Feature Flags UI tab in settings
   *
   * When `false` (default):
   * - Feature flags tab is hidden from SettingsScreen
   * - Feature flags can still be set programmatically via AgentforceService
   *
   * When `true`:
   * - Feature flags configuration tab is shown in SettingsScreen
   * - Users can toggle features like voice, multiAgent, etc. through UI
   */
  SHOW_FEATURE_FLAGS_TAB: false,
} as const;

/**
 * Type-safe access to UI feature flags
 */
export type UIFeatureFlags = typeof UI_FEATURES;
