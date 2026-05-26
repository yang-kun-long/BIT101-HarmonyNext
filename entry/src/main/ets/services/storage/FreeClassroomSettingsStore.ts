import preferences from '@ohos.data.preferences';
import { guardAsyncStorage } from './storageGuard';

const PREF_FILE = 'free_classroom_settings';
const KEY_CAMPUS_CODE = 'current_campus_code';
const KEY_CAMPUS_NAME = 'current_campus_name';
const KEY_HIDE_BUSY = 'hide_busy_classroom';
const KEY_FREE_THRESHOLD = 'free_minutes_threshold';

export const FREE_CLASSROOM_APP_CAMPUS_CODE = 'free_classroom_current_campus_code';
export const FREE_CLASSROOM_APP_CAMPUS_NAME = 'free_classroom_current_campus_name';
export const FREE_CLASSROOM_APP_HIDE_BUSY = 'free_classroom_hide_busy_classroom';
export const FREE_CLASSROOM_APP_FREE_THRESHOLD = 'free_classroom_free_minutes_threshold';

export interface FreeClassroomSettingsData {
  currentCampusCode: string;
  currentCampusName: string;
  hideBusyClassroom: boolean;
  freeMinutesThreshold: number;
}

export const DEFAULT_FREE_CLASSROOM_SETTINGS: FreeClassroomSettingsData = {
  currentCampusCode: '',
  currentCampusName: '',
  hideBusyClassroom: true,
  freeMinutesThreshold: 5,
};

export function normalizeFreeClassroomThreshold(value: number): number {
  if (!Number.isFinite(value)) {
    return DEFAULT_FREE_CLASSROOM_SETTINGS.freeMinutesThreshold;
  }
  return Math.max(0, Math.floor(value));
}

export function parseFreeClassroomThresholdInput(text: string): number | null {
  if (!/^\d+$/.test(text)) {
    return null;
  }
  const value = Number(text);
  if (!Number.isSafeInteger(value)) {
    return null;
  }
  return value;
}

export class FreeClassroomSettingsStore {
  private static abilityContext: any | null = null;

  static setAbilityContext(ctx: any): void {
    FreeClassroomSettingsStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = FreeClassroomSettingsStore.abilityContext ??
      (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error('[FreeClassroomSettingsStore] abilityContext is not set.');
    }
    return ctx;
  }

  private async getPref(): Promise<preferences.Preferences> {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage<preferences.Preferences>('FreeClassroomSettingsStore.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  async load(): Promise<FreeClassroomSettingsData> {
    const pref = await this.getPref();
    const currentCampusCode = await guardAsyncStorage('FreeClassroomSettingsStore.load.campusCode', async () =>
      (await pref.get(KEY_CAMPUS_CODE, DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusCode)) as string,
    );
    const currentCampusName = await guardAsyncStorage('FreeClassroomSettingsStore.load.campusName', async () =>
      (await pref.get(KEY_CAMPUS_NAME, DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusName)) as string,
    );
    const hideBusyClassroom = await guardAsyncStorage('FreeClassroomSettingsStore.load.hideBusy', async () =>
      (await pref.get(KEY_HIDE_BUSY, DEFAULT_FREE_CLASSROOM_SETTINGS.hideBusyClassroom)) as boolean,
    );
    const freeMinutesThreshold = await guardAsyncStorage('FreeClassroomSettingsStore.load.threshold', async () =>
      Number(await pref.get(KEY_FREE_THRESHOLD, DEFAULT_FREE_CLASSROOM_SETTINGS.freeMinutesThreshold)),
    );
    return {
      currentCampusCode,
      currentCampusName,
      hideBusyClassroom,
      freeMinutesThreshold: normalizeFreeClassroomThreshold(freeMinutesThreshold),
    };
  }

  async save(data: FreeClassroomSettingsData): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('FreeClassroomSettingsStore.save', async () => {
      await pref.put(KEY_CAMPUS_CODE, data.currentCampusCode);
      await pref.put(KEY_CAMPUS_NAME, data.currentCampusName);
      await pref.put(KEY_HIDE_BUSY, data.hideBusyClassroom);
      await pref.put(KEY_FREE_THRESHOLD, normalizeFreeClassroomThreshold(data.freeMinutesThreshold));
      await pref.flush();
    });
  }

  async saveCampus(code: string, name: string): Promise<void> {
    const current = await this.load();
    await this.save({
      currentCampusCode: code,
      currentCampusName: name,
      hideBusyClassroom: current.hideBusyClassroom,
      freeMinutesThreshold: current.freeMinutesThreshold,
    });
  }

  async saveHideBusyClassroom(value: boolean): Promise<void> {
    const current = await this.load();
    await this.save({
      currentCampusCode: current.currentCampusCode,
      currentCampusName: current.currentCampusName,
      hideBusyClassroom: value,
      freeMinutesThreshold: current.freeMinutesThreshold,
    });
  }

  async saveFreeMinutesThreshold(value: number): Promise<void> {
    const current = await this.load();
    await this.save({
      currentCampusCode: current.currentCampusCode,
      currentCampusName: current.currentCampusName,
      hideBusyClassroom: current.hideBusyClassroom,
      freeMinutesThreshold: value,
    });
  }
}

export function initFreeClassroomSettingsStore(ctx: any): void {
  FreeClassroomSettingsStore.setAbilityContext(ctx);
}
