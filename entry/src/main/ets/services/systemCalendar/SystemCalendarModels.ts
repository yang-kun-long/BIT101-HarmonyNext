import type {
  CustomScheduleItem,
  ExamScheduleItem,
} from '../schoolSchedule/ScheduleModels';

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
  exams: ExamScheduleItem[];
  customSchedules: CustomScheduleItem[];
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
  const includeExams = options.includeExams ?? true;
  const includeCustomSchedules = options.includeCustomSchedules ?? true;
  const out: SystemCalendarEventDraft[] = [];
  const seen: Record<string, boolean> = {};

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
