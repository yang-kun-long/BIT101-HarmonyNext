import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import type { ExamScheduleItem } from '../schoolSchedule/ScheduleModels';
import {
  JXZXEHALLAPP_INNER_BASE,
  JXZXEHALLAPP_WEBVPN_BASE,
} from './freeClassroomRepository';
import { normalizeSchoolTermCode } from '../schoolSchedule/termUtils';

const logger = new Logger('CourseExamRepository');

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

export interface ExamApiRow {
  JASMC?: string;
  KSSJMS?: string;
  KSRQ?: string;
  ZWH?: string;
  KSMC?: string;
  XNXQDM_DISPLAY?: string;
  KCM?: string;
  ZJJSXM?: string;
  KCH?: string;
}

interface ExamApiResponse {
  datas?: {
    cxxsksap?: {
      rows?: ExamApiRow[];
    };
  };
}

export interface ExamTimeRange {
  beginTime: string;
  endTime: string;
}

export interface ExamScheduleRepositoryOptions {
  baseUrl?: string;
  mode?: SchoolLoginMode;
  debug?: boolean;
  cookieDump?: CookieDump;
  timeoutMs?: number;
}

export function getExamBaseUrlForMode(mode: SchoolLoginMode): string {
  return mode === 'inner' ? JXZXEHALLAPP_INNER_BASE : JXZXEHALLAPP_WEBVPN_BASE;
}

function normalizeClock(value: string): string {
  const parts = value.trim().split(':');
  if (parts.length < 2) {
    return '';
  }
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return '';
  }
  return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
}

function dateISOFromExamDate(value: string): string {
  const match = /^(\d{4}-\d{2}-\d{2})/.exec(value.trim());
  return match ? match[1] : '';
}

function extractCourseName(value: string): string {
  const text = value.trim();
  if (text.length === 0) {
    return '';
  }
  const leading = /^\[[^\]]+\](.+)$/.exec(text);
  if (leading && leading[1].trim().length > 0) {
    return leading[1].trim();
  }
  const trailing = /^(.+)\[[^\]]+\]$/.exec(text);
  if (trailing && trailing[1].trim().length > 0) {
    return trailing[1].trim();
  }
  return text;
}

function buildExamId(item: ExamScheduleItem): string {
  const keyCourse = item.courseId.length > 0 ? item.courseId : item.name;
  return `${item.term}:${keyCourse}:${item.dateISO}:${item.beginTime}:${item.endTime}`;
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

export function parseExamTimeRange(value: string): ExamTimeRange {
  const match = /(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/.exec(value);
  if (!match) {
    return { beginTime: '', endTime: '' };
  }
  return {
    beginTime: normalizeClock(match[1]),
    endTime: normalizeClock(match[2]),
  };
}

export function mapExamApiRows(rows: ExamApiRow[], fallbackTerm: string): ExamScheduleItem[] {
  const out: ExamScheduleItem[] = [];
  const normalizedTerm = normalizeSchoolTermCode(fallbackTerm);
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const dateISO = dateISOFromExamDate(row.KSRQ || '');
    const range = parseExamTimeRange(row.KSSJMS || '');
    const name = extractCourseName(row.KCM || '');
    if (dateISO.length === 0 || range.beginTime.length === 0 || range.endTime.length === 0 || name.length === 0) {
      continue;
    }
    const item: ExamScheduleItem = {
      id: '',
      term: normalizedTerm,
      name,
      courseId: row.KCH || '',
      teacher: row.ZJJSXM || '',
      classroom: row.JASMC || '',
      dateISO,
      beginTime: range.beginTime,
      endTime: range.endTime,
      examMode: row.KSMC || '',
      seatId: row.ZWH || '',
    };
    item.id = buildExamId(item);
    out.push(item);
  }
  return out;
}

export class ExamScheduleRepository {
  private readonly baseUrl: string;
  private readonly mode: SchoolLoginMode;
  private readonly debug: boolean;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;

  constructor(options?: ExamScheduleRepositoryOptions) {
    this.mode = options?.mode || 'webvpn';
    const defaultBase = getExamBaseUrlForMode(this.mode);
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

  async getExams(term: string): Promise<ExamScheduleItem[]> {
    const trimmed = term.trim();
    if (trimmed.length === 0) {
      throw new Error('term is empty');
    }
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.post(
      '/jwapp/sys/wdksapMobile/modules/ksap/cxxsksap.do',
      toFormUrlEncoded({
        XNXQDM: trimmed,
        '*order': '-KSRQ',
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      },
    );
    assertOk(resp, 'getExams');
    const parsed = parseJson<ExamApiResponse>(resp.bodyText, 'getExams');
    const rows = parsed.datas?.cxxsksap?.rows || [];
    if (this.debug) {
      logger.info('exam count =', rows.length, 'term =', trimmed);
    }
    return mapExamApiRows(rows, trimmed);
  }
}
