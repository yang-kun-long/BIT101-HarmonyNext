// entry/src/main/ets/services/jw/timetableRepository.ts
// 获取课程表：/courses/schedule -> 下载 .ics -> 本地解析 VEVENT
// 依赖：@ohos.net.http、TokenStore（读取 webvpn_cookie）
// 日志：全链路详细输出，可用 debug 开关控制

import http from '@ohos.net.http'
import { TokenStore } from '../storage/tokenStore'

export interface ScheduleLinkResp {
  url: string
  note: string
}

export interface CalendarEvent {
  uid?: string
  summary?: string
  location?: string
  description?: string
  dtstart?: string // ICS 原值
  dtend?: string   // ICS 原值
}

function redact(s: string, keepStart = 8, keepEnd = 6): string {
  const v = s || ''
  if (v.length <= keepStart + keepEnd) return '*'.repeat(v.length)
  return v.slice(0, keepStart) + '***' + v.slice(-keepEnd)
}

// 将超长文本拆段打印，避免日志系统截断
function logLarge(prefix: string, text: string, chunk = 1800) {
  const s = text ?? ''
  if (s.length <= chunk) {
    console.info(prefix + s)
    return
  }
  console.info(`${prefix}[len=${s.length}] ↓`)
  for (let i = 0; i < s.length; i += chunk) {
    const seg = s.slice(i, i + chunk)
    console.info(`${prefix}[${i}-${i + seg.length}] ${seg}`)
  }
}

// 尽量安全地解析 JSON，失败时返回 null
function safeJson<T>(txt: string): T | null {
  try { return JSON.parse(txt) as T } catch { return null }
}

export class TimetableRepository {
  private baseUrl: string
  private store = new TokenStore()
  private debug: boolean

  constructor(baseUrl: string = 'https://bit101.flwfdd.xyz', debug = true) {
    this.baseUrl = baseUrl.replace(/\/$/, '')
    this.debug = debug
  }

