// entry/src/main/ets/components/schedule/CourseDetailDialog.ets

import type { RawIcsEvent } from '../../services/storage/semesterStore'
import type { CalendarEvent } from '../../services/jw/timetableRepository'
import type { PeriodTime } from '../../services/jw/periodTimes'
import { parseIcsToDate, sanitizeLocation } from '../../utils/scheduleUtils'

@Component
export struct CourseDetailDialog {
  // --- Props ---
  @Prop show: boolean
  ev: CalendarEvent | null = null
  raw: RawIcsEvent | null = null
  baseFont: number = 12
  periodTimes: PeriodTime[] = []

  // --- Callback ---
  onClose: () => void = () => {}

  // --- Period Helpers (dependent on periodTimes) ---
  private parseHHMMToMin(hhmm?: string): number | null {
    if (!hhmm || typeof hhmm !== 'string') return null
    const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim())
    if (!m) return null
    const h = parseInt(m[1], 10), mm = parseInt(m[2], 10)
    if (h < 0 || h > 23 || mm < 0 || mm > 59) return null
    return h * 60 + mm
  }

  private startMinOf(i1: number): number {
    const idx = i1 - 1
    const t = (this.periodTimes && this.periodTimes.length === 13) ? this.periodTimes[idx] : null
    const m = t ? this.parseHHMMToMin(t.start) : null
    if (m == null) return 8 * 60 + (idx * 50)
    return m
  }

  private endMinOf(i1: number): number {
    const idx = i1 - 1
    const t = (this.periodTimes && this.periodTimes.length === 13) ? this.periodTimes[idx] : null
    const mEnd = t ? this.parseHHMMToMin(t.end) : null
    if (mEnd != null) return mEnd
    const nextStart = (idx < 12) ? this.startMinOf(i1 + 1) : null
    if (nextStart != null) return nextStart
    return this.startMinOf(i1) + 50
  }

  private minutesOfDay(dt: Date): number { return dt.getHours() * 60 + dt.getMinutes() }

  private periodIndexByStart(dt: Date): number {
    const m = this.minutesOfDay(dt)
    for (let i1 = 1; i1 <= 13; i1++) {
      const st = this.startMinOf(i1)
      const ed = this.endMinOf(i1)
      if (m >= st && m < ed) return i1
    }
    if (m < this.startMinOf(1)) return 1
    return 13
  }

  private periodSpanByStartEnd(start: Date, end: Date): number {
    const sIdx = this.periodIndexByStart(start)
    const endMin = this.minutesOfDay(end)
    let eIdx = sIdx
    for (let probe = sIdx; probe <= 13; probe++) {
      const e = this.endMinOf(probe)
      if (endMin <= e) { eIdx = probe; break }
      eIdx = probe
    }
    const span = eIdx - sIdx + 1
    return span < 1 ? 1 : span
  }

  // --- String Formatters ---
  private rawAsPrettyJson(raw: RawIcsEvent | null): string {
    if (!raw) return ''
    return JSON.stringify(raw, null, 2)
  }

  private evTitle(): string {
    if (this.raw && typeof this.raw.summary === 'string' && this.raw.summary.length > 0) {
      return this.raw.summary;
    }
    if (this.ev && this.ev.summary && this.ev.summary.length > 0) return this.ev.summary;
    return '(未命名)';
  }

  private evRoom(): string {
    if (this.raw && typeof this.raw.location === 'string' && this.raw.location.length > 0) {
      return sanitizeLocation(this.raw.location);
    }
    if (this.ev && this.ev.location) return sanitizeLocation(this.ev.location);
    return '';
  }

  private evDateStr(): string {
    const sIcs = (this.raw && this.raw.dtstart) ? String(this.raw.dtstart) : (this.ev ? this.ev.dtstart : undefined);
    const s = parseIcsToDate(sIcs);
    if (!s) return '';
    return `${s.getFullYear()}-${(s.getMonth()+1).toString().padStart(2,'0')}-${s.getDate().toString().padStart(2,'0')}`;
  }

  private evTimeStr(): string {
    const sIcs = (this.raw && this.raw.dtstart) ? String(this.raw.dtstart) : (this.ev ? this.ev.dtstart : undefined);
    const eIcs = (this.raw && this.raw.dtend)   ? String(this.raw.dtend)   : (this.ev ? this.ev.dtend   : undefined);
    const s = parseIcsToDate(sIcs);
    const e = parseIcsToDate(eIcs);
    if (!s || !e) return '';
    const f = (n:number)=>n.toString().padStart(2,'0');
    return `${f(s.getHours())}:${f(s.getMinutes())} - ${f(e.getHours())}:${f(e.getMinutes())}`;
  }

  private evPeriodsStr(): string {
    const sIcs = (this.raw && this.raw.dtstart) ? String(this.raw.dtstart) : (this.ev ? this.ev.dtstart : undefined);
    const eIcs = (this.raw && this.raw.dtend)   ? String(this.raw.dtend)   : (this.ev ? this.ev.dtend   : undefined);
    const s = parseIcsToDate(sIcs);
    const e = parseIcsToDate(eIcs);
    if (!s || !e) return '';
    const sp = this.periodIndexByStart(s);
    const span = this.periodSpanByStartEnd(s, e);
    const ep = sp + span - 1;
    return `第 ${sp} - ${ep} 节（共 ${span} 节）`;
  }

  build() {

    if (this.show && this.ev) {
      Stack() {
        Row() { }
        .width('100%').height('100%')
        .onClick(() => this.onClose())

        Column() {
          Text(this.evTitle())
            .fontSize(18).fontWeight(FontWeight.Bold)
            .maxLines(10)
            .textOverflow({ overflow: TextOverflow.Clip })

          Text(this.evDateStr() + '  ' + this.evTimeStr())
            .fontSize(this.baseFont).fontColor('#6B7280')
            .margin({ top: 6 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Clip })

          Text(this.evPeriodsStr())
            .fontSize(this.baseFont).fontColor('#6B7280')
            .margin({ top: 2 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Clip })

          if (this.evRoom().length > 0) {
            Text('教室：' + this.evRoom())
              .fontSize(14)
              .margin({ top: 10 })
              .maxLines(10)
              .textOverflow({ overflow: TextOverflow.Clip })
          }

          if (this.raw) {
            Text('—— ICS 原始字段 ——')
              .fontSize(12).fontColor('#6B7280').margin({ top: 12, bottom: 4 })
            Scroll() {
              Text(this.rawAsPrettyJson(this.raw))
                .fontSize(12)
                .textOverflow({ overflow: TextOverflow.Clip })
            }
            .height(160)
            .backgroundColor('#F9FAFB')
            .borderRadius(8)
            .padding(8)
          }

          Row() {
            Blank()
            Button('关闭').type(ButtonType.Capsule).onClick(() => this.onClose())
          }.margin({ top: 12 })
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .width('86%')
        .height('72%')
        .align(Alignment.Center)
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        console.info('[Dialog] appear. show=', this.show,
          ', evTitle=', this.evTitle())
      })
    }
  }
}