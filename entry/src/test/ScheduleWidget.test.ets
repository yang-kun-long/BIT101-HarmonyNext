import { describe, it, expect } from '@ohos/hypium';
import { buildScheduleWidgetPayload } from '../main/ets/services/schoolSchedule/ScheduleWidgetModel';
import { getDefaultPeriodTimes } from '../main/ets/services/jw/periodTimes';
import type { CourseScheduleItem } from '../main/ets/services/schoolSchedule/ScheduleModels';
import type { ScheduleCacheInfo } from '../main/ets/services/schoolSchedule/ScheduleLocalStore';

function course(id: string, weekday: number, start: number, end: number, weeks: string = '[8]'): CourseScheduleItem {
  return { id, term: '2026-2027-1', weekday, weeks, name: id, teacher: 'Teacher', classroom: '101', description: '',
    startSection: start, endSection: end, campus: '', number: '', credit: 0, hour: 0, type: '', category: '', department: '' };
}

export default function scheduleWidgetTest() {
  describe('Schedule widget course deck', () => {
    const info: ScheduleCacheInfo = { term: '2026-2027-1', firstDayISO: '2026-08-31' };
    const times = getDefaultPeriodTimes();

    it('keeps one card for a multi-section class and focuses the ongoing class', 0, () => {
      const courses = [course('English', 4, 8, 10), course('Math', 4, 3, 5)];
      const payload = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 10, 0));
      expect(payload.deck.cards.length).assertEqual(2);
      expect(payload.deck.focusIndex).assertEqual(0);
      expect(payload.deck.cards[0].name).assertEqual('Math');
      expect(payload.deck.cards[0].heading).assertEqual('周四 · 第8周');
      expect(payload.deck.cards[0].sections).assertEqual('第3–5节');
      expect(payload.deck.cards[0].time).assertEqual('09:55–12:20');
      expect(payload.deck.cards[0].status).assertEqual('正在上课');
      expect(payload.deck.cards[0].color === payload.deck.cards[1].color).assertFalse();
    });

    it('focuses the next class during a break and keeps earlier classes available to flip back', 0, () => {
      const payload = buildScheduleWidgetPayload([course('Math', 4, 3, 5), course('English', 4, 8, 10)],
        info, times, new Date(2026, 9, 22, 13, 0));
      expect(payload.deck.focusIndex).assertEqual(1);
      expect(payload.deck.cards[0].status).assertEqual('已结束');
      expect(payload.deck.cards[1].status).assertEqual('即将上课');
    });

    it('uses exact start and end boundaries and schedules a refresh near the transition', 0, () => {
      const courses = [course('Math', 4, 3, 5), course('English', 4, 8, 10)];
      const start = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 9, 55));
      expect(start.deck.cards[0].status).assertEqual('正在上课');
      const end = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 12, 20));
      expect(end.deck.focusIndex).assertEqual(1);
      const near = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 9, 49));
      expect(near.refreshMinutes).assertEqual(6);
      const minimum = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 9, 54));
      expect(minimum.refreshMinutes).assertEqual(5);
    });

    it("keeps only today's cards after classes finish and leaves the next day empty", 0, () => {
      const courses = [course('Math', 4, 3, 5, '[8][9]'), course('English', 4, 8, 10, '[8][9]')];
      const late = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 22, 18, 0));
      expect(late.deck.cards.length).assertEqual(2);
      expect(late.deck.cards[0].heading).assertEqual('周四 · 第8周');
      expect(late.deck.focusIndex).assertEqual(0);
      const weekend = buildScheduleWidgetPayload(courses, info, times, new Date(2026, 9, 18, 12, 0));
      expect(weekend.deck.cards.length).assertEqual(0);
      expect(weekend.deck.emptyText).assertEqual('今日无课');
      expect(weekend.deck.cards.length).assertEqual(0);
    });

    it("filters term and teaching weeks to only show today's courses", 0, () => {
      const old = course('Old term', 4, 1, 2);
      old.term = '2025-2026-1';
      const payload = buildScheduleWidgetPayload([old, course('Past', 4, 3, 5, '[7]')],
        info, times, new Date(2026, 9, 22, 10, 0));
      expect(payload.deck.cards.length).assertEqual(0);
      expect(payload.deck.emptyText).assertEqual('今日无课');
    });

    it('handles missing cache, empty days, pre-term dates and invalid sections', 0, () => {
      const now = new Date(2026, 7, 1);
      expect(buildScheduleWidgetPayload([], null, times, now).deck.cacheReady).assertFalse();
      expect(buildScheduleWidgetPayload([], info, times, now).deck.cacheReady).assertTrue();
      const before = buildScheduleWidgetPayload([course('Math', 1, 3, 5, '[1]')], info, times, now);
      expect(before.deck.cards.length).assertEqual(0);
      expect(before.deck.emptyText).assertEqual('今日无课');
      const invalid = buildScheduleWidgetPayload([course('Invalid', 4, 3, 20)], info, times, new Date(2026, 9, 22));
      expect(invalid.deck.cards.length).assertEqual(0);
    });
  });
}
