import type { PeriodTime } from '../jw/periodTimes';
import { CourseScheduleApiRepository } from '../jw/courseScheduleApiRepository';
import { ExamScheduleRepository } from '../jw/examScheduleRepository';
import { TimetableRepository } from '../jw/timetableRepository';
import type { CalendarEvent } from '../jw/timetableRepository';
import { makeCourseColorKey, pickTeacherFromScheduleText } from '../../utils/scheduleUtils';
import { normalizeSchoolTermCode } from './termUtils';
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
  localStore: CourseScheduleLocalStoreLike;
  courseSource?: CourseScheduleSource;
  timetableRepository?: TimetableRepository;
  examSource?: CourseExamSource;
}

export interface CourseScheduleLocalStoreLike {
  loadCourses(): CourseScheduleItem[];
  saveCourses(items: CourseScheduleItem[]): void;
  loadExams(): ExamScheduleItem[];
  saveExams(items: ExamScheduleItem[]): void;
  loadCustomSchedules(): CustomScheduleItem[];
}

export interface CourseExamSource {
  getExams(term: string): Promise<ExamScheduleItem[]>;
}

export interface CourseScheduleSource {
  getCourses(term: string): Promise<CourseScheduleItem[]>;
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

function normalizeLookupText(value: string): string {
  return value.trim().replace(/\s+/g, ' ').toLowerCase();
}

function isCodeLikeExamName(name: string, courseId: string): boolean {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return false;
  }
  if (courseId.trim().length > 0 && trimmed === courseId.trim()) {
    return true;
  }
  return /^[A-Za-z0-9_-]+$/.test(trimmed);
}

function pickTeacherFromLocalCourse(course: CourseScheduleItem): string {
  if (course.teacher.trim().length > 0) {
    return course.teacher.trim();
  }
  const labeled = pickTeacherFromScheduleText(course.description);
  if (labeled.length > 0) {
    return labeled;
  }
  const delimiter = course.description.indexOf('|');
  if (delimiter > 0) {
    return course.description.slice(0, delimiter).trim();
  }
  return '';
}

function rememberUniqueName(
  names: Record<string, string>,
  ambiguous: Record<string, boolean>,
  key: string,
  name: string,
): void {
  const normalizedKey = normalizeLookupText(key);
  const trimmedName = name.trim();
  if (normalizedKey.length === 0 || trimmedName.length === 0) {
    return;
  }
  const existing = names[normalizedKey];
  if (!existing) {
    names[normalizedKey] = trimmedName;
    return;
  }
  if (existing !== trimmedName) {
    ambiguous[normalizedKey] = true;
  }
}

function enrichedExamName(
  exam: ExamScheduleItem,
  courseNameByNumber: Record<string, string>,
  ambiguousCourseNumber: Record<string, boolean>,
  courseNameByTeacher: Record<string, string>,
  ambiguousTeacher: Record<string, boolean>,
): string {
  if (!isCodeLikeExamName(exam.name, exam.courseId)) {
    return exam.name;
  }

  const numberKey = normalizeLookupText(exam.courseId);
  if (numberKey.length > 0 && !ambiguousCourseNumber[numberKey]) {
    const nameByNumber = courseNameByNumber[numberKey];
    if (nameByNumber && nameByNumber.length > 0) {
      return nameByNumber;
    }
  }

  const teacherKey = normalizeLookupText(exam.teacher);
  if (teacherKey.length > 0 && !ambiguousTeacher[teacherKey]) {
    const nameByTeacher = courseNameByTeacher[teacherKey];
    if (nameByTeacher && nameByTeacher.length > 0) {
      return nameByTeacher;
    }
  }

  return exam.name;
}

function enrichExamNamesWithCourses(
  exams: ExamScheduleItem[],
  courses: CourseScheduleItem[],
  term: string,
): ExamScheduleItem[] {
  const normalizedTerm = normalizeSchoolTermCode(term);
  const courseNameByNumber: Record<string, string> = {};
  const ambiguousCourseNumber: Record<string, boolean> = {};
  const courseNameByTeacher: Record<string, string> = {};
  const ambiguousTeacher: Record<string, boolean> = {};

  for (const course of courses) {
    if (normalizedTerm.length > 0 && normalizeSchoolTermCode(course.term) !== normalizedTerm) {
      continue;
    }
    rememberUniqueName(courseNameByNumber, ambiguousCourseNumber, course.number, course.name);
    rememberUniqueName(courseNameByTeacher, ambiguousTeacher, pickTeacherFromLocalCourse(course), course.name);
  }

  const out: ExamScheduleItem[] = [];
  for (const exam of exams) {
    const nextName = enrichedExamName(
      exam,
      courseNameByNumber,
      ambiguousCourseNumber,
      courseNameByTeacher,
      ambiguousTeacher,
    );
    out.push({
      id: exam.id,
      term: exam.term,
      name: nextName,
      courseId: exam.courseId,
      teacher: exam.teacher,
      classroom: exam.classroom,
      dateISO: exam.dateISO,
      beginTime: exam.beginTime,
      endTime: exam.endTime,
      examMode: exam.examMode,
      seatId: exam.seatId,
    });
  }
  return out;
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
    colorKey: makeCourseColorKey(course.name, course.teacher),
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
      teacher: pickTeacherFromScheduleText(ev.description),
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
  private localStore: CourseScheduleLocalStoreLike;
  private courseSource: CourseScheduleSource | null;
  private timetableRepository: TimetableRepository | null;
  private examSource: CourseExamSource;

  constructor(deps: CourseScheduleRepositoryDeps) {
    this.localStore = deps.localStore;
    this.courseSource = deps.courseSource ?? (deps.timetableRepository ? null : new CourseScheduleApiRepository());
    this.timetableRepository = deps.timetableRepository ?? null;
    this.examSource = deps.examSource ?? new ExamScheduleRepository();
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
    if (this.courseSource) {
      const trimmed = term.trim();
      if (trimmed.length === 0) {
        throw new Error('term is empty');
      }
      const courses = await this.courseSource.getCourses(trimmed);
      this.localStore.saveCourses(courses);
      return courses;
    }
    if (!this.timetableRepository) {
      throw new Error('course source is not configured');
    }
    const result = await this.timetableRepository.getScheduleEvents();
    const courses = calendarEventsToCourseScheduleItems(result.events, term, firstDayISO, periodTimes);
    this.localStore.saveCourses(courses);
    return courses;
  }

  async refreshExams(term: string): Promise<ExamScheduleItem[]> {
    const trimmed = term.trim();
    if (trimmed.length === 0) {
      throw new Error('term is empty');
    }
    const exams = await this.examSource.getExams(trimmed);
    const enriched = enrichExamNamesWithCourses(exams, this.localStore.loadCourses(), trimmed);
    this.localStore.saveExams(enriched);
    return enriched;
  }

}
