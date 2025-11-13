// entry/src/main/ets/services/storage/semesterStore.ts
import fs from '@ohos.file.fs'
import util from '@ohos.util'

/** ICS 属性（含参数） */
export interface IcsProp {
  name: string;                                // 如 'DTSTART'
  params?: Record<string, string>;             // 如 { TZID: 'Asia/Shanghai' }
  value: string;                               // 原始或解析后的值
}

/** ICS 事件原文（详情弹窗用） */
export interface RawIcsEvent {
  // 常用直达字段（便于渲染/搜索）
  uid?: string;
  summary?: string;
  description?: string;
  location?: string;
  dtstart?: string;
  dtend?: string;

  // ★ 保真字段
  rawText?: string;      // VEVENT 原文（含参数/折行）
  props?: IcsProp[];     // 参数化后的属性列表（可多次出现 ATTENDEE/EXDATE）

  // 兜底：其它非标字段
  [key: string]: string | string[] | IcsProp[] | undefined;
}

/** 一次具体上课（已对齐到节次） */
export interface CourseInstance {
  instanceId: string;
  dateISO: string;
  weekStartISO: string;
  startPeriod: number;
  span: number;
  title: string;
  room: string;

  // 详情原文
  raw: RawIcsEvent;

  // 用于“同课同色”的归并键
  teacher?: string;
  courseKey?: string;

  // 可选：直接保留 ICS 的关键 id/时间
  rawUid?: string;
  rawDtStart?: string;
  rawDtEnd?: string;
}

/** 一个学期的完整快照 */
export interface SemesterSnapshot {
  semesterId: string;    // 如 "2025-fall"
  startISO: string;
  endISO: string;
  updatedAt: number;
  version: number;

  instances: CourseInstance[];

  /** 课程颜色映射：key=courseKey，value=#RRGGBB */
  courseColors?: Record<string, string>;
}

/** 索引文件（本地有哪些学期） */
export interface SemesterIndex {
  version: number;
  items: Array<{ semesterId: string; updatedAt: number; size: number }>;
}

export interface FilesCtx { filesDir: string }

// ---------------- 配色 & 归并工具 ----------------

const COLOR_PALETTE = [
  '#4F46E5', '#10B981', '#F59E0B', '#EF4444', '#06B6D4',
  '#8B5CF6', '#84CC16', '#F43F5E', '#0EA5E9', '#D946EF',
  '#22C55E', '#EAB308', '#64748B', '#14B8A6', '#FB7185'
];

