// entry/src/main/ets/pages/SchedulePage.ets
import { Logger } from '../utils/Logger';
import fileIo from '@ohos.file.fs'

import { TimetableRepository, CalendarEvent } from '../services/jw/timetableRepository'
import { TokenStore } from '../services/storage/tokenStore'
import { SchoolCookieStore } from '../services/storage/SchoolCookieStore'
import { LexueCookieStore } from '../services/storage/LexueCookieStore'
import { CourseScheduleApiRepository } from '../services/jw/courseScheduleApiRepository'
import { CourseTermRepository } from '../services/jw/courseTermRepository'
import { SemesterRepository, SemesterId } from '../services/jw/semesterRepository'
import { layoutsFromInstances } from '../services/jw/layoutFromInstances'
import type { CourseInstance, FilesCtx, RawIcsEvent } from '../services/storage/semesterStore'
import type { ToInstancesDeps } from '../services/jw/normalize'
import { PeriodTimesStore } from '../services/jw/periodTimesStore'
import type { PeriodTime } from '../services/jw/periodTimes'
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes'
import { detectSchoolLoginMode } from '../services/school/SchoolNetworkProbe'


// 导入新的工具和组件
import * as utils from '../utils/scheduleUtils'
import { ScheduleHeaderRow } from '../components/schedule/ScheduleHeaderRow'
import { ScheduleSidebar } from '../components/schedule/ScheduleSidebar'
import { ScheduleGrid } from '../components/schedule/ScheduleGrid'
import { WeekNavigator } from '../components/schedule/WeekNavigator'
import { CourseDetailDialog } from '../components/schedule/CourseDetailDialog'
import { ExamDetailDialog } from '../components/schedule/ExamDetailDialog'
import { CustomScheduleDetailDialog } from '../components/schedule/CustomScheduleDetailDialog'
import { AddEditCustomScheduleDialog } from '../components/schedule/AddEditCustomScheduleDialog'
import { uiPushUrl, uiShowToast } from '../utils/uiContextBridge'
import { buildCourseColorMap } from '../services/schoolSchedule/ScheduleColors'
import { publishScheduleWidgets } from '../services/schoolSchedule/ScheduleWidgetPublisher'
import { CourseScheduleSettingsStore } from '../services/storage/CourseScheduleSettingsStore'
import { visibleWeekdayNumbers } from '../services/schoolSchedule/ScheduleSettingsModels'
import {
  buildWeekScheduleDisplayItems,
  computeWeekNumber,
} from '../services/schoolSchedule/CourseScheduleRepository'
import { ScheduleLocalStore, upsertCustomSchedule, deleteCustomSchedule } from '../services/schoolSchedule/ScheduleLocalStore'
import type {
  CourseScheduleItem,
  CustomScheduleItem,
  ExamScheduleItem,
  ScheduleDisplayItem,
} from '../services/schoolSchedule/ScheduleModels'


