import { DebugCase } from './DebugCase';
import {
  syncSystemCalendarEventDrafts,
  SystemCalendarService,
} from '../services/systemCalendar/SystemCalendarService';
import type {
  SystemCalendarEventDraft,
  SystemCalendarSyncResult,
} from '../services/systemCalendar/SystemCalendarModels';

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
  }
}