// 简单哈希：把字符串映射到 0..2^32-1
function hash32(s: string): number {
  let h = 2166136261 >>> 0; // FNV-1a FNV offset basis
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function normalizeName(x?: string): string {
  return (x || '').trim().replace(/\s+/g, ' ').toLowerCase();
}

// 你可以替换这段为“从 raw.description/raw.organizer 等解析教师名”
function pickTeacher(ci: CourseInstance): string {
  if (ci.teacher) return ci.teacher;
  const desc = (ci.raw?.description || '') + '\n' + (ci.raw?.rawText || '');
  const m = /(?:教师|老师|teacher)\s*[:：]\s*([^\n;]+)/i.exec(desc);
  return m ? m[1].trim() : '';
}

function makeCourseKey(ci: CourseInstance): string {
  const title = normalizeName(ci.title);
  const teacher = normalizeName(pickTeacher(ci));
  return `${title}|${teacher}`;
}

function colorForKey(key: string): string {
  const idx = COLOR_PALETTE.length > 0 ? (hash32(key) % COLOR_PALETTE.length) : 0;
  return COLOR_PALETTE[idx] || '#64748B';
}

// ---------------- 常量 ----------------

/**
 * 数据版本
 * 1：无 courseColors / courseKey / ICS 保真字段的旧结构
 * 2：引入 courseColors、courseKey、rawText/props，并修复 exists()
 */
const VERSION = 2;

// ---------------- 存储类 ----------------

export class SemesterStore {
  private readonly rootDir: string;

  constructor(ctx: FilesCtx) {
    // <filesDir>/bit101/timetable
    this.rootDir = ctx.filesDir;
    console.info('[SEMFS] ctor.rootDir =', this.rootDir);
    this.ensureDirRecursive(this.rootDir); // 仍然留着，幂等
    console.info('[SEMFS] ctor.rootDir =', this.rootDir);
    this.ensureDirRecursive(this.rootDir);
  }

  // ---------- 路径/文件工具 ----------
  private join(a: string, b: string): string {
    return a.endsWith('/') ? (a + b) : (a + '/' + b);
  }

  private exists(path: string): boolean {
    try {
      fs.accessSync(path);
      return true;
    } catch {
      return false;
    }
  }

  private ensureDirRecursive(dir: string): void {
    const norm: string = dir.replace(/\/+/g, '/');
    const parts: string[] = norm.split('/').filter(p => p.length > 0);
    let cur: string = norm.startsWith('/') ? '/' : '';
    for (let i = 0; i < parts.length; i++) {
      const next = parts[i];
      cur = this.join(cur || '', next);
      const exists: boolean = this.exists(cur);
      console.info('[SEMFS] ensureDir step=', i, ' dir=', cur, ' exists=', exists);
      if (!exists) {
        try {
          fs.mkdirSync(cur);
          console.info('[SEMFS] mkdir ok dir=', cur);
        } catch (e) {
          const msg: string = (e instanceof Error) ? e.message : String(e);
          console.error('[SEMFS] mkdir failed dir=', cur, ' msg=', msg);
          // 不修改行为：交给后续 openSync 抛错
        }
      }
    }
  }


  private ensureParentDir(filePath: string): void {
    const idx = filePath.lastIndexOf('/');
    const dir = idx >= 0 ? filePath.slice(0, idx) : '';
    if (dir) this.ensureDirRecursive(dir);
  }

  private readJson<T>(path: string): T | null {
    if (!this.exists(path)) {
      console.info('[SEMFS] readJson.miss path =', path);
      return null;
    }
    try {
      console.info('[SEMFS] readJson.path =', path);
      const text = fs.readTextSync(path);
      const obj = JSON.parse(text) as T;
      console.info('[SEMFS] readJson.ok size =', text.length);
      return obj;
    } catch (e) {
      const msg: string = (e instanceof Error) ? e.message : String(e);
      console.error('[SEMFS] readJson.failed path =', path, ' msg =', msg);
      return null;
    }
  }

  // 用 openSync + writeSync + closeSync 写文本，避免部分设备 writeTextSync 不落盘
  private writeJson(path: string, obj: object): void {
    const parentIdx: number = path.lastIndexOf('/');
    const parent: string = parentIdx >= 0 ? path.slice(0, parentIdx) : '';
    console.info('[SEMFS] writeJson.path =', path, ' parent =', parent);

    // 父目录存在性/类型日志
    try {
      const exists: boolean = parent.length > 0 ? this.exists(parent) : false;
      console.info('[SEMFS] writeJson.parent.exists =', exists);
      if (exists) {
        try {
          const st = fs.statSync(parent);
          let isDir = false;
          let isFile = false;
          try { isDir = st.isDirectory(); } catch { isDir = false; }
          try { isFile = st.isFile(); } catch { isFile = false; }
          console.info('[SEMFS] writeJson.parent.kind isDir=', isDir, ' isFile=', isFile, ' size=', st.size);
        } catch (se) {
          const msg: string = (se instanceof Error) ? se.message : String(se);
          console.error('[SEMFS] writeJson.parent.stat.error =', msg);
        }
      }
    } catch (pe) {
      const msg: string = (pe instanceof Error) ? pe.message : String(pe);
      console.error('[SEMFS] writeJson.parent.check.error =', msg, ' parent =', parent);
    }

    // 仍确保父目录
    this.ensureParentDir(path);

    // 实际写入：先尝试 open+write；失败则触发“touch -> reopen”兜底
    let stage: string = 'encode';
    try {
      const json = JSON.stringify(obj);
      const enc = new util.TextEncoder();
      const bytes = enc.encode(json);
      console.info('[SEMFS] writeJson.bytes =', bytes.byteLength);

      stage = 'open';
      let fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      console.info('[SEMFS] writeJson.open.ok fd=', fd.fd);

      try {
        stage = 'write';
        const written = fs.writeSync(fd.fd, bytes.buffer);
        console.info('[SEMFS] writeJson.write.ok bytes=', written);

        stage = 'fsync';
        fs.fsyncSync(fd.fd);
        console.info('[SEMFS] writeJson.fsync.ok');
      } finally {
        try { stage = 'close'; fs.closeSync(fd); console.info('[SEMFS] writeJson.close.ok'); } catch { /* ignore */ }
      }

      console.info('[SEMFS] writeJson.done path =', path);
    } catch (e) {
      const firstMsg: string = (e instanceof Error) ? e.message : String(e);
      console.error('[SEMFS] writeJson.failed stage=', stage, ' path =', path, ' msg =', firstMsg);

      // 仅在 open 阶段 ENOENT/找不到时，执行兜底：用 openSync(create+read_only) 触发“touch”，再 reopen
      const needFallback: boolean = (stage === 'open') && (firstMsg.indexOf('No such file or directory') >= 0);
      if (!needFallback) throw e;

      console.info('[SEMFS] writeJson.fallback.touch+reopen path =', path);
      try {
        // 1) touch：不 TRUNC，只 CREATE + READ_ONLY 打开并马上关闭，生成一个空文件
        const fdTouch = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_ONLY);
        try {
          console.info('[SEMFS] writeJson.fallback.touch.open.ok fd=', fdTouch.fd);
        } finally {
          try { fs.closeSync(fdTouch); } catch { /* ignore */ }
        }

        // 2) 重新以 READ_WRITE + TRUNC 打开并写入
        const json2 = JSON.stringify(obj);
        const enc2 = new util.TextEncoder();
        const bytes2 = enc2.encode(json2);

        const fd2 = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        try {
          const written2 = fs.writeSync(fd2.fd, bytes2.buffer);
          console.info('[SEMFS] writeJson.fallback.write.ok bytes=', written2);
          fs.fsyncSync(fd2.fd);
          console.info('[SEMFS] writeJson.fallback.fsync.ok');
        } finally {
          try { fs.closeSync(fd2); } catch { /* ignore */ }
        }
        console.info('[SEMFS] writeJson.fallback.done path =', path);
      } catch (e2) {
        const msg2: string = (e2 instanceof Error) ? e2.message : String(e2);
        console.error('[SEMFS] writeJson.fallback.failed path =', path, ' msg =', msg2);
        throw e2; // 保持原抛错
      }
    }
  }



  private fileSize(path: string): number {
    try {
      const size = fs.statSync(path).size;
      return size;
    } catch {
      return 0;
    }
  }

  private semesterPath(semesterId: string): string {
    return this.join(this.rootDir, `semester-${semesterId}.json`);
  }

  private indexPath(): string {
    return this.join(this.rootDir, 'semester-index.json');
  }

  // ---------- 迁移/补齐逻辑 ----------
  /**
   * 对快照做惰性迁移：
   * - 回填 courseKey/teacher
   * - 生成或合并 courseColors
   * - 升级 version
   * - 可在此加入后续的字段修复逻辑
   */
  private migrateSnapshot(s: SemesterSnapshot | null): SemesterSnapshot | null {
    if (!s) return s;

    let updated = false;

    // 1) 回填 courseKey/teacher
    for (const ci of s.instances) {
      const teacher = pickTeacher(ci);
      if (teacher && ci.teacher !== teacher) {
        ci.teacher = teacher;
        updated = true;
      }
      if (!ci.courseKey) {
        ci.courseKey = makeCourseKey(ci);
        updated = true;
      }
    }

    // 2) 生成或合并 courseColors
    const colors = { ...(s.courseColors || {}) };
    for (const ci of s.instances) {
      const key = ci.courseKey || makeCourseKey(ci);
      if (!colors[key]) {
        colors[key] = colorForKey(key);
        updated = true;
      }
    }
    if (!s.courseColors || Object.keys(colors).length !== Object.keys(s.courseColors).length) {
      s.courseColors = colors;
    }

    // 3) 版本升级
    if (s.version !== VERSION) {
      s.version = VERSION;
      updated = true;
    }

    return s && updated ? s : s;
  }

  // ---------- 主文件读写 ----------
  async saveSemester(data: SemesterSnapshot): Promise<void> {
    // 1) 生成/补全 courseKey/teacher
    for (const ci of data.instances) {
      const teacher = pickTeacher(ci);
      if (teacher && ci.teacher !== teacher) {
        ci.teacher = teacher;
      }
      if (!ci.courseKey) ci.courseKey = makeCourseKey(ci);
    }

    // 2) 生成或合并 courseColors
    const existing = data.courseColors || {};
    const merged: Record<string, string> = { ...existing };
    for (const ci of data.instances) {
      const key = ci.courseKey ? ci.courseKey : makeCourseKey(ci);
      if (!merged[key]) {
        merged[key] = colorForKey(key);
      }
    }

    const payload: SemesterSnapshot = {
      semesterId: data.semesterId,
      startISO: data.startISO,
      endISO: data.endISO,
      updatedAt: (data.updatedAt && data.updatedAt > 0) ? data.updatedAt : Date.now(),
      version: VERSION,
      instances: data.instances,
      courseColors: merged
    };

    const p = this.semesterPath(data.semesterId);
    console.info('[SEMFS] saveSemester.path =', p, ' semId =', data.semesterId);
    const parentIdx = p.lastIndexOf('/');
    const parent = parentIdx >= 0 ? p.slice(0, parentIdx) : '';
    try {
      const parentOk = parent.length > 0 ? this.exists(parent) : false;
      console.info('[SEMFS] saveSemester.parent.exists =', parentOk, ' parent =', parent);
    } catch (pe) {
      const msg: string = (pe instanceof Error) ? pe.message : String(pe);
      console.error('[SEMFS] saveSemester.parent.check.error =', msg, ' parent =', parent);
    }

    this.writeJson(p, payload);
    const sizeAfter = this.fileSize(p);
    console.info('[SEMFS] saveSemester.after.size =', sizeAfter, ' path =', p);

    await this.upsertIndexItem(data.semesterId, payload.updatedAt, sizeAfter);
  }

  async loadSemester(semesterId: string): Promise<SemesterSnapshot | null> {
    const p = this.semesterPath(semesterId);
    const obj = this.readJson<SemesterSnapshot>(p);
    if (!obj) {
      console.info('[SEMFS] loadSemester.miss path =', p);
      return null;
    }

    // 惰性迁移：读取后补齐并回写
    const migrated = this.migrateSnapshot(obj);
    const needRewrite =
      !!migrated &&
        (
          migrated.version !== obj.version ||
            JSON.stringify(migrated.courseColors || {}) !== JSON.stringify(obj.courseColors || {}) ||
          migrated.instances.some((ci, i) =>
          ci.courseKey !== obj.instances[i]?.courseKey || ci.teacher !== obj.instances[i]?.teacher
          )
        );

    if (needRewrite && migrated) {
      console.info('[SEMFS] loadSemester.migrate.rewrite path =', p);
      this.writeJson(p, migrated);
      await this.upsertIndexItem(semesterId, migrated.updatedAt || Date.now(), this.fileSize(p));
      return migrated;
    }
    return obj;
  }

  async removeSemester(semesterId: string): Promise<void> {
    const p = this.semesterPath(semesterId);
    if (this.exists(p)) {
      try {
        fs.unlinkSync(p);
        console.info('[SEMFS] removeSemester.unlink path =', p);
      } catch (e) {
        const msg: string = (e instanceof Error) ? e.message : String(e);
        console.error('[SEMFS] removeSemester.unlink.failed path =', p, ' msg =', msg);
      }
    }
    await this.removeIndexItem(semesterId);
  }

  // ---------- 索引读写 ----------
  async listIndex(): Promise<SemesterIndex> {
    const idxPath = this.indexPath();
    const obj = this.readJson<SemesterIndex>(idxPath);
    if (obj && obj.items) {
      return obj;
    }
    console.info('[SEMFS] listIndex.default path =', idxPath);
    return { version: VERSION, items: [] };
  }

  private async upsertIndexItem(semesterId: string, updatedAt: number, size: number): Promise<void> {
    const idx = await this.listIndex();
    const out: SemesterIndex = { version: VERSION, items: [] };
    let replaced = false;
    for (let i = 0; i < idx.items.length; i++) {
      const it = idx.items[i];
      if (it.semesterId === semesterId) {
        out.items.push({ semesterId, updatedAt, size });
        replaced = true;
      } else {
        out.items.push(it);
      }
    }
    if (!replaced) out.items.push({ semesterId, updatedAt, size });

    const ip = this.indexPath();
    console.info('[SEMFS] upsertIndexItem.path =', ip, ' semId =', semesterId, ' size =', size);
    this.writeJson(ip, out);
  }

  private async removeIndexItem(semesterId: string): Promise<void> {
    const idx = await this.listIndex();
    const out: SemesterIndex = { version: VERSION, items: [] };
    for (let i = 0; i < idx.items.length; i++) {
      if (idx.items[i].semesterId !== semesterId) out.items.push(idx.items[i]);
    }
    const ip = this.indexPath();
    console.info('[SEMFS] removeIndexItem.path =', ip, ' semId =', semesterId);
    this.writeJson(ip, out);
  }
}
