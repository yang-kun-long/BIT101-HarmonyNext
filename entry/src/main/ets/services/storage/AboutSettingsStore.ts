import preferences from '@ohos.data.preferences';
import type { common } from '@kit.AbilityKit';
import { guardAsyncStorage } from './storageGuard';

export interface AboutSettings {
  autoDetectUpgrade: boolean;
  ignoredVersion: number;
  lastCheckTime: number;
}

export interface AboutSettingsBackend {
  read(): Promise<string>;
  write(value: string): Promise<void>;
}

export function defaultAboutSettings(): AboutSettings {
  return { autoDetectUpgrade: true, ignoredVersion: 0, lastCheckTime: 0 };
}

export function normalizeAboutSettings(settings: AboutSettings): AboutSettings {
  return {
    autoDetectUpgrade: typeof settings.autoDetectUpgrade === 'boolean' ? settings.autoDetectUpgrade : true,
    ignoredVersion: Number.isSafeInteger(settings.ignoredVersion) && settings.ignoredVersion >= 0
      ? settings.ignoredVersion : 0,
    lastCheckTime: Number.isSafeInteger(settings.lastCheckTime) && settings.lastCheckTime >= 0
      ? settings.lastCheckTime : 0,
  };
}

class PreferencesAboutSettingsBackend implements AboutSettingsBackend {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  async read(): Promise<string> {
    return await guardAsyncStorage('AboutSettingsStore.read', async () => {
      const pref = await preferences.getPreferences(this.context, 'about_settings');
      return String(await pref.get('settings', ''));
    });
  }

  async write(value: string): Promise<void> {
    await guardAsyncStorage('AboutSettingsStore.write', async () => {
      const pref = await preferences.getPreferences(this.context, 'about_settings');
      await pref.put('settings', value);
      await pref.flush();
    });
  }
}

export class AboutSettingsStore {
  private readonly backend: AboutSettingsBackend;

  constructor(backend: AboutSettingsBackend) {
    this.backend = backend;
  }

  async load(): Promise<AboutSettings> {
    const raw = await this.backend.read();
    if (raw.length === 0) return defaultAboutSettings();
    try {
      const parsed: AboutSettings | null = JSON.parse(raw);
      return parsed === null ? defaultAboutSettings() : normalizeAboutSettings(parsed);
    } catch (_) {
      return defaultAboutSettings();
    }
  }

  async save(settings: AboutSettings): Promise<void> {
    await this.backend.write(JSON.stringify(normalizeAboutSettings(settings)));
  }
}

export function createAboutSettingsStore(context: common.Context): AboutSettingsStore {
  return new AboutSettingsStore(new PreferencesAboutSettingsBackend(context));
}
