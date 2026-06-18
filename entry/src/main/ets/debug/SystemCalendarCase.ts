import { DebugCase } from './DebugCase';
import {
  syncSystemCalendarEventDrafts,
  SystemCalendarService,
} from '../services/systemCalendar/SystemCalendarService';
import {
  buildScheduleCalendarEventDrafts,
} from '../services/systemCalendar/SystemCalendarModels';
import type {
  SystemCalendarEventDraft,
  SystemCalendarSyncResult,
} from '../services/systemCalendar/SystemCalendarModels';
import type { CourseScheduleItem } from '../services/schoolSchedule/ScheduleModels';
import type { PeriodTime } from '../services/jw/periodTimes';

export class SystemCalendarCase extends DebugCase {
  readonly name: string = 'System calendar write cleanup';

  async run(): Promise<void> {
    const service = new SystemCalendarService();
    const now = Date.now();
    const startTime = now + 60 * 60 * 1000;
    const endTime = startTime + 30 * 60 * 1000;
    const draft: SystemCalendarEventDraft = {
      identifier: `bit101:debug:${now}`,
      title: 'BIT101 Debug Calendar Event',
      description: 'Created by SystemCalendarCase and deleted before finishing.',
      startTime,
      endTime,
      location: 'BIT101 Debug',
      reminderMinutes: [],
    };

    this.logInfo('draft identifier =', draft.identifier);

    const first: SystemCalendarSyncResult = await syncSystemCalendarEventDrafts(service, [draft]);
    this.logInfo('first sync result =', first);
    this.assertTrue(first.created === 1, 'first sync should create one event');

    const second: SystemCalendarSyncResult = await syncSystemCalendarEventDrafts(service, [draft]);
    this.logInfo('second sync result =', second);
    this.assertTrue(second.skipped === 1, 'second sync should skip existing event');

    const deleted = await service.deleteEventsByIdentifier(draft.identifier, startTime, endTime);
    this.logInfo('deleted events =', deleted);
    this.assertTrue(deleted >= 1, 'debug event should be deleted');

    const course: CourseScheduleItem = {
      id: `debug-course-${now}`,
      term: 'debug-term',
      name: 'BIT101 Debug Course',
      teacher: 'Debug Teacher',
      classroom: 'Debug Room',
      description: 'Debug course for system calendar integration.',
      weeks: '[1][2]',
      weekday: 1,
      startSection: 1,
      endSection: 1,
      campus: 'Debug Campus',
      number: 'DEBUG101',
      credit: 0,
      hour: 0,
      type: '',
      category: '',
      department: '',
    };
    const periodTimes: PeriodTime[] = [{ start: '08:00', end: '08:45' }];
    const courseDrafts: SystemCalendarEventDraft[] = buildScheduleCalendarEventDrafts({
      courses: [course],
      exams: [],
      customSchedules: [],
      firstDayISO: '2026-07-06',
      periodTimes,
    });
    this.logInfo('course drafts count =', courseDrafts.length);
    this.assertTrue(courseDrafts.length === 2, 'course should expand to two events');

    const courseFirst: SystemCalendarSyncResult = await syncSystemCalendarEventDrafts(service, courseDrafts);
    this.logInfo('course first sync result =', courseFirst);
    this.assertTrue(courseFirst.created === 2, 'course sync should create two events');

    const courseSecond: SystemCalendarSyncResult = await syncSystemCalendarEventDrafts(service, courseDrafts);
    this.logInfo('course second sync result =', courseSecond);
    this.assertTrue(courseSecond.skipped === 2, 'course second sync should skip two existing events');

    let courseDeleted = 0;
    for (const courseDraft of courseDrafts) {
      courseDeleted += await service.deleteEventsByIdentifier(
        courseDraft.identifier,
        courseDraft.startTime,
        courseDraft.endTime,
      );
    }
    this.logInfo('deleted course events =', courseDeleted);
    this.assertTrue(courseDeleted >= 2, 'debug course events should be deleted');
  }
}