  // 1) 请求 /courses/schedule 拿 .ics 下载链接
  async getScheduleLink(): Promise<ScheduleLinkResp> {
    const cookie = await this.store.getWebvpnCookie()
    console.info(cookie)
    if (!cookie) {
      console.info(cookie)
      throw new Error('缺少 WebVPN 会话，请先完成教务登录,webvpn-cookie=$\{redact(cookie)}')
    }

    const url = this.baseUrl + '/courses/schedule'
    if (this.debug) {
      console.info(`[Timetable] GET ${url}`)
      console.info(`[Timetable] headers.webvpn-cookie=${redact(cookie)}`)
    }

    const client = http.createHttp()
    try {
      const res = await client.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json, text/plain, */*',
          'User-Agent': 'BIT101 HarmonyOS/1.0 (ArkTS)',
          // OpenAPI 指定使用 header: webvpn-cookie
          'webvpn-cookie': cookie,
        },
        readTimeout: 15000,
        connectTimeout: 15000
      })

      const code = res.responseCode
      const headers = JSON.stringify(res.header ?? {})
      const body = String(res.result ?? '')

      if (this.debug) {
        console.info(`[Timetable] /courses/schedule -> HTTP ${code}`)
        logLarge('[Timetable] response.headers: ', headers)
        logLarge('[Timetable] response.body: ', body)
      }

      if (code < 200 || code >= 300) {
        throw new Error(`/courses/schedule HTTP ${code}`)
      }

      // 兼容 { url, note } 或 { data: { url, note } }
      const obj = safeJson<{ url?: string; note?: string; data?: { url?: string; note?: string } }>(body)
      if (!obj) throw new Error('返回不是 JSON')
      const link = (obj.url ?? obj.data?.url) || ''
      const note = (obj.note ?? obj.data?.note) || ''
      if (!link) throw new Error('缺少 .ics 下载地址')

      if (this.debug) {
        console.info(`[Timetable] ics url = ${link}`)
        if (note) console.info(`[Timetable] note = ${note}`)
      }

      return { url: link, note }
    } finally {
      client.destroy()
    }
  }

  // 2) 下载 ICS 文本
  async downloadIcs(icsUrl: string): Promise<string> {
    if (this.debug) {
      console.info(`[Timetable] Download ICS: ${icsUrl}`)
    }
    const client = http.createHttp()
    try {
      const res = await client.request(icsUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'text/calendar, text/plain, */*',
          'User-Agent': 'BIT101 HarmonyOS/1.0 (ArkTS)',
          'Referer': this.baseUrl + '/'
        },
        readTimeout: 20000,
        connectTimeout: 15000
      })
      const code = res.responseCode
      const text = String(res.result ?? '')

      if (this.debug) {
        console.info(`[Timetable] ICS HTTP ${code}, length=${text.length}`)
        // 不建议全量打印 ICS（可能很长），仅打印前后 500 字
        const head = text.slice(0, 500)
        const tail = text.slice(-500)
        logLarge('[Timetable] ics.head: ', head)
        if (text.length > 1000) logLarge('[Timetable] ics.tail: ', tail)
      }

      if (code < 200 || code >= 300) {
        throw new Error(`下载 ICS 失败 HTTP ${code}`)
      }
      return text
    } finally {
      client.destroy()
    }
  }

  // 3) 解析 ICS（支持行折叠；提取 VEVENT 常见字段）
  parseIcs(icsText: string): CalendarEvent[] {
    if (!icsText) return []
    const lines = this.unfoldIcs(icsText)
    const events: CalendarEvent[] = []
    let cur: CalendarEvent | null = null

    for (let i = 0; i < lines.length; i++) {
      const raw = lines[i]
      const colon = raw.indexOf(':')
      const hasColon = colon >= 0
      const keyPart = hasColon ? raw.slice(0, colon) : raw
      const valPart = hasColon ? raw.slice(colon + 1) : ''

      // 去掉参数（如 DTSTART;TZID=Asia/Shanghai）
      const semi = keyPart.indexOf(';')
      const key = semi >= 0 ? keyPart.slice(0, semi) : keyPart

      if (key === 'BEGIN' && valPart === 'VEVENT') {
        cur = {}
      } else if (key === 'END' && valPart === 'VEVENT') {
        if (cur) events.push(cur)
        cur = null
      } else if (cur) {
        if (key === 'UID') cur.uid = valPart
        else if (key === 'SUMMARY') cur.summary = this.unescapeIcs(valPart)
        else if (key === 'LOCATION') cur.location = this.unescapeIcs(valPart)
        else if (key === 'DESCRIPTION') cur.description = this.unescapeIcs(valPart)
        else if (key === 'DTSTART') cur.dtstart = valPart
        else if (key === 'DTEND') cur.dtend = valPart
      }
    }

    if (this.debug) {
      console.info(`[Timetable] Parsed events: ${events.length}`)
    }
    return events
  }

  // 4) 组合：请求链接 + 下载 + 解析
  async getScheduleEvents(): Promise<{ note: string; events: CalendarEvent[] }> {
    const link = await this.getScheduleLink()
    const ics = await this.downloadIcs(link.url)
    const events = this.parseIcs(ics)

    if (this.debug) {
      // 打印前 3 个事件概要
      const previewCount = Math.min(events.length, 3)
      for (let i = 0; i < previewCount; i++) {
        const e = events[i]
        console.info(`[Timetable] ev#${i + 1}: ${e.summary ?? '(未命名)'} | ${this.formatIcsDate(e.dtstart)} ~ ${this.formatIcsDate(e.dtend)} | ${e.location ?? ''}`)
      }
    }

    return { note: link.note, events }
  }

  // ----- ICS 工具 -----
  private unfoldIcs(text: string): string[] {
    // 行折叠：以空格或制表符开头的行拼接到前一行
    const raw = text.replace(/\r\n/g, '\n').split('\n')
    const out: string[] = []
    for (let i = 0; i < raw.length; i++) {
      const line = raw[i]
      if (out.length > 0 && (line.startsWith(' ') || line.startsWith('\t'))) {
        out[out.length - 1] = out[out.length - 1] + line.slice(1)
      } else {
        out.push(line)
      }
    }
    return out
  }

  private unescapeIcs(s: string): string {
    return s
      .replace(/\\n/g, '\n')
      .replace(/\\,/g, ',')
      .replace(/\\;/g, ';')
      .replace(/\\\\/g, '\\')
  }

  // 把 ICS 的时间（如 20250930T090000Z / 20250930T090000）渲染为人类可读
  formatIcsDate(ics: string | undefined): string {
    if (!ics) return ''
    const z = ics.endsWith('Z')
    const core = z ? ics.slice(0, -1) : ics
    const y = core.slice(0, 4)
    const m = core.slice(4, 6)
    const d = core.slice(6, 8)
    if (core.length <= 8) return `${y}-${m}-${d}`
    const T = core.indexOf('T')
    const hh = core.slice(T + 1, T + 3)
    const mm = core.slice(T + 3, T + 5)
    const hasSec = core.length >= T + 7
    const ss = hasSec ? core.slice(T + 5, T + 7) : ''
    return `${y}-${m}-${d} ${hh}:${mm}${hasSec ? ':' + ss : ''}${z ? 'Z' : ''}`
  }
}
