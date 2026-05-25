import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from './ScheduleModels';

export interface DetailRow {
  label: string;
  value: string;
}

function hasText(value: string): boolean {
  return value.trim().length > 0;
}

function pushTextRow(rows: DetailRow[], label: string, value: string): void {
  const text = value.trim();
  if (text.length > 0) {
    rows.push({ label, value: text });
  }
}

function formatNumber(value: number): string {
  if (Math.floor(value) === value) {
    return value.toString();
  }
  return value.toFixed(1);
}

function formatSectionRange(startSection: number, endSection: number): string {
  if (startSection <= 0 || endSection <= 0) {
    return '';
  }
  if (startSection === endSection) {
    return `第 ${startSection} 节`;
  }
  return `第 ${startSection} - ${endSection} 节`;
}

function formatCreditHour(credit: number, hour: number): string {
  if (credit <= 0 && hour <= 0) {
    return '';
  }
  if (credit > 0 && hour > 0) {
    return `${formatNumber(credit)} / ${formatNumber(hour)}`;
  }
  if (credit > 0) {
    return formatNumber(credit);
  }
  return formatNumber(hour);
}

function formatTimeRange(beginTime: string, endTime: string): string {
  const begin = beginTime.trim();
  const end = endTime.trim();
  if (begin.length > 0 && end.length > 0) {
    return `${begin} - ${end}`;
  }
  if (begin.length > 0) {
    return begin;
  }
  return end;
}

export function buildCourseDetailRows(item: CourseScheduleItem): DetailRow[] {
  const rows: DetailRow[] = [];
  pushTextRow(rows, '教师', item.teacher);
  pushTextRow(rows, '地点', item.classroom);
  pushTextRow(rows, '课程说明', item.description);
  pushTextRow(rows, '周次', item.weeks);
  pushTextRow(rows, '节次', formatSectionRange(item.startSection, item.endSection));
  pushTextRow(rows, '校区', item.campus);
  pushTextRow(rows, '学分/学时', formatCreditHour(item.credit, item.hour));
  pushTextRow(rows, '课程编号', item.number);
  pushTextRow(rows, '类型', item.type);
  pushTextRow(rows, '类别', item.category);
  pushTextRow(rows, '开课院系', item.department);
  return rows;
}

export function buildExamDetailRows(item: ExamScheduleItem): DetailRow[] {
  const rows: DetailRow[] = [];
  pushTextRow(rows, '日期', item.dateISO);
  pushTextRow(rows, '时间', formatTimeRange(item.beginTime, item.endTime));
  pushTextRow(rows, '地点', item.classroom);
  pushTextRow(rows, '教师', item.teacher);
  pushTextRow(rows, '考试方式', item.examMode);
  pushTextRow(rows, '座位号', item.seatId);
  return rows;
}

export function buildCustomScheduleDetailRows(item: CustomScheduleItem): DetailRow[] {
  const rows: DetailRow[] = [];
  pushTextRow(rows, '副标题', item.subtitle);
  pushTextRow(rows, '日期', item.dateISO);
  pushTextRow(rows, '时间', formatTimeRange(item.beginTime, item.endTime));
  pushTextRow(rows, '备注', item.description);
  return rows;
}

export function hasDetailRows(rows: DetailRow[]): boolean {
  return rows.length > 0 && rows.some((row: DetailRow) => hasText(row.value));
}
