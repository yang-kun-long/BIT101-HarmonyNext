import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import { TokenStore } from '../storage/tokenStore';
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

export interface CourseScheduleApiResponse {
  datas?: {
    cxxszhxqkb?: {
      rows?: CourseScheduleApiRow[];
    };
  };
}

export function mapCourseScheduleApiResponse(
  payload: CourseScheduleApiResponse,
  fallbackTerm: string,
): CourseScheduleItem[] {
  const rows = payload.datas?.cxxszhxqkb?.rows;
  if (!Array.isArray(rows)) {
    throw new Error('getCourses response missing course rows');
  }
  return mapCourseScheduleApiRows(rows, fallbackTerm);
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
    const preview = (text || '').replace(/\s+/g, ' ').slice(0, 220);
    const html = /^\s*<(?:!doctype\s+html|html|head|body)\b/i.test(text || '');
    const suffix = html ? '; teaching-center session is not authenticated' : ` (${preview})`;
    throw new Error(`${label} response is not JSON${suffix}: ${String(e)}`);
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
  const slot = `${term}:${number}:${row.SKXQ || 0}:${row.KSJC || 0}:${row.JSJC || 0}:${weekKey}`;
  return slot + ':' + encodeURIComponent((row.SKJS || '').trim()) + ':' +
    encodeURIComponent((row.JASMC || '').trim()) + ':' + encodeURIComponent((row.XXXQMC || '').trim());
}

export function mapCourseScheduleApiRows(
  rows: CourseScheduleApiRow[],
  fallbackTerm: string,
): CourseScheduleItem[] {
  const out: CourseScheduleItem[] = [];
  const seenIds: Record<string, boolean> = {};
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
    if (weeks.length === 0) {
      continue;
    }
    const id = buildCourseId(row, term, weeks);
    if (seenIds[id]) {
      continue;
    }
    seenIds[id] = true;
    out.push({
      id,
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
    // LoginCoordinator also persists the WebVPN bootstrap Cookie header in
    // TokenStore. Convert it into the jar so the teaching-center requests
    // work even when no domain-aware dump was written yet.
    if (this.mode === 'webvpn') {
      const header = await new TokenStore().getWebvpnCookie();
      this.jar.restoreFromCookieHeaderForHosts(header, [
        this.baseUrl + '/',
        'https://webvpn.bit.edu.cn/',
        'https://jxzxehallapp.bit.edu.cn/',
      ]);
    }
    if (this.debug) {
      const domains: string[] = [];
      const snapshot = this.jar.dump();
      for (let i = 0; i < snapshot.length; i++) {
        if (domains.indexOf(snapshot[i].domain) < 0) domains.push(snapshot[i].domain);
      }
      logger.info('restored cookies count=', snapshot.length, 'domains=', domains.join(','), 'mode=', this.mode);
    }
  }

  getCookieDump(): CookieDump {
    return this.jar.dump();
  }

  private async warmup(): Promise<void> {
    // Course.getCourses on Android assumes the application index has first
    // initialized the teaching-center session and WebVPN rewrite context.
    const index = await this.client.get('/jwapp/sys/wdkbby/*default/index.do', {
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': this.baseUrl + '/',
      },
    });
    if (this.debug) logger.info('course app index HTTP', index.statusCode, 'mode=', this.mode, 'base=', this.baseUrl);
    assertOk(index, 'course app index');
    const config = await this.client.get('/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do');
    if (this.debug) logger.info('course app config HTTP', config.statusCode);
    const i18n = await this.client.get('/jwapp/i18n.do', {
      query: {
        appName: 'wdkbby',
        EMAP_LANG: 'zh',
      },
    });
    if (this.debug) logger.info('course app i18n HTTP', i18n.statusCode);
  }

  async getCourses(term: string): Promise<CourseScheduleItem[]> {
    const trimmed = term.trim();
    if (trimmed.length === 0) {
      throw new Error('term is empty');
    }
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.post(
      // Android Course.getCourses keeps the WebVPN host marker on this
      // rewritten endpoint; it is required by some WebVPN gateways.
      this.mode === 'webvpn'
        ? '/jwapp/sys/wdkbby/modules/xskcb/cxxszhxqkb.do?vpn-12-o2-jxzxehallapp.bit.edu.cn'
        : '/jwapp/sys/wdkbby/modules/xskcb/cxxszhxqkb.do',
      toFormUrlEncoded({ XNXQDM: trimmed }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      },
    );
    if (this.debug) logger.info('getCourses HTTP', resp.statusCode, 'term=', trimmed);
    assertOk(resp, 'getCourses');
    const parsed = parseJson<CourseScheduleApiResponse>(resp.bodyText, 'getCourses');
    const courses = mapCourseScheduleApiResponse(parsed, trimmed);
    if (this.debug) {
      logger.info('course count =', courses.length, 'term =', trimmed);
    }
    return courses;
  }
}
