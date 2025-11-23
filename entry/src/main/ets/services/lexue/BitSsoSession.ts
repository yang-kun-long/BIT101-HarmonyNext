// entry/src/main/ets/services/lexue/BitSsoSession.ts

import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar from '../../core/network/cookieJar';
import { encryptPassword } from '../auth/encryptPassword';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { loginViaWebvpn } from './BitSsoWebvpn';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

const SSO_INNER_URL = 'https://sso.bit.edu.cn/cas/login';
const LEXUE_BASE = 'https://lexue.bit.edu.cn';

export interface BitSsoSessionOptions {
  useWebvpn?: boolean;
  debug?: boolean;
  webvpnLexueBase?: string;
}

function isLoginPage(html: string): boolean {
  if (!html) return false;
  return html.includes('统一身份认证') || html.includes('帐号登录或动态码登录');
}

function extractSaltAndExecution(html: string): { salt: string; execution: string } {
  let salt = '';
  let execution = '';

  const saltValueRe = /id=["']login-croypto["'][^>]*value=["']([^"']+)["']/i;
  const saltTextRe = /id=["']login-croypto["'][^>]*>([^<]+)</i;

  const execValueRe = /id=["']login-page-flowkey["'][^>]*value=["']([^"']+)["']/i;
  const execTextRe = /id=["']login-page-flowkey["'][^>]*>([^<]+)</i;

  let m = html.match(saltValueRe);
  if (m && m[1]) {
    salt = m[1].trim();
  } else {
    m = html.match(saltTextRe);
    if (m && m[1]) {
      salt = m[1].trim();
    }
  }

  m = html.match(execValueRe);
  if (m && m[1]) {
    execution = m[1].trim();
  } else {
    m = html.match(execTextRe);
    if (m && m[1]) {
      execution = m[1].trim();
    }
  }

  if (!salt || !execution) {
    throw new Error('[BitSsoSession] 未能从登录页解析到 salt 或 execution');
  }

  return { salt, execution };
}

function toFormUrlEncoded(data: Record<string, string>): string {
  const parts: string[] = [];
  for (const [k, v] of Object.entries(data)) {
    parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(v));
  }
  return parts.join('&');
}

/**
 * 解析重定向 Location，支持：
 * - 绝对地址：https://...
 * - 以 / 开头的绝对路径（保留原 host）
 * - 其它相对路径（基于 currentUrl 的路径拼接）
 */
function resolveRedirectUrl(currentUrl: string, location: string): string {
  if (!location) return currentUrl;
  if (/^https?:\/\//i.test(location)) {
    return location;
  }
  if (location.startsWith('/')) {
    const m = currentUrl.match(/^(https?:\/\/[^/]+)/i);
    if (m) {
      return m[1] + location;
    }
  }
  // 简单相对路径处理：基于当前 URL 的路径部分
  const qPos = currentUrl.indexOf('?', currentUrl.indexOf('://') + 3);
  const base = qPos >= 0 ? currentUrl.slice(0, qPos) : currentUrl;
  const lastSlash = base.lastIndexOf('/');
  if (lastSlash >= 0) {
    return base.slice(0, lastSlash + 1) + location;
  }
  return location;
}

export class BitSsoSession {
  private readonly useWebvpn: boolean;
  private readonly debug: boolean;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;
  private loggedInSso = false;
  private loggedInLexue = false;
  private readonly cookieStore: LexueCookieStore;
  private readonly webvpnLexueBase?: string;

  constructor(options?: BitSsoSessionOptions) {
    this.useWebvpn = !!options?.useWebvpn;
    this.debug = !!options?.debug;
    this.webvpnLexueBase = options?.webvpnLexueBase;

    if (this.useWebvpn && this.debug) {
      console.log('[BitSsoSession] useWebvpn = true，将通过 WebVPN 登录 SSO');
    }

    this.jar = new SimpleCookieJar();
    this.client = new RcpSession({
      debug: this.debug,
      timeoutMs: 15000,
      defaultHeaders: {
        'User-Agent': UA,
      },
      cookieJar: this.jar,
    });
    this.cookieStore = new LexueCookieStore(
      this.useWebvpn ? 'webvpn' : 'inner',
    );
  }


  getHttpClient(): RcpSession {
    return this.client;
  }

  isFullyLoggedIn(): boolean {
    return this.loggedInSso && this.loggedInLexue;
  }

  async loginToLexue(username: string, password: string): Promise<void> {
    try {
      if (!this.loggedInSso) {
        await this.loginSso(username, password);
      }
      await this.ensureLexueSession();
      this.loggedInLexue = true;
    } catch (e) {
      // 如果是“统一身份认证登录页”错误，说明 SSO 失效了，尝试重登一次
      const msg = String(e);
      if (msg.includes('统一身份认证登录页')) {
        if (this.debug) {
          console.warn('[BitSsoSession] 检测到 SSO 失效，清空 cookie 后重试一次登录');
        }
        await this.clearPersistentSession();
        await this.loginSso(username, password);
        await this.ensureLexueSession();
        this.loggedInLexue = true;
        return;
      }
      throw e;
    }
  }


  /**
   * 从本地持久化存储中恢复 cookie：
   * - 把 LexueCookieStore 里保存的 dump 填回 SimpleCookieJar
   * - 根据 MoodleSession 粗略判断是否已经登录过
   *
   * 使用方式：
   *   const s = new BitSsoSession({ debug: true });
   *   await s.restoreFromStorage();
   *   if (!s.isFullyLoggedIn()) {
   *     await s.loginToLexue(username, password);
   *   }
   */
  async restoreFromStorage(): Promise<void> {
    try {
      const dump = await this.cookieStore.loadCookieDump();
      if (!dump) {
        if (this.debug) {
          console.log('[BitSsoSession] restoreFromStorage: 没有持久化 cookie');
        }
        return;
      }

      this.jar.restoreFromDump(dump);

      let hasSso = false;
      let hasLexue = false;

      if (this.useWebvpn) {
        // WebVPN 模式：看有没有 WebVPN ticket
        const all = this.jar.dump() as any[];
        const hasVpnTicket = all.some(
          (c) =>
          c &&
            c.name === 'wengine_vpn_ticketwebvpn_bit_edu_cn' &&
            typeof c.value === 'string' &&
            c.value.length > 0,
        );
        hasSso = hasVpnTicket;
        // Lexue 会话交给 ensureLexueSession 再跑一遍，不在这里强行认为已登录
        hasLexue = false;
      } else {
        // 内网模式：沿用原逻辑，用 MoodleSession 判定
        const hasMoodle = this.hasMoodleSession();
        hasSso = hasMoodle;
        hasLexue = hasMoodle;
      }

      this.loggedInSso = hasSso;
      this.loggedInLexue = hasLexue;

      if (this.debug) {
        console.log(
          '[BitSsoSession] restoreFromStorage: 已恢复 cookie, hasSso =',
          hasSso,
          ', hasLexue =',
          hasLexue,
        );
      }
    } catch (e) {
      console.warn('[BitSsoSession] restoreFromStorage 出错：', e);
    }
  }


  /**
   * 统一认证登录（直连 SSO）
   * 逻辑与 Python bit_auth._inner_login 对齐：
   * - 状态码异常直接失败
   * - 不再因为“看起来像登录页”就立刻失败
   * - 最终成功与否交给 ensureLexueSession 判定
   */
  private async loginSsoInner(username: string, password: string): Promise<void> {
    const loginPage: RcpResponseData = await this.client.get(SSO_INNER_URL, {
      autoRedirect: true,
      collectTimeInfo: false,
    });

    if (loginPage.statusCode !== 200) {
      throw new Error(`[BitSsoSession] GET 登录页失败：HTTP ${loginPage.statusCode}`);
    }

    const { salt, execution } = extractSaltAndExecution(loginPage.bodyText);
    if (this.debug) {
      console.log('[BitSsoSession] salt =', salt);
      console.log('[BitSsoSession] execution =', execution);
    }

    const encryptedPassword = encryptPassword(password, salt);
    if (this.debug) {
      console.log('[BitSsoSession] encryptedPassword (length) =', encryptedPassword.length);
    }

    const form: Record<string, string> = {
      username,
      password: encryptedPassword,
      execution,
      captcha_payload: '',
      croypto: salt,
      captcha_code: '',
      type: 'UsernamePassword',
      _eventId: 'submit',
      geolocation: '',
    };
    const body = toFormUrlEncoded(form);

    const loginResp: RcpResponseData = await this.client.post(SSO_INNER_URL, body, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      autoRedirect: true,
      collectTimeInfo: false,
    });

    if (this.debug) {
      console.log(
        '[BitSsoSession] loginResp status =',
        loginResp.statusCode,
        'effectiveUrl =',
        loginResp.effectiveUrl,
      );
      console.log(
        '[BitSsoSession] loginResp looksLikeLoginPage =',
        isLoginPage(loginResp.bodyText),
      );
      console.log('[BitSsoSession] cookies after login =', JSON.stringify(this.jar.dump()));
    }

    if (
      loginResp.statusCode !== 200 &&
        loginResp.statusCode !== 302 &&
        loginResp.statusCode !== 303
    ) {
      throw new Error(`[BitSsoSession] 登录提交失败：HTTP ${loginResp.statusCode}`);
    }


  }
  private async loginSso(username: string, password: string): Promise<void> {
    if (this.useWebvpn) {
      await loginViaWebvpn(this.client, username, password, { debug: this.debug });
    } else {
      await this.loginSsoInner(username, password);
    }
    this.loggedInSso = true;
  }

  /**
   * 手动跟随重定向的 GET（避免 RCP 内部的 redirect 次数限制）
   */
  private async getWithManualRedirects(
    initialUrl: string,
    maxRedirects: number = 20,
  ): Promise<RcpResponseData> {
    let currentUrl = initialUrl;
    for (let i = 0; i <= maxRedirects; i++) {
      const resp = await this.client.get(currentUrl, {
        autoRedirect: false, // 关键：关闭内部自动重定向
        collectTimeInfo: false,
      });

      if (this.debug) {
        console.log(
          `[BitSsoSession] manual GET step=${i} status=${resp.statusCode} url=${currentUrl}`,
        );
      }

      if (
        resp.statusCode === 301 ||
          resp.statusCode === 302 ||
          resp.statusCode === 303 ||
          resp.statusCode === 307 ||
          resp.statusCode === 308
      ) {
        // 看 Location
        const headersLower: Record<string, string> = {};
        for (const k in resp.headers) {
          if (!Object.prototype.hasOwnProperty.call(resp.headers, k)) continue;
          const v = (resp.headers as any)[k];
          if (typeof v === 'string') {
            headersLower[k.toLowerCase()] = v;
          }
        }
        const loc = headersLower['location'];
        if (!loc) {
          // 没有 Location，当作最终响应返回
          return resp;
        }
        const nextUrl = resolveRedirectUrl(currentUrl, loc);
        if (this.debug) {
          console.log(`[BitSsoSession] redirect to: ${nextUrl}`);
        }
        currentUrl = nextUrl;
        continue;
      }

      // 非 3xx，视为终点
      return resp;
    }
    throw new Error(`[BitSsoSession] 手动重定向次数超过上限：${maxRedirects}`);
  }
  async clearPersistentSession(): Promise<void> {
    this.jar.clear();
    this.loggedInSso = false;
    this.loggedInLexue = false;
    try {
      await this.cookieStore.clearCookieDump();
    } catch (e) {
      console.warn('[BitSsoSession] 清理持久化 cookie 失败：', e);
    }
  }
  /**
   * 确保乐学端会话已建立：
   * - 手动完成重定向链，拿到最终页面
   * - 要求 HTTP 200
   * - 最终不能是统一身份认证登录页
   * - 内网模式：Cookie 中必须包含 MoodleSession
   * - WebVPN 模式：对齐 Python 脚本，访问 webvpnLexueBase + /calendar/export.php
   */
  private async ensureLexueSession(): Promise<void> {
    let targetUrl: string;

    if (this.useWebvpn) {
      if (!this.webvpnLexueBase) {
        throw new Error(
          '[BitSsoSession] WebVPN 模式需要提供 webvpnLexueBase（例如 Python 输出里的 base）',
        );
      }
      // 去掉尾部多余的 /，再拼 /calendar/export.php
      const base = this.webvpnLexueBase.replace(/\/+$/, '');
      targetUrl = `${base}/calendar/export.php`;
    } else {
      targetUrl = `${LEXUE_BASE}/`;
    }

    const resp: RcpResponseData =
      await this.getWithManualRedirects(targetUrl, 20);

    if (this.debug) {
      console.log(
        '[BitSsoSession] ensureLexueSession final status =',
        resp.statusCode,
        'effectiveUrl =',
        resp.effectiveUrl,
      );
      console.log(
        '[BitSsoSession] cookies snapshot =',
        JSON.stringify(this.jar.dump()),
      );
    }

    if (resp.statusCode !== 200) {
      throw new Error(
        `[BitSsoSession] 访问乐学入口失败：HTTP ${resp.statusCode}`,
      );
    }

    // 如果最终又被重定向回统一身份认证登录页，说明 SSO 实际未生效
    if (isLoginPage(resp.bodyText)) {
      throw new Error(
        '[BitSsoSession] 最终页面仍然是统一身份认证登录页，说明 SSO 登录失败或被重定向回登录',
      );
    }

    // 内网：必须要有 MoodleSession
    // WebVPN：此时还未访问 export_execute.php，一般拿不到 MoodleSession，就不要强制了
    if (!this.useWebvpn) {
      const hasMoodle = this.hasMoodleSession();
      if (!hasMoodle) {
        throw new Error(
          '[BitSsoSession] 未找到 MoodleSession，乐学单点登录可能失败（账号错误或需要验证码）',
        );
      }
    }

    try {
      await this.cookieStore.saveCookieDump(this.jar.dump());
      if (this.debug) {
        console.log('[BitSsoSession] ensureLexueSession: cookie 已持久化');
      }
    } catch (e) {
      console.warn('[BitSsoSession] 持久化 cookie 失败：', e);
    }
  }


  private hasMoodleSession(): boolean {
    const all = this.jar.dump() as any[];
    return all.some(
      (c) =>
      c &&
        c.name === 'MoodleSession' &&
        typeof c.value === 'string' &&
        c.value.length > 0,
    );
  }
}

export default BitSsoSession;
