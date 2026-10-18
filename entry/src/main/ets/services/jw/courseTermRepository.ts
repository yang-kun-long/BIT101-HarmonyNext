import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import { TokenStore } from '../storage/tokenStore';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import { SchoolAuthService } from '../school/SchoolAuthService';
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
  const root: any = resp as any;
  const candidates: any[] = [root?.data, root?.rows, root?.currentTerm, root?.term];
  for (let i = 0; i < candidates.length; i++) {
    const value = candidates[i];
    if (typeof value === 'string' && isTermCode(value)) return value;
    if (Array.isArray(value)) {
      for (let j = 0; j < value.length; j++) {
        const candidate = typeof value[j] === 'string' ? value[j] : String(value[j]?.DM || value[j]?.term || value[j]?.code || '');
        if (isTermCode(candidate)) return candidate;
      }
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
      logger.info('TERM_STORE count=', snapshot.length, 'domains=', domains.join(','), 'mode=', this.mode);
    }
  }

  private async warmup(): Promise<void> {
    await this.ensureTeachingCenterSession();
    const index = await this.client.get('/jwapp/sys/wdkbby/*default/index.do', {
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': this.baseUrl + '/',
      },
    });
    if (this.debug) logger.info('term app index HTTP', index.statusCode, 'mode=', this.mode, 'base=', this.baseUrl);
    assertOk(index, 'course app index');
    const config = await this.client.get('/jwapp/sys/funauthapp/api/getAppConfig/wdkbby-5959167891382285.do');
    if (this.debug) logger.info('term app config HTTP', config.statusCode);
    const i18n = await this.client.get('/jwapp/i18n.do', {
      query: {
        appName: 'wdkbby',
        EMAP_LANG: 'zh',
      },
    });
    if (this.debug) logger.info('term app i18n HTTP', i18n.statusCode);
  }

  private async ensureTeachingCenterSession(): Promise<void> {
    const stored = await new SchoolCookieStore(this.mode).loadCookieDump();
    if (!stored || stored.length === 0) return;
    const auth = new SchoolAuthService({ debug: this.debug, userAgent: USER_AGENT });
    auth.restoreCookieDump(stored);
    if (this.debug) logger.info('teaching-center bootstrap stored cookie names=', stored.map((item) => item.name).join(','));
    const targetUrl = `${this.baseUrl}/jwapp/sys/wdkbby/*default/index.do`;
    try {
      if (this.mode === 'inner') {
        await auth.loginInnerTarget(targetUrl, 'jxzxehall', '', '');
      } else {
        await auth.loginWebvpnTarget(targetUrl, 'jxzxehall');
      }
      const repaired = auth.getCookieDump();
      this.jar.restoreFromDump(repaired);
      await new SchoolCookieStore(this.mode).saveCookieDump(repaired);
      if (this.debug) logger.info('teaching-center session ready cookies=', repaired.length);
    } catch (error) {
      if (this.debug) logger.warn('teaching-center session bootstrap failed', error);
    }
  }

  async getCurrentTerm(): Promise<string> {
    await this.restoreCookiesFromStorage();
    await this.warmup();
    const resp = await this.client.get('/jwapp/sys/wdkbby/modules/jshkcb/dqxnxq.do');
    if (this.debug) logger.info('TERM_RESULT status=', resp.statusCode, 'bodyLen=', (resp.bodyText || '').length);
    assertOk(resp, 'getCurrentTerm');
    const parsed = parseJson<CurrentTermApiResponse>(resp.bodyText, 'getCurrentTerm');
    if (this.debug) {
      const root = parsed as any;
      const dataKeys = root && root.datas && typeof root.datas === 'object' ? Object.keys(root.datas).join(',') : '';
      logger.info('TERM_SHAPE dataKeys=', dataKeys);
    }
    const term = mapCurrentTermResponse(parsed);
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
    if (this.debug) logger.info('term list HTTP', resp.statusCode, 'body=', (resp.bodyText || '').replace(/\s+/g, ' ').slice(0, 240));
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
