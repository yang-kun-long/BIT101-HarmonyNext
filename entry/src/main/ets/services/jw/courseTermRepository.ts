import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import {
  JXZXEHALLAPP_INNER_BASE,
  JXZXEHALLAPP_WEBVPN_BASE,
} from './freeClassroomRepository';

const logger = new Logger('CourseTermRepository');

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

export interface CourseTermRow {
  DM?: string;
}

export interface CurrentTermApiResponse {
  datas?: {
    dqxnxq?: {
      rows?: CourseTermRow[];
    };
  };
}

export interface TermListApiResponse {
  datas?: {
    xnxqcx?: {
      rows?: CourseTermRow[];
    };
  };
}

export interface WeekAndDateRow {
  XQ?: number;
  RQ?: string;
}

export interface WeekAndDateApiResponse {
  data?: WeekAndDateRow[];
}

export interface CourseTermRepositoryOptions {
  baseUrl?: string;
  mode?: SchoolLoginMode;
  debug?: boolean;
  cookieDump?: CookieDump;
  timeoutMs?: number;
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

function toFormUrlEncoded(fields: Record<string, string>): string {
  const keys = Object.keys(fields);
  const parts: string[] = [];
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(fields[key]));
  }
  return parts.join('&');
}

function isTermCode(value: string): boolean {
  return /^\d{4}-\d{4}-[12]$/.test(value.trim());
}

function isDateISO(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value.trim());
}

export function mapCurrentTermResponse(resp: CurrentTermApiResponse): string {
  const rows = resp.datas?.dqxnxq?.rows || [];
  for (let i = 0; i < rows.length; i++) {
    const term = rows[i].DM || '';
    if (isTermCode(term)) {
      return term;
    }
  }
  return '';
}

export function mapTermListResponse(resp: TermListApiResponse): string[] {
  const rows = resp.datas?.xnxqcx?.rows || [];
  const out: string[] = [];
  const seen: Record<string, boolean> = {};
  for (let i = 0; i < rows.length; i++) {
    const term = rows[i].DM || '';
    if (!isTermCode(term) || seen[term]) {
      continue;
    }
    seen[term] = true;
    out.push(term);
  }
  return out;
}

export function mapFirstDayResponse(resp: WeekAndDateApiResponse): string {
  const rows = resp.data || [];
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].XQ === 1) {
      const date = rows[i].RQ || '';
      return isDateISO(date) ? date : '';
    }
  }
  return '';
}

export class CourseTermRepository {
  private readonly baseUrl: string;
  private readonly mode: SchoolLoginMode;
  private readonly debug: boolean;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;

  constructor(options?: CourseTermRepositoryOptions) {
    this.mode = options?.mode || 'webvpn';
    const defaultBase = this.mode === 'inner' ? JXZXEHALLAPP_INNER_BASE : JXZXEHALLAPP_WEBVPN_BASE;
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

  private async warmup(): Promise<void> {
    await this.client.get('/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do');
    await this.client.get('/jwapp/i18n.do', {
      query: {
        appName: 'wdkbby',
        EMAP_LANG: 'zh',
      },
    });
  }

  async getCurrentTerm(): Promise<string> {
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.get('/jwapp/sys/wdkbby/modules/jshkcb/dqxnxq.do');
    assertOk(resp, 'getCurrentTerm');
    const term = mapCurrentTermResponse(parseJson<CurrentTermApiResponse>(resp.bodyText, 'getCurrentTerm'));
    if (term.length === 0) {
      throw new Error('current term is empty');
    }
    if (this.debug) {
      logger.info('current term =', term);
    }
    return term;
  }

  async getTermList(): Promise<string[]> {
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.get('/jwapp/sys/wdkbby/modules/jshkcb/xnxqcx.do');
    assertOk(resp, 'getTermList');
    const terms = mapTermListResponse(parseJson<TermListApiResponse>(resp.bodyText, 'getTermList'));
    if (this.debug) {
      logger.info('term list count =', terms.length);
    }
    return terms;
  }

  async getFirstDay(term: string): Promise<string> {
    const trimmed = term.trim();
    if (trimmed.length === 0) {
      throw new Error('term is empty');
    }
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.post(
      '/jwapp/sys/wdkbby/wdkbByController/cxzkbrq.do',
      toFormUrlEncoded({
        requestParamStr: `{"XNXQDM":"${trimmed}","ZC":"1"}`,
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      },
    );
    assertOk(resp, 'getFirstDay');
    const firstDay = mapFirstDayResponse(parseJson<WeekAndDateApiResponse>(resp.bodyText, 'getFirstDay'));
    if (firstDay.length === 0) {
      throw new Error('first day is empty');
    }
    if (this.debug) {
      logger.info('first day =', firstDay, 'term =', trimmed);
    }
    return firstDay;
  }
}
