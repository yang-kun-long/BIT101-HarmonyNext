// entry/src/main/ets/services/jw/layoutFromInstances.ts
import { CourseInstance, RawIcsEvent } from '../storage/semesterStore'
import { CalendarEvent } from './timetableRepository'

export interface DayBlock {
  kind: number;             // 0=空白,1=课程
  units: number;
  ev?: CalendarEvent;       // 供卡片展示用（summary/location）
  raw?: RawIcsEvent;        // 🔽 详情弹窗用：完整 ICS 字段
}
export interface DayLayout { dateISO: string; blocks: DayBlock[] }

export function layoutsFromInstances(weekStartISO: string, instances: CourseInstance[]): DayLayout[] {
  const out: DayLayout[] = []
  for (let i = 0; i < 7; i++) out.push({ dateISO: addDaysISO(weekStartISO, i), blocks: [] })

  for (let i = 0; i < instances.length; i++) {
    const it = instances[i]
    const idx = dayIndex(weekStartISO, it.dateISO)
    if (idx < 0 || idx > 6) continue
    const col = out[idx].blocks

    let cursor = currentTailPeriods(col)
    if (cursor < 1) cursor = 1
    const gap = it.startPeriod - cursor
    if (gap > 0) { col.push({ kind: 0, units: gap }); cursor += gap }

    // 🔽 课程块：保留 raw
    col.push({
      kind: 1,
      units: it.span,
      ev: { summary: it.title, location: it.room, dtstart: it.rawDtStart, dtend: it.rawDtEnd } as unknown as CalendarEvent,
      raw: it.raw
    })
    cursor += it.span
  }

  for (let i = 0; i < out.length; i++) {
    const used = currentTailPeriods(out[i].blocks) - 1
    const tail = 13 - used
    if (tail > 0) out[i].blocks.push({ kind: 0, units: tail })
  }
  return out
}


// 工具：给出该列已占用的节次数（块累加）
function currentTailPeriods(blocks: DayBlock[]): number {
  let sum = 0;
  for (let i = 0; i < blocks.length; i++) sum += blocks[i].units;
  return sum + 1;
}

// 工具：iso 加天数
function addDaysISO(iso: string, days: number): string {
  const p = iso.split('-'); const y = parseInt(p[0]); const m = parseInt(p[1]) - 1; const d = parseInt(p[2]);
  const t = new Date(y, m, d); t.setDate(t.getDate() + days);
  const mm = (t.getMonth() + 1).toString().padStart(2, '0');
  const dd = t.getDate().toString().padStart(2, '0');
  return `${t.getFullYear()}-${mm}-${dd}`;
}
function dayIndex(weekStartISO: string, dateISO: string): number {
  const a = new Date(weekStartISO); const b = new Date(dateISO);
  const ms = b.getTime() - a.getTime();
  const idx = Math.floor(ms / 86400000);
  return idx;
}
