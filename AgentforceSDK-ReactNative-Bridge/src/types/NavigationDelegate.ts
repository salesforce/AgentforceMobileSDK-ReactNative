/**
 * Navigation delegate types for Agentforce SDK
 *
 * Allows JS to receive navigation requests from the native Agentforce SDK
 * when users tap records, links, quick actions, or page references.
 *
 * Known `type` values: 'record', 'link', 'quickAction', 'pageReference',
 * 'objectHome', 'app', 'unknown'.
 *
 * Known fields by type:
 *   record       — recordId, objectType, pageReference?
 *   link         — uri, pageReference?
 *   quickAction  — actionName, recordId?, objectType?
 *   pageReference — pageReference
 *   objectHome   — objectType, pageReference?
 *   app          — packageName, uri?
 *   unknown      — raw
 *
 * The index signature lets consumers access any field the native bridge
 * sends, so the JS layer is forward-compatible when the SDK adds new
 * destination types or fields.
 */

export interface NavigationRequest {
  /** Destination kind (e.g. 'record', 'link', 'quickAction', 'pageReference', 'objectHome', 'app') */
  type: string;
  /** Any additional fields serialized by the native bridge */
  [key: string]: string | boolean | undefined;
}

export interface NavigationDelegate {
  /**
   * Called when the Agentforce SDK requests navigation.
   *
   * @param request - The navigation request with destination details
   */
  onNavigate(request: NavigationRequest): void;
}
