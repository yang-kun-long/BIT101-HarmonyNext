import { describe, it, expect } from '@ohos/hypium';
import type { LexueCalendarEvent } from '../main/ets/services/lexue/LexueCalendarParser';
import {
  buildDdlItemFromManualInput,
  computeDdlRemainRatio,
  deleteDdlItem,
  listVisibleDdlItems,
  mergeLexueEventsWithDdlItems,
  parseDdlItemsJson,
  toggleDdlDone,
  upsertManualDdlItem,
} from '../main/ets/services/deadline/DdlModels';
import type { DdlItem, ManualDdlInput } from '../main/ets/services/deadline/DdlModels';
import { normalizeDdlDisplaySettings } from '../main/ets/services/storage/DdlSettingsStore';

export default function ddlLocalTest() {
  describe('DDL local model', () => {
    it('preserves local done state while replacing synced Lexue fields', 0, () => {
      const existing: DdlItem[] = [{
        uid: 'lexue-1',
        source: 'lexue',
        title: 'Old title',
        courseName: 'Old course',
        startTime: 1000,
        endTime: 1000,
        description: 'Old detail',
        location: '',
        done: true,
        updatedAt: 10,
      }];
      const incoming: LexueCalendarEvent[] = [{
        uid: 'lexue-1',
        title: 'New 作业',
        courseName: 'New course',
        startTime: 2000,
        endTime: 3000,
        description: 'New detail',
        location: 'Room 101',
      }];

      const merged: DdlItem[] = mergeLexueEventsWithDdlItems(existing, incoming, 9999);

      expect(merged.length).assertEqual(1);
      expect(merged[0].uid).assertEqual('lexue-1');
      expect(merged[0].title).assertEqual('New 作业');
      expect(merged[0].courseName).assertEqual('New course');
      expect(merged[0].done).assertTrue();
      expect(merged[0].updatedAt).assertEqual(9999);
    });

    it('keeps manual items when Lexue sync replaces synced items', 0, () => {
      const existing: DdlItem[] = [{
        uid: 'manual-1',
        source: 'manual',
        title: 'Manual task',
        courseName: '',
        startTime: 5000,
        endTime: 5000,
        description: '',
        location: '',
        done: false,
        updatedAt: 1,
      }, {
        uid: 'lexue-old',
        source: 'lexue',
        title: 'Removed remote task',
        courseName: '',
        startTime: 1000,
        endTime: 1000,
        description: '',
        location: '',
        done: false,
        updatedAt: 1,
      }];

      const merged: DdlItem[] = mergeLexueEventsWithDdlItems(existing, [], 2);

      expect(merged.length).assertEqual(1);
      expect(merged[0].uid).assertEqual('manual-1');
      expect(merged[0].source).assertEqual('manual');
    });

    it('creates manual items with stable required fields', 0, () => {
      const input: ManualDdlInput = {
        title: 'Write report',
        courseName: 'BIT101',
        time: 2000,
        description: 'draft first',
        location: '',
      };

      const item: DdlItem = buildDdlItemFromManualInput(input, 'manual-test', 1234);

      expect(item.uid).assertEqual('manual-test');
      expect(item.source).assertEqual('manual');
      expect(item.title).assertEqual('Write report');
      expect(item.startTime).assertEqual(2000);
      expect(item.endTime).assertEqual(2000);
      expect(item.done).assertFalse();
      expect(item.updatedAt).assertEqual(1234);
    });

    it('lists only unfinished future items before finished and expired items', 0, () => {
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({ title: 'Future B', courseName: '', time: 3000, description: '', location: '' }, 'b', 1),
        buildDdlItemFromManualInput({ title: 'Past', courseName: '', time: 500, description: '', location: '' }, 'past', 1),
        buildDdlItemFromManualInput({
          title: 'Done future',
          courseName: '',
          time: 2000,
          description: '',
          location: '',
          done: true,
        }, 'done', 1),
        buildDdlItemFromManualInput({ title: 'Future A', courseName: '', time: 1000, description: '', location: '' }, 'a', 1),
      ];

      const visible: DdlItem[] = listVisibleDdlItems(items, 800);

      expect(visible.length).assertEqual(2);
      expect(visible[0].uid).assertEqual('a');
      expect(visible[1].uid).assertEqual('b');
    });

    it('keeps unfinished expired items within retention days', 0, () => {
      const dayMs: number = 24 * 60 * 60 * 1000;
      const now: number = 10 * dayMs;
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({ title: 'Expired kept', courseName: '', time: now - dayMs, description: '', location: '' }, 'kept', 1),
        buildDdlItemFromManualInput({ title: 'Expired dropped', courseName: '', time: now - 4 * dayMs, description: '', location: '' }, 'dropped', 1),
        buildDdlItemFromManualInput({ title: 'Future', courseName: '', time: now + dayMs, description: '', location: '' }, 'future', 1),
      ];

      const visible: DdlItem[] = listVisibleDdlItems(items, now, 3);

      expect(visible.length).assertEqual(2);
      expect(visible[0].uid).assertEqual('kept');
      expect(visible[1].uid).assertEqual('future');
    });

    it('computes DDL remaining time ratio from warning days', 0, () => {
      const dayMs: number = 24 * 60 * 60 * 1000;
      const now: number = 10 * dayMs;

      expect(computeDdlRemainRatio(now - 1, now, 7)).assertEqual(0);
      expect(computeDdlRemainRatio(now + 7 * dayMs, now, 7)).assertEqual(1);
      expect(computeDdlRemainRatio(now + 14 * dayMs, now, 7)).assertEqual(1);
      expect(computeDdlRemainRatio(now + 3.5 * dayMs, now, 7)).assertEqual(0.5);
    });

    it('normalizes DDL display settings to non-negative whole days', 0, () => {
      const normalized = normalizeDdlDisplaySettings({
        warningDays: 7.8,
        retentionDays: -2,
      });

      expect(normalized.warningDays).assertEqual(7);
      expect(normalized.retentionDays).assertEqual(0);
    });

    it('toggles done state without changing other items', 0, () => {
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({ title: 'A', courseName: '', time: 1000, description: '', location: '' }, 'a', 1),
        buildDdlItemFromManualInput({ title: 'B', courseName: '', time: 2000, description: '', location: '' }, 'b', 1),
      ];

      const updated: DdlItem[] = toggleDdlDone(items, 'b', true, 99);

      expect(updated.length).assertEqual(2);
      expect(updated[0].uid).assertEqual('a');
      expect(updated[0].done).assertFalse();
      expect(updated[1].uid).assertEqual('b');
      expect(updated[1].done).assertTrue();
      expect(updated[1].updatedAt).assertEqual(99);
    });

    it('deletes only the requested DDL item', 0, () => {
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({ title: 'A', courseName: '', time: 1000, description: '', location: '' }, 'a', 1),
        buildDdlItemFromManualInput({ title: 'B', courseName: '', time: 2000, description: '', location: '' }, 'b', 1),
      ];

      const updated: DdlItem[] = deleteDdlItem(items, 'a');

      expect(updated.length).assertEqual(1);
      expect(updated[0].uid).assertEqual('b');
    });

    it('upserts manual DDL items by uid', 0, () => {
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({ title: 'Old', courseName: '', time: 1000, description: '', location: '' }, 'manual-1', 1),
      ];

      const updated: DdlItem[] = upsertManualDdlItem(items, {
        title: 'New',
        courseName: 'Course',
        time: 3000,
        description: 'Detail',
        location: 'Room',
      }, 'manual-1', 2);

      expect(updated.length).assertEqual(1);
      expect(updated[0].uid).assertEqual('manual-1');
      expect(updated[0].title).assertEqual('New');
      expect(updated[0].courseName).assertEqual('Course');
      expect(updated[0].startTime).assertEqual(3000);
      expect(updated[0].updatedAt).assertEqual(2);
    });

    it('preserves manual done state when editing existing item', 0, () => {
      const items: DdlItem[] = [
        buildDdlItemFromManualInput({
          title: 'Old',
          courseName: '',
          time: 1000,
          description: '',
          location: '',
          done: true,
        }, 'manual-1', 1),
      ];

      const updated: DdlItem[] = upsertManualDdlItem(items, {
        title: 'Edited',
        courseName: 'Course',
        time: 2000,
        description: 'Detail',
        location: 'Room',
      }, 'manual-1', 2);

      expect(updated.length).assertEqual(1);
      expect(updated[0].title).assertEqual('Edited');
      expect(updated[0].done).assertTrue();
      expect(updated[0].updatedAt).assertEqual(2);
    });

    it('parses persisted DDL JSON defensively', 0, () => {
      const valid: DdlItem[] = parseDdlItemsJson('[{"uid":"a","source":"manual","title":"A","courseName":"","startTime":1,"endTime":1,"description":"","location":"","done":false,"updatedAt":1}]');
      const invalid: DdlItem[] = parseDdlItemsJson('{bad json');
      const wrongShape: DdlItem[] = parseDdlItemsJson('{"uid":"a"}');

      expect(valid.length).assertEqual(1);
      expect(valid[0].uid).assertEqual('a');
      expect(invalid.length).assertEqual(0);
      expect(wrongShape.length).assertEqual(0);
    });
  });
}
