// src/main/ets/services/jw/normalize.ts
import { CalendarEvent } from './timetableRepository'
import { CourseInstance, RawIcsEvent } from '../storage/semesterStore'

export interface ToInstancesDeps {
  parseIcsToDate: (s?: string) => Date | null
  periodIndexByStart: (d: Date) => number
  periodSpanByStartEnd: (s: Date, e: Date) => number
  sanitizeLocation: (s?: string) => string
  trimTitle: (name?: string, span?: number) => string
  fmtDateISO: (d: Date) => string
  weekStartISOOf: (anyDayISO: string) => string
}

// ---------------- 工具：保真字段/课程键 ----------------

function normalizeName(x?: string): string {
  return (x || '').trim().replace(/\s+/g, ' ').toLowerCase()
}

/** 从原始描述/原文里提取教师名（尽力而为；没有就返回空） */
function pickTeacherFromRawLike(description?: string, rawText?: string): string {
  const pool = ((description || '') + '\n' + (rawText || ''))
  const m = /(?:教师|老师|teacher)\s*[:：]\s*([^\n;]+)/i.exec(pool)
  return m ? m[1].trim() : ''
}

/** 生成课程归并键：课名+教师（都做 normalize） */
function makeCourseKey(title: string, teacher: string): string {
  return `${normalizeName(title)}|${normalizeName(teacher)}`
}

/** 把已有字段合成为一个最小可用的 VEVENT 原文 */
function synthesizeVeventText(ev: CalendarEvent): string {
  const L = (k: string, v?: string) => (v && v.length > 0) ? `${k}:${v}` : ''
  const lines = [
    'BEGIN:VEVENT',
    L('UID', ev.uid),
    L('SUMMARY', ev.summary),
    L('DESCRIPTION', ev.description),
    L('LOCATION', ev.location),
    L('DTSTART', ev.dtstart),
    L('DTEND', ev.dtend),
    // 你也可以继续加：RRULE/EXDATE/ORGANIZER/...
    'END:VEVENT'
  ].filter(Boolean)
  return lines.join('\n')
}

/** 把常见直达字段包装成 props（兜底用） */
function synthesizeProps(ev: CalendarEvent): Array<{ name: string; params?: Record<string, string>; value: string }> {
  const push = (arr: any[], name: string, v?: string) => { if (v && v.length > 0) arr.push({ name, value: v }) }
  const out: Array<{ name: string; params?: Record<string, string>; value: string }> = []
  push(out, 'UID', ev.uid)
  push(out, 'SUMMARY', ev.summary)
  push(out, 'DESCRIPTION', ev.description)
  push(out, 'LOCATION', ev.location)
  push(out, 'DTSTART', ev.dtstart)
  push(out, 'DTEND', ev.dtend)
  // 可按需继续补充 RRULE/EXDATE...
  return out
}

// ---------------- RawIcsEvent：宽松拷贝 + 保真字段 ----------------

/**
 * 宽松拷贝 CalendarEvent 到 RawIcsEvent：
 * - 拷贝常见字符串/数组字段
 * - 优先使用上游解析器提供的 __veventText/__props（或 rawText/props）
 * - 若无，则合成最小 VEVENT 与 props 兜底
 */
function copyRawWithFidelity(ev: CalendarEvent): RawIcsEvent {
  const out: RawIcsEvent = {}
  const src = ev as unknown as Record<string, unknown>

  // 1) 常见核心字段优先拷贝（string/string[]）
  const keys = [
    'uid','summary','description','location','dtstart','dtend',
    'rrule','exdate','organizer','status','categories','url','sequence',
    'created','lastModified','transp','alarm'
  ]
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    const v = src[k]
    if (typeof v === 'string') {
      out[k] = v
    } else if (Array.isArray(v)) {
      const arr: string[] = []
      for (let j = 0; j < v.length; j++) {
        const it = v[j]
        if (typeof it === 'string') arr.push(it)
      }
      if (arr.length > 0) out[k] = arr
    }
  }

  // 2) 兜底：拷贝其它可序列化的 string / string[]
  for (const k in src) {
    if (out[k] !== undefined) continue
    const v = src[k]
    if (typeof v === 'string') out[k] = v
    else if (Array.isArray(v)) {
      const arr: string[] = []
      for (let j = 0; j < v.length; j++) if (typeof v[j] === 'string') arr.push(v[j] as string)
      if (arr.length > 0) out[k] = arr
    }
  }

  // 3) 保真字段：优先用上游解析器提供的原文/属性
  const veventText = (src['__veventText'] as string) || (src['rawText'] as string)
  const props = (src['__props'] as Array<{ name: string; params?: Record<string, string>; value: string }>)
    || (src['props'] as Array<{ name: string; params?: Record<string, string>; value: string }>)

  if (veventText && veventText.length > 0) {
    (out as any).rawText = veventText
  } else {
    // 没有的话，合成一个最小可用的 VEVENT 原文
    (out as any).rawText = synthesizeVeventText(ev)
  }

  if (Array.isArray(props) && props.length > 0) {
    (out as any).props = props
  } else {
    // 没有的话，合成最小 props
    (out as any).props = synthesizeProps(ev)
  }

  return out
}

// ---------------- 主导出：events -> CourseInstance[] ----------------

export function eventsToInstances(events: CalendarEvent[], deps: ToInstancesDeps): CourseInstance[] {
  const out: CourseInstance[] = []
  for (let i = 0; i < events.length; i++) {
    const ev = events[i]

    const s = deps.parseIcsToDate(ev.dtstart)
    const e = deps.parseIcsToDate(ev.dtend)
    if (!s || !e) continue

    const startPeriod = deps.periodIndexByStart(s)
    const span = deps.periodSpanByStartEnd(s, e)
    const dateISO = deps.fmtDateISO(s)
    const weekStartISO = deps.weekStartISOOf(dateISO)
    const title = deps.trimTitle(ev.summary, span)
    const room = deps.sanitizeLocation(ev.location)
    const id = (ev.uid && ev.uid.length > 0) ? ev.uid : `${dateISO}-${startPeriod}-${title}-${room}`

    // 构造 raw（含保真字段）
    const raw = copyRawWithFidelity(ev)

    // 尝试从 raw 中提取教师名 & 生成课程键（供同课同色）
    const teacher = pickTeacherFromRawLike(raw.description as string, (raw as any).rawText as string)
    const courseKey = makeCourseKey(ev.summary || title || '', teacher)

    out.push({
      instanceId: id,
      dateISO,
      weekStartISO,
      startPeriod,
      span,
      title,
      room,
      raw,                     // ✅ 包含 rawText/props
      teacher,                 // ✅ 尽力填；没解析出来则为空字符串
      courseKey,               // ✅ 和 SemesterStore 的规则一致
      rawUid: ev.uid,
      rawDtStart: ev.dtstart,
      rawDtEnd: ev.dtend
    })
  }

  // 先按日期，再按节次排序
  out.sort((a, b) => a.dateISO === b.dateISO ? (a.startPeriod - b.startPeriod) : a.dateISO.localeCompare(b.dateISO))
  return out
}
