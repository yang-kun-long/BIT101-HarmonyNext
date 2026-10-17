export enum DarkThemeMode {
  System = 'system',
  Light = 'light',
  Dark = 'dark',
}

export interface ThemeSettings {
  darkThemeMode: DarkThemeMode;
  autoRotate: boolean;
}

export function defaultThemeSettings(): ThemeSettings {
  return { darkThemeMode: DarkThemeMode.System, autoRotate: false };
}

export function normalizeThemeSettings(value: ThemeSettings): ThemeSettings {
  return {
    darkThemeMode: value.darkThemeMode === DarkThemeMode.Light || value.darkThemeMode === DarkThemeMode.Dark
      ? value.darkThemeMode : DarkThemeMode.System,
    autoRotate: typeof value.autoRotate === 'boolean' ? value.autoRotate : false,
  };
}

export function getDarkThemeName(mode: DarkThemeMode): string {
  switch (mode) {
    case DarkThemeMode.System: return '跟随系统';
    case DarkThemeMode.Light: return '亮色模式';
    case DarkThemeMode.Dark: return '深色模式';
  }
}
