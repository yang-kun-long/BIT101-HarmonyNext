// entry/src/main/ets/entryformability/EntryFormAbility.ets
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

import { SemesterStore, SemesterSnapshot } from '../services/storage/semesterStore';
import { PeriodTimesStore, TimesFilesCtx } from '../services/jw/periodTimesStore';
import { getDefaultPeriodTimes, PeriodTime } from '../services/jw/periodTimes';

/** —— 显式类型 —— */
interface TodayItem {
  id: string;
  period: number;
  span: number;
  name: string;
  room: string;
  time: string;                                  // 08:00-08:45
  status: 'done' | 'ongoing' | 'upcoming';       // 用于逻辑判断（可选）
  color: string;                                 // 同课同色
  periodSpanText: string;                        // “第1节×2”
  tagClass: TagClass;
  statusText: string;                            // “进行中/已结束/即将开始”
}

interface TodayPayload {
  title: string;
  date: string;                                  // 2025-10-10 周五
  now: string;                                   // 09:12
  items: TodayItem[];
  focusIndex: number;                            // 建议滚动到的索引
}
type TagClass = 'tag_ongoing' | 'tag_upcoming' | 'tag_done';

interface ContextWithFilesDir {
  filesDir: string;
}

/** —— 配置：当前学期 —— */
const SEMESTER_ID: string = '2025-fall';

/** —— 工具函数 —— */
function hhmm(): string {
  const d: Date = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function ymd(d: Date = new Date()): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function cmp(a: string, b: string): number { return a.localeCompare(b); }

/** —— 构建“今日课程”payload（仅用本地缓存） —— */
async function buildTodayPayload(filesDir: string): Promise<TodayPayload> {
  const semRoot: string = `${filesDir}/bit101/timetable`;
  const semStore: SemesterStore = new SemesterStore({ filesDir: semRoot });
  const snapshot: SemesterSnapshot | null = await semStore.loadSemester(SEMESTER_ID);

  const pStore: PeriodTimesStore = new PeriodTimesStore({ filesDir } as TimesFilesCtx);
  const periods: PeriodTime[] = pStore.load() || getDefaultPeriodTimes();

  const today: string = ymd();
  const now: string = hhmm();

  const items: TodayItem[] = (snapshot?.instances || [])
    .filter(ci => ci.dateISO === today)
    .sort((a, b) => a.startPeriod - b.startPeriod)
    .map((ci): TodayItem => {
      const startIdx: number = Math.max(0, ci.startPeriod - 1);
      const endIdx: number = Math.min(startIdx + Math.max(0, ci.span - 1), periods.length - 1);

      const pStart: PeriodTime | undefined = periods[startIdx];
      const pEnd: PeriodTime | undefined = periods[endIdx];
      const start: string = pStart ? pStart.start : '';
      const end: string = pEnd ? pEnd.end : '';
      const timeStr: string = (start && end) ? `${start}-${end}` : '';

      let status: 'done' | 'ongoing' | 'upcoming' = 'upcoming';
      if (start && end) {
        if (cmp(now, start) >= 0 && cmp(now, end) <= 0) status = 'ongoing';
        else if (cmp(now, end) > 0) status = 'done';
      }

      const colorMap: Record<string, string> | undefined = snapshot?.courseColors;
      const key: string = ci.courseKey || '';
      const color: string = (colorMap && colorMap[key]) ? colorMap[key] : '#64748B';

      const periodSpanText: string = ci.span > 1 ? `第${ci.startPeriod}节×${ci.span}` : `第${ci.startPeriod}节`;
      const statusText: string = status === 'ongoing' ? '进行中' : (status === 'done' ? '已结束' : '即将开始');
      const tagClass: TagClass =
        status === 'ongoing' ? 'tag_ongoing' :
          status === 'done'    ? 'tag_done'    :
            'tag_upcoming';
        status === 'ongoing' ? 'tag_ongoing' : (status === 'done' ? 'tag_done' : 'tag_upcoming');

      return {
        id: ci.instanceId,
        period: ci.startPeriod,
        span: ci.span,
        name: ci.title,
        room: ci.room || '',
        time: timeStr,
        status,
        color,
        periodSpanText,
        tagClass,
        statusText
      };
    });

  const ongoingIdx: number = items.findIndex(x => x.status === 'ongoing');
  let focusIndex: number = ongoingIdx >= 0 ? ongoingIdx : items.findIndex(x => x.status === 'upcoming');
  if (focusIndex < 0) focusIndex = 0;

  const wdList: string[] = ['日', '一', '二', '三', '四', '五', '六'];
  const wd: string = wdList[new Date().getDay()];

  const payload: TodayPayload = {
    title: '今日课程',
    date: `${today} 周${wd}`,
    now,
    items,
    focusIndex
  };
  return payload;
}

/** —— Ability —— */
export default class EntryFormAbility extends FormExtensionAbility {
  private filesDir: string = '';

  onCreate(want: Want): formBindingData.FormBindingData {
    const ctx: ContextWithFilesDir = this.context as ContextWithFilesDir;
    this.filesDir = (ctx && typeof ctx.filesDir === 'string') ? ctx.filesDir : '';

    const initPayload: TodayPayload = { title: '今日课程', date: '初始化中…', now: '', items: [], focusIndex: 0 };
    return formBindingData.createFormBindingData(initPayload);
  }

  async onUpdate(formId: string): Promise<void> {
    console.info('[FORM] onUpdate start');
    const payload: TodayPayload = await buildTodayPayload(this.filesDir);
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(payload));
      console.info('[FORM] onUpdate ok, items=', payload.items.length, ' focus=', payload.focusIndex);
    } catch (e) {
      console.error('[FORM] onUpdate updateForm failed: ', (e as Error).message);
    }
  }


  async onEvent(formId: string, message: string): Promise<void> {
    console.info('[FORM] onEvent formId=', formId, ' msg=', message);
    if (message === 'REFRESH_TODAY') await this.onUpdate(formId);
    try {
      if (message === 'REFRESH_TODAY') {
        await this.onUpdate(formId);
        console.info('[FORM] onEvent refreshed ok');
      } else {
        console.info('[FORM] onEvent ignored message');
      }
    } catch (e) {
      console.error('[FORM] onEvent error: ', (e as Error).message);
    }
  }


  onAcquireFormState(): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
