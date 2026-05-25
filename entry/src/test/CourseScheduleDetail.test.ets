import { describe, it, expect } from '@ohos/hypium';
import {
  buildCourseDetailRows,
  buildCustomScheduleDetailRows,
  buildExamDetailRows,
} from '../main/ets/services/schoolSchedule/ScheduleDetailModels';
import type { DetailRow } from '../main/ets/services/schoolSchedule/ScheduleDetailModels';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from '../main/ets/services/schoolSchedule/ScheduleModels';

function course(): CourseScheduleItem {
  return {
    id: 'c1',
    term: '2025-2026-2',
    name: '高等数学',
    teacher: '张老师',
    classroom: '理教楼 101',
    description: '线性代数部分',
    weeks: '[1][2][3]',
    weekday: 1,
    startSection: 1,
    endSection: 2,
    campus: '良乡',
    number: 'MATH101',
    credit: 3,
    hour: 48,
    type: '必修',
    category: '基础课',
    department: '数学学院',
  };
}

function exam(): ExamScheduleItem {
  return {
    id: 'e1',
    term: '2025-2026-2',
    name: '高等数学',
    courseId: 'c1',
    teacher: '张老师',
    classroom: '理教楼 202',
    dateISO: '2026-06-20',
    beginTime: '09:00',
    endTime: '11:00',
    examMode: '闭卷',
    seatId: 'A12',
  };
}

function custom(): CustomScheduleItem {
  return {
    id: 'm1',
    title: '答辩',
    subtitle: '中心楼',
    description: '准备 PPT',
    dateISO: '2026-05-25',
    beginTime: '14:00',
    endTime: '15:00',
    updatedAt: 1,
  };
}

export default function courseScheduleDetailTest() {
  describe('Course schedule detail rows', () => {
    it('builds Android-parity course detail rows', 0, () => {
      const rows = buildCourseDetailRows(course());

      expect(rows.length).assertEqual(11);
      expect(rows[0].label).assertEqual('教师');
      expect(rows[0].value).assertEqual('张老师');
      expect(rows[3].label).assertEqual('周次');
      expect(rows[3].value).assertEqual('[1][2][3]');
      expect(rows[6].label).assertEqual('学分/学时');
      expect(rows[6].value).assertEqual('3 / 48');
      expect(rows[10].label).assertEqual('开课院系');
      expect(rows[10].value).assertEqual('数学学院');
    });

    it('omits empty optional course fields', 0, () => {
      const item = course();
      item.teacher = '';
      item.description = '';
      item.credit = 0;
      item.hour = 0;
      item.type = '';

      const rows = buildCourseDetailRows(item);

      expect(rows.some((row: DetailRow) => row.label === '教师')).assertFalse();
      expect(rows.some((row: DetailRow) => row.label === '课程说明')).assertFalse();
      expect(rows.some((row: DetailRow) => row.label === '学分/学时')).assertFalse();
      expect(rows.some((row: DetailRow) => row.label === '类型')).assertFalse();
    });

    it('builds exam detail rows', 0, () => {
      const rows = buildExamDetailRows(exam());

      expect(rows.length).assertEqual(6);
      expect(rows[1].label).assertEqual('时间');
      expect(rows[1].value).assertEqual('09:00 - 11:00');
      expect(rows[5].label).assertEqual('座位号');
      expect(rows[5].value).assertEqual('A12');
    });

    it('builds custom schedule detail rows', 0, () => {
      const rows = buildCustomScheduleDetailRows(custom());

      expect(rows.length).assertEqual(4);
      expect(rows[2].label).assertEqual('时间');
      expect(rows[2].value).assertEqual('14:00 - 15:00');
      expect(rows[3].value).assertEqual('准备 PPT');
    });
  });
}
