// entry/src/main/ets/components/schedule/ScheduleGrid.ets
import { DayLayout, AbsoluteItem } from '../../pages/SchedulePage'
import type { RawIcsEvent } from '../../services/storage/semesterStore'
import type { CalendarEvent } from '../../services/jw/timetableRepository'
import { CourseCard } from './CourseCard'
import { sanitizeLocation, makeCourseKeyForCard } from '../../utils/scheduleUtils'
import { Logger } from '../../utils/Logger';
import type { PeriodTime } from '../../services/jw/periodTimes'
import type { ScheduleDisplayItem } from '../../services/schoolSchedule/ScheduleModels'

@Component
export struct ScheduleGrid {
  // --- Props ---
  @Prop weekLayouts: DayLayout[] = []
  @Prop unitHeight: number = 42
  @Prop baseFont: number = 12
  @Prop courseColWidth: number = 0
  @Prop colGap: number = 0
  @Prop courseColors: Record<string, string> = {}
  @Prop rightAreaWidth: number = 0
  @Prop rightAreaHeight: number = 0
  @Prop periodTimes: PeriodTime[] = []
  @Prop showDivider: boolean = true
  @Prop showCurrentTime: boolean = true
  @Prop showBorder: boolean = false
  private logger = new Logger('ScheduleGrid');
  onCourseClick: (ev: CalendarEvent, raw?: RawIcsEvent) => void = (ev, raw) => {}
  onDisplayItemClick: (item: ScheduleDisplayItem) => void = (item) => {}

  // --- LOGGING FUNCTION ---
  private onGridAreaChange(rect: Area): void {
    const w = Number(rect.width);
    const h = Number(rect.height);
    // 这个日志将告诉我们 Stack 的真实高度
    this.logger.info(
      'onAreaChange: Fired.',
      `w=${w}, h=${h}.`,
      'Expected prop height:', this.rightAreaHeight
    );
  }

  // --- Layout Helpers ---
  private buildDayAbsoluteItems(dl: DayLayout): AbsoluteItem[] {
    const items: AbsoluteItem[] = []
    let r = 0
    for (let j = 0; j < dl.blocks.length; j++) {
      const b = dl.blocks[j]
      if (b.kind === 0) {
        r += b.units
      } else {
        const units = b.units
        items.push({
          top: r * this.unitHeight,
          height: units * this.unitHeight,
          units,
          ev: b.ev!,
          raw: b.raw,
          item: b.item
        })
        r += units
      }
    }
    return items
  }

  private dayLeft(i: number): number {
    return i * (this.courseColWidth + this.colGap);
  }

  private bottomLineWidth(idx: number): number {
    return idx === 12 ? 0 : 4;
  }

  private periods(): number[] {
    const arr: number[] = []
    const total = this.periodTimes && this.periodTimes.length > 0 ? this.periodTimes.length : 13
    let i = 1
    while (i <= total) { arr.push(i); i++ }
    return arr
  }

  private parseClockMinutes(value: string): number {
    const m = /^(\d{1,2}):(\d{2})$/.exec(value)
    if (!m) return -1
    const h = Number(m[1])
    const mm = Number(m[2])
    if (h < 0 || h > 23 || mm < 0 || mm > 59) return -1
    return h * 60 + mm
  }

  private currentTimeTop(): number {
    if (!this.periodTimes || this.periodTimes.length === 0) return -1
    const now = new Date()
    const current = now.getHours() * 60 + now.getMinutes()
    let completed = 0
    for (let i = 0; i < this.periodTimes.length; i++) {
      const start = this.parseClockMinutes(this.periodTimes[i].start)
      const end = this.parseClockMinutes(this.periodTimes[i].end)
      if (start < 0 || end <= start) continue
      if (current <= start) {
        break
      }
      if (current >= end) {
        completed += 1
      } else {
        completed += (current - start) / (end - start)
        break
      }
    }
    if (completed <= 0 || completed >= this.periodTimes.length) return -1
    return completed * this.unitHeight
  }

  // --- Card Data Helpers ---
  private cardTitle(ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (raw && typeof raw.summary === 'string' && raw.summary.length > 0) return raw.summary;
    return ev.summary ? ev.summary : '(未命名)';
  }

  private cardTitleForItem(item: ScheduleDisplayItem | undefined, ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (item) {
      return item.title
    }
    return this.cardTitle(ev, raw)
  }

  private cardRoom(ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (raw && typeof raw.location === 'string' && raw.location.length > 0) return sanitizeLocation(raw.location);
    // ✅ 修复 1：当 raw 为 undefined 时，应从 ev.location 获取
    return ev.location ? sanitizeLocation(ev.location) : '';
  }

