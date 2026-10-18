import { describe, it, expect } from '@ohos/hypium';
import { buildCourseColorMap } from '../main/ets/services/schoolSchedule/ScheduleColors';
import {
  buildWeekScheduleDisplayItems,
  calendarEventsToCourseScheduleItems,
  clockToSection,
  computeWeekNumber,
  CourseScheduleSource,
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
import {
  getCourseBaseUrlForMode,
  mapCourseScheduleApiRows,
  mapCourseScheduleApiResponse,
} from '../main/ets/services/jw/courseScheduleApiRepository';
import type { CourseScheduleApiRow } from '../main/ets/services/jw/courseScheduleApiRepository';
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

class FakeCourseSource implements CourseScheduleSource {
  requestedTerm: string = '';
  courses: CourseScheduleItem[] = [];

  async getCourses(term: string): Promise<CourseScheduleItem[]> {
    this.requestedTerm = term;
    return this.courses;
  }
}

export default function courseScheduleRepositoryTest() {
  describe('Course schedule repository helpers', () => {
    it('keeps course colors distinct and stable across reordered recurring slots', 0, () => {
      const keys = ['math|alice', 'physics|bob', 'chemistry|carol', 'history|dan'];
      const colors = buildCourseColorMap(keys);
      const reordered = buildCourseColorMap([keys[3], keys[1], keys[0], keys[2], keys[0]]);
      expect(Object.keys(reordered).length).assertEqual(4);
      for (let i = 0; i < keys.length; i++) {
        expect(colors[keys[i]]).assertEqual(reordered[keys[i]]);
        for (let j = i + 1; j < keys.length; j++) {
          expect(colors[keys[i]] !== colors[keys[j]]).assertTrue();
        }
      }
    });

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

    it('maps Android native course API rows to local course items', 0, () => {
      expect(getCourseBaseUrlForMode('inner')).assertEqual('https://jxzxehallapp.bit.edu.cn');
      expect(getCourseBaseUrlForMode('webvpn').indexOf('https://webvpn.bit.edu.cn/https/')).assertEqual(0);

      const courses: CourseScheduleItem[] = mapCourseScheduleApiRows([{
        XNXQDM: '2025-2026-2',
        KCM: '化学工程基础A (I)',
        SKJS: '刘文芳',
        JASMC: '理教楼407',
        YPSJDD: '4周 星期三 8-10节 理教楼407',
        SKZC: '00010000000000000000',
        SKXQ: 3,
        KSJC: 8,
        JSJC: 10,
        XXXQMC: '中关村校区',
        KCH: '100101101',
        XF: 3,
        XS: 48,
        KCXZDM_DISPLAY: '必修',
        KCLBDM_DISPLAY: '专业课',
        KKDWDM_DISPLAY: '化学与化工学院',
      }], '2025-2026-2');

      expect(courses.length).assertEqual(1);
      expect(courses[0].term).assertEqual('2025-2026-2');
      expect(courses[0].id).assertEqual('2025-2026-2:100101101:3:8:10:4:' +
        encodeURIComponent('刘文芳') + ':' + encodeURIComponent('理教楼407') + ':' + encodeURIComponent('中关村校区'));
      expect(courses[0].name).assertEqual('化学工程基础A (I)');
      expect(courses[0].teacher).assertEqual('刘文芳');
      expect(courses[0].classroom).assertEqual('理教楼407');
      expect(courses[0].description).assertEqual('4周 星期三 8-10节 理教楼407');
      expect(courses[0].weeks).assertEqual('[4]');
      expect(courses[0].weekday).assertEqual(3);
      expect(courses[0].startSection).assertEqual(8);
      expect(courses[0].endSection).assertEqual(10);
      expect(courses[0].campus).assertEqual('中关村校区');
      expect(courses[0].number).assertEqual('100101101');
      expect(courses[0].credit).assertEqual(3);
      expect(courses[0].hour).assertEqual(48);
      expect(courses[0].type).assertEqual('必修');
      expect(courses[0].category).assertEqual('专业课');
      expect(courses[0].department).assertEqual('化学与化工学院');
    });

    it('drops invalid native rows and de-duplicates repeated course slots', 0, () => {
      const rows: CourseScheduleApiRow[] = [
        { XNXQDM: '2025-2026-2', KCM: '同一课程', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2 },
        { XNXQDM: '2025-2026-2', KCM: '同一课程', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2 },
        { XNXQDM: '2025-2026-2', KCM: '无周次', KCH: 'C2', SKZC: '0000', SKXQ: 2, KSJC: 1, JSJC: 2 },
        { XNXQDM: '2025-2026-2', KCM: '非法星期', KCH: 'C3', SKZC: '1000', SKXQ: 0, KSJC: 1, JSJC: 2 },
      ];
      const courses = mapCourseScheduleApiRows(rows, '2025-2026-2');
      expect(courses.length).assertEqual(1);
      expect(courses[0].id).assertEqual('2025-2026-2:C1:1:1:2:1:::');
    });

    it('rejects a malformed native course response but accepts a valid empty result', 0, () => {
      let failed = false;
      try { mapCourseScheduleApiResponse({}, '2025-2026-2'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      const courses = mapCourseScheduleApiResponse({ datas: { cxxszhxqkb: { rows: [] } } }, '2025-2026-2');
      expect(courses.length).assertEqual(0);
    });

    it('keeps distinct teachers rooms and campuses in identical course slots', 0, () => {
      const base: CourseScheduleApiRow = { KCM: '实验课', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2,
        SKJS: '教师甲', JASMC: '101', XXXQMC: '校区甲' };
      const otherTeacher: CourseScheduleApiRow = { KCM: '实验课', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2,
        SKJS: '教师乙', JASMC: '101', XXXQMC: '校区甲' };
      const otherRoom: CourseScheduleApiRow = { KCM: '实验课', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2,
        SKJS: '教师甲', JASMC: '102', XXXQMC: '校区甲' };
      const otherCampus: CourseScheduleApiRow = { KCM: '实验课', KCH: 'C1', SKZC: '1000', SKXQ: 1, KSJC: 1, JSJC: 2,
        SKJS: '教师甲', JASMC: '101', XXXQMC: '校区乙' };
      const items = mapCourseScheduleApiRows([base, base, otherTeacher, otherRoom, otherCampus], '2025-2026-2');
      expect(items.length).assertEqual(4);
      expect(new Set(items.map((item: CourseScheduleItem) => item.id)).size).assertEqual(4);
    });

    it('refreshes courses from Android native source and persists local courses', 0, async () => {
      const store = new MemoryScheduleStore();
      const source = new FakeCourseSource();
      source.courses = [course('native-c1', 1, 1, 2, '[1]')];
      const repo = new CourseScheduleRepository({
        localStore: store,
        courseSource: source,
      });

      const refreshed: CourseScheduleItem[] = await repo.refreshCourses('2025-2026-2', '2026-02-23', periodTimes);

      expect(source.requestedTerm).assertEqual('2025-2026-2');
      expect(refreshed.length).assertEqual(1);
      expect(store.courses.length).assertEqual(1);
      expect(store.courses[0].id).assertEqual('native-c1');
    });

    it('keeps the previous local courses when native refresh fails', 0, async () => {
      const store = new MemoryScheduleStore();
      store.courses = [course('old-c1', 1, 1, 2, '[1]')];
      class FailingCourseSource implements CourseScheduleSource {
        async getCourses(_term: string): Promise<CourseScheduleItem[]> {
          throw new Error('school service unavailable');
        }
      }
      const repo = new CourseScheduleRepository({ localStore: store, courseSource: new FailingCourseSource() });
      let failed = false;
      try { await repo.refreshCourses('2025-2026-2', '2026-02-23', periodTimes); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect(store.courses.length).assertEqual(1);
      expect(store.courses[0].id).assertEqual('old-c1');
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
