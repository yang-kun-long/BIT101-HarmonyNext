import type { PeriodTime } from '../jw/periodTimes';
import { TimetableRepository } from '../jw/timetableRepository';
import type { CalendarEvent } from '../jw/timetableRepository';
import { ScheduleLocalStore } from './ScheduleLocalStore';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
  ScheduleDisplayItem,
} from './ScheduleModels';

export interface BuildWeekScheduleDisplayOptions {
  weekStartISO: string;
  weekNumber: number;
  periodTimes: PeriodTime[];
  showExamInfo: boolean;
  courses: CourseScheduleItem[];
  exams: ExamScheduleItem[];
  customSchedules: CustomScheduleItem[];
}

export interface CourseScheduleRepositoryDeps {
  localStore: ScheduleLocalStore;
  timetableRepository?: TimetableRepository;
}

function parseIcsDate(value?: string): Date | null {
  if (!value || value.length < 8) {
    return null;
  }
  const text = value.endsWith('Z') ? value.slice(0, value.length - 1) : value;
  const tIndex = text.indexOf('T');
  const year = Number(text.slice(0, 4));
  const month = Number(text.slice(4, 6)) - 1;
  const day = Number(text.slice(6, 8));
  let hour = 0;
  let minute = 0;
  let second = 0;
  if (tIndex >= 0) {
    hour = Number(text.slice(tIndex + 1, tIndex + 3));
    minute = Number(text.slice(tIndex + 3, tIndex + 5));
    if (text.length >= tIndex + 7) {
      second = Number(text.slice(tIndex + 5, tIndex + 7));
    }
  }
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return null;
  }
  return new Date(year, month, day, hour, minute, second);
}

function parseDateISO(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return null;
  }
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

function formatDateISO(date: Date): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const mm = month < 10 ? `0${month}` : `${month}`;
  const dd = day < 10 ? `0${day}` : `${day}`;
  return `${date.getFullYear()}-${mm}-${dd}`;
}

function addDaysISO(iso: string, days: number): string {
  const date = parseDateISO(iso);
  if (!date) {
    return iso;
  }
  date.setDate(date.getDate() + days);
  return formatDateISO(date);
}

function dateDiffDays(startISO: string, endISO: string): number {
  const start = parseDateISO(startISO);
  const end = parseDateISO(endISO);
  if (!start || !end) {
    return 0;
  }
  return Math.floor((end.getTime() - start.getTime()) / 86400000);
}

function parseClockMinutes(value: string): number {
  const match = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) {
    return -1;
  }
  return Number(match[1]) * 60 + Number(match[2]);
}

export function computeWeekNumber(firstDayISO: string, todayISO: string): number {
  if (!firstDayISO || !todayISO) {
    return 1;
  }
  const diff = dateDiffDays(firstDayISO, todayISO);
  const week = Math.floor(diff / 7) + 1;
  return week < 1 ? 1 : week;
}

export function courseContainsWeek(weeks: string, week: number): boolean {
  if (!weeks || week < 1) {
    return false;
  }
  return weeks.indexOf(`[${week}]`) >= 0;
}

export function clockToSection(time: string, periodTimes: PeriodTime[]): number {
  const target = parseClockMinutes(time);
  if (target < 0 || periodTimes.length === 0) {
    return 0;
  }

  for (let i = 0; i < periodTimes.length; i++) {
    const start = parseClockMinutes(periodTimes[i].start);
    const end = parseClockMinutes(periodTimes[i].end);
    if (start < 0 || end <= start) {
      continue;
    }
    if (target <= end) {
      if (target <= start) {
        return i;
      }
      return i + ((target - start) / (end - start));
    }
  }

  return periodTimes.length;
}

function weekdayForDate(weekStartISO: string, dateISO: string): number {
  return dateDiffDays(weekStartISO, dateISO) + 1;
}

function courseToDisplayItem(course: CourseScheduleItem): ScheduleDisplayItem {
  return {
    kind: 'course',
    id: `course:${course.id}`,
    title: course.name,
    subtitle: course.classroom,
    dateISO: '',
    weekday: course.weekday,
    startSection: course.startSection - 1,
    endSection: course.endSection,
    colorKey: course.name,
    rawCourse: course,
  };
}

function examToDisplayItem(exam: ExamScheduleItem, weekStartISO: string, periodTimes: PeriodTime[]): ScheduleDisplayItem {
  return {
    kind: 'exam',
    id: `exam:${exam.id}`,
    title: `(考试)\n${exam.name}`,
    subtitle: exam.classroom,
    dateISO: exam.dateISO,
    weekday: weekdayForDate(weekStartISO, exam.dateISO),
    startSection: clockToSection(exam.beginTime, periodTimes),
    endSection: clockToSection(exam.endTime, periodTimes),
    colorKey: `exam:${exam.name}`,
    rawExam: exam,
  };
}

function customToDisplayItem(custom: CustomScheduleItem, weekStartISO: string, periodTimes: PeriodTime[]): ScheduleDisplayItem {
  return {
    kind: 'custom',
    id: `custom:${custom.id}`,
    title: custom.title,
    subtitle: custom.subtitle,
    dateISO: custom.dateISO,
    weekday: weekdayForDate(weekStartISO, custom.dateISO),
    startSection: clockToSection(custom.beginTime, periodTimes),
    endSection: clockToSection(custom.endTime, periodTimes),
    colorKey: `custom:${custom.title}`,
    rawCustom: custom,
  };
}

