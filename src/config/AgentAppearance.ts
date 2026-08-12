import type {
  AgentforceAppearance,
  AgentforceGenericFontFamily,
  AgentforceThemeMode,
} from '@salesforce/react-native-agentforce';

export type AppearancePresetId = 'default' | 'ocean' | 'forest' | 'sunset' | 'royal' | 'custom';

export interface AppearancePreset {
  id: Exclude<AppearancePresetId, 'custom'>;
  name: string;
  description: string;
  swatches: string[];
  lightColors?: Record<string, string>;
  darkColors?: Record<string, string>;
}

export const COLOR_GROUPS = [
  {
    title: 'Foundations',
    tokens: [
      'surface1',
      'surface2',
      'onSurface1',
      'onSurface2',
      'accent1',
      'accent2',
      'accent3',
      'onAccent1',
    ],
  },
  {
    title: 'Conversation',
    tokens: [
      'chatBackground',
      'agentMessageNameColor',
      'userMessageBubbleBackground',
      'userMessageBubbleTextColor',
    ],
  },
  {
    title: 'Composer',
    tokens: [
      'inputBarBackground',
      'inputBarFieldBackground',
      'inputBarFieldBorderColor',
      'sendButtonEnabledBackground',
      'sendButtonIconTint',
    ],
  },
] as const;

