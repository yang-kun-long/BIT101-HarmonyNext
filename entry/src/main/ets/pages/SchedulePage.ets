// entry/src/main/ets/pages/SchedulePage.ets
import { Logger } from '../utils/Logger';
import fileIo from '@ohos.file.fs'

import { TimetableRepository, CalendarEvent } from '../services/jw/timetableRepository'
import { TokenStore } from '../services/storage/tokenStore'
import { SemesterRepository, SemesterId } from '../services/jw/semesterRepository'
import { layoutsFromInstances } from '../services/jw/layoutFromInstances'
import type { CourseInstance, FilesCtx, RawIcsEvent } from '../services/storage/semesterStore'
import type { ToInstancesDeps } from '../services/jw/normalize'
import { PeriodTimesStore } from '../services/jw/periodTimesStore'
import type { PeriodTime } from '../services/jw/periodTimes'


// 导入新的工具和组件
import * as utils from '../utils/scheduleUtils'
import { ScheduleHeaderRow } from '../components/schedule/ScheduleHeaderRow'
import { ScheduleSidebar } from '../components/schedule/ScheduleSidebar'
import { ScheduleGrid } from '../components/schedule/ScheduleGrid'
import { WeekNavigator } from '../components/schedule/WeekNavigator'
import { CourseDetailDialog } from '../components/schedule/CourseDetailDialog'


// ---------- 本文件内部用到的类型 (需要 export) ----------
// 请在 SchedulePage.ets 文件的顶部（import 下方）定义并导出这些类型
export interface DayEvents { date: Date; events: CalendarEvent[] }
interface WeekRange { start: Date; end: Date } // 这个可以不导出，仅本文件使用
export interface DayBlock {
  kind: number;
  units: number;
  ev?: CalendarEvent;
  raw?: RawIcsEvent;
}
export interface DayLayout { date: Date; blocks: DayBlock[] }
export interface IsoLayout { dateISO: string; blocks: DayBlock[] }
export interface AbsoluteItem {
  top: number
  height: number
  units: number
  ev: CalendarEvent
  raw?: RawIcsEvent
}
// --------------------------------------------------


@Component
export default struct SchedulePage {
  private logger = new Logger('SchedulePage');
  onCourseClick?: (ev: CalendarEvent, raw?: RawIcsEvent | null, baseFont?: number, periodTimes?: PeriodTime[]) => void
  // --- 状态管理 ---
  @State loading: boolean = true
  @State err: string = ''
  @State hasWebvpn: boolean = false
  @State weekStartISO: string = ''  // 周一 YYYY-MM-DD
  @State weekTitle: string = ''     // “MM/DD - MM/DD”
  @State weekDays: DayEvents[] = []
  @State weekLayouts: DayLayout[] = []
  @State showCourseDlg: boolean = false
  @State dlgEv: CalendarEvent | null = null
  @State dlgRaw: RawIcsEvent | null = null
  @State gridHeight: number = 0
  @State unitHeight: number = 42
  private readonly innerPad = 6
  @State baseFont: number = 12
  @State periodTimes: PeriodTime[] = []
  @State firstWeekISO: string = ''
  @State colGap: number = 0
  @State courseColWidth: number = 0
  @State leftColWidth: number = 0
  @State courseColors: Record<string, string> = {}
  @State weekNoTextComputed: string = '1'
  @StorageProp('filesDir') filesDirFromApp: string = ''
  @StorageProp('cacheDir') cacheDirFromApp: string = ''
  @StorageProp('tempDir') tempDirFromApp: string = ''

  // --- 仓储实例 ---
  private repo = new TimetableRepository()
  private store = new TokenStore()
  private semRepo?: SemesterRepository
  private timesStore?: PeriodTimesStore

  // --- 生命周期 ---
  aboutToAppear(): void {
    this.logger.info('aboutToAppear: Fired. Initializing.');
    this.initWeek()
    this.initSemesterRepoIfNeeded()

    // ✅ 修复：把加载放回这里，它只在创建时运行一次
    this.loadLocalFirst(false)
  }


