import type { PeriodTime } from '../jw/periodTimes';
import { getDefaultPeriodTimes } from '../jw/periodTimes';

export interface ScheduleDisplaySettings {
  currentTerm: string;
  firstDayISO: string;
  showSaturday: boolean;
  showSunday: boolean;
  showBorder: boolean;
  showHighlightToday: boolean;
  showDivider: boolean;
  showCurrentTime: boolean;
  showExamInfo: boolean;
  periodTimes: PeriodTime[];
}

export const DEFAULT_SCHEDULE_DISPLAY_SETTINGS: ScheduleDisplaySettings = {
  currentTerm: '',
  firstDayISO: '',
  showSaturday: true,
  showSunday: true,
  showBorder: false,
  showHighlightToday: true,
  showDivider: true,
  showCurrentTime: true,
  showExamInfo: true,
  periodTimes: getDefaultPeriodTimes(),
};

function parseClockMinutes(value: string): number {
  const match = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) {
    return -1;
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  return hour * 60 + minute;
}

function normalizeClock(value: string): string {
  const minutes = parseClockMinutes(value);
  if (minutes < 0) {
    return '';
  }
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  const hourText = hour < 10 ? `0${hour}` : `${hour}`;
  const minuteText = minute < 10 ? `0${minute}` : `${minute}`;
  return `${hourText}:${minuteText}`;
}

function parsePeriodLine(line: string): PeriodTime | null {
  const trimmed = line.trim();
  if (trimmed.length === 0) {
    return null;
  }
  const separator = trimmed.indexOf(',') >= 0 ? ',' : '-';
  const parts = trimmed.split(separator);
  if (parts.length !== 2) {
    return null;
  }
  const start = normalizeClock(parts[0]);
  const end = normalizeClock(parts[1]);
  if (start.length === 0 || end.length === 0) {
    return null;
  }
  return { start, end };
}

export function parsePeriodTimesText(text: string): PeriodTime[] {
  const lines = text.split('\n');
  const result: PeriodTime[] = [];
  let previousEnd = -1;

  for (const line of lines) {
    if (line.trim().length === 0) {
      continue;
    }
    const period = parsePeriodLine(line);
    if (!period) {
      return [];
    }
    const start = parseClockMinutes(period.start);
    const end = parseClockMinutes(period.end);
    if (start < 0 || end <= start || start < previousEnd) {
      return [];
    }
    result.push(period);
    previousEnd = end;
  }

  return result.length > 0 ? result : [];
}

export function periodTimesToText(periodTimes: PeriodTime[]): string {
  return periodTimes.map((period) => `${period.start},${period.end}`).join('\n');
}

export function normalizePeriodTimes(periodTimes?: PeriodTime[]): PeriodTime[] {
  if (!periodTimes || periodTimes.length === 0) {
    return getDefaultPeriodTimes();
  }
  const parsed = parsePeriodTimesText(periodTimesToText(periodTimes));
  return parsed.length > 0 ? parsed : getDefaultPeriodTimes();
}

export function normalizeScheduleDisplaySettings(settings: Partial<ScheduleDisplaySettings>): ScheduleDisplaySettings {
  return {
    currentTerm: settings.currentTerm ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.currentTerm,
    firstDayISO: settings.firstDayISO ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.firstDayISO,
    showSaturday: settings.showSaturday ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showSaturday,
    showSunday: settings.showSunday ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showSunday,
    showBorder: settings.showBorder ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showBorder,
    showHighlightToday: settings.showHighlightToday ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showHighlightToday,
    showDivider: settings.showDivider ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showDivider,
    showCurrentTime: settings.showCurrentTime ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showCurrentTime,
    showExamInfo: settings.showExamInfo ?? DEFAULT_SCHEDULE_DISPLAY_SETTINGS.showExamInfo,
    periodTimes: normalizePeriodTimes(settings.periodTimes),
  };
}

export function visibleWeekdayNumbers(showSaturday: boolean, showSunday: boolean): number[] {
  const weekdays: number[] = [1, 2, 3, 4, 5];
  if (showSaturday) {
    weekdays.push(6);
  }
  if (showSunday) {
    weekdays.push(7);
  }
  return weekdays;
}
