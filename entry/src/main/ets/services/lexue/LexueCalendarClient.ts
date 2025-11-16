// entry/src/main/ets/services/lexue/LexueCalendarClient.ts

import BitSsoSession from './BitSsoSession';
import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import { LexueCalendarStore } from '../storage/LexueCalendarStore';


export type CalendarExportWhat = 'all' | 'categories' | 'courses' | 'groups' | 'user';
export type CalendarExportTime = 'weeknow' | 'monthnow' | 'recentupcoming' | 'custom';

export interface LexueCalendarExportOptions {
  what?: CalendarExportWhat;
  time?: CalendarExportTime;
}

export interface LexueCalendarClientOptions {
  baseUrl?: string;   // 默认 https://lexue.bit.edu.cn
  debug?: boolean;
  username?: string;
}

/**
 * export 执行结果：包含订阅 URL 和 ICS 文本
 */
export interface LexueCalendarExportResult {
  subscribeUrl: string;
  icsText: string;
}

/**
 * Lexue 日历导出客户端（鸿蒙版）
 * 步骤与 lexue_calendar.py 对齐：
 *  1) 依赖外部的 BitSsoSession（必须已经登录到乐学）
 *  2) GET /calendar/export.php 解析 sesskey
 *  3) POST /calendar/export.php（generateurl）生成订阅 URL
 *  4) GET export_execute.php?... 拉取 ICS
 */
export class LexueCalendarClient {
  private readonly baseUrl: string;
  private readonly debug: boolean;
  private readonly sso: BitSsoSession;
  private readonly http: RcpSession;
  private readonly username?: string;                // ✅ 新增
  private readonly calendarStore: LexueCalendarStore; // ✅ 新增

  constructor(sso: BitSsoSession, options?: LexueCalendarClientOptions) {
    this.sso = sso;
    this.baseUrl = options?.baseUrl ?? 'https://lexue.bit.edu.cn';
    this.debug = !!options?.debug;
    this.http = sso.getHttpClient();
    this.username = options?.username;
    this.calendarStore = new LexueCalendarStore();
  }
  private looksLikeIcs(text: string | undefined | null): boolean {
    if (!text) return false;
    let s = text;
    // 去掉 UTF-8 BOM 和前导空白
    if (s.charCodeAt(0) === 0xfeff) {
      s = s.slice(1);
    }
    s = s.trimStart();
    return s.startsWith('BEGIN:VCALENDAR');
  }
  private htmlDecode(text: string): string {
    if (!text) {
      return '';
    }
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }

