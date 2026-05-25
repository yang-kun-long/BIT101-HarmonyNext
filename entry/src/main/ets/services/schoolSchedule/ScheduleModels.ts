export interface CourseScheduleItem {
  id: string;
  term: string;
  name: string;
  teacher: string;
  classroom: string;
  description: string;
  weeks: string;
  weekday: number;
  startSection: number;
  endSection: number;
  campus: string;
  number: string;
  credit: number;
  hour: number;
  type: string;
  category: string;
  department: string;
  rawUid?: string;
}

export interface ExamScheduleItem {
  id: string;
  term: string;
  name: string;
  courseId: string;
  teacher: string;
  classroom: string;
  dateISO: string;
  beginTime: string;
  endTime: string;
  examMode: string;
  seatId: string;
}

export interface CustomScheduleItem {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  dateISO: string;
  beginTime: string;
  endTime: string;
  updatedAt: number;
}

export type ScheduleDisplayKind = 'course' | 'exam' | 'custom';

export interface ScheduleDisplayItem {
  kind: ScheduleDisplayKind;
  id: string;
  title: string;
  subtitle: string;
  dateISO: string;
  weekday: number;
  startSection: number;
  endSection: number;
  colorKey: string;
  rawCourse?: CourseScheduleItem;
  rawExam?: ExamScheduleItem;
  rawCustom?: CustomScheduleItem;
}
