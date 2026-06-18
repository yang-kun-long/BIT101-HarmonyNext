import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import type {
  SystemCalendarEventDraft,
  SystemCalendarSyncResult,
} from './SystemCalendarModels';
import { Logger } from '../../utils/Logger';

export interface SystemCalendarEventWriter {
  hasEvent(identifier: string, startTime: number, endTime: number): Promise<boolean>;
  addEvent(draft: SystemCalendarEventDraft): Promise<number>;
}

export interface SystemCalendarEventCleaner {
  deleteEventsByIdentifier(identifier: string, startTime: number, endTime: number): Promise<number>;
}

const CALENDAR_ACCOUNT: calendarManager.CalendarAccount = {
  name: 'BIT101 Schedule',
  type: calendarManager.CalendarType.LOCAL,
  displayName: 'BIT101 课程表',
};

const CALENDAR_CONFIG: calendarManager.CalendarConfig = {
  enableReminder: true,
  color: '#2563EB',
};

let abilityContext: common.UIAbilityContext | null = null;

export function initSystemCalendarService(ctx: common.UIAbilityContext): void {
  abilityContext = ctx;
}

export async function syncSystemCalendarEventDrafts(
  writer: SystemCalendarEventWriter,
  drafts: SystemCalendarEventDraft[],
): Promise<SystemCalendarSyncResult> {
  const result: SystemCalendarSyncResult = {
    total: drafts.length,
    created: 0,
    skipped: 0,
    failed: 0,
  };

  for (const draft of drafts) {
    try {
      const exists = await writer.hasEvent(draft.identifier, draft.startTime, draft.endTime);
      if (exists) {
        result.skipped += 1;
        continue;
      }
      await writer.addEvent(draft);
      result.created += 1;
    } catch (_) {
      result.failed += 1;
    }
  }

  return result;
}

function draftToCalendarEvent(draft: SystemCalendarEventDraft): calendarManager.Event {
  return {
    title: draft.title,
    description: draft.description,
    identifier: draft.identifier,
    type: calendarManager.EventType.NORMAL,
    startTime: draft.startTime,
    endTime: draft.endTime,
    reminderTime: draft.reminderMinutes,
    location: {
      location: draft.location,
    },
  };
}

export class SystemCalendarService implements SystemCalendarEventWriter {
  private logger: Logger = new Logger('SystemCalendarService');
  private calendar: calendarManager.Calendar | null = null;

  private getContext(): common.UIAbilityContext {
    if (!abilityContext) {
      throw new Error('系统日历服务尚未初始化');
    }
    return abilityContext;
  }

  private async requestCalendarPermissions(ctx: common.UIAbilityContext): Promise<void> {
    const permissions: Permissions[] = [
      'ohos.permission.READ_CALENDAR',
      'ohos.permission.WRITE_CALENDAR',
    ];
    const atManager = abilityAccessCtrl.createAtManager();
    let result;
    try {
      result = await atManager.requestPermissionsFromUser(ctx, permissions);
    } catch (error) {
      this.logger.error('request calendar permissions failed', error);
      throw new Error('申请系统日历权限失败');
    }
    for (const authResult of result.authResults) {
      if (authResult !== 0) {
        throw new Error('未获得系统日历权限');
      }
    }
  }

  private async getBit101Calendar(): Promise<calendarManager.Calendar> {
    if (this.calendar) {
      return this.calendar;
    }
    const ctx = this.getContext();
    await this.requestCalendarPermissions(ctx);
    const manager = calendarManager.getCalendarManager(ctx);

    try {
      this.calendar = await manager.getCalendar(CALENDAR_ACCOUNT);
      return this.calendar;
    } catch (_) {
      try {
        this.calendar = await manager.createCalendar(CALENDAR_ACCOUNT);
      } catch (error) {
        this.logger.error('create BIT101 calendar failed', error);
        throw new Error('创建 BIT101 系统日历失败');
      }
      try {
        await this.calendar.setConfig(CALENDAR_CONFIG);
      } catch (error) {
        this.logger.warn('set BIT101 calendar config failed', error);
      }
      return this.calendar;
    }
  }

  async hasEvent(identifier: string, startTime: number, endTime: number): Promise<boolean> {
    const calendar = await this.getBit101Calendar();
    const filter = calendarManager.EventFilter.filterByTime(startTime, endTime);
    let events: calendarManager.Event[] = [];
    try {
      events = await calendar.getEvents(filter, ['identifier']);
    } catch (error) {
      this.logger.error('query system calendar events failed', error);
      throw new Error('查询系统日历失败');
    }
    for (const event of events) {
      if (event.identifier === identifier) {
        return true;
      }
    }
    return false;
  }

  async addEvent(draft: SystemCalendarEventDraft): Promise<number> {
    const calendar = await this.getBit101Calendar();
    try {
      return await calendar.addEvent(draftToCalendarEvent(draft));
    } catch (error) {
      this.logger.error('add system calendar event failed', error);
      throw new Error('写入系统日历失败');
    }
  }

  async deleteEventsByIdentifier(identifier: string, startTime: number, endTime: number): Promise<number> {
    const calendar = await this.getBit101Calendar();
    const filter = calendarManager.EventFilter.filterByTime(startTime, endTime);
    let events: calendarManager.Event[] = [];
    try {
      events = await calendar.getEvents(filter, ['id', 'identifier']);
    } catch (error) {
      this.logger.error('query system calendar events before delete failed', error);
      throw new Error('查询系统日历失败');
    }

    let deleted = 0;
    for (const event of events) {
      if (event.identifier !== identifier || event.id === undefined) {
        continue;
      }
      try {
        await calendar.deleteEvent(event.id);
        deleted += 1;
      } catch (error) {
        this.logger.warn('delete system calendar event failed', error);
      }
    }
    return deleted;
  }
}
