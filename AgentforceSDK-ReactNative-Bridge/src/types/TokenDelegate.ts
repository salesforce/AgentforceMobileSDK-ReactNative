/**
 * Token Delegate Interface
 *
 * Defines the contract for providing OAuth tokens to the Agentforce SDK.
 * Consuming apps implement this interface to integrate with their authentication system.
 *
 * Only used for Employee Agent mode - Service Agent mode does not require authentication.
 */

/**
 * Delegate interface for providing OAuth tokens to the Agentforce SDK.
 *
 * Implement this interface to provide tokens from your app's authentication system.
 * Register the delegate using `AgentforceService.setTokenDelegate()` before
 * configuring an Employee Agent without a direct accessToken.
 *
 * @example
 * ```typescript
 * // Simple implementation
 * const tokenDelegate: TokenDelegate = {
 *   getAccessToken: async () => {
 *     return await myAuthService.getCurrentToken();
 *   },
 *   refreshToken: async () => {
 *     return await myAuthService.refreshAndGetToken();
 *   },
 *   onAuthenticationFailure: () => {
 *     // Navigate to login screen
 *     navigation.navigate('Login');
 *   },
 * };
 *
 * AgentforceService.setTokenDelegate(tokenDelegate);
 * ```
 *
 * @example
 * ```typescript
 * // Class-based implementation
 * class MyTokenDelegate implements TokenDelegate {
 *   constructor(private authService: AuthService) {}
 *
 *   async getAccessToken(): Promise<string> {
 *     const token = await this.authService.getToken();
 *     if (!token) {
 *       throw new Error('No token available');
 *     }
 *     return token;
 *   }
 *
 *   async refreshToken(): Promise<string> {
 *     try {
 *       return await this.authService.refreshToken();
 *     } catch (error) {
 *       throw new Error(`Token refresh failed: ${error.message}`);
 *     }
 *   }
 *
 *   onAuthenticationFailure(): void {
 *     this.authService.logout();
 *     // Trigger login flow
 *   }
 * }
 * ```
 */
export interface TokenDelegate {
  /**
   * Called when the SDK needs an access token.
   *
   * This is called during initial configuration if no accessToken is provided,
   * and may be called again if the SDK needs to verify the current token.
   *
   * @returns Promise resolving to the current valid OAuth access token
   * @throws Error if token cannot be obtained (e.g., user not logged in)
   *
   * @example
   * ```typescript
   * getAccessToken: async () => {
   *   const token = await SecureStore.getItemAsync('accessToken');
   *   if (!token) {
   *     throw new Error('No access token available');
   *   }
   *   return token;
   * }
   * ```
   */
  getAccessToken(): Promise<string>;

  /**
   * Called when the current token is expired or invalid and needs to be refreshed.
   *
   * The SDK will call this when it receives a 401 Unauthorized response or
   * when it detects that the token has expired. The implementing app should
   * use its refresh token to obtain a new access token.
   *
   * @returns Promise resolving to a fresh OAuth access token
   * @throws Error if token refresh fails (e.g., refresh token expired)
   *
   * @example
   * ```typescript
   * refreshToken: async () => {
   *   const refreshToken = await SecureStore.getItemAsync('refreshToken');
   *   const response = await fetch('/oauth/token', {
   *     method: 'POST',
   *     body: JSON.stringify({ grant_type: 'refresh_token', refresh_token: refreshToken }),
   *   });
   *
   *   if (!response.ok) {
   *     throw new Error('Token refresh failed');
   *   }
   *
   *   const { access_token } = await response.json();
   *   await SecureStore.setItemAsync('accessToken', access_token);
   *   return access_token;
   * }
   * ```
   */
  refreshToken(): Promise<string>;

  /**
   * Called when authentication has completely failed and cannot be recovered.
   *
   * This is called after token refresh fails or when the SDK determines that
   * the user needs to re-authenticate. The implementing app should typically
   * clear any stored credentials and navigate to the login screen.
   *
   * This method is optional - if not provided, authentication failures will
   * only be logged and the SDK operation will fail.
   *
   * @example
   * ```typescript
   * onAuthenticationFailure: () => {
   *   // Clear stored tokens
   *   SecureStore.deleteItemAsync('accessToken');
   *   SecureStore.deleteItemAsync('refreshToken');
   *
   *   // Show alert to user
   *   Alert.alert(
   *     'Session Expired',
   *     'Please log in again to continue.',
   *     [{ text: 'OK', onPress: () => navigation.navigate('Login') }]
   *   );
   * }
   * ```
   */
  onAuthenticationFailure?(): void;
}

/**
 * Token refresh event payload (emitted from native to JS)
 * Currently empty - just signals that refresh is needed
 */
export interface TokenRefreshEvent {
  // Empty for now - could include error details in future
}

/**
 * Authentication failure event payload (emitted from native to JS)
 */
export interface AuthenticationFailureEvent {
  /** Error message describing the failure */
  error?: string;

  /** Error code if available */
  code?: string;
}