export function calendarEventsToCourseScheduleItems(
  events: CalendarEvent[],
  term: string,
  firstDayISO: string,
  periodTimes: PeriodTime[],
): CourseScheduleItem[] {
  const courses: CourseScheduleItem[] = [];
  for (let i = 0; i < events.length; i++) {
    const ev = events[i];
    const start = parseIcsDate(ev.dtstart);
    const end = parseIcsDate(ev.dtend);
    if (!start || !end) {
      continue;
    }
    const dateISO = formatDateISO(start);
    const week = computeWeekNumber(firstDayISO, dateISO);
    const weekday = start.getDay() === 0 ? 7 : start.getDay();
    const startClock = `${start.getHours() < 10 ? '0' : ''}${start.getHours()}:${start.getMinutes() < 10 ? '0' : ''}${start.getMinutes()}`;
    const endClock = `${end.getHours() < 10 ? '0' : ''}${end.getHours()}:${end.getMinutes() < 10 ? '0' : ''}${end.getMinutes()}`;
    const startSection = Math.floor(clockToSection(startClock, periodTimes)) + 1;
    const endSection = Math.ceil(clockToSection(endClock, periodTimes));
    const id = ev.uid && ev.uid.length > 0 ? ev.uid : `${dateISO}-${startClock}-${ev.summary || 'course'}-${i}`;

    courses.push({
      id,
      term,
      name: ev.summary || '(未命名)',
      teacher: '',
      classroom: ev.location || '',
      description: ev.description || '',
      weeks: `[${week}]`,
      weekday,
      startSection,
      endSection: endSection < startSection ? startSection : endSection,
      campus: '',
      number: '',
      credit: 0,
      hour: 0,
      type: '',
      category: '',
      department: '',
      rawUid: ev.uid,
    });
  }
  return courses;
}

function trimOverlaps(items: ScheduleDisplayItem[]): ScheduleDisplayItem[] {
  const sorted = items.slice().sort((a, b) => {
    if (a.weekday !== b.weekday) return a.weekday - b.weekday;
    if (a.startSection !== b.startSection) return a.startSection - b.startSection;
    return b.endSection - a.endSection;
  });
  const result: ScheduleDisplayItem[] = [];
  const dayEnds: number[] = [0, 0, 0, 0, 0, 0, 0, 0];

  for (const item of sorted) {
    if (item.weekday < 1 || item.weekday > 7) {
      continue;
    }
    let next = item;
    const lastEnd = dayEnds[item.weekday];
    if (next.startSection < lastEnd) {
      if (next.endSection <= lastEnd) {
        continue;
      }
      next = {
        kind: item.kind,
        id: item.id,
        title: item.title,
        subtitle: item.subtitle,
        dateISO: item.dateISO,
        weekday: item.weekday,
        startSection: lastEnd,
        endSection: item.endSection,
        colorKey: item.colorKey,
        rawCourse: item.rawCourse,
        rawExam: item.rawExam,
        rawCustom: item.rawCustom,
      };
    }
    if (next.endSection <= next.startSection + 0.05) {
      continue;
    }
    result.push(next);
    dayEnds[next.weekday] = next.endSection;
  }
  return result;
}

export function buildWeekScheduleDisplayItems(options: BuildWeekScheduleDisplayOptions): ScheduleDisplayItem[] {
  const items: ScheduleDisplayItem[] = [];
  const weekEndISO = addDaysISO(options.weekStartISO, 7);

  for (const course of options.courses) {
    if (courseContainsWeek(course.weeks, options.weekNumber)) {
      items.push(courseToDisplayItem(course));
    }
  }

  if (options.showExamInfo) {
    for (const exam of options.exams) {
      if (exam.dateISO >= options.weekStartISO && exam.dateISO < weekEndISO) {
        items.push(examToDisplayItem(exam, options.weekStartISO, options.periodTimes));
      }
    }
  }

  for (const custom of options.customSchedules) {
    if (custom.dateISO >= options.weekStartISO && custom.dateISO < weekEndISO) {
      items.push(customToDisplayItem(custom, options.weekStartISO, options.periodTimes));
    }
  }

  return trimOverlaps(items);
}

export class CourseScheduleRepository {
  private localStore: ScheduleLocalStore;
  private timetableRepository: TimetableRepository;

  constructor(deps: CourseScheduleRepositoryDeps) {
    this.localStore = deps.localStore;
    this.timetableRepository = deps.timetableRepository ?? new TimetableRepository();
  }

  loadCourses(): CourseScheduleItem[] {
    return this.localStore.loadCourses();
  }

  loadExams(): ExamScheduleItem[] {
    return this.localStore.loadExams();
  }

  loadCustomSchedules(): CustomScheduleItem[] {
    return this.localStore.loadCustomSchedules();
  }

  async refreshCourses(term: string, firstDayISO: string, periodTimes: PeriodTime[]): Promise<CourseScheduleItem[]> {
    const result = await this.timetableRepository.getScheduleEvents();
    const courses = calendarEventsToCourseScheduleItems(result.events, term, firstDayISO, periodTimes);
    this.localStore.saveCourses(courses);
    return courses;
  }

  async refreshExams(): Promise<ExamScheduleItem[]> {
    throw new Error('Exam schedule sync is not implemented for HarmonyOS school API yet.');
  }

}
