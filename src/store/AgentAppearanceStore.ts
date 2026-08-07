import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';
import type {
  AgentforceAppearance,
  AgentforceGenericFontFamily,
  AgentforceThemeMode,
} from '@salesforce/react-native-agentforce';
import {
  appearanceFromSettings,
  DEFAULT_APPEARANCE_SETTINGS,
  type AppearancePresetId,
  type AppearanceSettings,
  THEME_PRESETS,
} from '../config/AgentAppearance';

const STORAGE_KEY = '@agentforce/appearance-settings';
let settings: AppearanceSettings = { ...DEFAULT_APPEARANCE_SETTINGS };
let loaded = false;

function snapshot(): AppearanceSettings {
  return {
    ...settings,
    lightColors: { ...settings.lightColors },
    darkColors: { ...settings.darkColors },
  };
}

async function persist(): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
}

export async function loadAppearanceSettings(): Promise<AppearanceSettings> {
  if (loaded) {
    return snapshot();
  }
  try {
    const stored = await AsyncStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored) as Partial<AppearanceSettings>;
      settings = {
        ...DEFAULT_APPEARANCE_SETTINGS,
        ...parsed,
        lightColors: parsed.lightColors ?? {},
        darkColors: parsed.darkColors ?? {},
      };
    }
  } catch (error) {
    console.warn('Failed to load appearance settings:', error);
  }
  loaded = true;
  return snapshot();
}

export function getAppearanceSettings(): AppearanceSettings {
  return snapshot();
}
export function getAgentAppearance(): AgentforceAppearance | undefined {
  const appearance = appearanceFromSettings(settings);
  // The installed iOS SDK rejects sparse overrides combined with a forced mode.
  // Android supports both, so preserve the selected mode there.
  if (Platform.OS === 'ios' && appearance) {
    delete appearance.themeMode;
  }
  return appearance;
}

export async function applyAppearancePreset(
  id: Exclude<AppearancePresetId, 'custom'>,
): Promise<AppearanceSettings> {
  const preset = THEME_PRESETS.find(candidate => candidate.id === id);
  settings = {
    ...settings,
    presetId: id,
    lightColors: { ...(preset?.lightColors ?? {}) },
    darkColors: { ...(preset?.darkColors ?? {}) },
  };
  await persist();
  return snapshot();
}

export async function updateAppearanceThemeMode(
  themeMode: AgentforceThemeMode,
): Promise<AppearanceSettings> {
  settings = { ...settings, themeMode };
  await persist();
  return snapshot();
}

export async function updateAppearanceColor(
  scheme: 'lightColors' | 'darkColors',
  token: string,
  value: string,
): Promise<AppearanceSettings> {
  if (!/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value)) {
    return snapshot();
  }
  settings = { ...settings, presetId: 'custom', [scheme]: { ...settings[scheme], [token]: value } };
  await persist();
  return snapshot();
}

export async function updateAppearanceAvatar(
  useCustomAvatar: boolean,
): Promise<AppearanceSettings> {
  settings = { ...settings, useCustomAvatar };
  await persist();
  return snapshot();
}

export async function updateAppearanceFontFamily(
  fontFamily: AgentforceGenericFontFamily,
): Promise<AppearanceSettings> {
  settings = { ...settings, fontFamily };
  await persist();
  return snapshot();
}

export async function resetAppearanceSettings(): Promise<AppearanceSettings> {
  settings = { ...DEFAULT_APPEARANCE_SETTINGS };
  await persist();
  return snapshot();
}