// ---------- 本文件内部用到的类型 (需要 export) ----------
// 请在 SchedulePage.ets 文件的顶部（import 下方）定义并导出这些类型
export interface DayEvents { date: Date; events: CalendarEvent[] }
interface WeekRange { start: Date; end: Date } // 这个可以不导出，仅本文件使用
export interface DayBlock {
  kind: number;
  units: number;
  ev?: CalendarEvent;
  raw?: RawIcsEvent;
  item?: ScheduleDisplayItem;
}
export interface DayLayout { date: Date; blocks: DayBlock[] }
export interface IsoLayout { dateISO: string; blocks: DayBlock[] }
export interface AbsoluteItem {
  top: number
  height: number
  units: number
  ev: CalendarEvent
  raw?: RawIcsEvent
  item?: ScheduleDisplayItem
}
interface TimedScheduleBlock {
  startSection: number;
  endSection: number;
  ev?: CalendarEvent;
  raw?: RawIcsEvent;
  item?: ScheduleDisplayItem;
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
  @State showExamDlg: boolean = false
  @State showCustomDlg: boolean = false
  @State showCustomEditDlg: boolean = false
  @State dlgEv: CalendarEvent | null = null
  @State dlgRaw: RawIcsEvent | null = null
  @State dlgCourse: CourseScheduleItem | null = null
  @State dlgExam: ExamScheduleItem | null = null
  @State dlgCustom: CustomScheduleItem | null = null
  @State editingCustom: CustomScheduleItem | null = null
  @State customScheduleMemory: CustomScheduleItem[] = []
  @State navigatorContainerHeight: number = 0
  @State gridHeight: number = 0
  @State unitHeight: number = 42
  private readonly innerPad = 6
  @State baseFont: number = 12
  @State periodTimes: PeriodTime[] = []
  @State firstWeekISO: string = ''
  @State colGap: number = 0
  @State courseColWidth: number = 0
  @State leftColWidth: number = 0
  private availableWidth: number = 0
  @State courseColors: Record<string, string> = {}
  @State weekNoTextComputed: string = '1'
  @StorageProp('filesDir') filesDirFromApp: string = ''
  @StorageProp('cacheDir') cacheDirFromApp: string = ''
  @StorageProp('tempDir') tempDirFromApp: string = ''
  @StorageProp('course_schedule_show_saturday') @Watch('onWeekendVisibilityChanged') showSaturdaySetting: boolean = true
  @StorageProp('course_schedule_show_sunday') @Watch('onWeekendVisibilityChanged') showSundaySetting: boolean = true
  @StorageProp('course_schedule_show_border') showBorderSetting: boolean = false
  @StorageProp('course_schedule_show_highlight_today') showHighlightTodaySetting: boolean = true
  @StorageProp('course_schedule_show_divider') showDividerSetting: boolean = true
  @StorageProp('course_schedule_show_current_time') showCurrentTimeSetting: boolean = true
  @StorageProp('course_schedule_show_exam_info') showExamInfoSetting: boolean = true
  @StorageProp('course_schedule_current_term') currentTermSetting: string = ''
  @StorageProp('course_schedule_first_day_iso') firstDaySetting: string = ''
  @StorageProp('course_schedule_period_times') appPeriodTimes: PeriodTime[] = []

  // --- 仓储实例 ---
  private repo = new TimetableRepository()
  private store = new TokenStore()
  private semRepo?: SemesterRepository
  private timesStore?: PeriodTimesStore
  private scheduleLoadInFlight: boolean = false

  // --- 生命周期 ---
  aboutToAppear(): void {
    this.logger.info('aboutToAppear: Fired. Initializing.');
    this.initWeek()
    this.syncPeriodTimesFromSettings()
    this.initSemesterRepoIfNeeded()

    // ✅ 修复：把加载放回这里，它只在创建时运行一次
    this.loadLocalFirst(false)
  }


  // --- 核心数据加载逻辑 (保留) ---
  private async loadLocalFirst(forceRefresh: boolean) {
    this.err = ''
    const filesDir = this.getFilesDir()
    if (!filesDir || filesDir.length === 0) {
      this.loading = false; this.err = '无法获取应用文件目录'; return
    }
    const localScheduleStore = new ScheduleLocalStore({ filesDir });
    const cachedInfo = localScheduleStore.loadScheduleInfo();
    let term = this.currentTermSetting.trim() || cachedInfo?.term || '';
    let firstDay = this.firstDaySetting.trim() ||
      (cachedInfo?.term === term ? cachedInfo.firstDayISO : '');
    const hasCache = term.length > 0 && firstDay.length > 0 && localScheduleStore.hasCachedCourses(term);
    // No async work before cache rendering: page/tab/week switches stay local.
    if (hasCache) {
      this.renderSchedule(localScheduleStore, term, firstDay);
      this.loading = false;
      this.logger.info('schedule cache hit term=', term);
      if (!forceRefresh) return;
    }
    if (this.scheduleLoadInFlight) return;
    this.loading = !hasCache && this.weekLayouts.length === 0;
    this.scheduleLoadInFlight = true;
    try {
      const mode = await this.resolveSchoolMode();
      this.hasWebvpn = mode === 'webvpn';
      if (term.length === 0) {
        term = await new CourseTermRepository({ mode, debug: true }).getCurrentTerm();
      }
      if (term.length === 0) {
        throw new Error('未获取到当前学期');
      }
      if (firstDay.length === 0) {
        firstDay = await new CourseTermRepository({ mode, debug: true }).getFirstDay(term);
      }
      if (forceRefresh || !localScheduleStore.hasCachedCourses(term)) {
        const source = new CourseScheduleApiRepository({ mode, debug: true });
        const courses = await source.getCourses(term);
        localScheduleStore.saveCourses(courses);
      }
      localScheduleStore.saveScheduleInfo({ term, firstDayISO: firstDay });
      this.renderSchedule(localScheduleStore, term, firstDay);
      this.loading = false;
      await new CourseScheduleSettingsStore().saveTermInfo(term, firstDay);
      publishScheduleWidgets(filesDir);
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      if (hasCache) {
        uiShowToast(this.getUIContext(), { message: '刷新失败，已保留本地课表' });
      } else {
        this.err = msg;
      }
      this.logger.error('getSemester failed:', msg);
    } finally {
      this.loading = false;
      this.scheduleLoadInFlight = false;
    }
  }