  /**
   * 拉取 ICS 文本（包含所有课表/DDL）
   * 约定：调用前 BitSsoSession 已经 loginToLexue 成功。
   */
  async exportCalendar(
    options?: LexueCalendarExportOptions,
  ): Promise<LexueCalendarExportResult> {
    const what: CalendarExportWhat = options?.what ?? 'all';
    const time: CalendarExportTime = options?.time ?? 'recentupcoming';

    if (!this.sso.isFullyLoggedIn() && this.debug) {
      console.warn(
        '[LexueCalendarClient] BitSsoSession 尚未完全登录，后续请求可能被重定向到登录页。',
      );
    }

    // ========== Fast Path：优先尝试使用缓存订阅 URL ==========
    if (this.username) {
      try {
        const cachedUrl = await this.calendarStore.getCachedSubscribeUrl(
          this.username,
          this.baseUrl,
        );
        if (cachedUrl) {
          if (this.debug) {
            console.log(
              '[LexueCalendarClient] FastPath: 使用缓存订阅 URL =',
              cachedUrl,
            );
          }

          const fastResp: RcpResponseData = await this.http.get(cachedUrl, {
            autoRedirect: true,
            collectTimeInfo: false,
          });

          if (this.debug) {
            console.log(
              '[LexueCalendarClient] FastPath GET ICS status =',
              fastResp.statusCode,
              'effectiveUrl =',
              fastResp.effectiveUrl,
            );
          }

          if (
            fastResp.statusCode === 200 &&
            this.looksLikeIcs(fastResp.bodyText)
          ) {
            const icsText = fastResp.bodyText ?? '';
            if (this.debug) {
              const preview = icsText.replace(/\r?\n/g, '\\n').slice(0, 200);
              console.log('[LexueCalendarClient] FastPath ICS 预览前 200 字符 =', preview);
            }
            return {
              subscribeUrl: cachedUrl,
              icsText,
            };
          } else if (this.debug) {
            console.log(
              '[LexueCalendarClient] FastPath: 缓存 URL 不可用，fallback 到正常流程',
            );
          }
        } else if (this.debug) {
          console.log('[LexueCalendarClient] FastPath: 没有缓存订阅 URL');
        }
      } catch (e) {
        console.warn(
          '[LexueCalendarClient] FastPath: 使用缓存订阅 URL 时异常，fallback 到正常流程：',
          e,
        );
      }
    }

    // 1) GET /calendar/export.php -> 解析 sesskey
    const exportPage = await this.http.get(`${this.baseUrl}/calendar/export.php`, {
      autoRedirect: true,
      collectTimeInfo: false,
      headers: {
        Referer: `${this.baseUrl}/`,
      },
    });

    if (this.debug) {
      console.log(
        '[LexueCalendarClient] GET export.php status =',
        exportPage.statusCode,
        'effectiveUrl =',
        exportPage.effectiveUrl,
      );
    }

    if (exportPage.statusCode !== 200) {
      throw new Error(
        `[LexueCalendarClient] 加载导出页失败：HTTP ${exportPage.statusCode}`,
      );
    }

    const sesskey = this.parseSesskey(exportPage.bodyText ?? '');
    if (!sesskey) {
      if (this.debug) {
        const preview = (exportPage.bodyText ?? '').replace(/\s+/g, ' ').slice(0, 400);
        console.log('[LexueCalendarClient] 未解析到 sesskey，HTML 预览 =', preview);
      }
      throw new Error('[LexueCalendarClient] 未能从导出页解析到 sesskey');
    }

    if (this.debug) {
      console.log('[LexueCalendarClient] sesskey =', sesskey);
    }

    // 2) POST /calendar/export.php（generateurl）
    const form: Record<string, string> = {
      sesskey,
      _qf__core_calendar_export_form: '1',
      'events[exportevents]': what,
      'period[timeperiod]': time,
      // 这里必须是中文的按钮文字，否则 Moodle 可能不认：
      generateurl: '获取日历网址',
    };
    const body = this.toFormUrlEncoded(form);

    const postResp: RcpResponseData = await this.http.post(
      `${this.baseUrl}/calendar/export.php`,
      body,
      {
        autoRedirect: false, // 关键：我们要自己看 Location
        collectTimeInfo: false,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Origin: this.baseUrl,
          Referer: `${this.baseUrl}/calendar/export.php`,
        },
      },
    );

    if (this.debug) {
      console.log(
        '[LexueCalendarClient] POST generateurl status =',
        postResp.statusCode,
        'effectiveUrl =',
        postResp.effectiveUrl,
      );
    }

    let subscribeUrl: string | undefined;

    // 优先从 Location 拿
    if (
      postResp.statusCode === 302 ||
        postResp.statusCode === 303 ||
        postResp.statusCode === 301
    ) {
      const loc = this.getHeader(postResp.headers, 'location');
      if (loc) {
        subscribeUrl = loc.startsWith('http') ? loc : this.baseUrl + loc;
      }
    }

    // 若没有 Location，再从 HTML 兜底解析
    if (!subscribeUrl) {
      if (this.debug) {
        const preview = (postResp.bodyText ?? '').replace(/\s+/g, ' ').slice(0, 400);
        console.log(
          '[LexueCalendarClient] POST generateurl 无 Location，尝试从 HTML 解析。预览 =',
          preview,
        );
      }
      subscribeUrl = this.extractExportUrl(postResp.bodyText ?? '');
    }

