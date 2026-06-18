import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import type { CourseScheduleItem } from '../schoolSchedule/ScheduleModels';
import {
  JXZXEHALLAPP_INNER_BASE,
  JXZXEHALLAPP_WEBVPN_BASE,
} from './freeClassroomRepository';

const logger = new Logger('CourseScheduleApiRepository');

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

export interface CourseScheduleApiRow {
  XNXQDM?: string;
  KCM?: string;
  SKJS?: string;
  JASMC?: string;
  YPSJDD?: string;
  SKZC?: string;
  SKXQ?: number;
  KSJC?: number;
  JSJC?: number;
  XXXQMC?: string;
  KCH?: string;
  XF?: number;
  XS?: number;
  KCXZDM_DISPLAY?: string;
  KCLBDM_DISPLAY?: string;
  KKDWDM_DISPLAY?: string;
}

interface CourseScheduleApiResponse {
  datas?: {
    cxxszhxqkb?: {
      rows?: CourseScheduleApiRow[];
    };
  };
}

export interface CourseScheduleApiRepositoryOptions {
  baseUrl?: string;
  mode?: SchoolLoginMode;
  debug?: boolean;
  cookieDump?: CookieDump;
  timeoutMs?: number;
}

export function getCourseBaseUrlForMode(mode: SchoolLoginMode): string {
  return mode === 'inner' ? JXZXEHALLAPP_INNER_BASE : JXZXEHALLAPP_WEBVPN_BASE;
}

function toFormUrlEncoded(fields: Record<string, string>): string {
  const keys = Object.keys(fields);
  const parts: string[] = [];
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(fields[key]));
  }
  return parts.join('&');
}

function parseJson<T>(text: string, label: string): T {
  try {
    return JSON.parse(text) as T;
  } catch (e) {
    throw new Error(`${label} response is not JSON: ${String(e)}`);
  }
}

function assertOk(resp: RcpResponseData, label: string): void {
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    const preview = (resp.bodyText || '').replace(/\s+/g, ' ').slice(0, 180);
    throw new Error(`${label} HTTP ${resp.statusCode}: ${preview}`);
  }
}

function weeksFromBitset(value: string): string {
  let weeks = '';
  for (let i = 0; i < value.length; i++) {
    if (value.charAt(i) === '1') {
      weeks += `[${i + 1}]`;
    }
  }
  return weeks;
}

function buildCourseId(row: CourseScheduleApiRow, term: string, weeks: string): string {
  const number = row.KCH || row.KCM || 'course';
  const weekKey = weeks.replace(/\]\[/g, '-').replace(/\[/g, '').replace(/\]/g, '');
  return `${term}:${number}:${row.SKXQ || 0}:${row.KSJC || 0}:${row.JSJC || 0}:${weekKey}`;
}

export function mapCourseScheduleApiRows(
  rows: CourseScheduleApiRow[],
  fallbackTerm: string,
): CourseScheduleItem[] {
  const out: CourseScheduleItem[] = [];
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const term = row.XNXQDM || fallbackTerm;
    const name = row.KCM || '';
    const weekday = row.SKXQ || 0;
    const startSection = row.KSJC || 0;
    const endSection = row.JSJC || 0;
    if (term.length === 0 || name.length === 0 || weekday < 1 || weekday > 7 || startSection < 1 || endSection < startSection) {
      continue;
    }
    const weeks = weeksFromBitset(row.SKZC || '');
    out.push({
      id: buildCourseId(row, term, weeks),
      term,
      name,
      teacher: row.SKJS || '',
      classroom: row.JASMC || '',
      description: row.YPSJDD || '',
      weeks,
      weekday,
      startSection,
      endSection,
      campus: row.XXXQMC || '',
      number: row.KCH || '',
      credit: row.XF || 0,
      hour: row.XS || 0,
      type: row.KCXZDM_DISPLAY || '',
      category: row.KCLBDM_DISPLAY || '',
      department: row.KKDWDM_DISPLAY || '',
    });
  }
  return out;
}

export class CourseScheduleApiRepository {
  private readonly baseUrl: string;
  private readonly mode: SchoolLoginMode;
  private readonly debug: boolean;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;

  constructor(options?: CourseScheduleApiRepositoryOptions) {
    this.mode = options?.mode || 'webvpn';
    const defaultBase = getCourseBaseUrlForMode(this.mode);
    this.baseUrl = (options?.baseUrl || defaultBase).replace(/\/+$/, '');
    this.debug = !!options?.debug;
    this.jar = new SimpleCookieJar();
    if (options?.cookieDump) {
      this.jar.restoreFromDump(options.cookieDump);
    }
    this.client = new RcpSession({
      baseUrl: this.baseUrl,
      debug: this.debug,
      timeoutMs: options?.timeoutMs || 15000,
      defaultHeaders: {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json, text/plain, */*',
      },
      cookieJar: this.jar,
    });
  }

  async restoreCookiesFromStorage(): Promise<void> {
    const schoolStore = new SchoolCookieStore(this.mode);
    const lexueStore = new LexueCookieStore('webvpn');
    const dump = await schoolStore.loadCookieDump() ?? (this.mode === 'webvpn' ? await lexueStore.loadCookieDump() : null);
    if (dump) {
      this.jar.restoreFromDump(dump);
    }
  }

  getCookieDump(): CookieDump {
    return this.jar.dump();
  }

  private async warmup(): Promise<void> {
    await this.client.get('/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do');
    await this.client.get('/jwapp/i18n.do', {
      query: {
        appName: 'wdkbby',
        EMAP_LANG: 'zh',
      },
    });
  }

  async getCourses(term: string): Promise<CourseScheduleItem[]> {
    const trimmed = term.trim();
    if (trimmed.length === 0) {
      throw new Error('term is empty');
    }
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.post(
      '/jwapp/sys/wdkbby/modules/xskcb/cxxszhxqkb.do',
      toFormUrlEncoded({ XNXQDM: trimmed }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      },
    );
    assertOk(resp, 'getCourses');
    const parsed = parseJson<CourseScheduleApiResponse>(resp.bodyText, 'getCourses');
    const rows = parsed.datas?.cxxszhxqkb?.rows || [];
    if (this.debug) {
      logger.info('course count =', rows.length, 'term =', trimmed);
    }
    return mapCourseScheduleApiRows(rows, trimmed);
  }
}