  // --- 核心数据加载逻辑 (保留) ---
  private async loadLocalFirst(forceRefresh: boolean) {
    this.logger.debug('loadLocalFirst: Start.', 'forceRefresh=', forceRefresh, 'weekStartISO=', this.weekStartISO);
    this.loading = true
    this.err = ''
    this.weekLayouts = []
    this.hasWebvpn = await this.store.isLoggedInWebvpn()

    if (!this.hasWebvpn) {
      this.logger.warn('未登录教务（缺少 WebVPN 会话）');
      this.loading = false
      this.err = '未登录教务（缺少 WebVPN 会话）'
      return
    }
    const filesDir = this.getFilesDir()
    if (!filesDir || filesDir.length === 0) {
      this.loading = false; this.err = '无法获取应用文件目录'; return
    }
    if (!this.semRepo) {
      this.initSemesterRepoIfNeeded()
      if (!this.semRepo) { this.loading = false; this.err = '学期仓库初始化失败'; return }
    }

    try {
      const semIdStr: string = this.currentSemesterId();
      const sem: SemesterId = { id: semIdStr };
      const result = await this.semRepo.getSemester(sem, forceRefresh);

      const weekInstances: CourseInstance[] = this.semRepo.filterWeekInstances(result.semester, this.weekStartISO);
      this.courseColors = (result.semester && result.semester.courseColors) ? result.semester.courseColors : {};
      this.logger.debug('Checking firstWeekISO. Current value:', this.firstWeekISO);
      if (!this.firstWeekISO || this.firstWeekISO.length === 0) {
        this.logger.debug('firstWeekISO is empty, calculating...');

        if (result && result.semester && result.semester.instances && result.semester.instances.length > 0) {
          const insts: CourseInstance[] = result.semester.instances;
          let minISO: string = insts[0].weekStartISO;
          for (let i = 1; i < insts.length; i++) {
            if (insts[i].weekStartISO < minISO) minISO = insts[i].weekStartISO;
          }
          this.firstWeekISO = minISO;
          this.logger.info('Calculated firstWeekISO from instances:', this.firstWeekISO);
        } else {
          // 如果没有课程数据，就*姑且*用当前周作为第一周
          this.firstWeekISO = this.weekStartISO;
          this.logger.warn('No instances, setting firstWeekISO to weekStartISO:', this.firstWeekISO);
        }
      } else {
        this.logger.debug('firstWeekISO already set, skipping calculation.');
      }

      this.updateWeekNoText()

      const layouts = layoutsFromInstances(this.weekStartISO, weekInstances);
      this.weekLayouts = this.mapLayoutsWithDate(layouts);
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      this.err = msg;
      this.logger.error('getSemester failed:', msg);
    } finally {
      this.loading = false;
    }
  }

  // --- 布局计算 (保留) ---
  private recomputeWidthMetrics(totalWidth: number): void {
    this.logger.debug('recomputeWidthMetrics: Fired.', 'totalWidth=', totalWidth);
    // ⬇️ 关键：使用【干净】的逻辑
    // 1. 如果宽度为0，我们【什么也不做】。
    //    我们等待 onAreaChange 再次用
    //    【正确的】宽度（如 360）来调用我们。
    if (totalWidth <= 0) {
      this.logger.debug('recomputeWidthMetrics: totalWidth is 0, ignoring.');
      return;
    }

    // 2. 只有当宽度 > 0 时，才计算
    const gaps = this.colGap * 7;
    const usable = totalWidth - gaps;
    if (usable <= 0) {
      this.logger.debug('recomputeWidthMetrics: usable width is 0, ignoring.');
      return;
    }

    const c = Math.floor(usable / 7.7);
    const l = Math.floor(c * 0.7);

    // 3. 只有当状态【真正改变时】才设置
    if (c !== this.courseColWidth || l !== this.leftColWidth) {
      this.logger.debug('recomputeWidthMetrics: State CHANGED! Setting courseColWidth=', c);
      this.courseColWidth = c;
      this.leftColWidth = l;
    } else {
      this.logger.debug('recomputeWidthMetrics: State NOT changed. Ignoring. c=', c);
    }
  }

