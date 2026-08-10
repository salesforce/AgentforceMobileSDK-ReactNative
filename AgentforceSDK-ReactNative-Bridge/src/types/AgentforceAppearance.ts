/** Serializable appearance overrides applied when an Agentforce client is configured. */

export type AgentforceThemeMode = 'system' | 'light' | 'dark';

export type AgentforceFontWeight = 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900;

export type AgentforceGenericFontFamily =
  | 'default'
  | 'sans-serif'
  | 'serif'
  | 'monospace'
  | 'cursive';

export type AgentforceFontFamily =
  | { type: 'generic'; family: AgentforceGenericFontFamily }
  | {
      type: 'bundled';
      ios: { name: string };
      android: { resources: Partial<Record<AgentforceFontWeight, string>> };
    };

export interface AgentforceIconSource {
  ios: { light: string; dark?: string };
  android: { light: string; dark?: string };
}

export interface AgentforceFontOverride {
  size?: number;
  weight?: AgentforceFontWeight;
  fontFamily?: AgentforceFontFamily;
}

/**
 * Native SDK token names are intentionally strings: the SDK adds tokens regularly and the
 * bridge validates them against the platform installed in the host application.
 */
export interface AgentforceAppearance {
  themeMode?: AgentforceThemeMode;
  lightColors?: Record<string, string>;
  darkColors?: Record<string, string>;
  icons?: Record<string, AgentforceIconSource>;
  displayNames?: Record<string, string>;
  typography?: {
    fontFamily?: AgentforceFontFamily;
    styles?: Record<string, AgentforceFontOverride>;
  };
}
