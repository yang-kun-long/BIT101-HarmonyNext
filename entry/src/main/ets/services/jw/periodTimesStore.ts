// src/main/ets/services/jw/periodTimesStore.ts
import { Logger } from '../../utils/Logger';
import fileIo from '@ohos.file.fs'
import util from '@ohos.util'
import { __setPeriodTimesInMemory, getDefaultPeriodTimes, PeriodTime } from './periodTimes'

export interface TimesFilesCtx { filesDir: string }

const PERIOD_TIMES_FILENAME = 'period_times.json';

export class PeriodTimesStore {
  private logger = new Logger('PeriodTimesStore');
  constructor(private ctx: TimesFilesCtx) {}

  private filePath(): string {
    const base = this.ctx.filesDir || ''
    return base.endsWith('/') ? (base + PERIOD_TIMES_FILENAME) : (base + '/' + PERIOD_TIMES_FILENAME);
  }

  load(): PeriodTime[] {
    const p = this.filePath()
    try {
      this.logger.debug('load path:', p);
      const parent = p.slice(0, Math.max(0, p.lastIndexOf('/')))
      try {
        const parentOk = parent ? fileIo.accessSync(parent) : false
        this.logger.debug('parent check:', parentOk, 'parent:', parent);
      } catch (pe) {
        this.logger.debug('parent access check failed (expected if first run):', pe, 'parent:', parent);
      }

      let exists = false
      try {
        exists = fileIo.accessSync(p)
        this.logger.debug('file exists:', exists);
      } catch (ae) {
        this.logger.debug('file access check failed:', ae);
      }

      if (!exists) {
        const def = getDefaultPeriodTimes()
        this.logger.info('file not found, initializing default values.');
        this.save(def)          // 首次落盘
        __setPeriodTimesInMemory(def)
        return def
      }

      const fd = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY)
      try {
        const stat = fileIo.statSync(p)
        this.logger.debug('file size:', stat.size);
        const buf = new ArrayBuffer(stat.size)
        fileIo.readSync(fd.fd, buf, { offset: 0 })
        const txt = String.fromCharCode.apply(null, Array.from(new Uint8Array(buf)) as unknown as number[])
        const obj = JSON.parse(txt)
        const okArr = Array.isArray(obj) && obj.length === 13
        this.logger.debug('loaded json content:', okArr);
        if (okArr) {
          const list: PeriodTime[] = obj.map((it: any) => ({ start: String(it.start || ''), end: String(it.end || '') }))
          __setPeriodTimesInMemory(list)
          return list
        }
        const def = getDefaultPeriodTimes()
        __setPeriodTimesInMemory(def)
        return def
      } finally {
        try { fileIo.closeSync(fd) } catch {}
      }
    } catch (e) {
      this.logger.error('load failed:', e, 'path:', p);
      const def = getDefaultPeriodTimes()
      __setPeriodTimesInMemory(def)
      return def
    }
  }

  save(list: PeriodTime[]): void {
    const p = this.filePath()
    try {
      this.logger.debug('save path:', p);
      const parent = p.slice(0, Math.max(0, p.lastIndexOf('/')))
      try {
        const parentOk = parent ? fileIo.accessSync(parent) : false
        this.logger.debug('save parent check:', parentOk, 'parent:', parent);
      } catch (pe) {
        this.logger.debug('save parent access check failed:', pe, 'parent:', parent);
      }

      const json = JSON.stringify(list, null, 2)
      const fd = fileIo.openSync(p, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY)
      try {
        const encoder = new util.TextEncoder()
        const bytes = encoder.encodeInto(json)
        this.logger.debug('save bytes:', bytes.byteLength);
        fileIo.writeSync(fd.fd, bytes.buffer)
      } finally {
        try { fileIo.closeSync(fd) } catch {}
      }
      __setPeriodTimesInMemory(list)
      this.logger.debug('save success');
    } catch (e) {
      this.logger.error('save failed:', e, 'path:', p);
    }
  }
}