  private recomputeMetrics(availableHeight: number): void {
    this.logger.debug('recomputeMetrics: Fired.', 'availableHeight=', availableHeight);
    if (availableHeight <= 0) return
    const uh = Math.floor(availableHeight / 13)
    const usable = uh - this.innerPad * 2
    const fs = Math.max(10, Math.floor((usable / 3) * 0.92))
    if (uh !== this.unitHeight || fs !== this.baseFont || availableHeight !== this.gridHeight) {
      this.unitHeight = uh
      this.baseFont = fs
      this.gridHeight = availableHeight
    }
  }
  // ✅ 关键：添加这个新函数
  private onBodyAreaChange(rect: Area): void {
    const w = Number(rect.width);
    const h = Number(rect.height);

    // 这个日志总会打印
    this.logger.debug('onBodyAreaChange: Fired.', `w=${w}, h=${h}`);

    // 调用我们带日志的函数
    this.recomputeWidthMetrics(w);
    this.recomputeMetrics(h);
  }

  private getUnitHeight(): number {
    return this.unitHeight > 0 ? this.unitHeight : 42
  }
  private getBaseFont(): number {
    return this.baseFont > 0 ? this.baseFont : 12
  }
  private rightAreaWidth(): number {
    return 7 * this.courseColWidth + 6 * this.colGap
  }
  private rightAreaHeight(): number {
    return 13 * this.getUnitHeight()
  }

  // --- 事件处理器 (保留) ---
  private onTapEvent(ev: CalendarEvent, raw?: RawIcsEvent): void {
    this.logger.debug('onTapEvent fired', 'summary=', ev?.summary, 'hasCallback=', !!this.onCourseClick);

    if (this.onCourseClick) {
      this.onCourseClick(ev, raw ? raw : null, this.getBaseFont(), this.periodTimes)
      return
    }
    this.dlgEv = ev
    this.dlgRaw = raw ? raw : null
    this.showCourseDlg = true
  }

  private closeCourseDlg(): void {
    this.showCourseDlg = false
  }

  private onNextWeek(): void {
    this.weekStartISO = utils.addDaysISO(this.weekStartISO, 7)
    this.logger.info('onNextWeek: new weekStartISO =', this.weekStartISO);
    this.recomputeWeekHeader()
    this.updateWeekNoText()
    this.loadLocalFirst(false)
  }

  private onPrevWeek(): void {
    this.weekStartISO = utils.addDaysISO(this.weekStartISO, -7)
    this.logger.info('onPrevWeek: new weekStartISO =', this.weekStartISO);
    this.recomputeWeekHeader()
    this.updateWeekNoText()
    this.loadLocalFirst(false)
  }

  private onSettings(): void {
    // this.openSettings()
  }

  // --- 辅助函数 (保留在主页, 因为它们依赖 state/repo) ---
  private initWeek(): void {
    const monday = utils.mondayOf(new Date())
    this.weekStartISO = utils.fmtDate(monday)
    this.recomputeWeekHeader()
  }

  private recomputeWeekHeader(): void {
    const wr = this.weekRangeFromISO(this.weekStartISO) // 使用本地方法
    const startStr = `${utils.pad2(wr.start.getMonth() + 1)}/${utils.pad2(wr.start.getDate())}`
    const endMinus1 = new Date(wr.end.getFullYear(), wr.end.getMonth(), wr.end.getDate() - 1)
    const endStr = `${utils.pad2(endMinus1.getMonth() + 1)}/${utils.pad2(endMinus1.getDate())}`
    this.weekTitle = `${startStr} - ${endStr}`

    const daysArr: DayEvents[] = []
    let i = 0
    while (i < 7) {
      const d = new Date(wr.start.getFullYear(), wr.start.getMonth(), wr.start.getDate() + i)
      daysArr.push({ date: d, events: [] })
      i++
    }
    this.weekDays = daysArr
  }

