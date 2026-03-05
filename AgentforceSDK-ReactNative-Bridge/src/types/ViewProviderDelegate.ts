/**
 * View Provider delegate types for Agentforce SDK
 *
 * Allows JS to override native SDK output views with custom React Native components.
 * When enabled, the native SDK checks the registered component types before rendering
 * its built-in views. If a match is found, a React Native root view is rendered instead.
 *
 * Known component definition strings follow the pattern "copilot/<type>" or "agentforce/<type>".
 * Examples: 'copilot/richText', 'copilot/markdown', 'copilot/recordInfo', 'copilot/list'.
 *
 * @example
 * ```typescript
 * AgentforceService.setViewProviderDelegate({
 *   componentTypes: ['copilot/richText', 'copilot/markdown'],
 *   reactComponentName: 'CustomAgentforceView',
 * });
 * ```
 */

/**
 * Data passed from the native SDK to the React Native view for rendering.
 */
export interface ViewProviderComponentData {
  /** The component definition string (e.g. 'copilot/richText') */
  definition: string;
  /** Component name from the SDK (may be null) */
  name?: string;
  /** Key-value properties for the component */
  properties: Record<string, unknown>;
  /** Nested sub-components, if any */
  subComponents?: ViewProviderComponentData[];
}

/**
 * Configuration for the View Provider delegate.
 *
 * Register this to tell the native SDK which component types your React Native
 * view can handle. When the SDK encounters a matching type, it renders your
 * registered React component instead of the built-in native view.
 */
export interface ViewProviderDelegate {
  /**
   * List of component definition strings this provider handles.
   * The native `canHandle()` method checks against this list synchronously.
   *
   * @example ['copilot/richText', 'copilot/markdown', 'copilot/recordInfo']
   */
  componentTypes: string[];

  /**
   * The registered React Native component name that will be rendered
   * for matching types. This component receives `ViewProviderComponentData`
   * as its props via the native root view.
   *
   * Register the component with `AppRegistry.registerComponent()`.
   */
  reactComponentName: string;
}
