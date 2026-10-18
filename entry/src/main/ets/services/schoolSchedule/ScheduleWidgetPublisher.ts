import { formBindingData, formProvider } from '@kit.FormKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { Logger } from '../../utils/Logger';
import { PeriodTimesStore } from '../jw/periodTimesStore';
import { ScheduleLocalStore } from './ScheduleLocalStore';
import { buildScheduleWidgetPayload, ScheduleWidgetPayload } from './ScheduleWidgetModel';

function registeredFormIds(filesDir: string): string[] {
  try {
    const value = JSON.parse(fs.readTextSync(filesDir + '/schedule_widget_ids.json')) as Object;
    return Array.isArray(value) ? value.filter((id: Object) => typeof id === 'string') as string[] : [];
  } catch (_) { return []; }
}

export function registerScheduleWidget(filesDir: string, formId: string, remove: boolean = false): void {
  const ids = registeredFormIds(filesDir).filter(id => id !== formId);
  if (!remove && formId.length > 0) ids.push(formId);
  const file = fs.openSync(filesDir + '/schedule_widget_ids.json', fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
  try { fs.writeSync(file.fd, JSON.stringify(ids)); } finally { fs.closeSync(file); }
}

export function loadScheduleWidgetPayload(filesDir: string): ScheduleWidgetPayload {
  const store = new ScheduleLocalStore({ filesDir });
  const info = store.loadScheduleInfo();
  const times = new PeriodTimesStore({ filesDir }).load();
  return buildScheduleWidgetPayload(store.loadCourses(), info && store.hasCachedCourses(info.term) ? info : null,
    times, new Date());
}

// Persist IDs so systems before API 20 can also update cards after a course sync.
export async function publishScheduleWidgets(filesDir: string): Promise<void> {
  const logger = new Logger('EntryFormAbility');
  try {
    const ids = registeredFormIds(filesDir);
    if (deviceInfo.sdkApiVersion >= 20) {
      const forms = await formProvider.getPublishedRunningFormInfos();
      for (const form of forms) {
        if (form.abilityName === 'EntryFormAbility' && ids.indexOf(form.formId) < 0) ids.push(form.formId);
      }
    }
    if (ids.length === 0) return;
    const payload = loadScheduleWidgetPayload(filesDir);
    const binding = formBindingData.createFormBindingData(payload);
    for (const formId of ids) {
      try {
        await formProvider.updateForm(formId, binding);
        try { await formProvider.setFormNextRefreshTime(formId, payload.refreshMinutes); }
        catch (error) { logger.warn('[FORM] using periodic refresh:', error); }
      } catch (error) {
        // A removed or expired preview must not prevent the other cards updating.
        logger.warn('[FORM] skipped unavailable card:', error);
      }
    }
    logger.info('[FORM] published cached schedule, count=', ids.length);
  } catch (error) {
    logger.warn('[FORM] publish deferred to scheduled refresh:', error);
  }
}