  private weekRangeFromISO(iso: string): WeekRange {
    const parts = iso.split('-')
    const y = parseInt(parts[0]); const m = parseInt(parts[1]) - 1; const dd = parseInt(parts[2])
    const start = new Date(y, m, dd)
    const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7)
    return { start: start, end: end }
  }

  private getFilesDir(): string {
    const pick = (this.filesDirFromApp && this.filesDirFromApp.length > 0)
      ? this.filesDirFromApp
      : ((this.cacheDirFromApp && this.cacheDirFromApp.length > 0)
        ? this.cacheDirFromApp
        : (this.tempDirFromApp || ''));
    if (!pick || pick.length === 0) {
      this.err = '无法获取应用文件目录'
    }
    return pick;
  }
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
    if (m == null) return 8 * 60 + (idx * 50) // 兜底
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

  private minutesOfDay(dt: Date): number {
    return dt.getHours() * 60 + dt.getMinutes()
  }

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

  private initSemesterRepoIfNeeded(): void {
    if (this.semRepo) return

    const filesDir: string = this.getFilesDir()
    if (!filesDir || filesDir.length === 0) {
      this.err = '无法获取 filesDir (initSemesterRepoIfNeeded)'
      return
    }

    // ✅ 关键修复：
    // 1. 必须【首先】加载 periodTimes（上课时间表）
    //    因为下面的 deps 对象中的函数依赖它。
    this.timesStore = new PeriodTimesStore({ filesDir })
    this.periodTimes = this.timesStore.load()
    this.logger.info('periodTimes loaded count:', this.periodTimes.length);

    // 2. 【然后】才能创建依赖 this.periodTimes 的 deps 对象
    // (请确保您在 SchedulePage 中保留了 periodIndexByStart 等 6 个私有函数)
    const deps: ToInstancesDeps = {
      parseIcsToDate: (s?: string) => utils.parseIcsToDate(s),
      periodIndexByStart: (d: Date) => this.periodIndexByStart(d),
      periodSpanByStartEnd: (s: Date, e: Date) => this.periodSpanByStartEnd(s, e),
      sanitizeLocation: (s?: string) => utils.sanitizeLocation(s),
      trimTitle: (name?: string, units?: number) => this.trimmedTitleForCard(name, units),
      fmtDateISO: (d: Date) => utils.fmtDate(d),
      weekStartISOOf: (anyDayISO: string) => utils.weekStartOfISO(anyDayISO),
    }

    // 3. 【最后】才能创建使用 deps 的仓库
    const filesCtx: FilesCtx = { filesDir }
    this.semRepo = new SemesterRepository(this.repo, filesCtx, deps)

    this.logger.debug('SemesterRepository created.');
  }

  private calculateWeekNoText(): string {
    // 1. 如果 firstWeekISO 还没加载好，我们不能计算，默认返回 "1"
    if (!this.firstWeekISO || this.firstWeekISO.length === 0) {
      this.logger.debug('calculateWeekNoText: firstWeekISO is empty. Returning 1.');
      return '1';
    }
    // 2. 只有 firstWeekISO 存在时，才用它作为 baseISO
    const baseISO: string = this.firstWeekISO;
    const a = new Date(this.weekStartISO);
    const b = new Date(baseISO);
    const diffDays = Math.floor((a.getTime() - b.getTime()) / 86400000);
    const weeks = Math.floor(diffDays / 7) + 1;
    const finalWeek = (weeks < 1) ? '1' : String(weeks);

    this.logger.debug('calculateWeekNoText result:', `weeks=${weeks}, returning=${finalWeek}`);
    return finalWeek;
  }
  private updateWeekNoText(): void {
    const newWeekText = this.calculateWeekNoText()
    this.logger.debug('updateWeekNoText: Setting weekNoTextComputed to', newWeekText);
    this.weekNoTextComputed = newWeekText
  }

  private currentSemesterId(): string {
    const today = new Date()
    const y = today.getFullYear()
    const m = today.getMonth() + 1
    const term = (m >= 3 && m <= 8) ? 'spring' : 'fall'
    return `${y}-${term}`
  }

  private mapLayoutsWithDate(layouts: IsoLayout[]): DayLayout[] {
    const out: DayLayout[] = []
    let i = 0
    while (i < layouts.length) {
      const li = layouts[i]
      const p = li.dateISO.split('-')
      const y = parseInt(p[0]); const m = parseInt(p[1]) - 1; const d = parseInt(p[2])
      out.push({ date: new Date(y, m, d), blocks: li.blocks })
      i++
    }
    return out
  }

  // (您原来代码中的 fsChk, logErr, logFsIo, trimmedTitleForCard 等函数应保留)
  // ... 此处省略这些函数的代码 ...
  private trimmedTitleForCard(name?: string, units?: number): string {
    if (!name || name.length === 0) return '(未命名)'
    const shortCard = (units !== undefined && units <= 1)
    if (shortCard || name.length > 8) {
      const h = name.length >= 2 ? name.slice(0, 2) : name
      return h + '…'
    }
    return name
  }
  private async refreshWeek(): Promise<void> {
    await this.loadLocalFirst(true)
    setTimeout(() => { this.loadLocalFirst(false) }, 16)
  }



  // ===== 页面 (Build) =====
  build() {

    Stack() {
      Column() {
        // --- 顶部标题栏 ---


        // --- 加载/错误状态 ---
        if (this.loading) {
          Text('加载中…').fontSize(16)
        } else if (this.err.length > 0) {
          Column() {
            Text('加载失败').fontColor('#ef4444').fontSize(16)
            Text(this.err).fontColor('#ef4444').fontSize(12).maxLines(3)
            Button('重试').type(ButtonType.Capsule).onClick(() => { this.loadLocalFirst(true) }).margin({ top: 8 })
          }
        } else {

          // --- 课表头部 ---
          ScheduleHeaderRow({
            weekNoText: this.weekNoTextComputed,
            weekDays: this.weekDays,
            leftColWidth: this.leftColWidth,
            courseColWidth: this.courseColWidth,
            colGap: this.colGap
          })


          // --- 课表主体 ---
          Row() {
            // 左侧节次
            ScheduleSidebar({
              periodTimes: this.periodTimes,
              unitHeight: this.getUnitHeight(),
              baseFont: this.getBaseFont()
            })
              .width(this.leftColWidth)
              .margin({ right: this.colGap })

            // 右侧网格
            ScheduleGrid({
              weekLayouts: this.weekLayouts,
              unitHeight: this.getUnitHeight(),
              baseFont: this.getBaseFont(),
              courseColWidth: this.courseColWidth,
              colGap: this.colGap,
              courseColors: this.courseColors,
              rightAreaWidth: this.rightAreaWidth(),
              rightAreaHeight: this.rightAreaHeight(),
              onCourseClick: (ev, raw) => this.onTapEvent(ev, raw)
            })
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ top: 8 })
          .onAreaChange((_, rect: Area) => {
            const h = Number(rect.height);
            this.logger.debug('onAreaChange (Body Row): Fired.', `h=${h}`);
            this.recomputeMetrics(h);
          })
        }
      }
      .padding({ left: 10, right: 10, top: 0, bottom: 0 })
      .width('100%')
      .height('100%')
      .onAreaChange((_, rect: Area) => {
        const w = Number(rect.width);
        this.logger.debug('onAreaChange (Column): Fired.', `w=${w}`);
        this.recomputeWidthMetrics(w);

        // ❌ 修复：从这里【删除】高度计算
        // const h = Number(rect.height);
        // this.recomputeMetrics(h);
      })

      // --- 周切换导航 ---
      WeekNavigator({
        onNext: () => this.onNextWeek(),
        onPrev: () => this.onPrevWeek(),
        onSettings: () => this.onSettings(),
        onRefresh: () => {
          this.refreshWeek()   // 异步函数直接调用即可
        }
      })
    }
    .height('100%')
    .width('100%')


  }
}