import type { CourseScheduleItem } from './ScheduleModels';
import type { ScheduleCacheInfo } from './ScheduleLocalStore';
import type { PeriodTime } from '../jw/periodTimes';
import { computeWeekNumber, courseContainsWeek } from './CourseScheduleRepository';
import { buildCourseColorMap } from './ScheduleColors';
import { makeCourseColorKey } from '../../utils/scheduleUtils';

export interface WidgetCourseCard {
  id: string;
  heading: string;
  name: string;
  room: string;
  time: string;
  sections: string;
  color: string;
  status: string;
  startAt: number;
  endAt: number;
}

export interface WidgetCourseDeck {
  cards: WidgetCourseCard[];
  focusIndex: number;
  cacheReady: boolean;
  emptyText: string;
}

export interface ScheduleWidgetPayload {
  deck: WidgetCourseDeck;
  refreshMinutes: number;
}

function dateISO(date: Date): string {
  return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
}

function atClock(date: Date, clock: string): number {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), Number(clock.slice(0, 2)), Number(clock.slice(3, 5))).getTime();
}

// The deck is always limited to today's course occurrences.
export function buildScheduleWidgetPayload(
  courses: CourseScheduleItem[], info: ScheduleCacheInfo | null, times: PeriodTime[], now: Date,
): ScheduleWidgetPayload {
  const termCourses = info ? courses.filter(course => course.term === info.term) : [];
  const colors = buildCourseColorMap(termCourses.map(course => makeCourseColorKey(course.name, course.teacher)));
  const weekdays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
  const currentTime = now.getTime();
  let nextChange = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1).getTime();
  const iso = dateISO(now);
  const week = info ? computeWeekNumber(info.firstDayISO, iso) : 1;
  const weekday = now.getDay() || 7;
  const cards: WidgetCourseCard[] = [];

  if (info && iso >= info.firstDayISO) {
    const matches = termCourses.filter(course => course.weekday === weekday && courseContainsWeek(course.weeks, week))
      .sort((a, b) => a.startSection - b.startSection || a.endSection - b.endSection || a.id.localeCompare(b.id));
    for (const course of matches) {
      const start = times[course.startSection - 1];
      const end = times[course.endSection - 1];
      if (!start || !end) continue;
      const startAt = atClock(now, start.start);
      const endAt = atClock(now, end.end);
      if (!Number.isFinite(startAt) || !Number.isFinite(endAt) || endAt <= startAt) continue;
      const status = currentTime >= endAt ? '已结束' : (currentTime >= startAt ? '正在上课' : '即将上课');
      cards.push({
        id: iso + ':' + course.id,
        heading: '周' + weekdays[now.getDay()] + ' · 第' + week + '周',
        name: course.name, room: course.classroom || '教室待定', time: start.start + '–' + end.end,
        sections: course.startSection === course.endSection ? '第' + course.startSection + '节' :
          '第' + course.startSection + '–' + course.endSection + '节',
        color: colors[makeCourseColorKey(course.name, course.teacher)], status, startAt, endAt,
      });
    }
  }

  let focusIndex = cards.findIndex(card => card.startAt <= currentTime && card.endAt > currentTime);
  if (focusIndex < 0) focusIndex = cards.findIndex(card => card.startAt > currentTime);
  if (focusIndex < 0) focusIndex = 0;
  for (const card of cards) {
    if (card.startAt > currentTime) nextChange = Math.min(nextChange, card.startAt);
    if (card.endAt > currentTime) nextChange = Math.min(nextChange, card.endAt);
  }

  return {
    deck: { cards, focusIndex, cacheReady: info !== null,
      emptyText: info ? '今日无课' : '先在应用内获取课表' },
    // FormKit's minimum is five minutes.
    refreshMinutes: Math.max(5, Math.min(30, Math.ceil((nextChange - currentTime) / 60000))),
  };
}
