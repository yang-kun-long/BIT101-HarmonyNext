import { describe, it, expect } from '@ohos/hypium';
import {
  buildWeekScheduleDisplayItems,
  calendarEventsToCourseScheduleItems,
  clockToSection,
  computeWeekNumber,
  courseContainsWeek,
} from '../main/ets/services/schoolSchedule/CourseScheduleRepository';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
  ScheduleDisplayItem,
} from '../main/ets/services/schoolSchedule/ScheduleModels';
import type { PeriodTime } from '../main/ets/services/jw/periodTimes';
import type { CalendarEvent } from '../main/ets/services/jw/timetableRepository';

function course(id: string, weekday: number, start: number, end: number, weeks: string): CourseScheduleItem {
  return {
    id,
    term: '2025-2026-2',
    name: `Course ${id}`,
    teacher: '',
    classroom: '101',
    description: '',
    weeks,
    weekday,
    startSection: start,
    endSection: end,
    campus: '',
    number: '',
    credit: 0,
    hour: 0,
    type: '',
    category: '',
    department: '',
  };
}

function exam(id: string, dateISO: string, beginTime: string, endTime: string): ExamScheduleItem {
  return {
    id,
    term: '2025-2026-2',
    name: `Exam ${id}`,
    courseId: '',
    teacher: '',
    classroom: '202',
    dateISO,
    beginTime,
    endTime,
    examMode: '',
    seatId: '',
  };
}

function custom(id: string, dateISO: string, beginTime: string, endTime: string): CustomScheduleItem {
  return {
    id,
    title: `Custom ${id}`,
    subtitle: 'manual',
    description: '',
    dateISO,
    beginTime,
    endTime,
    updatedAt: 1,
  };
}

export default function courseScheduleRepositoryTest() {
  describe('Course schedule repository helpers', () => {
    const periodTimes: PeriodTime[] = [
      { start: '08:00', end: '08:45' },
      { start: '08:50', end: '09:35' },
      { start: '09:55', end: '10:40' },
    ];

    it('computes current week from first day', 0, () => {
      expect(computeWeekNumber('2026-02-23', '2026-02-23')).assertEqual(1);
      expect(computeWeekNumber('2026-02-23', '2026-03-01')).assertEqual(1);
      expect(computeWeekNumber('2026-02-23', '2026-03-02')).assertEqual(2);
      expect(computeWeekNumber('', '2026-03-02')).assertEqual(1);
    });

    it('filters Android-style week markers', 0, () => {
      expect(courseContainsWeek('[1][2][10]', 2)).assertTrue();
      expect(courseContainsWeek('[1][2][10]', 3)).assertFalse();
      expect(courseContainsWeek('', 1)).assertFalse();
    });

    it('converts clock time to fractional section', 0, () => {
      expect(clockToSection('08:00', periodTimes)).assertEqual(0);
      expect(clockToSection('08:45', periodTimes)).assertEqual(1);
      expect(clockToSection('08:50', periodTimes)).assertEqual(1);
      expect(clockToSection('09:12', periodTimes)).assertEqual(1.488888888888889);
      expect(clockToSection('10:40', periodTimes)).assertEqual(3);
    });

    it('builds week display items from courses exams and custom schedules', 0, () => {
      const items: ScheduleDisplayItem[] = buildWeekScheduleDisplayItems({
        weekStartISO: '2026-02-23',
        weekNumber: 1,
        periodTimes,
        showExamInfo: true,
        courses: [course('c1', 1, 1, 2, '[1]'), course('c2', 2, 1, 2, '[2]')],
        exams: [exam('e1', '2026-02-24', '08:50', '09:35')],
        customSchedules: [custom('m1', '2026-02-25', '09:55', '10:40')],
      });

      expect(items.length).assertEqual(3);
      expect(items[0].kind).assertEqual('course');
      expect(items[1].kind).assertEqual('exam');
      expect(items[1].weekday).assertEqual(2);
      expect(items[2].kind).assertEqual('custom');
      expect(items[2].startSection).assertEqual(2);
      expect(items[2].endSection).assertEqual(3);
    });

    it('trims overlapping display items within a day', 0, () => {
      const items: ScheduleDisplayItem[] = buildWeekScheduleDisplayItems({
        weekStartISO: '2026-02-23',
        weekNumber: 1,
        periodTimes,
        showExamInfo: true,
        courses: [course('c1', 1, 1, 3, '[1]'), course('c2', 1, 2, 3, '[1]')],
        exams: [],
        customSchedules: [],
      });

      expect(items.length).assertEqual(1);
      expect(items[0].id).assertEqual('course:c1');
    });

    it('hides exams when exam display is disabled', 0, () => {
      const items: ScheduleDisplayItem[] = buildWeekScheduleDisplayItems({
        weekStartISO: '2026-02-23',
        weekNumber: 1,
        periodTimes,
        showExamInfo: false,
        courses: [],
        exams: [exam('e1', '2026-02-24', '08:50', '09:35')],
        customSchedules: [],
      });

      expect(items.length).assertEqual(0);
    });

    it('converts calendar events to local course items with week and section markers', 0, () => {
      const events: CalendarEvent[] = [{
        uid: 'ics-1',
        summary: 'Math',
        location: 'Room 101',
        description: 'Teacher A',
        dtstart: '20260303T085000',
        dtend: '20260303T093500',
      }];

      const courses: CourseScheduleItem[] = calendarEventsToCourseScheduleItems(
        events,
        '2025-2026-2',
        '2026-02-23',
        periodTimes,
      );

      expect(courses.length).assertEqual(1);
      expect(courses[0].id).assertEqual('ics-1');
      expect(courses[0].weeks).assertEqual('[2]');
      expect(courses[0].weekday).assertEqual(2);
      expect(courses[0].startSection).assertEqual(2);
      expect(courses[0].endSection).assertEqual(2);
    });
  });
}
