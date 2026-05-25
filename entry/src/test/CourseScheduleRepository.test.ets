import { describe, it, expect } from '@ohos/hypium';
import {
  buildWeekScheduleDisplayItems,
  calendarEventsToCourseScheduleItems,
  clockToSection,
  computeWeekNumber,
  CourseExamSource,
  CourseScheduleLocalStoreLike,
  CourseScheduleRepository,
  courseContainsWeek,
} from '../main/ets/services/schoolSchedule/CourseScheduleRepository';
import {
  getExamBaseUrlForMode,
  mapExamApiRows,
  parseExamTimeRange,
} from '../main/ets/services/jw/examScheduleRepository';
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

class MemoryScheduleStore implements CourseScheduleLocalStoreLike {
  courses: CourseScheduleItem[] = [];
  exams: ExamScheduleItem[] = [];
  customSchedules: CustomScheduleItem[] = [];

  loadCourses(): CourseScheduleItem[] {
    return this.courses;
  }

  saveCourses(items: CourseScheduleItem[]): void {
    this.courses = items;
  }

  loadExams(): ExamScheduleItem[] {
    return this.exams;
  }

  saveExams(items: ExamScheduleItem[]): void {
    this.exams = items;
  }

  loadCustomSchedules(): CustomScheduleItem[] {
    return this.customSchedules;
  }
}

class FakeExamSource implements CourseExamSource {
  requestedTerm: string = '';
  exams: ExamScheduleItem[] = [];

  async getExams(term: string): Promise<ExamScheduleItem[]> {
    this.requestedTerm = term;
    return this.exams;
  }
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

    it('uses legacy course color key for local course display items', 0, () => {
      const localCourse: CourseScheduleItem = course('math', 1, 1, 2, '[1]');
      localCourse.name = ' Advanced  Math ';
      localCourse.teacher = ' Alice  Zhang ';

      const items: ScheduleDisplayItem[] = buildWeekScheduleDisplayItems({
        weekStartISO: '2026-02-23',
        weekNumber: 1,
        periodTimes,
        showExamInfo: false,
        courses: [localCourse],
        exams: [],
        customSchedules: [],
      });

      expect(items.length).assertEqual(1);
      expect(items[0].colorKey).assertEqual('advanced math|alice zhang');
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

    it('extracts teacher from calendar event descriptions for color keys', 0, () => {
      const events: CalendarEvent[] = [{
        uid: 'ics-2',
        summary: 'Advanced Math',
        location: 'Room 101',
        description: '教师：Alice Zhang\n教学班：01',
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
      expect(courses[0].teacher).assertEqual('Alice Zhang');
    });

    it('maps Android exam API rows to local exam items', 0, () => {
      expect(getExamBaseUrlForMode('inner')).assertEqual('https://jxzxehallapp.bit.edu.cn');
      expect(getExamBaseUrlForMode('webvpn').indexOf('https://webvpn.bit.edu.cn/https/')).assertEqual(0);

      const range = parseExamTimeRange('2026-06-30 星期二 09:00-11:00(120分钟)');
      expect(range.beginTime).assertEqual('09:00');
      expect(range.endTime).assertEqual('11:00');

      const exams: ExamScheduleItem[] = mapExamApiRows([{
        JASMC: '良乡-综教A101',
        KSSJMS: '2026-06-30 星期二 09:00-11:00(120分钟)',
        KSRQ: '2026-06-30 00:00:00',
        ZWH: '12',
        KSMC: '集中考试',
        XNXQDM_DISPLAY: '2025-2026-2',
        KCM: '[MATH1001]高等数学',
        ZJJSXM: '张三',
        KCH: 'MATH1001',
      }], '2025-2026-2');

      expect(exams.length).assertEqual(1);
      expect(exams[0].id).assertEqual('2025-2026-2:MATH1001:2026-06-30:09:00:11:00');
      expect(exams[0].name).assertEqual('高等数学');
      expect(exams[0].courseId).assertEqual('MATH1001');
      expect(exams[0].teacher).assertEqual('张三');
      expect(exams[0].classroom).assertEqual('良乡-综教A101');
      expect(exams[0].examMode).assertEqual('集中考试');
      expect(exams[0].seatId).assertEqual('12');
    });

    it('keeps requested term when exam API returns display term text', 0, () => {
      const exams: ExamScheduleItem[] = mapExamApiRows([{
        JASMC: '理教楼107',
        KSSJMS: '2026-05-16 星期六 10:10-12:10(120分钟)',
        KSRQ: '2026-05-16 00:00:00',
        ZWH: '18',
        KSMC: '(本)分散考试',
        XNXQDM_DISPLAY: '2025-2026学年 2学期',
        KCM: '100191034',
        ZJJSXM: '张志攀',
        KCH: '100191034',
      }], '2025-2026-2');

      expect(exams.length).assertEqual(1);
      expect(exams[0].term).assertEqual('2025-2026-2');
      expect(exams[0].id).assertEqual('2025-2026-2:100191034:2026-05-16:10:10:12:10');
    });

    it('refreshes exams from source and persists local exams', 0, async () => {
      const store = new MemoryScheduleStore();
      const source = new FakeExamSource();
      source.exams = [exam('e1', '2026-06-30', '09:00', '11:00')];
      const repo = new CourseScheduleRepository({
        localStore: store,
        examSource: source,
      });

      const refreshed: ExamScheduleItem[] = await repo.refreshExams('2025-2026-2');

      expect(source.requestedTerm).assertEqual('2025-2026-2');
      expect(refreshed.length).assertEqual(1);
      expect(store.exams.length).assertEqual(1);
      expect(store.exams[0].id).assertEqual('e1');
    });

    it('enriches code-only exam names from local course numbers', 0, async () => {
      const store = new MemoryScheduleStore();
      const source = new FakeExamSource();
      const localCourse: CourseScheduleItem = course('c1', 1, 1, 2, '[1]');
      localCourse.name = '电化学与电分析化学';
      localCourse.number = '100191034';
      store.courses = [localCourse];
      source.exams = [exam('e1', '2026-05-16', '10:10', '12:10')];
      source.exams[0].name = '100191034';
      source.exams[0].courseId = '100191034';
      const repo = new CourseScheduleRepository({
        localStore: store,
        examSource: source,
      });

      const refreshed: ExamScheduleItem[] = await repo.refreshExams('2025-2026-2');

      expect(refreshed[0].name).assertEqual('电化学与电分析化学');
      expect(store.exams[0].name).assertEqual('电化学与电分析化学');
    });

    it('enriches code-only exam names from unique local course teacher when course numbers are missing', 0, async () => {
      const store = new MemoryScheduleStore();
      const source = new FakeExamSource();
      const localCourse: CourseScheduleItem = course('c1', 1, 1, 2, '[1]');
      localCourse.name = '化学工程基础A (I)';
      localCourse.number = '';
      localCourse.description = '刘文芳 | 4周 星期三 8-10节 理教楼407';
      store.courses = [localCourse];
      source.exams = [exam('e1', '2026-06-17', '15:30', '17:30')];
      source.exams[0].name = '100101101';
      source.exams[0].courseId = '100101101';
      source.exams[0].teacher = '刘文芳';
      const repo = new CourseScheduleRepository({
        localStore: store,
        examSource: source,
      });

      const refreshed: ExamScheduleItem[] = await repo.refreshExams('2025-2026-2');

      expect(refreshed[0].name).assertEqual('化学工程基础A (I)');
      expect(store.exams[0].name).assertEqual('化学工程基础A (I)');
    });
  });
}
