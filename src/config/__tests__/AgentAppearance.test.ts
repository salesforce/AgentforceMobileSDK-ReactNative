import {
  appearanceFromSettings,
  DEFAULT_APPEARANCE_SETTINGS,
  THEME_PRESETS,
} from '../AgentAppearance';

describe('appearance presets', () => {
  it('provides coordinated colors for every non-default preset', () => {
    for (const preset of THEME_PRESETS.filter(candidate => candidate.id !== 'default')) {
      expect(preset.lightColors?.accent1).toMatch(/^#[0-9A-F]{6}$/);
      expect(preset.darkColors?.chatBackground).toMatch(/^#[0-9A-F]{6}$/);
    }
  });

  it('builds a sparse native appearance from settings', () => {
    expect(appearanceFromSettings(DEFAULT_APPEARANCE_SETTINGS)).toMatchObject({
      themeMode: 'system',
      icons: { aiAgent: { ios: { light: 'agentforce_avatar' } } },
    });
  });
});
