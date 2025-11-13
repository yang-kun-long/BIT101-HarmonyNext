// entry/src/main/ets/utils/scheduleUtils.ts

import type { RawIcsEvent } from '../services/storage/semesterStore'
import type { CalendarEvent } from '../services/jw/timetableRepository'

// ---------- 日期/格式化 ----------
export function pad2(n: number): string { return n < 10 ? '0' + n : '' + n }
export function fmtDate(d: Date): string { return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}` }

export function mondayOf(d: Date): Date {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const wd = x.getDay() === 0 ? 7 : x.getDay()
  if (wd > 1) x.setDate(x.getDate() - (wd - 1))
  return x
}

export function addDaysISO(iso: string, days: number): string {
  const parts = iso.split('-')
  const y = parseInt(parts[0]); const m = parseInt(parts[1]) - 1; const dd = parseInt(parts[2])
  const t = new Date(y, m, dd)
  t.setDate(t.getDate() + days)
  return fmtDate(t)
}

export function isSameDate(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

// 把 YYYY-MM-DD（任意一天）映射成这一周的周一 ISO 字符串
export function weekStartOfISO(anyDayISO: string): string {
  const p = anyDayISO.split('-')
  const y = parseInt(p[0]); const m = parseInt(p[1]) - 1; const d = parseInt(p[2])
  const monday = mondayOf(new Date(y, m, d))
  return fmtDate(monday)
}

// ---------- 字符串/课程 ----------
export function sanitizeLocation(loc?: string): string {
  if (!loc) return ''
  let s = loc.replace(/北京理工大学(\(.*?\))?/g, '')
  s = s.replace(/^\s*[-、·,，]/, '').replace(/[-、·,，]\s*$/,'').trim()
  return s
}

function normalizeName(x?: string): string {
  return (x || '').trim().replace(/\s+/g, ' ').toLowerCase()
}

function pickTeacherFromRaw(raw?: RawIcsEvent | null): string {
  if (!raw) return ''
  const desc = (raw.description || '') + '\n' + (raw.rawText || '')
  const m = /(?:教师|老师|teacher)\s*[:：]\s*([^\n;]+)/i.exec(desc)
  return m ? m[1].trim() : ''
}

export function makeCourseKeyForCard(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
  // 课名优先用 raw.summary，其次 ev.summary
  const title = normalizeName(raw?.summary || (ev?.summary || ''))
  // 教师优先 raw 解析
  const teacher = normalizeName(pickTeacherFromRaw(raw))
  return `${title}|${teacher}`
}

export function parseIcsToDate(ics: string | undefined): Date | null {
  if (!ics) return null
  const z = ics.endsWith('Z')
  const s = z ? ics.slice(0, -1) : ics
  const T = s.indexOf('T')
  const y = parseInt(s.slice(0, 4)); const m = parseInt(s.slice(4, 6)) - 1; const d = parseInt(s.slice(6, 8))
  let hh = 0; let mm = 0; let ss = 0
  if (T >= 0) {
    hh = parseInt(s.slice(T + 1, T + 3))
    mm = parseInt(s.slice(T + 3, T + 5))
    if (s.length >= T + 7) ss = parseInt(s.slice(T + 5, T + 7))
  }
  return new Date(y, m, d, hh, mm, ss)
}