  private renderSchedule(store: ScheduleLocalStore, term: string, firstDay: string): void {
    const courses = store.loadCourses().filter((item: CourseScheduleItem) => item.term === term);
    this.firstWeekISO = firstDay;
    this.courseColors = buildCourseColorMap(courses.map((item: CourseScheduleItem) =>
      utils.makeCourseColorKey(item.name, item.teacher)));
    this.logger.info('render local schedule courses=', courses.length, 'colorKeys=', Object.keys(this.courseColors).length);
    const displayItems = buildWeekScheduleDisplayItems({
      weekStartISO: this.weekStartISO,
      weekNumber: computeWeekNumber(firstDay, this.weekStartISO),
      periodTimes: this.periodTimes,
      showExamInfo: this.showExamInfoSetting,
      courses,
      exams: store.loadExams().filter((item: ExamScheduleItem) => item.term === term),
      customSchedules: this.mergeCustomSchedules(store.loadCustomSchedules(), this.customScheduleMemory),
    });
    this.weekLayouts = this.layoutsFromDisplayItems(displayItems);
    this.updateWeekNoText();
  }

  private async resolveSchoolMode(): Promise<SchoolLoginMode> {
    // The generic webvpn_cookie is also written by the BIT101 verification
    // step for inner-network logins, so it cannot identify the school mode.
    // Use the mode-specific authenticated cookie dump first.
    try {
      const persistedMode = await this.store.getSchoolLoginMode();
      if (persistedMode === 'inner' || persistedMode === 'webvpn') {
        this.logger.info('resolveSchoolMode: using persisted mode', persistedMode);
        return persistedMode as SchoolLoginMode;
      }
      const webvpnDump = await new SchoolCookieStore('webvpn').loadCookieDump();
      if (webvpnDump && webvpnDump.length > 0) {
        this.logger.info('resolveSchoolMode: using persisted webvpn school cookies');
        return 'webvpn';
      }
      const webvpnLexueDump = await new LexueCookieStore('webvpn').loadCookieDump();
      if (webvpnLexueDump && webvpnLexueDump.length > 0) {
        this.logger.info('resolveSchoolMode: using persisted webvpn lexue cookies');
        return 'webvpn';
      }
      const innerDump = await new SchoolCookieStore('inner').loadCookieDump();
      if (innerDump && innerDump.length > 0) {
        this.logger.info('resolveSchoolMode: using persisted inner school cookies');
        return 'inner';
      }
      const innerLexueDump = await new LexueCookieStore('inner').loadCookieDump();
      if (innerLexueDump && innerLexueDump.length > 0) {
        this.logger.info('resolveSchoolMode: using persisted inner lexue cookies');
        return 'inner';
      }
      // Backward compatibility for sessions created before school_login_mode
      // and SchoolCookieStore were introduced. A non-empty verification
      // cookie is the only persisted school signal in those installations;
      // it must win over the network probe (which reports inner merely
      // because the campus hostname is DNS-resolvable).
      const tokenCookie = await this.store.getWebvpnCookie();
      if (tokenCookie && tokenCookie.length > 0) {
        this.logger.info('resolveSchoolMode: using legacy token webvpn cookie');
        return 'webvpn';
      }
    } catch (error) {
      this.logger.warn('resolveSchoolMode storage probe failed', error);
    }
    const detected = await detectSchoolLoginMode({ debug: true });
    this.logger.info('resolveSchoolMode: network detected', detected);
    return detected;
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
    const visibleCount = this.visibleDayCount();
    const gaps = this.colGap * visibleCount;
    const usable = totalWidth - gaps;
    if (usable <= 0) {
      this.logger.debug('recomputeWidthMetrics: usable width is 0, ignoring.');
      return;
    }

    const c = Math.floor(usable / (visibleCount + 0.7));
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

  private onWeekendVisibilityChanged(): void {
    this.recomputeWidthMetrics(this.availableWidth)
  }

  private recomputeMetrics(availableHeight: number): void {
    this.logger.debug('recomputeMetrics: Fired.', 'availableHeight=', availableHeight);
    if (availableHeight <= 0) return
    const uh = Math.floor(availableHeight / this.periodCount())
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
    const count = this.visibleDayCount()
    return count * this.courseColWidth + Math.max(0, count - 1) * this.colGap
  }
  private rightAreaHeight(): number {
    return this.periodCount() * this.getUnitHeight()
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
    this.dlgCourse = null
    this.showCourseDlg = true
  }

  private onTapDisplayItem(item: ScheduleDisplayItem): void {
    if (item.rawExam) {
      this.dlgExam = item.rawExam
      this.showExamDlg = true
      return
    }
    if (item.rawCustom) {
      this.dlgCustom = item.rawCustom
      this.showCustomDlg = true
      return
    }
    if (item.rawCourse) {
      this.dlgCourse = item.rawCourse
      this.dlgEv = {
        summary: item.rawCourse.name,
        location: item.rawCourse.classroom,
        description: item.rawCourse.description,
        dtstart: '',
        dtend: '',
        uid: item.rawCourse.id,
      }
      this.dlgRaw = null
      this.showCourseDlg = true
    }
  }

  private closeCourseDlg(): void {
    this.showCourseDlg = false
  }

  private closeExamDlg(): void {
    this.showExamDlg = false
  }

  private closeCustomDlg(): void {
    this.showCustomDlg = false
  }

  private closeCustomEditDlg(): void {
    this.showCustomEditDlg = false
  }

  private openCreateCustom(): void {
    this.editingCustom = null
    this.showCustomEditDlg = true
  }

  private openEditCustom(item: CustomScheduleItem): void {
    this.editingCustom = item
    this.showCustomDlg = false
    this.showCustomEditDlg = true
  }

  private saveCustomSchedule(item: CustomScheduleItem): void {
    const store = this.createScheduleLocalStore()
    if (!store) {
      this.err = '无法获取应用文件目录'
      return
    }
    const items = upsertCustomSchedule(store.loadCustomSchedules(), item)
    store.saveCustomSchedules(items)
    this.customScheduleMemory = upsertCustomSchedule(this.customScheduleMemory, item)
    this.showCustomEditDlg = false
    this.dlgCustom = item
    this.loadLocalFirst(false)
  }

  private deleteCustomScheduleById(id: string): void {
    const store = this.createScheduleLocalStore()
    if (!store) {
      this.err = '无法获取应用文件目录'
      return
    }
    store.saveCustomSchedules(deleteCustomSchedule(store.loadCustomSchedules(), id))
    this.customScheduleMemory = deleteCustomSchedule(this.customScheduleMemory, id)
    this.showCustomDlg = false
    this.dlgCustom = null
    this.loadLocalFirst(false)
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
    uiPushUrl(this.getUIContext(), { url: 'pages/settings/CalendarSettingPage' })
      .catch((err: Error) => {
        this.logger.error('open schedule settings failed', err);
      });
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

  private periodCount(): number {
    return this.periodTimes && this.periodTimes.length > 0 ? this.periodTimes.length : 13
  }

  private syncPeriodTimesFromSettings(): void {
    if (this.appPeriodTimes && this.appPeriodTimes.length > 0) {
      this.periodTimes = this.appPeriodTimes;
    }
  }

  private visibleDayCount(): number {
    return visibleWeekdayNumbers(this.showSaturdaySetting, this.showSundaySetting).length
  }

  private isWeekdayVisible(weekday: number): boolean {
    if (weekday === 6) return this.showSaturdaySetting
    if (weekday === 7) return this.showSundaySetting
    return weekday >= 1 && weekday <= 5
  }

  private visibleWeekDays(): DayEvents[] {
    const out: DayEvents[] = []
    for (let i = 0; i < this.weekDays.length; i++) {
      const weekday = i + 1
      if (this.isWeekdayVisible(weekday)) {
        out.push(this.weekDays[i])
      }
    }
    return out
  }

  private visibleWeekLayouts(): DayLayout[] {
    const out: DayLayout[] = []
    for (let i = 0; i < this.weekLayouts.length; i++) {
      const weekday = i + 1
      if (this.isWeekdayVisible(weekday)) {
        out.push(this.weekLayouts[i])
      }
    }
    return out
  }

  private createScheduleLocalStore(): ScheduleLocalStore | null {
    const filesDir = this.getFilesDir()
    if (!filesDir || filesDir.length === 0) {
      return null
    }
    return new ScheduleLocalStore({ filesDir })
  }

  private filterCoursesByTerm(items: CourseScheduleItem[]): CourseScheduleItem[] {
    if (!this.currentTermSetting || this.currentTermSetting.length === 0) {
      return items
    }
    return items.filter((item: CourseScheduleItem) => item.term === this.currentTermSetting)
  }

  private filterExamsByTerm(items: ExamScheduleItem[]): ExamScheduleItem[] {
    if (!this.currentTermSetting || this.currentTermSetting.length === 0) {
      return items
    }
    return items.filter((item: ExamScheduleItem) => item.term === this.currentTermSetting)
  }

  private mergeCustomSchedules(stored: CustomScheduleItem[], memory: CustomScheduleItem[]): CustomScheduleItem[] {
    let out = stored
    for (const item of memory) {
      out = upsertCustomSchedule(out, item)
    }
    return out
  }

  private firstDayForSchedule(): string {
    if (this.firstDaySetting && this.firstDaySetting.length > 0) {
      return this.firstDaySetting
    }
    if (this.firstWeekISO && this.firstWeekISO.length > 0) {
      return this.firstWeekISO
    }
    return this.weekStartISO
  }

  private displayEventForItem(item: ScheduleDisplayItem): CalendarEvent {
    return {
      summary: item.title,
      location: item.subtitle,
      description: '',
      dtstart: '',
      dtend: '',
      uid: item.id,
    }
  }

  private itemBlocksForDay(items: ScheduleDisplayItem[], weekday: number): TimedScheduleBlock[] {
    const blocks: TimedScheduleBlock[] = []
    for (const item of items) {
      if (item.weekday !== weekday) {
        continue
      }
      blocks.push({
        startSection: item.startSection,
        endSection: item.endSection,
        ev: this.displayEventForItem(item),
        item,
      })
    }
    return blocks
  }

  private legacyBlocksForDay(layout: DayLayout): TimedScheduleBlock[] {
    const blocks: TimedScheduleBlock[] = []
    let cursor = 0
    for (const block of layout.blocks) {
      const start = cursor
      const end = cursor + block.units
      if (block.kind !== 0 && block.ev) {
        blocks.push({
          startSection: start,
          endSection: end,
          ev: block.ev,
          raw: block.raw,
        })
      }
      cursor = end
    }
    return blocks
  }

  private trimTimedBlocks(blocks: TimedScheduleBlock[]): TimedScheduleBlock[] {
    const sorted = blocks.slice().sort((a: TimedScheduleBlock, b: TimedScheduleBlock) => {
      if (a.startSection !== b.startSection) return a.startSection - b.startSection
      return b.endSection - a.endSection
    })
    const out: TimedScheduleBlock[] = []
    let cursor = 0
    for (const block of sorted) {
      let start = block.startSection
      if (start < cursor) {
        start = cursor
      }
      if (block.endSection <= start + 0.05) {
        continue
      }
      out.push({
        startSection: start,
        endSection: block.endSection,
        ev: block.ev,
        raw: block.raw,
        item: block.item,
      })
      cursor = block.endSection
    }
    return out
  }

  private blocksToDayLayout(date: Date, blocks: TimedScheduleBlock[]): DayLayout {
    const dayBlocks: DayBlock[] = []
    let cursor = 0
    const trimmed = this.trimTimedBlocks(blocks)
    for (const block of trimmed) {
      if (block.startSection > cursor) {
        dayBlocks.push({ kind: 0, units: block.startSection - cursor })
      }
      dayBlocks.push({
        kind: 1,
        units: block.endSection - block.startSection,
        ev: block.ev,
        raw: block.raw,
        item: block.item,
      })
      cursor = block.endSection
    }
    const tail = this.periodCount() - cursor
    if (tail > 0) {
      dayBlocks.push({ kind: 0, units: tail })
    }
    return { date, blocks: dayBlocks }
  }

  private layoutsFromDisplayItems(items: ScheduleDisplayItem[]): DayLayout[] {
    const wr = this.weekRangeFromISO(this.weekStartISO)
    const out: DayLayout[] = []
    for (let i = 0; i < 7; i++) {
      const date = new Date(wr.start.getFullYear(), wr.start.getMonth(), wr.start.getDate() + i)
      out.push(this.blocksToDayLayout(date, this.itemBlocksForDay(items, i + 1)))
    }
    return out
  }

  private mergeDisplayItemsIntoLegacyLayouts(legacyLayouts: DayLayout[], items: ScheduleDisplayItem[]): DayLayout[] {
    const out: DayLayout[] = []
    for (let i = 0; i < legacyLayouts.length; i++) {
      const date = legacyLayouts[i].date
      const blocks = this.legacyBlocksForDay(legacyLayouts[i]).concat(this.itemBlocksForDay(items, i + 1))
      out.push(this.blocksToDayLayout(date, blocks))
    }
    return out
  }

  private buildScheduleLayouts(weekInstances: CourseInstance[], legacyLayouts: DayLayout[]): DayLayout[] {
    const store = this.createScheduleLocalStore()
    if (!store) {
      return legacyLayouts
    }
    const courses = this.filterCoursesByTerm(store.loadCourses())
    const exams = this.filterExamsByTerm(store.loadExams())
    const customSchedules = this.mergeCustomSchedules(store.loadCustomSchedules(), this.customScheduleMemory)
    if (courses.length === 0 && exams.length === 0 && customSchedules.length === 0) {
      return legacyLayouts
    }

    const displayItems = buildWeekScheduleDisplayItems({
      weekStartISO: this.weekStartISO,
      weekNumber: computeWeekNumber(this.firstDayForSchedule(), this.weekStartISO),
      periodTimes: this.periodTimes,
      showExamInfo: this.showExamInfoSetting,
      courses,
      exams,
      customSchedules,
    })

    if (courses.length > 0 || weekInstances.length === 0) {
      return this.layoutsFromDisplayItems(displayItems)
    }
    return this.mergeDisplayItemsIntoLegacyLayouts(legacyLayouts, displayItems)
  }

  private startMinOf(i1: number): number {
    const idx = i1 - 1
    const t = (this.periodTimes && this.periodTimes.length > idx) ? this.periodTimes[idx] : null
    const m = t ? this.parseHHMMToMin(t.start) : null
    if (m == null) return 8 * 60 + (idx * 50) // 兜底
    return m
  }

  private endMinOf(i1: number): number {
    const idx = i1 - 1
    const t = (this.periodTimes && this.periodTimes.length > idx) ? this.periodTimes[idx] : null
    const mEnd = t ? this.parseHHMMToMin(t.end) : null
    if (mEnd != null) return mEnd
    const nextStart = (idx < this.periodCount() - 1) ? this.startMinOf(i1 + 1) : null
    if (nextStart != null) return nextStart
    return this.startMinOf(i1) + 50
  }

  private minutesOfDay(dt: Date): number {
    return dt.getHours() * 60 + dt.getMinutes()
  }

  private periodIndexByStart(dt: Date): number {
    const m = this.minutesOfDay(dt)
    for (let i1 = 1; i1 <= this.periodCount(); i1++) {
      const st = this.startMinOf(i1)
      const ed = this.endMinOf(i1)
      if (m >= st && m < ed) return i1
    }
    if (m < this.startMinOf(1)) return 1
    return this.periodCount()
  }

  private periodSpanByStartEnd(start: Date, end: Date): number {
    const sIdx = this.periodIndexByStart(start)
    const endMin = this.minutesOfDay(end)
    let eIdx = sIdx
    for (let probe = sIdx; probe <= this.periodCount(); probe++) {
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
    if (!this.periodTimes || this.periodTimes.length === 0) {
      this.periodTimes = this.timesStore.load()
    }
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
            weekDays: this.visibleWeekDays(),
            leftColWidth: this.leftColWidth,
            courseColWidth: this.courseColWidth,
            colGap: this.colGap,
            showHighlightToday: this.showHighlightTodaySetting
          })


          // --- 课表主体 ---
          Row() {
            // 左侧节次
            ScheduleSidebar({
              periodTimes: this.periodTimes,
              unitHeight: this.getUnitHeight(),
              baseFont: this.getBaseFont(),
              showDivider: this.showDividerSetting
            })
              .width(this.leftColWidth)
              .margin({ right: this.colGap })

            // 右侧网格
            ScheduleGrid({
              weekLayouts: this.visibleWeekLayouts(),
              unitHeight: this.getUnitHeight(),
              baseFont: this.getBaseFont(),
              courseColWidth: this.courseColWidth,
              colGap: this.colGap,
              courseColors: this.courseColors,
              rightAreaWidth: this.rightAreaWidth(),
              rightAreaHeight: this.rightAreaHeight(),
              periodTimes: this.periodTimes,
              showDivider: this.showDividerSetting,
              showCurrentTime: this.showCurrentTimeSetting,
              showBorder: this.showBorderSetting,
              onCourseClick: (ev, raw) => this.onTapEvent(ev, raw),
              onDisplayItemClick: (item: ScheduleDisplayItem) => this.onTapDisplayItem(item)
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
        this.availableWidth = w;
        this.recomputeWidthMetrics(w);

        // ❌ 修复：从这里【删除】高度计算
        // const h = Number(rect.height);
        // this.recomputeMetrics(h);
      })

      // --- 周切换导航 ---
      WeekNavigator({
        containerHeight: this.navigatorContainerHeight,
        onNext: () => this.onNextWeek(),
        onPrev: () => this.onPrevWeek(),
        onSettings: () => this.onSettings(),
        onAddCustom: () => this.openCreateCustom()
      })

      if (this.showCourseDlg) {
        CourseDetailDialog({
          ev: this.dlgEv,
          raw: this.dlgRaw,
          course: this.dlgCourse,
          baseFont: this.getBaseFont(),
          periodTimes: this.periodTimes,
          onClose: () => this.closeCourseDlg()
        })
      }

      if (this.showExamDlg) {
        ExamDetailDialog({
          exam: this.dlgExam,
          baseFont: this.getBaseFont(),
          onClose: () => this.closeExamDlg()
        })
      }

      if (this.showCustomDlg) {
        CustomScheduleDetailDialog({
          item: this.dlgCustom,
          baseFont: this.getBaseFont(),
          onClose: () => this.closeCustomDlg(),
          onEdit: (item: CustomScheduleItem) => this.openEditCustom(item),
          onDelete: (id: string) => this.deleteCustomScheduleById(id)
        })
      }

      if (this.showCustomEditDlg) {
        AddEditCustomScheduleDialog({
          item: this.editingCustom,
          defaultDateISO: this.weekStartISO,
          onCancel: () => this.closeCustomEditDlg(),
          onSave: (item: CustomScheduleItem) => this.saveCustomSchedule(item)
        })
      }
    }
    .height('100%')
    .width('100%')
    .onAreaChange((_, rect: Area) => {
      this.navigatorContainerHeight = Number(rect.height)
    })


  }
}
