import { describe, it, expect } from '@ohos/hypium';
import {
  buildScheduleCalendarEventDrafts,
  formatSystemCalendarSyncMessage,
} from '../main/ets/services/systemCalendar/SystemCalendarModels';
import {
  syncSystemCalendarEventDrafts,
  SystemCalendarEventWriter,
} from '../main/ets/services/systemCalendar/SystemCalendarService';
import type { SystemCalendarEventDraft } from '../main/ets/services/systemCalendar/SystemCalendarModels';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from '../main/ets/services/schoolSchedule/ScheduleModels';
import type { SystemCalendarSyncResult } from '../main/ets/services/systemCalendar/SystemCalendarModels';
import type { PeriodTime } from '../main/ets/services/jw/periodTimes';

function course(id: string, weeks: string, weekday: number, startSection: number, endSection: number): CourseScheduleItem {
  return {
    id,
    term: '2025-2026-2',
    name: '生命分析化学',
    teacher: '李老师',
    classroom: '理教楼309',
    description: '4周 星期三 3-4节 理教楼309',
    weeks,
    weekday,
    startSection,
    endSection,
    campus: '中关村校区',
    number: 'CHEM101',
    credit: 2,
    hour: 32,
    type: '必修',
    category: '专业课',
    department: '化学学院',
  };
}

function exam(id: string, dateISO: string, beginTime: string, endTime: string): ExamScheduleItem {
  return {
    id,
    term: '2025-2026-2',
    name: '高等数学',
    courseId: 'MATH101',
    teacher: '张老师',
    classroom: '理教楼 202',
    dateISO,
    beginTime,
    endTime,
    examMode: '闭卷',
    seatId: 'A12',
  };
}

function custom(id: string, dateISO: string, beginTime: string, endTime: string): CustomScheduleItem {
  return {
    id,
    title: '答辩',
    subtitle: '中心楼',
    description: '准备 PPT',
    dateISO,
    beginTime,
    endTime,
    updatedAt: 1,
  };
}

export default function systemCalendarModelsTest() {
  describe('System calendar event models', () => {
    const periodTimes: PeriodTime[] = [
      { start: '08:00', end: '08:45' },
      { start: '08:50', end: '09:35' },
      { start: '09:55', end: '10:40' },
      { start: '10:45', end: '11:30' },
    ];

    it('expands course weeks into per-class event drafts', 0, () => {
      const drafts = buildScheduleCalendarEventDrafts({
        courses: [course('c1', '[1][3]', 3, 2, 4)],
        exams: [],
        customSchedules: [],
        firstDayISO: '2026-02-23',
        periodTimes,
      });

      expect(drafts.length).assertEqual(2);
      expect(drafts[0].identifier).assertEqual('bit101:course:2025-2026-2:c1:w1:d3:s2-4');
      expect(drafts[0].title).assertEqual('生命分析化学');
      expect(drafts[0].location).assertEqual('理教楼309');
      expect(drafts[0].startTime).assertEqual(new Date(2026, 1, 25, 8, 50, 0).getTime());
      expect(drafts[0].endTime).assertEqual(new Date(2026, 1, 25, 11, 30, 0).getTime());
      expect(drafts[0].description.indexOf('周次：第 1 周') >= 0).assertTrue();
      expect(drafts[1].identifier).assertEqual('bit101:course:2025-2026-2:c1:w3:d3:s2-4');
      expect(drafts[1].startTime).assertEqual(new Date(2026, 2, 11, 8, 50, 0).getTime());
    });

    it('skips invalid course calendar inputs', 0, () => {
      const drafts = buildScheduleCalendarEventDrafts({
        courses: [
          course('valid', '[1]', 1, 1, 1),
          course('no-weeks', '', 1, 1, 1),
          course('bad-weekday', '[1]', 8, 1, 1),
          course('bad-section', '[1]', 1, 5, 6),
        ],
        exams: [],
        customSchedules: [],
        firstDayISO: '2026-02-23',
        periodTimes,
      });

      expect(drafts.length).assertEqual(1);
      expect(drafts[0].identifier).assertEqual('bit101:course:2025-2026-2:valid:w1:d1:s1-1');
    });

    it('builds stable exam and custom event drafts', 0, () => {
      const drafts = buildScheduleCalendarEventDrafts({
        exams: [exam('e1', '2026-06-20', '09:00', '11:00')],
        customSchedules: [custom('m1', '2026-05-25', '14:00', '15:00')],
      });

      expect(drafts.length).assertEqual(2);
      expect(drafts[0].identifier).assertEqual('bit101:custom:m1');
      expect(drafts[0].title).assertEqual('答辩');
      expect(drafts[0].location).assertEqual('中心楼');
      expect(drafts[0].startTime).assertEqual(new Date(2026, 4, 25, 14, 0, 0).getTime());
      expect(drafts[1].identifier).assertEqual('bit101:exam:e1');
      expect(drafts[1].title).assertEqual('(考试) 高等数学');
      expect(drafts[1].location).assertEqual('理教楼 202');
      expect(drafts[1].description.indexOf('座位号：A12') >= 0).assertTrue();
    });

    it('skips invalid schedule times and duplicate identifiers', 0, () => {
      const drafts = buildScheduleCalendarEventDrafts({
        exams: [
          exam('e1', '2026-06-20', '09:00', '11:00'),
          exam('e1', '2026-06-20', '09:00', '11:00'),
          exam('bad', '2026-06-20', 'xx', '11:00'),
        ],
        customSchedules: [custom('bad', '2026-05-25', '15:00', '14:00')],
      });

      expect(drafts.length).assertEqual(1);
      expect(drafts[0].identifier).assertEqual('bit101:exam:e1');
    });

    it('formats sync result messages', 0, () => {
      const result: SystemCalendarSyncResult = {
        total: 3,
        created: 2,
        skipped: 1,
        failed: 0,
      };

      expect(formatSystemCalendarSyncMessage(result)).assertEqual('已写入 2 条，跳过 1 条已存在日程');
      expect(formatSystemCalendarSyncMessage({ total: 0, created: 0, skipped: 0, failed: 0 }))
        .assertEqual('没有可写入的考试或自定义日程');
      expect(formatSystemCalendarSyncMessage({ total: 2, created: 1, skipped: 0, failed: 1 }))
        .assertEqual('已写入 1 条，失败 1 条');
    });

    it('syncs drafts without duplicating existing identifiers', 0, async () => {
      class FakeWriter implements SystemCalendarEventWriter {
        existing: Record<string, boolean> = {
          'bit101:custom:m1': true,
        };
        added: string[] = [];

        async hasEvent(identifier: string, startTime: number, endTime: number): Promise<boolean> {
          return this.existing[identifier] === true && startTime > 0 && endTime > startTime;
        }

        async addEvent(draft: SystemCalendarEventDraft): Promise<number> {
          this.added.push(draft.identifier);
          return this.added.length;
        }
      }

      const writer = new FakeWriter();
      const drafts = buildScheduleCalendarEventDrafts({
        exams: [exam('e1', '2026-06-20', '09:00', '11:00')],
        customSchedules: [custom('m1', '2026-05-25', '14:00', '15:00')],
      });

      const result = await syncSystemCalendarEventDrafts(writer, drafts);

      expect(result.total).assertEqual(2);
      expect(result.created).assertEqual(1);
      expect(result.skipped).assertEqual(1);
      expect(result.failed).assertEqual(0);
      expect(writer.added.length).assertEqual(1);
      expect(writer.added[0]).assertEqual('bit101:exam:e1');
    });
  });
}
