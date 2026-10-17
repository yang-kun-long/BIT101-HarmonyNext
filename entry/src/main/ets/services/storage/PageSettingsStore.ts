import preferences from '@ohos.data.preferences';
import type { common } from '@kit.AbilityKit';
import { guardAsyncStorage } from './storageGuard';
import { defaultPageSettings, LegacyPageSettings, migratePageSettings, PageSettings, validatePageSettings } from '../settings/PageSettingsModel';

export interface PageSettingsBackend {
  read(): Promise<string>;
  write(value: string): Promise<void>;
}

class PreferencesPageSettingsBackend implements PageSettingsBackend {
  private readonly context: common.Context;
  constructor(context: common.Context) { this.context = context; }

  async read(): Promise<string> {
    return await guardAsyncStorage('PageSettingsStore.read', async () => {
      const pref = await preferences.getPreferences(this.context, 'page_settings');
      return String(await pref.get('settings', ''));
    });
  }

  async write(value: string): Promise<void> {
    await guardAsyncStorage('PageSettingsStore.write', async () => {
      const pref = await preferences.getPreferences(this.context, 'page_settings');
      await pref.put('settings', value);
      await pref.flush();
    });
  }
}

export class PageSettingsStore {
  private readonly backend: PageSettingsBackend;
  constructor(backend: PageSettingsBackend) { this.backend = backend; }

  async load(legacy?: LegacyPageSettings): Promise<PageSettings> {
    const raw = await this.backend.read();
    let settings = legacy ? migratePageSettings(legacy) : defaultPageSettings();
    if (raw.length > 0) {
      try {
        const parsed: LegacyPageSettings | null = JSON.parse(raw);
        settings = parsed === null ? defaultPageSettings() : migratePageSettings(parsed);
      } catch (_) { settings = defaultPageSettings(); }
    }
    // Migration is durable before callers remove the old PersistentStorage keys.
    await this.save(settings);
    return settings;
  }

  async save(settings: PageSettings): Promise<void> {
    validatePageSettings(settings);
    await this.backend.write(JSON.stringify(settings));
  }
}

export function createPageSettingsStore(context: common.Context): PageSettingsStore {
  return new PageSettingsStore(new PreferencesPageSettingsBackend(context));
}

export function applyPageSettings(settings: PageSettings): void {
  AppStorage.setOrCreate('home_page', settings.home);
  AppStorage.setOrCreate('pages_order', settings.order.slice());
  AppStorage.setOrCreate('pages_hidden', settings.hidden.slice());
}
