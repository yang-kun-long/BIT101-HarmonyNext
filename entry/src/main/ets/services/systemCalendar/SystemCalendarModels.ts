import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from '../schoolSchedule/ScheduleModels';
import type { PeriodTime } from '../jw/periodTimes';

export interface SystemCalendarEventDraft {
  identifier: string;
  title: string;
  description: string;
  startTime: number;
  endTime: number;
  location: string;
  reminderMinutes: number[];
}

export interface BuildScheduleCalendarEventDraftsOptions {
  courses?: CourseScheduleItem[];
  exams: ExamScheduleItem[];
  customSchedules: CustomScheduleItem[];
  firstDayISO?: string;
  periodTimes?: PeriodTime[];
  includeCourses?: boolean;
  includeExams?: boolean;
  includeCustomSchedules?: boolean;
}

export interface SystemCalendarSyncResult {
  total: number;
  created: number;
  skipped: number;
  failed: number;
}

function parseClockMinutes(value: string): number {
  const match: RegExpExecArray | null = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!match) {
    return -1;
  }
  return Number(match[1]) * 60 + Number(match[2]);
}

function parseLocalDateTimeMs(dateISO: string, clock: string): number {
  const dateMatch: RegExpExecArray | null = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateISO.trim());
  const minutes = parseClockMinutes(clock);
  if (!dateMatch || minutes < 0) {
    return -1;
  }
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  return new Date(Number(dateMatch[1]), Number(dateMatch[2]) - 1, Number(dateMatch[3]), hour, minute, 0).getTime();
}

function parseLocalDateMs(dateISO: string): number {
  const dateMatch: RegExpExecArray | null = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateISO.trim());
  if (!dateMatch) {
    return -1;
  }
  return new Date(Number(dateMatch[1]), Number(dateMatch[2]) - 1, Number(dateMatch[3]), 0, 0, 0).getTime();
}

function dateMsToISO(ms: number): string {
  const date = new Date(ms);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const mm = month < 10 ? `0${month}` : `${month}`;
  const dd = day < 10 ? `0${day}` : `${day}`;
  return `${date.getFullYear()}-${mm}-${dd}`;
}

function pushLine(lines: string[], label: string, value: string): void {
  const trimmed = value.trim();
  if (trimmed.length > 0) {
    lines.push(`${label}：${trimmed}`);
  }
}

function examDescription(exam: ExamScheduleItem): string {
  const lines: string[] = [];
  pushLine(lines, '课程号', exam.courseId);
  pushLine(lines, '教师', exam.teacher);
  pushLine(lines, '考试方式', exam.examMode);
  pushLine(lines, '座位号', exam.seatId);
  pushLine(lines, '学期', exam.term);
  return lines.join('\n');
}

function customDescription(item: CustomScheduleItem): string {
  const lines: string[] = [];
  pushLine(lines, '备注', item.description);
  return lines.join('\n');
}

function courseDescription(course: CourseScheduleItem, week: number): string {
  const lines: string[] = [];
  pushLine(lines, '周次', `第 ${week} 周`);
  pushLine(lines, '教师', course.teacher);
  pushLine(lines, '课程号', course.number);
  pushLine(lines, '校区', course.campus);
  pushLine(lines, '课程说明', course.description);
  pushLine(lines, '类型', course.type);
  pushLine(lines, '类别', course.category);
  pushLine(lines, '开课院系', course.department);
  return lines.join('\n');
}

function parseCourseWeeks(weeks: string): number[] {
  const result: number[] = [];
  const seen: Record<string, boolean> = {};
  const regex = /\[(\d+)\]/g;
  let match: RegExpExecArray | null = regex.exec(weeks);
  while (match !== null) {
    const week = Number(match[1]);
    const key = `${week}`;
    if (week > 0 && !seen[key]) {
      seen[key] = true;
      result.push(week);
    }
    match = regex.exec(weeks);
  }
  return result.sort((a, b) => a - b);
}

function courseDateISO(firstDayISO: string, week: number, weekday: number): string {
  const firstDayMs = parseLocalDateMs(firstDayISO);
  if (firstDayMs < 0 || week < 1 || weekday < 1 || weekday > 7) {
    return '';
  }
  const offsetDays = (week - 1) * 7 + (weekday - 1);
  return dateMsToISO(firstDayMs + offsetDays * 86400000);
}

function periodClock(periodTimes: PeriodTime[], section: number, edge: 'start' | 'end'): string {
  if (section < 1 || section > periodTimes.length) {
    return '';
  }
  return edge === 'start' ? periodTimes[section - 1].start : periodTimes[section - 1].end;
}

