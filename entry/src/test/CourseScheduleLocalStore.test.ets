import { describe, it, expect } from '@ohos/hypium';
import {
  deleteCustomSchedule,
  createValidatedCustomSchedule,
  parseCourseScheduleItemsJson,
  parseScheduleCacheInfo,
  parseCustomScheduleItemsJson,
  parseExamScheduleItemsJson,
  upsertCustomSchedule,
} from '../main/ets/services/schoolSchedule/ScheduleLocalStore';
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
} from '../main/ets/services/schoolSchedule/ScheduleModels';

function buildCustom(id: string, title: string): CustomScheduleItem {
  return {
    id,
    title,
    subtitle: '',
    description: '',
    dateISO: '2026-05-25',
    beginTime: '08:00',
    endTime: '08:45',
    updatedAt: 1,
  };
}

export default function courseScheduleLocalStoreTest() {
  describe('Course schedule local store helpers', () => {
    it('restores semester metadata and rejects missing or corrupt cache info', 0, () => {
      const info = parseScheduleCacheInfo('{"term":"2026-2027-1","firstDayISO":"2026-08-31"}');
      expect(info?.term).assertEqual('2026-2027-1');
      expect(info?.firstDayISO).assertEqual('2026-08-31');
      expect(parseScheduleCacheInfo('[]') === null).assertTrue();
      expect(parseScheduleCacheInfo('{bad') === null).assertTrue();
      expect(parseScheduleCacheInfo('{"term":"2026-2027-1"}') === null).assertTrue();
    });

    it('parses course JSON defensively', 0, () => {
      const valid: CourseScheduleItem[] = parseCourseScheduleItemsJson(
        '[{"id":"c1","term":"2025-2026-2","name":"Math","teacher":"","classroom":"101","description":"","weeks":"[1]","weekday":1,"startSection":1,"endSection":2,"campus":"","number":"","credit":0,"hour":0,"type":"","category":"","department":""}]',
      );

      expect(valid.length).assertEqual(1);
      expect(valid[0].id).assertEqual('c1');
      expect(parseCourseScheduleItemsJson('{bad').length).assertEqual(0);
      expect(parseCourseScheduleItemsJson('{"id":"c1"}').length).assertEqual(0);
    });

    it('parses exam JSON defensively', 0, () => {
      const valid: ExamScheduleItem[] = parseExamScheduleItemsJson(
        '[{"id":"e1","term":"2025-2026-2","name":"Exam","courseId":"M1","teacher":"","classroom":"101","dateISO":"2026-06-01","beginTime":"09:00","endTime":"11:00","examMode":"","seatId":""}]',
      );

      expect(valid.length).assertEqual(1);
      expect(valid[0].id).assertEqual('e1');
      expect(parseExamScheduleItemsJson('{bad').length).assertEqual(0);
      expect(parseExamScheduleItemsJson('[]').length).assertEqual(0);
    });

    it('normalizes school display term when parsing stored exams', 0, () => {
      const valid: ExamScheduleItem[] = parseExamScheduleItemsJson(
        '[{"id":"e1","term":"2025-2026学年 2学期","name":"Exam","courseId":"M1","teacher":"","classroom":"101","dateISO":"2026-05-16","beginTime":"10:10","endTime":"12:10","examMode":"","seatId":""}]',
      );

      expect(valid.length).assertEqual(1);
      expect(valid[0].term).assertEqual('2025-2026-2');
    });

    it('upserts custom schedules by id', 0, () => {
      const existing: CustomScheduleItem[] = [buildCustom('a', 'Old')];
      const next: CustomScheduleItem = buildCustom('a', 'New');
      next.updatedAt = 2;

      const updated: CustomScheduleItem[] = upsertCustomSchedule(existing, next);

      expect(updated.length).assertEqual(1);
      expect(updated[0].id).assertEqual('a');
      expect(updated[0].title).assertEqual('New');
      expect(updated[0].updatedAt).assertEqual(2);
    });

    it('deletes only the requested custom schedule', 0, () => {
      const existing: CustomScheduleItem[] = [buildCustom('a', 'A'), buildCustom('b', 'B')];

      const updated: CustomScheduleItem[] = deleteCustomSchedule(existing, 'a');

      expect(updated.length).assertEqual(1);
      expect(updated[0].id).assertEqual('b');
    });

    it('parses custom schedule JSON defensively', 0, () => {
      const valid: CustomScheduleItem[] = parseCustomScheduleItemsJson(JSON.stringify([buildCustom('a', 'A')]));

      expect(valid.length).assertEqual(1);
      expect(valid[0].title).assertEqual('A');
      expect(parseCustomScheduleItemsJson('{bad').length).assertEqual(0);
      expect(parseCustomScheduleItemsJson('[{"id":"a"}]').length).assertEqual(0);
    });

    it('validates custom schedule form fields before save', 0, () => {
      const valid: CustomScheduleItem | null = createValidatedCustomSchedule({
        title: '答辩',
        subtitle: '良乡',
        description: '准备材料',
        dateISO: '2026-05-25',
        beginTime: '14:00',
        endTime: '15:00',
        existingId: 'custom-1',
        now: 100,
      });

      expect(valid !== null).assertTrue();
      expect(valid?.id).assertEqual('custom-1');
      expect(valid?.title).assertEqual('答辩');

      const invalid: CustomScheduleItem | null = createValidatedCustomSchedule({
        title: '无效',
        subtitle: '',
        description: '',
        dateISO: '2026-05-25',
        beginTime: '15:00',
        endTime: '14:00',
        now: 100,
      });

      expect(invalid === null).assertTrue();
    });
  });
}