    if (!subscribeUrl) {
      throw new Error('[LexueCalendarClient] 未获取到日历订阅 URL');
    }
    subscribeUrl = this.htmlDecode(subscribeUrl);
    if (this.debug) {
      console.log('[LexueCalendarClient] 订阅 URL =', subscribeUrl);
    }
    if (this.username) {
      try {
        await this.calendarStore.setCachedSubscribeUrl(
          this.username,
          this.baseUrl,
          subscribeUrl,
        );
        if (this.debug) {
          console.log(
            '[LexueCalendarClient] 已将订阅 URL 写入缓存用户名 =',
            this.username,
          );
        }
      } catch (e) {
        console.warn(
          '[LexueCalendarClient] 写入订阅 URL 缓存失败：',
          e,
        );
      }
    }

    // 3) GET 订阅 URL -> ICS 文本
    const icsResp: RcpResponseData = await this.http.get(subscribeUrl, {
      autoRedirect: true,
      collectTimeInfo: false,
    });

    if (this.debug) {
      console.log(
        '[LexueCalendarClient] GET ICS status =',
        icsResp.statusCode,
        'effectiveUrl =',
        icsResp.effectiveUrl,
      );
    }

    if (icsResp.statusCode !== 200) {
      throw new Error(
        `[LexueCalendarClient] ICS 下载失败：HTTP ${icsResp.statusCode}`,
      );
    }

    const icsText = icsResp.bodyText ?? '';
    if (this.debug) {
      const preview = icsText.replace(/\r?\n/g, '\\n').slice(0, 200);
      console.log('[LexueCalendarClient] ICS 预览前 200 字符 =', preview);
    }

    return {
      subscribeUrl,
      icsText,
    };
  }

  // ===== 工具函数 =====

  /**
   * 解析 sesskey，与 Python 版 parse_sesskey 对齐
   */
  private parseSesskey(html: string): string | undefined {
    // <input ... name="sesskey" ... value="xxxx">
    let m = html.match(
      /<input[^>]+name=["']sesskey["'][^>]+value=["']([^"']+)["']/i,
    );
    if (m && m[1]) {
      return m[1];
    }
    // M.cfg = {... "sesskey":"xxxx" ...}
    m = html.match(/M\.cfg\s*=\s*\{[^}]*"sesskey"\s*:\s*"([^"]+)"/i);
    if (m && m[1]) {
      return m[1];
    }
    // 兜底："sesskey":"xxxx"
    m = html.match(/"sesskey"\s*:\s*"([^"]+)"/i);
    if (m && m[1]) {
      return m[1];
    }
    return undefined;
  }

  /**
   * 从 HTML 中解析 export_execute.php 订阅 URL
   * 与 Python 版 clean_export_url / extract_export_url_from_html 对齐
   */
  private extractExportUrl(html: string): string | undefined {
    const text = this.htmlDecode(html);

    // 完整绝对 URL
    let m = text.match(
      /https?:\/\/[^<>"'\s]+\/calendar\/export_execute\.php\?[^<>"'\s]+/i,
    );
    if (m && m[0]) {
      return m[0];
    }

    // 相对 URL：/calendar/export_execute.php?...
    m = text.match(/\/calendar\/export_execute\.php\?[^<>"'\s]+/i);
    if (m && m[0]) {
      return this.baseUrl + m[0];
    }

    return undefined;
  }


  /**
   * x-www-form-urlencoded 序列化
   */
  private toFormUrlEncoded(data: Record<string, string>): string {
    const parts: string[] = [];
    for (const key in data) {
      if (!Object.prototype.hasOwnProperty.call(data, key)) continue;
      const v = data[key];
      parts.push(
        encodeURIComponent(key) + '=' + encodeURIComponent(v == null ? '' : v),
      );
    }
    return parts.join('&');
  }

  /**
   * 大小写不敏感地读取 Header
   */
  private getHeader(
    headers: Record<string, unknown>,
    name: string,
  ): string | undefined {
    const target = name.toLowerCase();
    for (const k in headers) {
      if (!Object.prototype.hasOwnProperty.call(headers, k)) continue;
      const v = (headers as any)[k];
      if (k.toLowerCase() === target) {
        if (Array.isArray(v)) {
          return v[0];
        }
        if (typeof v === 'string') {
          return v;
        }
      }
    }
    return undefined;
  }
}

export default LexueCalendarClient;