function buildCourseDrafts(
  course: CourseScheduleItem,
  firstDayISO: string,
  periodTimes: PeriodTime[],
): SystemCalendarEventDraft[] {
  const out: SystemCalendarEventDraft[] = [];
  if (firstDayISO.length === 0 || periodTimes.length === 0 || course.weekday < 1 || course.weekday > 7) {
    return out;
  }
  if (course.startSection < 1 || course.endSection < course.startSection || course.endSection > periodTimes.length) {
    return out;
  }
  const startClock = periodClock(periodTimes, course.startSection, 'start');
  const endClock = periodClock(periodTimes, course.endSection, 'end');
  if (startClock.length === 0 || endClock.length === 0) {
    return out;
  }

  for (const week of parseCourseWeeks(course.weeks)) {
    const dateISO = courseDateISO(firstDayISO, week, course.weekday);
    if (dateISO.length === 0) {
      continue;
    }
    const startTime = parseLocalDateTimeMs(dateISO, startClock);
    const endTime = parseLocalDateTimeMs(dateISO, endClock);
    if (startTime < 0 || endTime <= startTime) {
      continue;
    }
    out.push({
      identifier: `bit101:course:${course.term}:${course.id}:w${week}:d${course.weekday}:s${course.startSection}-${course.endSection}`,
      title: course.name,
      description: courseDescription(course, week),
      startTime,
      endTime,
      location: course.classroom,
      reminderMinutes: [10],
    });
  }

  return out;
}

function buildExamDraft(exam: ExamScheduleItem): SystemCalendarEventDraft | null {
  const startTime = parseLocalDateTimeMs(exam.dateISO, exam.beginTime);
  const endTime = parseLocalDateTimeMs(exam.dateISO, exam.endTime);
  if (startTime < 0 || endTime <= startTime) {
    return null;
  }
  return {
    identifier: `bit101:exam:${exam.id}`,
    title: `(考试) ${exam.name}`,
    description: examDescription(exam),
    startTime,
    endTime,
    location: exam.classroom,
    reminderMinutes: [60],
  };
}

function buildCustomDraft(item: CustomScheduleItem): SystemCalendarEventDraft | null {
  const startTime = parseLocalDateTimeMs(item.dateISO, item.beginTime);
  const endTime = parseLocalDateTimeMs(item.dateISO, item.endTime);
  if (startTime < 0 || endTime <= startTime) {
    return null;
  }
  return {
    identifier: `bit101:custom:${item.id}`,
    title: item.title,
    description: customDescription(item),
    startTime,
    endTime,
    location: item.subtitle,
    reminderMinutes: [10],
  };
}

function pushUniqueDraft(
  out: SystemCalendarEventDraft[],
  seen: Record<string, boolean>,
  draft: SystemCalendarEventDraft | null,
): void {
  if (!draft || seen[draft.identifier]) {
    return;
  }
  seen[draft.identifier] = true;
  out.push(draft);
}

export function buildScheduleCalendarEventDrafts(
  options: BuildScheduleCalendarEventDraftsOptions,
): SystemCalendarEventDraft[] {
  const includeCourses = options.includeCourses ?? true;
  const includeExams = options.includeExams ?? true;
  const includeCustomSchedules = options.includeCustomSchedules ?? true;
  const out: SystemCalendarEventDraft[] = [];
  const seen: Record<string, boolean> = {};

  if (includeCourses && options.courses && options.firstDayISO && options.periodTimes) {
    for (const course of options.courses) {
      for (const draft of buildCourseDrafts(course, options.firstDayISO, options.periodTimes)) {
        pushUniqueDraft(out, seen, draft);
      }
    }
  }

  if (includeExams) {
    for (const exam of options.exams) {
      pushUniqueDraft(out, seen, buildExamDraft(exam));
    }
  }

  if (includeCustomSchedules) {
    for (const item of options.customSchedules) {
      pushUniqueDraft(out, seen, buildCustomDraft(item));
    }
  }

  return out.sort((a, b) => {
    if (a.startTime !== b.startTime) {
      return a.startTime - b.startTime;
    }
    return a.identifier.localeCompare(b.identifier);
  });
}

export function formatSystemCalendarSyncMessage(result: SystemCalendarSyncResult): string {
  if (result.total === 0) {
    return '没有可写入的考试或自定义日程';
  }
  const parts: string[] = [];
  if (result.created > 0) {
    parts.push(`已写入 ${result.created} 条`);
  }
  if (result.skipped > 0) {
    parts.push(`跳过 ${result.skipped} 条已存在日程`);
  }
  if (result.failed > 0) {
    parts.push(`失败 ${result.failed} 条`);
  }
  if (parts.length === 0) {
    return '没有写入新的日程';
  }
  return parts.join('，');
}
