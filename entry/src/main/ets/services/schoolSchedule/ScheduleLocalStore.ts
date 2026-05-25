import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { Logger } from '../../utils/Logger';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from './ScheduleModels';
import { normalizeSchoolTermCode } from './termUtils';

export interface ScheduleFilesCtx {
  filesDir: string;
}

const ROOT_DIR = 'bit101/school_schedule';
const COURSES_FILE = 'courses.json';
const EXAMS_FILE = 'exams.json';
const CUSTOM_FILE = 'custom_schedules.json';

export interface CustomScheduleFormInput {
  title: string;
  subtitle: string;
  description: string;
  dateISO: string;
  beginTime: string;
  endTime: string;
  existingId?: string;
  now: number;
}

function asRecord(value: Object | null): Record<string, Object> | null {
  if (!value || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, Object>;
}

function readString(record: Record<string, Object>, key: string): string {
  const value = record[key];
  return typeof value === 'string' ? value : '';
}

function readNumber(record: Record<string, Object>, key: string): number {
  const value = record[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function isValidClock(value: string): boolean {
  return /^([01]\d|2[0-3]):([0-5]\d)$/.test(value);
}

function isValidDateISO(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function clockMinutes(value: string): number {
  if (!isValidClock(value)) {
    return -1;
  }
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));
}

function parseJsonArray(text: string): Object[] {
  try {
    const parsed = JSON.parse(text) as Object;
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function parseCourse(value: Object): CourseScheduleItem | null {
  const record = asRecord(value);
  if (!record) return null;
  const id = readString(record, 'id');
  const name = readString(record, 'name');
  const weekday = readNumber(record, 'weekday');
  const startSection = readNumber(record, 'startSection');
  const endSection = readNumber(record, 'endSection');
  if (id.length === 0 || name.length === 0 || weekday < 1 || weekday > 7 || startSection < 1 || endSection < startSection) {
    return null;
  }
  return {
    id,
    term: normalizeSchoolTermCode(readString(record, 'term')),
    name,
    teacher: readString(record, 'teacher'),
    classroom: readString(record, 'classroom'),
    description: readString(record, 'description'),
    weeks: readString(record, 'weeks'),
    weekday,
    startSection,
    endSection,
    campus: readString(record, 'campus'),
    number: readString(record, 'number'),
    credit: readNumber(record, 'credit'),
    hour: readNumber(record, 'hour'),
    type: readString(record, 'type'),
    category: readString(record, 'category'),
    department: readString(record, 'department'),
    rawUid: readString(record, 'rawUid'),
  };
}

function parseExam(value: Object): ExamScheduleItem | null {
  const record = asRecord(value);
  if (!record) return null;
  const id = readString(record, 'id');
  const name = readString(record, 'name');
  const dateISO = readString(record, 'dateISO');
  const beginTime = readString(record, 'beginTime');
  const endTime = readString(record, 'endTime');
  if (id.length === 0 || name.length === 0 || !isValidDateISO(dateISO) || !isValidClock(beginTime) || !isValidClock(endTime)) {
    return null;
  }
  return {
    id,
    term: normalizeSchoolTermCode(readString(record, 'term')),
    name,
    courseId: readString(record, 'courseId'),
    teacher: readString(record, 'teacher'),
    classroom: readString(record, 'classroom'),
    dateISO,
    beginTime,
    endTime,
    examMode: readString(record, 'examMode'),
    seatId: readString(record, 'seatId'),
  };
}

function parseCustom(value: Object): CustomScheduleItem | null {
  const record = asRecord(value);
  if (!record) return null;
  const id = readString(record, 'id');
  const title = readString(record, 'title');
  const dateISO = readString(record, 'dateISO');
  const beginTime = readString(record, 'beginTime');
  const endTime = readString(record, 'endTime');
  if (id.length === 0 || title.length === 0 || !isValidDateISO(dateISO) || !isValidClock(beginTime) || !isValidClock(endTime)) {
    return null;
  }
  return {
    id,
    title,
    subtitle: readString(record, 'subtitle'),
    description: readString(record, 'description'),
    dateISO,
    beginTime,
    endTime,
    updatedAt: readNumber(record, 'updatedAt'),
  };
}

export function parseCourseScheduleItemsJson(text: string): CourseScheduleItem[] {
  const out: CourseScheduleItem[] = [];
  for (const value of parseJsonArray(text)) {
    const item = parseCourse(value);
    if (item) out.push(item);
  }
  return out;
}

export function parseExamScheduleItemsJson(text: string): ExamScheduleItem[] {
  const out: ExamScheduleItem[] = [];
  for (const value of parseJsonArray(text)) {
    const item = parseExam(value);
    if (item) out.push(item);
  }
  return out;
}

export function parseCustomScheduleItemsJson(text: string): CustomScheduleItem[] {
  const out: CustomScheduleItem[] = [];
  for (const value of parseJsonArray(text)) {
    const item = parseCustom(value);
    if (item) out.push(item);
  }
  return out;
}

export function upsertCustomSchedule(items: CustomScheduleItem[], item: CustomScheduleItem): CustomScheduleItem[] {
  const out: CustomScheduleItem[] = [];
  let updated = false;
  for (const existing of items) {
    if (existing.id === item.id) {
      out.push(item);
      updated = true;
    } else {
      out.push(existing);
    }
  }
  if (!updated) {
    out.push(item);
  }
  return out;
}

export function deleteCustomSchedule(items: CustomScheduleItem[], id: string): CustomScheduleItem[] {
  return items.filter((item) => item.id !== id);
}

export function createValidatedCustomSchedule(input: CustomScheduleFormInput): CustomScheduleItem | null {
  const title = input.title.trim();
  const subtitle = input.subtitle.trim();
  const description = input.description.trim();
  const dateISO = input.dateISO.trim();
  const beginTime = input.beginTime.trim();
  const endTime = input.endTime.trim();
  const begin = clockMinutes(beginTime);
  const end = clockMinutes(endTime);

  if (title.length === 0 || !isValidDateISO(dateISO) || begin < 0 || end <= begin) {
    return null;
  }

  const existingId = input.existingId ? input.existingId.trim() : '';
  return {
    id: existingId.length > 0 ? existingId : `custom-${input.now}`,
    title,
    subtitle,
    description,
    dateISO,
    beginTime,
    endTime,
    updatedAt: input.now,
  };
}

export class ScheduleLocalStore {
  private logger = new Logger('ScheduleLocalStore');
  private readonly rootDir: string;

  constructor(ctx: ScheduleFilesCtx) {
    const base = ctx.filesDir.endsWith('/') ? ctx.filesDir.slice(0, ctx.filesDir.length - 1) : ctx.filesDir;
    const bit101Dir = this.join(base, 'bit101');
    this.ensureDir(bit101Dir);
    this.rootDir = this.join(bit101Dir, 'school_schedule');
    this.ensureDir(this.rootDir);
  }

  private join(a: string, b: string): string {
    return a.endsWith('/') ? `${a}${b}` : `${a}/${b}`;
  }

  private exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (_) {
      return false;
    }
  }

  private ensureDir(dir: string): void {
    if (this.exists(dir)) {
      return;
    }
    try {
      fs.mkdirSync(dir);
    } catch (error) {
      this.logger.warn('mkdir failed:', dir, error);
    }
  }

  private path(fileName: string): string {
    return this.join(this.rootDir, fileName);
  }

  private readText(path: string): string {
    if (!this.exists(path)) {
      return '[]';
    }
    try {
      return fs.readTextSync(path);
    } catch (error) {
      this.logger.warn('read failed:', path, error);
      return '[]';
    }
  }

  private writeJson(path: string, value: Object): void {
    try {
      const encoder = new util.TextEncoder();
      const bytes = encoder.encodeInto(JSON.stringify(value));
      const fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(fd.fd, bytes.buffer);
        fs.fsyncSync(fd.fd);
      } finally {
        try {
          fs.closeSync(fd);
        } catch (_) {
        }
      }
    } catch (error) {
      this.logger.error('write failed:', path, error);
    }
  }

  loadCourses(): CourseScheduleItem[] {
    return parseCourseScheduleItemsJson(this.readText(this.path(COURSES_FILE)));
  }

  saveCourses(items: CourseScheduleItem[]): void {
    this.writeJson(this.path(COURSES_FILE), items);
  }

  loadExams(): ExamScheduleItem[] {
    return parseExamScheduleItemsJson(this.readText(this.path(EXAMS_FILE)));
  }

  saveExams(items: ExamScheduleItem[]): void {
    this.writeJson(this.path(EXAMS_FILE), items);
  }

  loadCustomSchedules(): CustomScheduleItem[] {
    return parseCustomScheduleItemsJson(this.readText(this.path(CUSTOM_FILE)));
  }

  saveCustomSchedules(items: CustomScheduleItem[]): void {
    this.writeJson(this.path(CUSTOM_FILE), items);
  }
}
