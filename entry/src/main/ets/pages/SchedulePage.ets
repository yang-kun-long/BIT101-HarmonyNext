// entry/src/main/ets/pages/SchedulePage.ets

import fileIo from '@ohos.file.fs'

import { TimetableRepository, CalendarEvent } from '../services/jw/timetableRepository'
import { TokenStore } from '../services/storage/tokenStore'

// ⬇️ 新增：整学期本地优先接入
import { SemesterRepository, SemesterId } from '../services/jw/semesterRepository'
import { layoutsFromInstances } from '../services/jw/layoutFromInstances'
import type { CourseInstance, FilesCtx,RawIcsEvent } from '../services/storage/semesterStore'
import type { ToInstancesDeps } from '../services/jw/normalize'   // ← 新增
import { PeriodTimesStore } from '../services/jw/periodTimesStore'
import type { PeriodTime } from '../services/jw/periodTimes'



// ---------- 小工具 ----------
function pad2(n: number): string { return n < 10 ? '0' + n : '' + n }
function fmtDate(d: Date): string { return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}` }

// ---------- 本文件内部用到的类型 ----------
interface DayEvents { date: Date; events: CalendarEvent[] }
interface WeekRange { start: Date; end: Date }
interface DayBlock {
  kind: number;              // 0=空白；1=课程
  units: number;
  ev?: CalendarEvent;        // 卡片展示用
  raw?: RawIcsEvent;         // 🔸新增：详情弹窗用（完整 ICS 字段）
}

interface DayLayout { date: Date; blocks: DayBlock[] }
// 放在 DayBlock / DayLayout 定义附近
interface IsoLayout {
  dateISO: string;
  blocks: DayBlock[];
}
interface AbsoluteItem {
  top: number
  height: number
  units: number
  ev: CalendarEvent
  raw?: RawIcsEvent
}


@Component
export default struct SchedulePage {
  @State loading: boolean = true
  @State err: string = ''
  @State note: string = '' // 仍保留，但不展示

  @State events: CalendarEvent[] = []   // 仅用于“老的按周算布局”兜底
  @State hasWebvpn: boolean = false

  @State weekStartISO: string = ''  // 周一 YYYY-MM-DD
  @State weekTitle: string = ''     // “MM/DD - MM/DD”
  @State weekDays: DayEvents[] = [] // 仅给顶部日期用（保留）
  @State weekLayouts: DayLayout[] = [] // ✅ 真正渲染的数据源（来自整学期本地→按周过滤→转布局）
  @State showCourseDlg: boolean = false
  @State dlgEv: CalendarEvent | null = null
  @State dlgRaw: RawIcsEvent | null = null         // 🔽 新增：完整 ICS 原文
  // —— 自适应网格参数 ——
  // 实际可用高度（由 onAreaChange 回传）
  @State gridHeight: number = 0
  // 动态每节高度（默认 42，首次渲染后会自适应）
  @State unitHeight: number = 42
  // 卡片内边距（和你现在一致）
  private readonly innerPad = 6
  // 动态基础字号（标题与教室都用它；首次渲染后会自适应）
  @State baseFont: number = 12
  @State periodTimes: PeriodTime[] = []
  @State firstWeekISO: string = ''  // 学期起始周（周一，YYYY-MM-DD）
  @State colGap: number = 0          // 列间距（左右间隔）
  @State courseColWidth: number = 0  // 右侧每一天列的宽
  @State leftColWidth: number = 0    // 左侧索引列的宽
  // 状态区
  @State courseColors: Record<string, string> = {}








  @StorageProp('filesDir') filesDirFromApp: string = ''
  @StorageProp('cacheDir') cacheDirFromApp: string = ''
  @StorageProp('tempDir')  tempDirFromApp:  string = ''

  private repo = new TimetableRepository()
  private store = new TokenStore()
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
    // 兜底：若读不到，按默认 08:00 起每节 50 分钟估算
    if (m == null) return 8 * 60 + (idx * 50)
    return m
  }
  private endMinOf(i1: number): number {
    const idx = i1 - 1
    const t = (this.periodTimes && this.periodTimes.length === 13) ? this.periodTimes[idx] : null
    const mEnd = t ? this.parseHHMMToMin(t.end) : null
    if (mEnd != null) return mEnd
    // 若某节没有写结束时间：优先用下一节的开始时间作为结束，否则用开始+50兜底
    const nextStart = (idx < 12) ? this.startMinOf(i1 + 1) : null
    if (nextStart != null) return nextStart
    return this.startMinOf(i1) + 50
  }





  // ⬇️ 新增：整学期仓库（本地优先）
  private semRepo?: SemesterRepository
  private timesStore?: PeriodTimesStore

  aboutToAppear() {
    this.initWeek()
    this.initSemesterRepoIfNeeded()
    this.loadLocalFirst(false) // 首次：本地优先，不强制刷新
  }
  private recomputeWidthMetrics(totalWidth: number) {
    if (totalWidth <= 0) return;
    const gaps = this.colGap * 7;
    const usable = totalWidth - gaps;
    if (usable <= 0) return;

    // 右侧每一列
    const c = Math.floor(usable / 7.5);
    // 左侧列 = 课程列一半
    const l = Math.floor(c *0.7);

    if (c !== this.courseColWidth || l !== this.leftColWidth) {
      this.courseColWidth = c;
      this.leftColWidth = l;
    }
  }
  // 放在 SchedulePage 类里，直接替换原有两个方法

  private fsChk(label: string, p: string): void {
    try {
      const ok: boolean = fileIo.accessSync(p);
      console.info(`[FS] ${label}.access =`, ok, ' path =', p);
      if (ok) {
        try {
          const st: fileIo.Stat = fileIo.statSync(p);
          const size: number = st.size;
          let isFile = false;
          let isDir = false;
          try { isFile = st.isFile(); } catch { isFile = false; }
          try { isDir = st.isDirectory(); } catch { isDir = false; }
          console.info(`[FS] ${label}.stat size=`, size, ' isFile=', isFile, ' isDir=', isDir);
        } catch (se) {
          const msg: string = (se instanceof Error) ? se.message : String(se);
          console.error(`[FS] ${label}.stat.error =`, msg);
        }
      }
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      console.error(`[FS] ${label}.access.error =`, msg, ' path =', p);
    }
  }

  private logErr(where: string, e: Error | string): void {
    const msg: string = (typeof e === 'string') ? e : e.message;
    const stack: string = (typeof e === 'string') ? '' : (e.stack ?? '');
    console.error(`[ERR] ${where}:`, msg, '\nstack:', stack);
  }
  private logFsIo(label: string, path: string): void {
    try {
      const ok: boolean = fileIo.accessSync(path);
      let kind = 'unknown';
      if (ok) {
        try {
          const st: fileIo.Stat = fileIo.statSync(path);
          const isFile: boolean = (st as fileIo.Stat).isFile();
          const isDir: boolean = (st as fileIo.Stat).isDirectory();
          kind = isFile ? 'file' : (isDir ? 'dir' : 'other');
          console.info(`[FSIO] ${label} ok path=${path} kind=${kind} size=${st.size}`);
        } catch (_e) {
          console.info(`[FSIO] ${label} ok path=${path} (stat failed)`);
        }
      } else {
        console.info(`[FSIO] ${label} missing path=${path}`);
      }
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      console.error(`[FSIO] ${label} access error path=${path} msg=${msg}`);
    }
  }







  // 根据容器高度自适应计算每节高度 & 字号
  private recomputeMetrics(availableHeight: number) {
    if (availableHeight <= 0) return
    // 每天固定 13 节，尽量整除
    const uh = Math.floor(availableHeight / 13)
    // 3 行文字放进 1 个节：估算字号（行高≈字号），给一点余量避免换行抖动
    const usable = uh - this.innerPad * 2
    const fs = Math.max(10, Math.floor((usable / 3) * 0.92))
    // 避免无意义 setState 触发重算
    if (uh !== this.unitHeight || fs !== this.baseFont || availableHeight !== this.gridHeight) {
      this.unitHeight = uh
      this.baseFont = fs
      this.gridHeight = availableHeight
    }
  }

  // 提供一个安全获取“每节高度”的方法（避免 UI 里做计算）
  private getUnitHeight(): number {
    return this.unitHeight > 0 ? this.unitHeight : 42
  }
  // 提供一个安全获取“基础字号”的方法
  private getBaseFont(): number {
    return this.baseFont > 0 ? this.baseFont : 12
  }

  private onTapEvent(ev: CalendarEvent, raw?: RawIcsEvent) {
    this.dlgEv = ev
    this.dlgRaw = raw ? raw : null
    this.showCourseDlg = true
  }
  private rawAsPrettyJson(raw: RawIcsEvent | null): string {
    if (!raw) return ''
    return JSON.stringify(raw, null, 2) // 格式化展示
  }
  private closeCourseDlg() {
    this.showCourseDlg = false
  }

  private evTitle(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    if (raw && typeof raw.summary === 'string' && raw.summary.length > 0) {
      return raw.summary; // ✅ 优先用 ICS 原始标题，不再是裁剪过的
    }
    if (ev && ev.summary && ev.summary.length > 0) return ev.summary;
    return '(未命名)';
  }
  private evRoomFromRaw(raw?: RawIcsEvent | null): string {
    if (raw && typeof raw.location === 'string' && raw.location.length > 0) {
      return this.sanitizeLocation(raw.location);
    }
    return '';
  }
  private evRoom(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    const r = this.evRoomFromRaw(raw);
    if (r.length > 0) return r;
    if (ev && ev.location) return this.sanitizeLocation(ev.location);
    return '';
  }
  private evDateStr(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    const sIcs = (raw && raw.dtstart) ? String(raw.dtstart) : (ev ? ev.dtstart : undefined);
    const s = this.parseIcsToDate(sIcs);
    if (!s) return '';
    return `${s.getFullYear()}-${(s.getMonth()+1).toString().padStart(2,'0')}-${s.getDate().toString().padStart(2,'0')}`;
  }
  private evTimeStr(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    const sIcs = (raw && raw.dtstart) ? String(raw.dtstart) : (ev ? ev.dtstart : undefined);
    const eIcs = (raw && raw.dtend)   ? String(raw.dtend)   : (ev ? ev.dtend   : undefined);
    const s = this.parseIcsToDate(sIcs);
    const e = this.parseIcsToDate(eIcs);
    if (!s || !e) return '';
    const f = (n:number)=>n.toString().padStart(2,'0');
    return `${f(s.getHours())}:${f(s.getMinutes())} - ${f(e.getHours())}:${f(e.getMinutes())}`;
  }

  private evPeriodsStr(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    const sIcs = (raw && raw.dtstart) ? String(raw.dtstart) : (ev ? ev.dtstart : undefined);
    const eIcs = (raw && raw.dtend)   ? String(raw.dtend)   : (ev ? ev.dtend   : undefined);
    const s = this.parseIcsToDate(sIcs);
    const e = this.parseIcsToDate(eIcs);
    if (!s || !e) return '';
    const sp = this.periodIndexByStart(s);
    const span = this.periodSpanByStartEnd(s, e);
    const ep = sp + span - 1;
    return `第 ${sp} - ${ep} 节（共 ${span} 节）`;
  }


  // ---------- 新增：获取 filesDir & 初始化学期仓库 ----------
  private getFilesDir(): string {
    // 优先 filesDir，其次 cacheDir，再次 tempDir
    const pick = (this.filesDirFromApp && this.filesDirFromApp.length > 0)
      ? this.filesDirFromApp
      : ((this.cacheDirFromApp && this.cacheDirFromApp.length > 0)
        ? this.cacheDirFromApp
        : (this.tempDirFromApp || ''));

    console.info('[SchedulePage] pick dir =', pick)
    this.fsChk('filesDir.pick', pick)   // ← 新增

    if (!pick || pick.length === 0) {
      this.err = '无法获取应用文件目录（filesDir/cacheDir/tempDir 均为空）。请确认 EntryAbility.onCreate 已写入 AppStorage。'
    }
    return pick;
  }

  private initSemesterRepoIfNeeded() {
    if (this.semRepo) return

    // 把本页面已有的工具函数打包成依赖，传给 normalize
    // ✅ 显式对齐到接口类型，避免“未类型化对象字面量”
    const deps: ToInstancesDeps = {
      parseIcsToDate: (s?: string) => this.parseIcsToDate(s),
      periodIndexByStart: (d: Date) => this.periodIndexByStart(d),
      periodSpanByStartEnd: (s: Date, e: Date) => this.periodSpanByStartEnd(s, e),
      sanitizeLocation: (s?: string) => this.sanitizeLocation(s),
      trimTitle: (name?: string, units?: number) => this.trimmedTitleForCard(name, units),
      fmtDateISO: (d: Date) => fmtDate(d),
      weekStartISOOf: (anyDayISO: string) => this.weekStartOfISO(anyDayISO),
    }

    const filesDir: string = this.getFilesDir()
    this.fsChk('init.filesDir', filesDir)
    const filesCtx: FilesCtx = { filesDir }   // ← 先赋值给显式接口
    console.info('[Init] new SemesterRepository with filesDir =', filesDir)
    this.semRepo = new SemesterRepository(this.repo, filesCtx, deps)
    this.timesStore = new PeriodTimesStore({ filesDir })
    this.periodTimes = this.timesStore.load()
    console.info('[Init] periodTimes.loaded =', JSON.stringify(this.periodTimes)) // ← 新增

  }
  private weekNoText(): string {
    // 优先用 firstWeekISO；没有时退回到当前周一，结果至少为 1
    const baseISO: string = (this.firstWeekISO && this.firstWeekISO.length > 0)
      ? this.firstWeekISO
      : this.weekStartISO;

    // 解析成日期并计算差值
    const a = new Date(this.weekStartISO);
    const b = new Date(baseISO);
    const diffDays = Math.floor((a.getTime() - b.getTime()) / 86400000);
    const weeks = Math.floor(diffDays / 7) + 1;
    return (weeks < 1) ? '1' : String(weeks);
  }



  // 把 YYYY-MM-DD（任意一天）映射成这一周的周一 ISO 字符串
  private weekStartOfISO(anyDayISO: string): string {
    const p = anyDayISO.split('-')
    const y = parseInt(p[0]); const m = parseInt(p[1]) - 1; const d = parseInt(p[2])
    const monday = this.mondayOf(new Date(y, m, d))
    return fmtDate(monday)
  }

  // ---------- 老工具 & 业务计算（保留） ----------
  private sanitizeLocation(loc?: string): string {
    if (!loc) return ''
    let s = loc.replace(/北京理工大学(\(.*?\))?/g, '')
    s = s.replace(/^\s*[-、·,，]/, '').replace(/[-、·,，]\s*$/,'').trim()
    return s
  }
  private trimmedTitleForCard(name?: string, units?: number): string {
    if (!name || name.length === 0) return '(未命名)'
    const shortCard = (units !== undefined && units <= 1)
    if (shortCard || name.length > 8) {
      const h = name.length >= 2 ? name.slice(0, 2) : name
      return h + '…'
    }
    return name
  }
  private mondayOf(d: Date): Date {
    const x = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    const wd = x.getDay() === 0 ? 7 : x.getDay()
    if (wd > 1) x.setDate(x.getDate() - (wd - 1))
    return x
  }
  private weekRangeFromISO(iso: string): WeekRange {
    const parts = iso.split('-')
    const y = parseInt(parts[0]); const m = parseInt(parts[1]) - 1; const dd = parseInt(parts[2])
    const start = new Date(y, m, dd)
    const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 7)
    const wr: WeekRange = { start: start, end: end }
    return wr
  }
  private addDaysISO(iso: string, days: number): string {
    const parts = iso.split('-')
    const y = parseInt(parts[0]); const m = parseInt(parts[1]) - 1; const dd = parseInt(parts[2])
    const t = new Date(y, m, dd)
    t.setDate(t.getDate() + days)
    return fmtDate(t)
  }
  private isSameDate(a: Date, b: Date): boolean {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }
  private parseIcsToDate(ics: string | undefined): Date | null {
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
  private minutesOfDay(dt: Date): number { return dt.getHours() * 60 + dt.getMinutes() }
  private periodIndexByStart(dt: Date): number {
    const m = this.minutesOfDay(dt)
    // 在 1..13 范围内找第一个 [start, end) 区间
    for (let i1 = 1; i1 <= 13; i1++) {
      const st = this.startMinOf(i1)
      const ed = this.endMinOf(i1)
      if (m >= st && m < ed) return i1
    }
    // 若不在任何区间内：小于第一节 -> 1；大于最后一节 -> 13
    if (m < this.startMinOf(1)) return 1
    return 13
  }
  private periodSpanByStartEnd(start: Date, end: Date): number {
    const sIdx = this.periodIndexByStart(start)
    const endMin = this.minutesOfDay(end)

    // 从起始节往后探测，找到“覆盖到哪个节的结束边界”
    let eIdx = sIdx
    for (let probe = sIdx; probe <= 13; probe++) {
      const e = this.endMinOf(probe)
      if (endMin <= e) { eIdx = probe; break } // 注意：等于边界也算当前 probe 结束
      eIdx = probe
    }

    const span = eIdx - sIdx + 1
    return span < 1 ? 1 : span
  }


  private initWeek() {
    const monday = this.mondayOf(new Date())
    this.weekStartISO = fmtDate(monday)
    this.recomputeWeekHeader() // ← 重算周标题与顶部日期
  }



  // ---------- 🔴 核心变更：加载逻辑（本地优先 / 整学期） ----------
  private async loadLocalFirst(forceRefresh: boolean) {
    this.loading = true
    this.err = ''
    this.weekLayouts = []
    this.hasWebvpn = await this.store.isLoggedInWebvpn()

    if (!this.hasWebvpn) {
      this.loading = false
      this.err = '未登录教务（缺少 WebVPN 会话）'
      return
    }
    const filesDir = this.getFilesDir()
    if (!filesDir || filesDir.length === 0) {
      this.loading = false
      this.err = '无法获取应用文件目录（filesDir），请在 EntryAbility.onCreate 中设置 abilityContext。'
      return
    }
    if (!this.semRepo) {
      this.initSemesterRepoIfNeeded()
      if (!this.semRepo) {
        this.loading = false
        this.err = '学期仓库初始化失败'
        return
      }
    }

    try {
      const semIdStr: string = this.currentSemesterId();
      const sem: SemesterId = { id: semIdStr };
      console.info('[SEM] getSemester.begin id=', semIdStr, ' weekStartISO=', this.weekStartISO, ' filesDir=', this.getFilesDir());

      const result = await this.semRepo.getSemester(sem, forceRefresh);
      console.info('[SEM] getSemester.ok id=', semIdStr);

      // 取本周实例
      const weekInstances: CourseInstance[] = this.semRepo.filterWeekInstances(result.semester, this.weekStartISO);
      console.info('[SEM] filterWeekInstances.ok count=', weekInstances.length);

      // 课程颜色
      this.courseColors = (result.semester && result.semester.courseColors) ? result.semester.courseColors : {};

      // 计算本学期的第一周（按最小 weekStartISO 取）
      if (result && result.semester && result.semester.instances && result.semester.instances.length > 0) {
        const insts: CourseInstance[] = result.semester.instances;
        let minISO: string = insts[0].weekStartISO;
        for (let i = 1; i < insts.length; i++) {
          const iso: string = insts[i].weekStartISO;
          if (iso < minISO) minISO = iso;
        }
        this.firstWeekISO = minISO;
        console.info('[SEM] firstWeekISO.computed =', this.firstWeekISO);
      } else {
        this.firstWeekISO = this.weekStartISO;
        console.info('[SEM] firstWeekISO.fallback =', this.firstWeekISO);
      }

      // 转布局（跨行卡片）
      const layouts = layoutsFromInstances(this.weekStartISO, weekInstances);
      console.info('[SEM] layoutsFromInstances.ok days=', layouts.length);

      // 回填到页面
      this.weekLayouts = this.mapLayoutsWithDate(layouts);
      console.info('[SEM] weekLayouts.set days=', this.weekLayouts.length);
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      this.err = msg;
      console.error('[ERR] getSemester:', msg);
      const stack: string = (e instanceof Error && e.stack) ? e.stack : '';
      if (stack.length > 0) {
        console.error('[ERR] getSemester.stack:', stack);
      }
      console.error('[CTX] filesDir=', this.getFilesDir(), ' weekStartISO=', this.weekStartISO, ' semId=', this.currentSemesterId());
    } finally {
      this.loading = false;
    }

  }

  // 给 DayLayout 补充 Date 类型日期，方便顶部 DayHeader 使用
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

  // 简单的学期ID推断：用“最接近当前的学年-学期”占位（你也可以替换成后端返回的学期ID）
  private currentSemesterId(): string {
    const today = new Date()
    const y = today.getFullYear()
    const m = today.getMonth() + 1
    // 粗略：3-8 春季；9-2 秋季
    const term = (m >= 3 && m <= 8) ? 'spring' : 'fall'
    return `${y}-${term}`
  }

  // ---------- 旧按周直接算布局的方法（仅保留代码，不再使用） ----------
  // …（省略：computeLayouts 等保留方法可以删除，但我保留不调用，避免影响你其它引用）…

  private periods(): number[] {
    const arr: number[] = []
    let i = 1
    while (i <= 13) { arr.push(i); i++ }
    return arr
  }
  private periodNumText(i: number): string { return '' + i  }
  private periodTimeTextStart(i: number): string {
    if (!this.periodTimes || this.periodTimes.length !== 13) return '';
    const t = this.periodTimes[i - 1];
    if (!t || !t.start) return '';
    return t.start; // 只显示开始时间
  }
  private periodTimeTextEnd(i: number): string {
    if (!this.periodTimes || this.periodTimes.length !== 13) return '';
    const t = this.periodTimes[i - 1];
    if (!t || !t.end) return '';
    return t.end;
  }
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
          top: r * this.getUnitHeight(),
          height: units * this.getUnitHeight(),
          units,
          ev: b.ev!,
          raw: b.raw
        })
        r += units
      }
    }
    return items
  }




  // ===== UI 片段（@Builder 内不写 const/let）=====
  @Builder
  Status(ok: boolean, text: string) {
    Row() {
      Row() { }.width(10).height(10).borderRadius(5).backgroundColor(ok ? '#16a34a' : '#ef4444')
      Text(text).fontSize(12).fontColor(ok ? '#16a34a' : '#ef4444').margin({ left: 6 })
    }.margin({ bottom: 8 })
  }
  @Builder
  LeftHeader() {
    Column() {
      Text(this.weekNoText())
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0EA5E9')
        .textAlign(TextAlign.Center)
      Text('周').fontSize(12).fontColor('#6B7280').textAlign(TextAlign.Center)
    }
    .padding(4)
    .backgroundColor('#F3F4F6')
    .borderRadius(10)
  }
  @Builder
  LeftPeriods() {
    Column() {
      ForEach(this.periods(), (p: number, _idx: number) => {
        Column() {
          // 开始时间 —— 顶上
          Text(this.periodTimeTextStart(p))
            .fontSize(this.getBaseFont())
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)

          // 数字 —— 居中
          Text(this.periodNumText(p))
            .fontSize(this.getBaseFont())
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)

          // 结束时间--顶下
          Text(this.periodTimeTextEnd(p))
            .fontSize(this.getBaseFont())
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)


        }
        .height(this.getUnitHeight())  // 与网格严格对齐
        .border({ width: { bottom: (p === 13 ? 0 : 1) }, color: '#E5E7EB' })
        .padding(2)
      })
    }
  }




  @Builder
  DayHeader(d: Date, active: boolean) {
    // 第一行：周几；第二行：MM/DD；两行都居中
    Column() {
      Text(`周${['日','一','二','三','四','五','六'][d.getDay()]}`)
        .fontSize(12)
        .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(active ? '#0EA5E9' : '#6B7280')
        .textAlign(TextAlign.Center)

      Text(`${pad2(d.getMonth() + 1)}/${pad2(d.getDate())}`)
        .fontSize(12)
        .fontColor(active ? '#0EA5E9' : '#6B7280')
        .textAlign(TextAlign.Center)
    }
    .padding(4)
    .backgroundColor(active ? '#E0F2FE' : '#F3F4F6')
    .borderRadius(10)
  }


  @Builder
  PeriodGrid() {
    Column() {
      ForEach(this.periods(), (p: number, idx: number) => {
        Row() { }
        .height(this.getUnitHeight()) // 自适应 or 你原来的 UNIT_HEIGHT
        .backgroundColor('#00000000')
        .border({ width: { bottom: this.bottomLineWidth(idx) }, color: '#E5E7EB' })
      })
    }
  }
  private cardTitle(ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (raw && typeof raw.summary === 'string' && raw.summary.length > 0) return raw.summary;
    return ev.summary ? ev.summary : '(未命名)';
  }
  private cardRoom(ev: CalendarEvent, raw: RawIcsEvent | undefined): string {
    if (raw && typeof raw.location === 'string' && raw.location.length > 0) return this.sanitizeLocation(raw.location);
    return ev.location ? this.sanitizeLocation(ev.location) : '';
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
  private bottomLineWidth(idx: number): number {
    return idx === 12 ? 0 : 4; // 最后一格不画底线，其它画 1px
  }
  // 根据 weekStartISO 重算：weekTitle + weekDays（顶部日期用）
  private recomputeWeekHeader(): void {
    const wr = this.weekRangeFromISO(this.weekStartISO)

    // 周标题：MM/DD - MM/DD
    const startStr = `${pad2(wr.start.getMonth() + 1)}/${pad2(wr.start.getDate())}`
    const endMinus1 = new Date(wr.end.getFullYear(), wr.end.getMonth(), wr.end.getDate() - 1)
    const endStr = `${pad2(endMinus1.getMonth() + 1)}/${pad2(endMinus1.getDate())}`
    this.weekTitle = `${startStr} - ${endStr}`

    // 顶部 7 天
    const daysArr: DayEvents[] = []
    let i = 0
    while (i < 7) {
      const d = new Date(wr.start.getFullYear(), wr.start.getMonth(), wr.start.getDate() + i)
      daysArr.push({ date: d, events: [] })
      i++
    }
    this.weekDays = daysArr
  }
  private dayLeft(i: number): number {
    // 第 i 天（0~6）的左偏移 = i 个列宽 + i 个间距
    return i * (this.courseColWidth + this.colGap);
  }
  private rightAreaWidth(): number {
    // 7 列 + 6 个间距
    return 7 * this.courseColWidth + 6 * this.colGap
  }
  private rightAreaHeight(): number {
    return 13 * this.getUnitHeight()
  }






  @Builder
  RightCardsAbsolute() {
    Stack() {
      ForEach(this.weekLayouts, (dl: DayLayout, dayIdx: number) => {
        this.DayAbsoluteColumn(dl, dayIdx) // 你已经把计算移到普通方法，OK
      })
    }
    .width(this.rightAreaWidth())          // ✅
    .height(this.rightAreaHeight())        // ✅
  }


  @Builder
  DayAbsoluteColumn(dl: DayLayout, dayIdx: number) {
    ForEach(this.buildDayAbsoluteItems(dl), (it: AbsoluteItem, _k: number) => {
      // 外层承担绝对定位与尺寸，内部仍复用原有卡片样式
      Stack() {
        this.EventBlock(it.ev, it.units, it.raw)
      }
      .width(this.courseColWidth)
      .height(it.height)
      .position({
        x: this.dayLeft(dayIdx),
        y: it.top
      })
    })
  }
  // —— 轻量 normalize/哈希，与 semesterStore 的算法一致（确保同色）——
  private normalizeName(x?: string): string {
    return (x || '').trim().replace(/\s+/g, ' ').toLowerCase()
  }
  private pickTeacherFromRaw(raw?: RawIcsEvent | null): string {
    if (!raw) return ''
    const desc = (raw.description || '') + '\n' + (raw.rawText || '')
    const m = /(?:教师|老师|teacher)\s*[:：]\s*([^\n;]+)/i.exec(desc)
    return m ? m[1].trim() : ''
  }
  private makeCourseKeyForCard(ev: CalendarEvent | null, raw?: RawIcsEvent | null): string {
    // 课名优先用 raw.summary，其次 ev.summary
    const title = this.normalizeName(raw?.summary || (ev?.summary || ''))
    // 教师优先 raw 解析
    const teacher = this.normalizeName(this.pickTeacherFromRaw(raw))
    return `${title}|${teacher}`
  }


  private colorForCard(ev: CalendarEvent, raw?: RawIcsEvent): string {
    // 1) 优先用学期里存的颜色（与存储层完全一致）
    const key = this.makeCourseKeyForCard(ev, raw)
    return this.courseColors[key]
    // 2) 若没有（比如首次渲染），用本页同样算法兜底，视觉上不会跳
  }


  // 课程卡片：外层容器占满网格高度；内层留白不改变总高度
  @Builder
  EventBlock(ev: CalendarEvent, units: number, raw?: RawIcsEvent) {
    Column() {
      Column() {
        if (this.titleMaxLinesForUnits(units) > 0) {
          Text(this.cardTitle(ev, raw))
            .fontSize(this.getBaseFont())
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')            // ← 改：浅色文字
            .maxLines(this.titleMaxLinesForUnits(units))
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank().layoutWeight(1)
        Text(this.cardRoom(ev, raw))
          .fontSize(this.getBaseFont())
          .fontColor('#F3F4F6')              // ← 改：浅色文字
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Clip })
      }
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      .backgroundColor(this.colorForCard(ev, raw))                    // ← 改：课程色背景
      .borderRadius(10)
      .width('100%')
      .height('100%')
    }
    .height(units * this.getUnitHeight())
    .onClick(() => this.onTapEvent(ev, raw))
  }



  // 空白块：与课程块同高度策略
  @Builder
  EmptyBlock(units: number) {
    Row() { }.height(units * this.getUnitHeight())
  }
  @Builder
  RightGridAcross() {
    Column() {
      ForEach(this.periods(), (_p: number, idx: number) => {
        Row() { }
        .width('100%')                             // ✅ 必加
        .height(this.getUnitHeight())
        .border({ width: { bottom: (idx === 12 ? 0 : 1) }, color: '#E5E7EB' })
      })
    }
    .width(this.rightAreaWidth())
    .height(this.rightAreaHeight())
  }





  @Builder
  DayColumn(dl: DayLayout, isLast: boolean) {
    Stack() {
      // this.PeriodGrid()
      Column() {
        ForEach(dl.blocks, (b: DayBlock, j: number) => {
          if (b.kind === 0) { this.EmptyBlock(b.units) }
          else { this.EventBlock(b.ev!, b.units, b.raw) }
        })
      }
    }
    .height('100%')        // 关键：列本身撑满父容器
    .layoutWeight(1)
    .margin({ right: isLast ? 0 : 2 })
    .backgroundColor('#F8FAFC')
    .padding({ left: 0, right: 0 })
  }



  @Builder
  Fab(label: string, onTap: () => void) {
    Button(label).type(ButtonType.Capsule).onClick(() => onTap()).padding(12)
  }
  private roomFullForDialog(): string {
    return this.evRoom(this.dlgEv, this.dlgRaw);
  }



  // ===== 页面 =====
  build() {
    Stack() {
      Column() {
        Row() {
          Text('课表').fontSize(20).fontWeight(FontWeight.Bold)
          Text(`（${this.weekTitle}）`).fontSize(12).fontColor('#6B7280').margin({ left: 6 })
          Blank()
          // ⬇️ “刷新”按钮改为强制重拉，并写整学期本地
          Button('刷新').type(ButtonType.Capsule).onClick(async () => {
            await this.loadLocalFirst(true)              // 第一次：强制刷新
            setTimeout(() => { this.loadLocalFirst(false) }, 16) // 第二次：轻刷，给一帧时间
          })
        }.width('100%').margin({ top: 0 })

        // this.Status(this.hasWebvpn, this.hasWebvpn ? '教务会话可用' : '未登录教务（WebVPN）')

        if (this.loading) {
          Text('加载中…').fontSize(16)
        } else if (this.err.length > 0) {
          Column() {
            Text('加载失败').fontColor('#ef4444').fontSize(16)
            Text(this.err).fontColor('#ef4444').fontSize(12).maxLines(3)
            Button('重试').type(ButtonType.Capsule).onClick(() => { this.loadLocalFirst(true) }).margin({ top: 8 })
          }
        } else {
          // 顶部 7 天

          Row() {
            // 左侧窄列头（“周 / 周数”）
            Column() { this.LeftHeader() }
            .width(this.leftColWidth)                  // ← 自适应
            .margin({ right: this.colGap })

            // 右侧 7 天头部
            ForEach(this.weekDays, (d: DayEvents, i: number) => {
              Column() {
                this.DayHeader(d.date, this.isSameDate(d.date, new Date()))
              }
              .width(this.courseColWidth)                // ← 自适应
              .margin({ right: i < 6 ? this.colGap : 0 })
            })
          }
          .width('100%')
          .onAreaChange((_, rect) => {
            const w = (typeof rect.width === 'number') ? rect.width : parseFloat(String(rect.width));
            this.recomputeWidthMetrics(w);
          })


          // —— 页面 build() 里，7 天区域（去掉 DayColumn 列式渲染）——
          Row() {
            // 左侧节次/时间（保留）
            Column() { this.LeftPeriods() }
            .width(this.leftColWidth)
            .margin({ right: this.colGap })

            // 右侧：一个 Stack
            Stack() {
              // 底层：横线贯穿（无竖线）
              this.RightGridAcross()

              // 顶层：绝对定位的卡片集合
              this.RightCardsAbsolute()
            }
            .width(this.rightAreaWidth())            // ✅ 用确切宽高
            .height(this.rightAreaHeight())
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ top: 8 })
          .onAreaChange((_, rect) => {
            const w = Number(rect.width); this.recomputeWidthMetrics(w);
            const h = Number(rect.height); this.recomputeMetrics(h);
          })




        }
      }
      // 底部间距按你的需要，这里不与底部导航重叠
      .padding({ left: 10, right: 10, top: 0, bottom: 0 })
      .width('100%')
      .height('100%')

      // 周切换
      // —— 悬浮操作区（右下角）——
      Column() {
        this.Fab('＋', () => {
          this.weekStartISO = this.addDaysISO(this.weekStartISO, 7)
          this.recomputeWeekHeader()
          this.loadLocalFirst(false)
        })
        this.Fab('－', () => {
          this.weekStartISO = this.addDaysISO(this.weekStartISO, -7)
          this.recomputeWeekHeader()
          this.loadLocalFirst(false)
        })
        this.Fab('⚙️', () => { /* this.openSettings() */ })
      }
      .align(Alignment.Center)            // ← 以整屏为参照（根 Stack）
      .margin({ right: '-85%', bottom: '-140%'})     // ← 正常安全边距（正数）
      .zIndex(10)                            // ← 需要的话，确保在上层





      // —— 课程详情弹窗（覆盖层）——
      if (this.showCourseDlg && this.dlgEv) {
        Row() { }
        .width('100%').height('100%')
        .backgroundColor('#00000066')
        .onClick(() => this.closeCourseDlg())

        Column() {
          Text(this.evTitle(this.dlgEv, this.dlgRaw))
            .fontSize(18).fontWeight(FontWeight.Bold)
            .maxLines(10)
            .textOverflow({ overflow: TextOverflow.Clip })

          Text(this.evDateStr(this.dlgEv, this.dlgRaw) + '  ' + this.evTimeStr(this.dlgEv, this.dlgRaw))
            .fontSize(this.getBaseFont()).fontColor('#6B7280')
            .margin({ top: 6 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Clip })

          Text(this.evPeriodsStr(this.dlgEv, this.dlgRaw))
            .fontSize(this.getBaseFont()).fontColor('#6B7280')
            .margin({ top: 2 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Clip })

          if (this.roomFullForDialog().length > 0) {
            Text('教室：' + this.roomFullForDialog())
              .fontSize(14)
              .margin({ top: 10 })
              .maxLines(10)
              .textOverflow({ overflow: TextOverflow.Clip })
          }

          if (this.dlgRaw) {
            Text('—— ICS 原始字段 ——')
              .fontSize(12).fontColor('#6B7280').margin({ top: 12, bottom: 4 })
            Scroll() {
              Text(this.rawAsPrettyJson(this.dlgRaw))
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
            Button('关闭').type(ButtonType.Capsule).onClick(() => this.closeCourseDlg())
          }.margin({ top: 12 })
        }
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .width('86%')
        .height('72%')   // 用 maxHeight，避免超裁切
        .align(Alignment.Center)
      }


    }
    .width('100%')
    .height('100%')



  }

}
