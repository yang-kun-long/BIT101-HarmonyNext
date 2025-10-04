import fileIo from '@ohos.file.fs'
import { __setPeriodTimesInMemory, getDefaultPeriodTimes, PeriodTime } from './periodTimes'
import util from '@ohos.util'


// 与其它仓库一致的文件上下文（filesDir 来自 EntryAbility 注入）
export interface TimesFilesCtx { filesDir: string }

const PERIOD_TIMES_FILENAME = 'period_times.json';

export class PeriodTimesStore {
  constructor(private ctx: TimesFilesCtx) {}

  private filePath(): string {
    const base = this.ctx.filesDir || '';
    return base.endsWith('/') ? (base + PERIOD_TIMES_FILENAME) : (base + '/' + PERIOD_TIMES_FILENAME);
  }

  // 读取：文件不存在或不合法时落回默认
  load(): PeriodTime[] {
    try {
      const p = this.filePath();
      if (!p) return getDefaultPeriodTimes();
      if (!fileIo.accessSync(p)) {
        const def = getDefaultPeriodTimes();
        this.save(def);          // 首次落盘
        __setPeriodTimesInMemory(def);
        return def;
      }
      const fd = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(p);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(fd.fd, buf, { offset: 0 });
        const txt = String.fromCharCode.apply(null, Array.from(new Uint8Array(buf)) as unknown as number[]);
        const obj = JSON.parse(txt);
        if (Array.isArray(obj) && obj.length === 13) {
          const list: PeriodTime[] = obj.map((it: any) => ({ start: String(it.start || ''), end: String(it.end || '') }));
          __setPeriodTimesInMemory(list);
          return list;
        }
        const def = getDefaultPeriodTimes();
        __setPeriodTimesInMemory(def);
        return def;
      } finally {
        fileIo.closeSync(fd);
      }
    } catch (_e) {
      const def = getDefaultPeriodTimes();
      __setPeriodTimesInMemory(def);
      return def;
    }
  }

  // 保存（后续你开放“调整作息时间”的接口时会调用）
  save(list: PeriodTime[]): void {
    try {
      const p = this.filePath();
      if (!p) return;
      const json = JSON.stringify(list, null, 2);
      const fd = fileIo.openSync(p, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY);
      try {
        const encoder = new util.TextEncoder();
        const bytes = encoder.encode(json);            // Uint8Array
        fileIo.writeSync(fd.fd, bytes.buffer);         // 写入 ArrayBuffer
      } finally {
        fileIo.closeSync(fd);
      }
      __setPeriodTimesInMemory(list);
    } catch (_e) {
      // 忽略写入错误；必要时可上报日志
    }
  }
}
