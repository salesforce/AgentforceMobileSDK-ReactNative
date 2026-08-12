/**
 * Splash screen delegate types for Agentforce SDK
 *
 * Allows a host app to supply a custom welcome ("splash") screen — shown on top
 * of the conversation before the user has interacted with an agent — as a React
 * Native component. The native SDK asks the bridge for a splash screen when the
 * chat view is first shown and again whenever the active agent changes, so a host
 * can show a splash for only some agents.
 *
 * The chat UI itself is fully native, so the splash content is a React Native
 * component hosted inside the native conversation view (via RCTRootView on iOS /
 * ReactRootView on Android) — the same mechanism used by the View Provider. Each
 * agent ID maps 1:1 to a registered React Native component name.
 *
 * The splash screen is displayed in the conversation content region — below the
 * top bar and above the input bar — so both remain interactive, and it is inset
 * for the software keyboard so it moves up with the input bar when the input
 * field is focused.
 *
 * The splash screen is dismissed (animated away to reveal the conversation behind
 * it) when either:
 * - the user chooses a starter utterance — the component reports this by calling
 *   `AgentforceService.selectSplashScreenUtterance(agentId, utterance)`, after
 *   which the SDK sends that utterance into the conversation, or
 * - the user sends text from the input bar.
 *
 * @example
 * ```typescript
 * import { AppRegistry } from 'react-native';
 * import { AgentforceService } from '@salesforce/agentforce-mobile-sdk-react-native';
 *
 * // 1. A splash component. It receives { agentId } as initial props and reports
 * //    the chosen utterance back to the SDK.
 * function WelcomeSplash({ agentId }: { agentId: string }) {
 *   return (
 *     <View>
 *       <Text>Welcome! How can I help?</Text>
 *       <Button
 *         title="Track my order"
 *         onPress={() =>
 *           AgentforceService.selectSplashScreenUtterance(agentId, 'Track my order')
 *         }
 *       />
 *     </View>
 *   );
 * }
 *
 * // 2. Register it with a unique component name.
 * AppRegistry.registerComponent('WelcomeSplash', () => WelcomeSplash);
 *
 * // 3. Map agent IDs to that component name.
 * AgentforceService.setSplashScreenDelegate({
 *   componentMap: {
 *     '0XxABC0000001234': 'WelcomeSplash',
 *   },
 * });
 * ```
 */

/**
 * Initial properties passed from the native SDK to a splash screen React Native
 * component.
 */
export interface SplashScreenComponentProps {
  /**
   * The identifier of the agent the splash screen is being shown for. Pass it
   * back to `AgentforceService.selectSplashScreenUtterance` when the user chooses
   * a starter utterance.
   */
  agentId: string;
}

/**
 * Configuration for the splash screen delegate.
 *
 * Register this to tell the native SDK which React Native component to show as a
 * welcome screen for each agent. Register each component with
 * `AppRegistry.registerComponent()` before setting the delegate.
 */
export interface SplashScreenDelegate {
  /**
   * Maps agent IDs to registered React Native component names. The native SDK
   * shows the mapped component as a splash screen for that agent; an agent ID
   * with no entry gets no splash screen (the standard conversation UI is shown).
   *
   * Use the wildcard key `'*'` to supply a default splash screen for every agent
   * that does not have an explicit entry — handy for single-agent apps that do
   * not know the agent ID ahead of time.
   *
   * @example
   * ```typescript
   * {
   *   '0XxABC0000001234': 'BillingWelcomeSplash',
   *   '0XxDEF0000005678': 'SupportWelcomeSplash',
   *   '*': 'DefaultWelcomeSplash',
   * }
   * ```
   */
  componentMap: Record<string, string>;
}
