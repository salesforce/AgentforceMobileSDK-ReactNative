let useBrandedAppearance = true;

export function isBrandedAppearanceEnabled(): boolean {
  return useBrandedAppearance;
}

export function setBrandedAppearanceEnabled(enabled: boolean): void {
  useBrandedAppearance = enabled;
}
