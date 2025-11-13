// src/main/ets/services/jw/periodTimesStore.ts
import fileIo from '@ohos.file.fs'
import util from '@ohos.util'
import { __setPeriodTimesInMemory, getDefaultPeriodTimes, PeriodTime } from './periodTimes'

export interface TimesFilesCtx { filesDir: string }

const PERIOD_TIMES_FILENAME = 'period_times.json';

export class PeriodTimesStore {
  constructor(private ctx: TimesFilesCtx) {}

  private filePath(): string {
    const base = this.ctx.filesDir || ''
    return base.endsWith('/') ? (base + PERIOD_TIMES_FILENAME) : (base + '/' + PERIOD_TIMES_FILENAME);
  }

  load(): PeriodTime[] {
    const p = this.filePath()
    try {
      console.info('[PTS] load.path =', p)
      const parent = p.slice(0, Math.max(0, p.lastIndexOf('/')))
      try {
        const parentOk = parent ? fileIo.accessSync(parent) : false
        console.info('[PTS] parent.exists =', parentOk, ' parent =', parent)
      } catch (pe) {
        console.error('[PTS] parent.access error =', (pe as Error).message, ' parent =', parent)
      }

      let exists = false
      try {
        exists = fileIo.accessSync(p)
        console.info('[PTS] file.exists =', exists)
      } catch (ae) {
        console.error('[PTS] file.access error =', (ae as Error).message)
      }

      if (!exists) {
        const def = getDefaultPeriodTimes()
        console.info('[PTS] file not exist -> save default')
        this.save(def)          // 首次落盘
        __setPeriodTimesInMemory(def)
        return def
      }

      const fd = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY)
      try {
        const stat = fileIo.statSync(p)
        console.info('[PTS] file.size =', stat.size)
        const buf = new ArrayBuffer(stat.size)
        fileIo.readSync(fd.fd, buf, { offset: 0 })
        const txt = String.fromCharCode.apply(null, Array.from(new Uint8Array(buf)) as unknown as number[])
        const obj = JSON.parse(txt)
        const okArr = Array.isArray(obj) && obj.length === 13
        console.info('[PTS] json.okArr =', okArr)
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
      console.error('[PTS] load.failed =', (e as Error).message, ' path =', p)
      const def = getDefaultPeriodTimes()
      __setPeriodTimesInMemory(def)
      return def
    }
  }

  save(list: PeriodTime[]): void {
    const p = this.filePath()
    try {
      console.info('[PTS] save.path =', p)
      const parent = p.slice(0, Math.max(0, p.lastIndexOf('/')))
      try {
        const parentOk = parent ? fileIo.accessSync(parent) : false
        console.info('[PTS] save.parent.exists =', parentOk, ' parent =', parent)
      } catch (pe) {
        console.error('[PTS] save.parent.access error =', (pe as Error).message, ' parent =', parent)
      }

      const json = JSON.stringify(list, null, 2)
      const fd = fileIo.openSync(p, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.WRITE_ONLY)
      try {
        const encoder = new util.TextEncoder()
        const bytes = encoder.encode(json)
        console.info('[PTS] save.bytes =', bytes.byteLength)
        fileIo.writeSync(fd.fd, bytes.buffer)
      } finally {
        try { fileIo.closeSync(fd) } catch {}
      }
      __setPeriodTimesInMemory(list)
      console.info('[PTS] save.ok')
    } catch (e) {
      console.error('[PTS] save.failed =', (e as Error).message, ' path =', p)
    }
  }
}