  private cardRoomForItem(item: ScheduleDisplayItem | undefined, ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (item) {
      return item.subtitle
    }
    return this.cardRoom(ev, raw)
  }

  private totalTextLinesForUnits(units: number): number {
    if (!units || units < 1) return 3;
    return units * 3;
  }

  private titleMaxLinesForUnits(units: number): number {
    const total = this.totalTextLinesForUnits(units);
    const remain = total - 2; // 房间 2 行
    return remain > 0 ? remain : 0;
  }

  private colorForCard(ev: CalendarEvent, raw?: RawIcsEvent): string {
    const key = makeCourseKeyForCard(ev, raw)
    return this.courseColors[key] || '#0EA5E9'
  }

  private colorForDisplayCard(item: ScheduleDisplayItem | undefined, ev: CalendarEvent, raw?: RawIcsEvent): string {
    if (item && item.kind === 'exam') {
      return '#F97316'
    }
    if (item && item.kind === 'custom') {
      return '#8B5CF6'
    }
    if (item && item.kind === 'course') {
      return this.courseColors[item.colorKey] || '#0EA5E9'
    }
    return this.colorForCard(ev, raw)
  }

  private handleCardClick(it: AbsoluteItem): void {
    if (it.item) {
      this.onDisplayItemClick(it.item)
      return
    }
    this.onCourseClick(it.ev, it.raw)
  }

  // --- Builders ---
  @Builder
  RightGridAcross() {
    Column() {
      ForEach(this.periods(), (_p: number, idx: number) => {
        Row() { }
        .width('100%')

        // ✅ 关键修复 1：
        // 让13节课(Row)平分 100% 的高度
        .layoutWeight(1)

        .border({ width: { bottom: (idx === this.periods().length - 1 || !this.showDivider ? 0 : 1) }, color: '#E5E7EB' })
      })
    }
    .width(this.rightAreaWidth)

    // ✅ 关键修复 2：
    // 告诉背景 Column 填满 100%
    .height('100%')
  }

  @Builder
  DayAbsoluteColumn(dl: DayLayout, dayIdx: number) {
    ForEach(this.buildDayAbsoluteItems(dl), (it: AbsoluteItem, _k: number) => {
      Stack() {
        CourseCard({
          title: this.cardTitleForItem(it.item, it.ev, it.raw),
          room: this.cardRoomForItem(it.item, it.ev, it.raw),
          color: this.colorForDisplayCard(it.item, it.ev, it.raw),
          cardHeight: it.height,
          baseFont: this.baseFont,
          titleMaxLines: this.titleMaxLinesForUnits(it.units),
          showBorder: this.showBorder,
          // ✅ 修复 2：属性名应为 onCardClick
          onCardClick: () => this.handleCardClick(it)
        })
      }
      .width(this.courseColWidth)
      .height(it.height)
      .position({
        x: this.dayLeft(dayIdx),
        y: it.top
      })
    })
  }

  @Builder
  RightCardsAbsolute() {
    Stack() {
      ForEach(this.weekLayouts, (dl: DayLayout, dayIdx: number) => {
        this.DayAbsoluteColumn(dl, dayIdx)
      })
    }
    .width(this.rightAreaWidth)

    // ✅ 保持【计算高度】:
    // 卡片层【必须】使用计算出的高度 (13 * unitHeight)
    // 来确保绝对定位正确。
    .height(this.rightAreaHeight)
  }

  build() {

    Stack() {
      // 底层：横线贯穿 (必须 100% 高度)
      this.RightGridAcross()

      // 顶层：绝对定位的卡片集合 (必须固定高度)
      this.RightCardsAbsolute()

      if (this.showCurrentTime && this.currentTimeTop() >= 0) {
        Row() {}
          .width(this.rightAreaWidth)
          .height(2)
          .backgroundColor('#EF4444')
          .position({ x: 0, y: this.currentTimeTop() })
      }
    }
    .width(this.rightAreaWidth)
    // ✅ 关键：
    // 整个网格 Stack 填满父容器 (h=633.84)
    .height('100%')
    // ✅ 添加日志
    .onAreaChange((oldValue: Area, newValue: Area) => this.onGridAreaChange(newValue))
    // ✅ 修复 3：将日志移动到 onAppear 钩子中
    .onAppear(() => {
      this.logger.info(
        'build: Fired.',
        'rightAreaHeight=', this.rightAreaHeight,
        'rightAreaWidth=', this.rightAreaWidth,
        'unitHeight=', this.unitHeight
      );
    })
  }
}
