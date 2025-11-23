// entry/src/main/ets/components/schedule/CourseDetailDialog.ets

import type { RawIcsEvent } from '../../services/storage/semesterStore'
import type { CalendarEvent } from '../../services/jw/timetableRepository'
import type { PeriodTime } from '../../services/jw/periodTimes'
import { parseIcsToDate, sanitizeLocation } from '../../utils/scheduleUtils'

@Component
export struct CourseDetailDialog {
  // --- Props ---
  @Prop ev: CalendarEvent | null
  @Prop raw: RawIcsEvent | null
  @Prop baseFont: number = 12
  @Prop periodTimes: PeriodTime[] = []

  // --- Callback ---
  onClose: () => void = () => {}

  // --- 动画状态 ---
  @State private opacityVal: number = 0
  @State private scaleVal: number = 0.96
  @State private offsetY: number = 24

  // 组件挂载时做入场动画
  aboutToAppear(): void {
    console.info('[CourseDetailDialog] aboutToAppear, evTitle=', this.evTitle())

    this.opacityVal = 0
    this.scaleVal = 0.96
    this.offsetY = 24

    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.opacityVal = 1
      this.scaleVal = 1
      this.offsetY = 0
    })
  }

  private closeAnim(): void {
    // 退场动画：淡出 + 下沉 + 略缩小
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.opacityVal = 0
      this.scaleVal = 0.96
      this.offsetY = 24
      this.onClose()
    })
  }

  private handleMaskClick(): void {
    this.closeAnim()
  }

  private handleCloseBtn(): void {
    this.closeAnim()
  }

  // ================== 课次计算 ==================

  private parseHHMMToMin(hhmm?: string): number | null {
    if (!hhmm || typeof hhmm !== 'string') return null
    const m: RegExpExecArray | null = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim())
    if (!m) return null
    const h: number = parseInt(m[1], 10)
    const mm: number = parseInt(m[2], 10)
    if (h < 0 || h > 23 || mm < 0 || mm > 59) return null
    return h * 60 + mm
  }

  private startMinOf(i1: number): number {
    const idx: number = i1 - 1
    const t: PeriodTime | null =
      this.periodTimes && this.periodTimes.length === 13 ? this.periodTimes[idx] : null
    const m: number | null = t ? this.parseHHMMToMin(t.start) : null
    if (m == null) return 8 * 60 + idx * 50
    return m
  }

  private endMinOf(i1: number): number {
    const idx: number = i1 - 1
    const t: PeriodTime | null =
      this.periodTimes && this.periodTimes.length === 13 ? this.periodTimes[idx] : null
    const mEnd: number | null = t ? this.parseHHMMToMin(t.end) : null
    if (mEnd != null) return mEnd
    const nextStart: number | null = idx < 12 ? this.startMinOf(i1 + 1) : null
    if (nextStart != null) return nextStart
    return this.startMinOf(i1) + 50
  }

  private minutesOfDay(dt: Date): number {
    return dt.getHours() * 60 + dt.getMinutes()
  }

  private periodIndexByStart(dt: Date): number {
    const m: number = this.minutesOfDay(dt)
    for (let i1 = 1; i1 <= 13; i1++) {
      const st: number = this.startMinOf(i1)
      const ed: number = this.endMinOf(i1)
      if (m >= st && m < ed) return i1
    }
    if (m < this.startMinOf(1)) return 1
    return 13
  }

  private periodSpanByStartEnd(start: Date, end: Date): number {
    const sIdx: number = this.periodIndexByStart(start)
    const endMin: number = this.minutesOfDay(end)
    let eIdx: number = sIdx
    for (let probe = sIdx; probe <= 13; probe++) {
      const e: number = this.endMinOf(probe)
      if (endMin <= e) {
        eIdx = probe
        break
      }
      eIdx = probe
    }
    const span: number = eIdx - sIdx + 1
    return span < 1 ? 1 : span
  }

  // ================== 字段提取 & 格式化 ==================

  private evTitle(): string {
    if (this.raw && typeof this.raw.summary === 'string' && this.raw.summary.length > 0) {
      return this.raw.summary
    }
    if (this.ev && this.ev.summary && this.ev.summary.length > 0) return this.ev.summary
    return '(未命名)'
  }

  private evRoom(): string {
    if (this.raw && typeof this.raw.location === 'string' && this.raw.location.length > 0) {
      return sanitizeLocation(this.raw.location)
    }
    if (this.ev && this.ev.location) return sanitizeLocation(this.ev.location)
    return ''
  }

  // 老师：从 raw.description 里取第一行，去掉结尾的 “|”
  private evTeacher(): string {
    if (!this.raw || !this.raw.description) {
      return ''
    }
    const descStr: string = String(this.raw.description)
    const firstLine: string = descStr.split('\n')[0]
    const clean: string = firstLine.replace(/\s*\|\s*$/u, '').trim()
    return clean
  }

  private hasTeacher(): boolean {
    return this.evTeacher().length > 0
  }

  private startDate(): Date | null {
    const sIcs: string | undefined =
      this.raw && this.raw.dtstart
        ? String(this.raw.dtstart)
        : this.ev
        ? this.ev.dtstart
        : undefined
    return parseIcsToDate(sIcs)
  }

  private endDate(): Date | null {
    const eIcs: string | undefined =
      this.raw && this.raw.dtend
        ? String(this.raw.dtend)
        : this.ev
        ? this.ev.dtend
        : undefined
    return parseIcsToDate(eIcs)
  }

  private evDateStr(): string {
    const s: Date | null = this.startDate()
    if (!s) return ''
    const yyyy: string = s.getFullYear().toString()
    const mm: string = (s.getMonth() + 1).toString().padStart(2, '0')
    const dd: string = s.getDate().toString().padStart(2, '0')
    return `${yyyy}-${mm}-${dd}`
  }

  private evWeekdayStr(): string {
    const s: Date | null = this.startDate()
    if (!s) return ''
    const names: string[] = ['日', '一', '二', '三', '四', '五', '六']
    return `星期${names[s.getDay()]}`
  }

  private evTimeStr(): string {
    const s: Date | null = this.startDate()
    const e: Date | null = this.endDate()
    if (!s || !e) return ''
    const f = (n: number): string => n.toString().padStart(2, '0')
    return `${f(s.getHours())}:${f(s.getMinutes())} - ${f(e.getHours())}:${f(e.getMinutes())}`
  }

  private evPeriodsStr(): string {
    const s: Date | null = this.startDate()
    const e: Date | null = this.endDate()
    if (!s || !e) return ''
    const sp: number = this.periodIndexByStart(s)
    const span: number = this.periodSpanByStartEnd(s, e)
    const ep: number = sp + span - 1
    return `第 ${sp} - ${ep} 节（共 ${span} 节）`
  }

  // 地点主/副行：比如 “研楼506\n北京理工大学”
  private roomMain(): string {
    const loc: string = this.evRoom()
    if (!loc) return ''
    const parts: string[] = loc.split('\n')
    return parts[0].trim()
  }

  private roomSub(): string {
    const loc: string = this.evRoom()
    const parts: string[] = loc.split('\n')
    if (parts.length <= 1) return ''
    const rest: string = parts.slice(1).join(' · ')
    return rest.trim()
  }

  // ================== UI ==================

  build() {
    Stack() {
      // 半透明遮罩
      Row() { }
      .width('100%')
      .height('100%')
      .backgroundColor('#00000066')
      .onClick(() => this.handleMaskClick())

      // 内容卡片
      Column() {
        // ====== 头部：标题 + 关闭按钮 + 小标签 ======
        Row() {
          Column() {
            // 课程名
            Text(this.evTitle())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor('#111827')

            // 标题下方的一行轻量信息：日期 / 星期 / 主教室
            Row() {
              if (this.evDateStr().length > 0) {
                Text(this.evDateStr())
                  .fontSize(this.baseFont)
                  .fontColor('#6B7280')
              }

              if (this.evWeekdayStr().length > 0) {
                Text(
                  (this.evDateStr().length > 0 ? ' · ' : '') +
                  this.evWeekdayStr()
                )
                  .fontSize(this.baseFont)
                  .fontColor('#6B7280')
              }

              if (this.roomMain().length > 0) {
                Text(
                  ((this.evDateStr().length > 0 || this.evWeekdayStr().length > 0) ? ' · ' : '') +
                  this.roomMain()
                )
                  .fontSize(this.baseFont)
                  .fontColor('#6B7280')
              }
            }
            .margin({ top: 4 })
          }
          // .flex(1)

          // 头部右侧关闭小按钮（点它也能关闭）
          Text('✕')
            .fontSize(18)
            .fontColor('#9CA3AF')
            .margin({ left: 12 })
            .onClick(() => this.handleCloseBtn())
        }
        .margin({ bottom: 12 })

        // 头部与内容之间的细分割线
        Row() { }
        .height(1)
        .width('100%')
        .backgroundColor('#E5E7EB')
        .margin({ bottom: 8 })

        // ====== 可滚动内容区域 ======
        Scroll() {
          Column() {
            // 教师块
            if (this.hasTeacher()) {
              Column() {
                Text('教师')
                  .fontSize(this.baseFont)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#6B7280')

                Text(this.evTeacher())
                  .fontSize(this.baseFont + 1)
                  .fontColor('#111827')
                  .margin({ top: 4 })
              }
              .margin({ bottom: 12 })

              Row() { }
              .height(1)
              .width('100%')
              .backgroundColor('#F3F4F6')
              .margin({ bottom: 12 })
            }

            // 时间块
            if (this.evDateStr().length > 0 || this.evTimeStr().length > 0) {
              Column() {
                Text('时间')
                  .fontSize(this.baseFont)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#6B7280')

                // 日期 + 星期的小行
                if (this.evDateStr().length > 0 || this.evWeekdayStr().length > 0) {
                  Row() {
                    if (this.evDateStr().length > 0) {
                      Text(this.evDateStr())
                        .fontSize(this.baseFont + 1)
                        .fontColor('#111827')
                    }
                    if (this.evWeekdayStr().length > 0) {
                      Text(
                        (this.evDateStr().length > 0 ? '  ' : '') +
                        this.evWeekdayStr()
                      )
                        .fontSize(this.baseFont)
                        .fontColor('#4B5563')
                    }
                  }
                  .margin({ top: 4 })
                }

                // 具体时间段
                if (this.evTimeStr().length > 0) {
                  Text(this.evTimeStr())
                    .fontSize(this.baseFont)
                    .fontColor('#4B5563')
                    .margin({ top: 4 })
                }

                // 第几节
                if (this.evPeriodsStr().length > 0) {
                  Text(this.evPeriodsStr())
                    .fontSize(this.baseFont)
                    .fontColor('#6B7280')
                    .margin({ top: 4 })
                }
              }
              .margin({ bottom: 12 })

              Row() { }
              .height(1)
              .width('100%')
              .backgroundColor('#F3F4F6')
              .margin({ bottom: 12 })
            }

            // 地点块
            if (this.evRoom().length > 0) {
              Column() {
                Text('地点')
                  .fontSize(this.baseFont)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#6B7280')

                Text(this.roomMain())
                  .fontSize(this.baseFont + 1)
                  .fontColor('#111827')
                  .margin({ top: 4 })

                if (this.roomSub().length > 0) {
                  Text(this.roomSub())
                    .fontSize(this.baseFont)
                    .fontColor('#6B7280')
                    .margin({ top: 4 })
                }
              }
            }
          }
        }
        .layoutWeight(1) // 让 Scroll 占据剩余空间，内容多时可以滚动
        .margin({ top: 4 })

        // ====== 底部按钮 ======
        Row() {
          Blank()
          Button('关闭')
            .type(ButtonType.Capsule)
            .onClick(() => this.handleCloseBtn())
        }
        .margin({ top: 18 })
      }
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .width('86%')
      .height('80%') // 防止内容太多撑满屏幕
      .align(Alignment.Center)
      // ✨ 动画：淡入 + 上弹
      .opacity(this.opacityVal)
      .scale({ x: this.scaleVal, y: this.scaleVal })
      .translate({ y: this.offsetY })
    }
    .width('100%')
    .height('100%')
  }

}
