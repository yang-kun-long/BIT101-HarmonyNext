import preferences from '@ohos.data.preferences';
import { guardAsyncStorage } from './storageGuard';

const PREF_FILE = 'ddl_settings';
const KEY_WARNING_DAYS = 'warning_days';
const KEY_RETENTION_DAYS = 'retention_days';

export const DDL_APP_WARNING_DAYS = 'ddl_warning_days';
export const DDL_APP_RETENTION_DAYS = 'ddl_retention_days';

export interface DdlDisplaySettings {
  warningDays: number;
  retentionDays: number;
}

export const DEFAULT_DDL_DISPLAY_SETTINGS: DdlDisplaySettings = {
  warningDays: 7,
  retentionDays: 3,
};

export function normalizeDdlDisplaySettings(settings: DdlDisplaySettings): DdlDisplaySettings {
  const warningDays = Number.isFinite(settings.warningDays)
    ? Math.max(0, Math.floor(settings.warningDays))
    : DEFAULT_DDL_DISPLAY_SETTINGS.warningDays;
  const retentionDays = Number.isFinite(settings.retentionDays)
    ? Math.max(0, Math.floor(settings.retentionDays))
    : DEFAULT_DDL_DISPLAY_SETTINGS.retentionDays;

  return {
    warningDays,
    retentionDays,
  };
}

export class DdlSettingsStore {
  private static abilityContext: any | null = null;

  static setAbilityContext(ctx: any): void {
    DdlSettingsStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = DdlSettingsStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error('[DdlSettingsStore] abilityContext is not set.');
    }
    return ctx;
  }

  private async getPref(): Promise<preferences.Preferences> {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage<preferences.Preferences>('DdlSettingsStore.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  async load(): Promise<DdlDisplaySettings> {
    const pref = await this.getPref();
    const warningDays = await guardAsyncStorage('DdlSettingsStore.load.warningDays', async () =>
      Number(await pref.get(KEY_WARNING_DAYS, DEFAULT_DDL_DISPLAY_SETTINGS.warningDays)),
    );
    const retentionDays = await guardAsyncStorage('DdlSettingsStore.load.retentionDays', async () =>
      Number(await pref.get(KEY_RETENTION_DAYS, DEFAULT_DDL_DISPLAY_SETTINGS.retentionDays)),
    );

    return normalizeDdlDisplaySettings({
      warningDays,
      retentionDays,
    });
  }

  async save(settings: DdlDisplaySettings): Promise<void> {
    const normalized = normalizeDdlDisplaySettings(settings);
    const pref = await this.getPref();
    await guardAsyncStorage('DdlSettingsStore.save', async () => {
      await pref.put(KEY_WARNING_DAYS, normalized.warningDays);
      await pref.put(KEY_RETENTION_DAYS, normalized.retentionDays);
      await pref.flush();
    });
  }

  async saveWarningDays(value: number): Promise<DdlDisplaySettings> {
    const current = await this.load();
    const next = normalizeDdlDisplaySettings({
      warningDays: value,
      retentionDays: current.retentionDays,
    });
    await this.save(next);
    return next;
  }

  async saveRetentionDays(value: number): Promise<DdlDisplaySettings> {
    const current = await this.load();
    const next = normalizeDdlDisplaySettings({
      warningDays: current.warningDays,
      retentionDays: value,
    });
    await this.save(next);
    return next;
  }
}

export function applyDdlDisplaySettingsToAppStorage(settings: DdlDisplaySettings): void {
  const normalized = normalizeDdlDisplaySettings(settings);
  AppStorage.setOrCreate(DDL_APP_WARNING_DAYS, normalized.warningDays);
  AppStorage.setOrCreate(DDL_APP_RETENTION_DAYS, normalized.retentionDays);
}

export function initDdlSettingsStore(ctx: any): void {
  DdlSettingsStore.setAbilityContext(ctx);
}
