import preferences from '@ohos.data.preferences';
import { guardAsyncStorage } from './storageGuard';
import type { PeriodTime } from '../jw/periodTimes';
import { PeriodTimesStore } from '../jw/periodTimesStore';
import {
  DEFAULT_SCHEDULE_DISPLAY_SETTINGS,
  normalizeScheduleDisplaySettings,
  ScheduleDisplaySettings,
} from '../schoolSchedule/ScheduleSettingsModels';

const PREF_FILE = 'course_schedule_settings';
const KEY_CURRENT_TERM = 'current_term';
const KEY_FIRST_DAY_ISO = 'first_day_iso';
const KEY_SHOW_SATURDAY = 'show_saturday';
const KEY_SHOW_SUNDAY = 'show_sunday';
const KEY_SHOW_BORDER = 'show_border';
const KEY_SHOW_HIGHLIGHT_TODAY = 'show_highlight_today';
const KEY_SHOW_DIVIDER = 'show_divider';
const KEY_SHOW_CURRENT_TIME = 'show_current_time';
const KEY_SHOW_EXAM_INFO = 'show_exam_info';

export const COURSE_SCHEDULE_APP_CURRENT_TERM = 'course_schedule_current_term';
export const COURSE_SCHEDULE_APP_FIRST_DAY_ISO = 'course_schedule_first_day_iso';
export const COURSE_SCHEDULE_APP_SHOW_SATURDAY = 'course_schedule_show_saturday';
export const COURSE_SCHEDULE_APP_SHOW_SUNDAY = 'course_schedule_show_sunday';
export const COURSE_SCHEDULE_APP_SHOW_BORDER = 'course_schedule_show_border';
export const COURSE_SCHEDULE_APP_SHOW_HIGHLIGHT_TODAY = 'course_schedule_show_highlight_today';
export const COURSE_SCHEDULE_APP_SHOW_DIVIDER = 'course_schedule_show_divider';
export const COURSE_SCHEDULE_APP_SHOW_CURRENT_TIME = 'course_schedule_show_current_time';
export const COURSE_SCHEDULE_APP_SHOW_EXAM_INFO = 'course_schedule_show_exam_info';
export const COURSE_SCHEDULE_APP_PERIOD_TIMES = 'course_schedule_period_times';

export class CourseScheduleSettingsStore {
  private static abilityContext: any | null = null;

