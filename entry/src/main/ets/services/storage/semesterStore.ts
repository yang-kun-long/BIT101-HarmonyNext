// entry/src/main/ets/services/storage/semesterStore.ts
import fs from '@ohos.file.fs'

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
    this.rootDir = this.join(ctx.filesDir, 'bit101/timetable');
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
    // 逐级创建，兼容没有 recursive 选项的设备
    const parts = dir.split('/').filter(p => p.length > 0);
    let cur = dir.startsWith('/') ? '/' : '';
    for (let i = 0; i < parts.length; i++) {
      cur = this.join(cur || '', parts[i]);
      if (!this.exists(cur)) {
        try {
          fs.mkdirSync(cur);
        } catch (e: any) {
          if (e && e.code && e.code !== 'EEXIST') {
            throw e;
          }
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
    if (!this.exists(path)) return null;
    try {
      const text = fs.readTextSync(path);
      return JSON.parse(text) as T;
    } catch {
      return null;
    }
  }

  // 用 openSync + writeSync + closeSync 写文本，避免部分设备 writeTextSync 不落盘
  private writeJson(path: string, obj: unknown): void {
    this.ensureParentDir(path);
    const json = JSON.stringify(obj);
    const fd = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    try {
      fs.writeSync(fd.fd, json);
      fs.fsyncSync(fd.fd);
    } finally {
      fs.closeSync(fd);
    }
  }

  private fileSize(path: string): number {
    try { return fs.statSync(path).size; } catch { return 0; }
  }

  private semesterPath(semesterId: string): string {
    return this.join(this.rootDir, `semester-${semesterId}.json`);
  }

  private indexPath(): string {
    return this.join(this.rootDir, 'index.json');
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
      const key = ci.courseKey!;
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
    this.writeJson(p, payload);
    await this.upsertIndexItem(data.semesterId, payload.updatedAt, this.fileSize(p));
  }

  async loadSemester(semesterId: string): Promise<SemesterSnapshot | null> {
    const p = this.semesterPath(semesterId);
    const obj = this.readJson<SemesterSnapshot>(p);
    if (!obj) return null;

    // 惰性迁移：读取后补齐并回写
    const migrated = this.migrateSnapshot(obj);
    if (migrated && (migrated.version !== obj.version ||
      JSON.stringify(migrated.courseColors || {}) !== JSON.stringify(obj.courseColors || {}) ||
      // 粗略判断 instances 是否有回填（避免重写频繁，可根据需要细化）
    migrated.instances.some((ci, i) =>
    ci.courseKey !== obj.instances[i]?.courseKey || ci.teacher !== obj.instances[i]?.teacher
    )
    )) {
      this.writeJson(p, migrated);
      await this.upsertIndexItem(semesterId, migrated.updatedAt || Date.now(), this.fileSize(p));
      return migrated;
    }
    return obj;
  }

  async removeSemester(semesterId: string): Promise<void> {
    const p = this.semesterPath(semesterId);
    if (this.exists(p)) {
      try { fs.unlinkSync(p); } catch {}
    }
    await this.removeIndexItem(semesterId);
  }

  // ---------- 索引读写 ----------
  async listIndex(): Promise<SemesterIndex> {
    const obj = this.readJson<SemesterIndex>(this.indexPath());
    return obj && obj.items ? obj : { version: VERSION, items: [] };
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
    this.writeJson(this.indexPath(), out);
  }

  private async removeIndexItem(semesterId: string): Promise<void> {
    const idx = await this.listIndex();
    const out: SemesterIndex = { version: VERSION, items: [] };
    for (let i = 0; i < idx.items.length; i++) {
      if (idx.items[i].semesterId !== semesterId) out.items.push(idx.items[i]);
    }
    this.writeJson(this.indexPath(), out);
  }
}
