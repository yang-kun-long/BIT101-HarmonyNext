import preferences from '@ohos.data.preferences';
import type { common } from '@kit.AbilityKit';
import { guardAsyncStorage } from './storageGuard';
import { defaultThemeSettings, normalizeThemeSettings, ThemeSettings } from '../settings/ThemeSettingsModel';

export interface ThemeSettingsBackend {
  read(): Promise<string>;
  write(value: string): Promise<void>;
}

class PreferencesThemeSettingsBackend implements ThemeSettingsBackend {
  private readonly context: common.Context;
  constructor(context: common.Context) { this.context = context; }

  async read(): Promise<string> {
    return await guardAsyncStorage('ThemeSettingsStore.read', async () => {
      const pref = await preferences.getPreferences(this.context, 'theme_settings');
      return String(await pref.get('settings', ''));
    });
  }

  async write(value: string): Promise<void> {
    await guardAsyncStorage('ThemeSettingsStore.write', async () => {
      const pref = await preferences.getPreferences(this.context, 'theme_settings');
      await pref.put('settings', value);
      await pref.flush();
    });
  }
}

export class ThemeSettingsStore {
  private readonly backend: ThemeSettingsBackend;
  constructor(backend: ThemeSettingsBackend) { this.backend = backend; }

  async load(): Promise<ThemeSettings> {
    const raw = await this.backend.read();
    if (raw.length === 0) return defaultThemeSettings();
    try {
      const parsed: ThemeSettings | null = JSON.parse(raw);
      return parsed === null ? defaultThemeSettings() : normalizeThemeSettings(parsed);
    } catch (_) { return defaultThemeSettings(); }
  }

  async save(settings: ThemeSettings): Promise<void> {
    await this.backend.write(JSON.stringify(normalizeThemeSettings(settings)));
  }
}

export function createThemeSettingsStore(context: common.Context): ThemeSettingsStore {
  return new ThemeSettingsStore(new PreferencesThemeSettingsBackend(context));
}