  static setAbilityContext(ctx: any): void {
    CourseScheduleSettingsStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = CourseScheduleSettingsStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error('[CourseScheduleSettingsStore] abilityContext is not set.');
    }
    return ctx;
  }

  private async getPref(): Promise<preferences.Preferences> {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage<preferences.Preferences>('CourseScheduleSettingsStore.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  private loadPeriodTimes(): PeriodTime[] {
    const ctx = this.getAbilityContextOrThrow();
    const filesDir = String(ctx.filesDir ?? '');
    if (filesDir.length === 0) {
      return DEFAULT_SCHEDULE_DISPLAY_SETTINGS.periodTimes;
    }
    const store = new PeriodTimesStore({ filesDir });
    return store.load();
  }

  async load(): Promise<ScheduleDisplaySettings> {
    const pref = await this.getPref();
    const currentTerm = await guardAsyncStorage('CourseScheduleSettingsStore.load.currentTerm', async () =>
      String(await pref.get(KEY_CURRENT_TERM, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.currentTerm)),
    );
    const firstDayISO = await guardAsyncStorage('CourseScheduleSettingsStore.load.firstDayISO', async () =>
      String(await pref.get(KEY_FIRST_DAY_ISO, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.firstDayISO)),
    );
    const showSaturday = await guardAsyncStorage('CourseScheduleSettingsStore.load.showSaturday', async () =>
      Boolean(await pref.get(KEY_SHOW_SATURDAY, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showSaturday)),
    );
    const showSunday = await guardAsyncStorage('CourseScheduleSettingsStore.load.showSunday', async () =>
      Boolean(await pref.get(KEY_SHOW_SUNDAY, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showSunday)),
    );
    const showBorder = await guardAsyncStorage('CourseScheduleSettingsStore.load.showBorder', async () =>
      Boolean(await pref.get(KEY_SHOW_BORDER, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showBorder)),
    );
    const showHighlightToday = await guardAsyncStorage('CourseScheduleSettingsStore.load.showHighlightToday', async () =>
      Boolean(await pref.get(KEY_SHOW_HIGHLIGHT_TODAY, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showHighlightToday)),
    );
    const showDivider = await guardAsyncStorage('CourseScheduleSettingsStore.load.showDivider', async () =>
      Boolean(await pref.get(KEY_SHOW_DIVIDER, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showDivider)),
    );
    const showCurrentTime = await guardAsyncStorage('CourseScheduleSettingsStore.load.showCurrentTime', async () =>
      Boolean(await pref.get(KEY_SHOW_CURRENT_TIME, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showCurrentTime)),
    );
    const showExamInfo = await guardAsyncStorage('CourseScheduleSettingsStore.load.showExamInfo', async () =>
      Boolean(await pref.get(KEY_SHOW_EXAM_INFO, DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showExamInfo)),
    );

    return normalizeScheduleDisplaySettings({
      currentTerm,
      firstDayISO,
      showSaturday,
      showSunday,
      showBorder,
      showHighlightToday,
      showDivider,
      showCurrentTime,
      showExamInfo,
      periodTimes: this.loadPeriodTimes(),
    });
  }

  async save(settings: ScheduleDisplaySettings): Promise<void> {
    const normalized = normalizeScheduleDisplaySettings(settings);
    const pref = await this.getPref();
    await guardAsyncStorage('CourseScheduleSettingsStore.save', async () => {
      await pref.put(KEY_CURRENT_TERM, normalized.currentTerm);
      await pref.put(KEY_FIRST_DAY_ISO, normalized.firstDayISO);
      await pref.put(KEY_SHOW_SATURDAY, normalized.showSaturday);
      await pref.put(KEY_SHOW_SUNDAY, normalized.showSunday);
      await pref.put(KEY_SHOW_BORDER, normalized.showBorder);
      await pref.put(KEY_SHOW_HIGHLIGHT_TODAY, normalized.showHighlightToday);
      await pref.put(KEY_SHOW_DIVIDER, normalized.showDivider);
      await pref.put(KEY_SHOW_CURRENT_TIME, normalized.showCurrentTime);
      await pref.put(KEY_SHOW_EXAM_INFO, normalized.showExamInfo);
      await pref.flush();
    });

    const ctx = this.getAbilityContextOrThrow();
    const filesDir = String(ctx.filesDir ?? '');
    if (filesDir.length > 0) {
      new PeriodTimesStore({ filesDir }).save(normalized.periodTimes);
    }
  }

  async saveCurrentTerm(value: string): Promise<ScheduleDisplaySettings> {
    const current = await this.load();
    const next = normalizeScheduleDisplaySettings({ ...current, currentTerm: value });
    await this.save(next);
    return next;
  }

  async saveTermInfo(term: string, firstDayISO: string): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('CourseScheduleSettingsStore.saveTermInfo', async () => {
      await pref.put(KEY_CURRENT_TERM, term);
      await pref.put(KEY_FIRST_DAY_ISO, firstDayISO);
      await pref.flush();
    });
    AppStorage.setOrCreate(COURSE_SCHEDULE_APP_CURRENT_TERM, term);
    AppStorage.setOrCreate(COURSE_SCHEDULE_APP_FIRST_DAY_ISO, firstDayISO);
  }

  async saveFirstDayISO(value: string): Promise<ScheduleDisplaySettings> {
    const current = await this.load();
    const next = normalizeScheduleDisplaySettings({ ...current, firstDayISO: value });
    await this.save(next);
    return next;
  }

  async saveDisplaySwitch(key: keyof ScheduleDisplaySettings, value: boolean): Promise<ScheduleDisplaySettings> {
    const current = await this.load();
    const next: ScheduleDisplaySettings = { ...current };
    if (key === 'showSaturday') next.showSaturday = value;
    if (key === 'showSunday') next.showSunday = value;
    if (key === 'showBorder') next.showBorder = value;
    if (key === 'showHighlightToday') next.showHighlightToday = value;
    if (key === 'showDivider') next.showDivider = value;
    if (key === 'showCurrentTime') next.showCurrentTime = value;
    if (key === 'showExamInfo') next.showExamInfo = value;
    await this.save(next);
    return next;
  }

  async savePeriodTimes(periodTimes: PeriodTime[]): Promise<ScheduleDisplaySettings> {
    const current = await this.load();
    const next = normalizeScheduleDisplaySettings({ ...current, periodTimes });
    await this.save(next);
    return next;
  }
}

export function applyCourseScheduleSettingsToAppStorage(settings: ScheduleDisplaySettings): void {
  const normalized = normalizeScheduleDisplaySettings(settings);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_CURRENT_TERM, normalized.currentTerm);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_FIRST_DAY_ISO, normalized.firstDayISO);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_SATURDAY, normalized.showSaturday);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_SUNDAY, normalized.showSunday);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_BORDER, normalized.showBorder);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_HIGHLIGHT_TODAY, normalized.showHighlightToday);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_DIVIDER, normalized.showDivider);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_CURRENT_TIME, normalized.showCurrentTime);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_SHOW_EXAM_INFO, normalized.showExamInfo);
  AppStorage.setOrCreate(COURSE_SCHEDULE_APP_PERIOD_TIMES, normalized.periodTimes);
}

export function initCourseScheduleSettingsStore(ctx: any): void {
  CourseScheduleSettingsStore.setAbilityContext(ctx);
}