export const THEME_PRESETS: AppearancePreset[] = [
  {
    id: 'default',
    name: 'Default',
    description: 'The standard Agentforce palette.',
    swatches: ['#0176D3', '#FFFFFF', '#181818'],
  },
  {
    id: 'ocean',
    name: 'Ocean',
    description: 'Calm blue and teal for focused conversations.',
    swatches: ['#006BA6', '#B8E0F5', '#003049'],
    lightColors: {
      surface1: '#F0F8FF',
      surface2: '#FFFFFF',
      onSurface1: '#003049',
      onSurface2: '#24546A',
      accent1: '#006BA6',
      accent2: '#B8E0F5',
      accent3: '#D9F0FB',
      onAccent1: '#FFFFFF',
      chatBackground: '#F0F8FF',
      agentMessageNameColor: '#003049',
      userMessageBubbleBackground: '#B8E0F5',
      userMessageBubbleTextColor: '#003049',
      inputBarBackground: '#FFFFFF',
      inputBarFieldBackground: '#F0F8FF',
      inputBarFieldBorderColor: '#80C8E5',
      sendButtonEnabledBackground: '#006BA6',
      sendButtonIconTint: '#FFFFFF',
    },
    darkColors: {
      surface1: '#001F33',
      surface2: '#002A40',
      onSurface1: '#D8F0FF',
      onSurface2: '#B8E0F5',
      accent1: '#4A9EE0',
      accent2: '#003049',
      accent3: '#002A40',
      onAccent1: '#001F33',
      chatBackground: '#001F33',
      agentMessageNameColor: '#B8E0F5',
      userMessageBubbleBackground: '#003049',
      userMessageBubbleTextColor: '#B8E0F5',
      inputBarBackground: '#001F33',
      inputBarFieldBackground: '#002A40',
      inputBarFieldBorderColor: '#006BA6',
      sendButtonEnabledBackground: '#4A9EE0',
      sendButtonIconTint: '#001F33',
    },
  },
  {
    id: 'forest',
    name: 'Forest',
    description: 'Grounded greens and earthy neutrals.',
    swatches: ['#2D6B2A', '#D4E8C5', '#1F3A0F'],
    lightColors: {
      surface1: '#F5F9F0',
      surface2: '#FFFFFF',
      onSurface1: '#1F3A0F',
      onSurface2: '#385A2A',
      accent1: '#2D6B2A',
      accent2: '#D4E8C5',
      accent3: '#E8F2E0',
      onAccent1: '#FFFFFF',
      chatBackground: '#F5F9F0',
      agentMessageNameColor: '#1F3A0F',
      userMessageBubbleBackground: '#D4E8C5',
      userMessageBubbleTextColor: '#1F3A0F',
      inputBarBackground: '#FFFFFF',
      inputBarFieldBackground: '#F5F9F0',
      inputBarFieldBorderColor: '#8FB970',
      sendButtonEnabledBackground: '#2D6B2A',
      sendButtonIconTint: '#FFFFFF',
    },
    darkColors: {
      surface1: '#0F1F08',
      surface2: '#1A2D0F',
      onSurface1: '#D4E8C5',
      onSurface2: '#B5D3A4',
      accent1: '#6FB360',
      accent2: '#1F3A0F',
      accent3: '#1A2D0F',
      onAccent1: '#0F1F08',
      chatBackground: '#0F1F08',
      agentMessageNameColor: '#D4E8C5',
      userMessageBubbleBackground: '#1F3A0F',
      userMessageBubbleTextColor: '#D4E8C5',
      inputBarBackground: '#0F1F08',
      inputBarFieldBackground: '#1A2D0F',
      inputBarFieldBorderColor: '#2D6B2A',
      sendButtonEnabledBackground: '#6FB360',
      sendButtonIconTint: '#0F1F08',
    },
  },
  {
    id: 'sunset',
    name: 'Sunset',
    description: 'Warm orange and peach with clear actions.',
    swatches: ['#FF6B35', '#FFDDC9', '#3D1F00'],
    lightColors: {
      surface1: '#FFF8F0',
      surface2: '#FFFFFF',
      onSurface1: '#3D1F00',
      onSurface2: '#70401E',
      accent1: '#FF6B35',
      accent2: '#FFDDC9',
      accent3: '#FFF0E0',
      onAccent1: '#FFFFFF',
      chatBackground: '#FFF8F0',
      agentMessageNameColor: '#3D1F00',
      userMessageBubbleBackground: '#FFDDC9',
      userMessageBubbleTextColor: '#3D1F00',
      inputBarBackground: '#FFFFFF',
      inputBarFieldBackground: '#FFF8F0',
      inputBarFieldBorderColor: '#FFB088',
      sendButtonEnabledBackground: '#FF6B35',
      sendButtonIconTint: '#FFFFFF',
    },
    darkColors: {
      surface1: '#2A1408',
      surface2: '#3A1A0C',
      onSurface1: '#FFE4B5',
      onSurface2: '#FFD0AC',
      accent1: '#FF8C5A',
      accent2: '#4A2210',
      accent3: '#3A1A0C',
      onAccent1: '#2A1408',
      chatBackground: '#2A1408',
      agentMessageNameColor: '#FFE4B5',
      userMessageBubbleBackground: '#4A2210',
      userMessageBubbleTextColor: '#FFE4B5',
      inputBarBackground: '#2A1408',
      inputBarFieldBackground: '#3A1A0C',
      inputBarFieldBorderColor: '#FF6B35',
      sendButtonEnabledBackground: '#FF8C5A',
      sendButtonIconTint: '#2A1408',
    },
  },
  {
    id: 'royal',
    name: 'Royal',
    description: 'Rich purple and lavender with a premium feel.',
    swatches: ['#6B3AA3', '#E0D0F5', '#2A1A4A'],
    lightColors: {
      surface1: '#FAF5FF',
      surface2: '#FFFFFF',
      onSurface1: '#2A1A4A',
      onSurface2: '#543D7A',
      accent1: '#6B3AA3',
      accent2: '#E0D0F5',
      accent3: '#F0E5FF',
      onAccent1: '#FFFFFF',
      chatBackground: '#FAF5FF',
      agentMessageNameColor: '#2A1A4A',
      userMessageBubbleBackground: '#E0D0F5',
      userMessageBubbleTextColor: '#2A1A4A',
      inputBarBackground: '#FFFFFF',
      inputBarFieldBackground: '#FAF5FF',
      inputBarFieldBorderColor: '#B088E0',
      sendButtonEnabledBackground: '#6B3AA3',
      sendButtonIconTint: '#FFFFFF',
    },
    darkColors: {
      surface1: '#1A0A2E',
      surface2: '#251238',
      onSurface1: '#E0D0F5',
      onSurface2: '#C8B0E8',
      accent1: '#B088E0',
      accent2: '#2A1A4A',
      accent3: '#251238',
      onAccent1: '#1A0A2E',
      chatBackground: '#1A0A2E',
      agentMessageNameColor: '#E0D0F5',
      userMessageBubbleBackground: '#2A1A4A',
      userMessageBubbleTextColor: '#E0D0F5',
      inputBarBackground: '#1A0A2E',
      inputBarFieldBackground: '#251238',
      inputBarFieldBorderColor: '#6B3AA3',
      sendButtonEnabledBackground: '#B088E0',
      sendButtonIconTint: '#1A0A2E',
    },
  },
];

export interface AppearanceSettings {
  presetId: AppearancePresetId;
  themeMode: AgentforceThemeMode;
  lightColors: Record<string, string>;
  darkColors: Record<string, string>;
  useCustomAvatar: boolean;
  fontFamily: AgentforceGenericFontFamily;
}

export const DEFAULT_APPEARANCE_SETTINGS: AppearanceSettings = {
  presetId: 'ocean',
  themeMode: 'system',
  lightColors: {},
  darkColors: {},
  useCustomAvatar: true,
  fontFamily: 'default',
};

export function appearanceFromSettings(
  settings: AppearanceSettings,
): AgentforceAppearance | undefined {
  const icons = settings.useCustomAvatar
    ? { aiAgent: { ios: { light: 'agentforce_avatar' }, android: { light: 'agentforce_avatar' } } }
    : undefined;
  const appearance: AgentforceAppearance = {
    themeMode: settings.themeMode,
    lightColors: Object.keys(settings.lightColors).length ? settings.lightColors : undefined,
    darkColors: Object.keys(settings.darkColors).length ? settings.darkColors : undefined,
    icons,
    typography:
      settings.fontFamily === 'default'
        ? undefined
        : { fontFamily: { type: 'generic', family: settings.fontFamily } },
  };
  return appearance;
}
