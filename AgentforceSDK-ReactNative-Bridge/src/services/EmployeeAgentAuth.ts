/**
 * Employee Agent auth capability and runtime.
 *
 * Uses Option C: capability (is auth supported?) + runtime (is auth ready?).
 * When Mobile SDK (or another auth bridge) is present, supported = true;
 * ready = SDK initialized and we can show login or have a session.
 */

import { NativeModules, Platform } from 'react-native';

export interface AuthCredentials {
  instanceUrl: string;
  organizationId: string;
  userId: string;
  accessToken: string;
  refreshToken?: string;
}

interface EmployeeAgentAuthBridgeSpec {
  isAuthSupported(): Promise<boolean>;
  getAuthCredentials(): Promise<AuthCredentials | null>;
  refreshAuthCredentials(): Promise<AuthCredentials>;
  login(): Promise<AuthCredentials>;
  logout(): Promise<void>;
}

const bridgeName = 'EmployeeAgentAuthBridge';
const EmployeeAgentAuthBridge = NativeModules[bridgeName] as EmployeeAgentAuthBridgeSpec | undefined;

/**
 * Whether this build supports Employee Agent via an auth flow (e.g. Mobile SDK).
 * When false, the Employee Agent launch button and Settings tab should be disabled.
 */
export async function isEmployeeAgentAuthSupported(): Promise<boolean> {
  if (Platform.OS !== 'ios' && Platform.OS !== 'android') {
    return false;
  }
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.isAuthSupported !== 'function') {
    return false;
  }
  try {
    return (await EmployeeAgentAuthBridge.isAuthSupported()) === true;
  } catch {
    return false;
  }
}

/**
 * Whether auth is ready right now (SDK initialized; we can show login or have a session).
 * Use to enable/disable the "Login to access the employee agent" and "Launch" actions.
 */
export async function isEmployeeAgentAuthReady(): Promise<boolean> {
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.getAuthCredentials !== 'function') {
    return false;
  }
  try {
    const creds = await EmployeeAgentAuthBridge.getAuthCredentials();
    return creds != null && !!creds.accessToken;
  } catch {
    return false;
  }
}

/**
 * Whether the user is currently logged in (has valid credentials).
 */
export async function hasEmployeeAgentSession(): Promise<boolean> {
  return isEmployeeAgentAuthReady();
}

/**
 * Launch the auth flow (e.g. Mobile SDK login screen).
 * Resolves with credentials on success; rejects on cancel or error.
 */
export async function loginForEmployeeAgent(): Promise<AuthCredentials> {
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.login !== 'function') {
    throw new Error('Employee Agent auth is not available. Add Mobile SDK or an auth bridge.');
  }
  return EmployeeAgentAuthBridge.login();
}

/**
 * Get current auth credentials if logged in; null otherwise.
 */
export async function getEmployeeAgentCredentials(): Promise<AuthCredentials | null> {
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.getAuthCredentials !== 'function') {
    return null;
  }
  try {
    return await EmployeeAgentAuthBridge.getAuthCredentials();
  } catch {
    return null;
  }
}

/**
 * Ask the Mobile SDK to refresh the current session and return new credentials.
 * Returns the new access token and related fields.
 * Note: The native SDK now handles token refresh automatically by fetching fresh tokens
 * from the Mobile SDK. This method is kept for manual refresh scenarios if needed.
 * @throws if no session, no refresh token, or refresh fails
 */
export async function refreshEmployeeAgentCredentials(): Promise<AuthCredentials> {
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.refreshAuthCredentials !== 'function') {
    throw new Error('Employee Agent auth refresh is not available. Add Mobile SDK (WithMobileSDK).');
  }
  return EmployeeAgentAuthBridge.refreshAuthCredentials();
}

/**
 * Log out the current user.
 */
export async function logoutEmployeeAgent(): Promise<void> {
  if (!EmployeeAgentAuthBridge || typeof EmployeeAgentAuthBridge.logout !== 'function') {
    return;
  }
  await EmployeeAgentAuthBridge.logout();
}
