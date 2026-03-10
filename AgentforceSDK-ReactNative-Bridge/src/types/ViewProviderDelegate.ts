/**
 * View Provider delegate types for Agentforce SDK
 *
 * Allows JS to override native SDK output views with custom React Native components.
 * When enabled, the native SDK checks the registered component types before rendering
 * its built-in views. If a match is found, a React Native root view is rendered instead.
 *
 * Each component type maps 1:1 to a React Native component name, so different
 * SDK view types can be rendered by different React components.
 *
 * Known component definition strings follow the pattern "copilot/<type>" or "agentforce/<type>".
 * Examples: 'copilot/richText', 'copilot/markdown', 'copilot/recordInfo', 'copilot/list'.
 *
 * @example
 * ```typescript
 * AgentforceService.setViewProviderDelegate({
 *   componentMap: {
 *     'copilot/richText': 'CustomRichTextView',
 *     'copilot/markdown': 'CustomMarkdownView',
 *   },
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
 * views can handle. Each key is a component definition string, and the value
 * is the registered React Native component name to render for that type.
 *
 * Register each component with `AppRegistry.registerComponent()`.
 */
export interface ViewProviderDelegate {
  /**
   * Maps component definition strings to React Native component names.
   * The native `canHandle()` method checks against the keys synchronously.
   * The `view()` / `GetView()` method looks up the component name for the
   * matching key and renders it via RCTRootView / ReactRootView.
   *
   * @example
   * ```typescript
   * {
   *   'copilot/richText': 'CustomRichTextView',
   *   'copilot/markdown': 'CustomMarkdownView',
   *   'copilot/recordInfo': 'CustomRecordInfoView',
   * }
   * ```
   */
  componentMap: Record<string, string>;
}
