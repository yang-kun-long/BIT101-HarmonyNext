// entry/src/main/ets/services/lexue/BitSsoSession.ts

import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar from '../../core/network/cookieJar';
import { encryptPassword } from '../auth/encryptPassword';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

const SSO_INNER_URL = 'https://sso.bit.edu.cn/cas/login';
const LEXUE_BASE = 'https://lexue.bit.edu.cn';

export interface BitSsoSessionOptions {
  useWebvpn?: boolean;
  debug?: boolean;
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

  constructor(options?: BitSsoSessionOptions) {
    this.useWebvpn = !!options?.useWebvpn;
    this.debug = !!options?.debug;

    if (this.useWebvpn) {
      // 目前 WebVPN 分支未实现，统一走直连 SSO
      console.warn('[BitSsoSession] useWebvpn = true 目前未实现，将退回直连 SSO');
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
  }

  getHttpClient(): RcpSession {
    return this.client;
  }

  isFullyLoggedIn(): boolean {
    return this.loggedInSso && this.loggedInLexue;
  }

  async loginToLexue(username: string, password: string): Promise<void> {
    await this.loginSso(username, password);
    await this.ensureLexueSession();
    this.loggedInLexue = true;
  }

  /**
   * 统一认证登录（直连 SSO）
   * 逻辑与 Python bit_auth._inner_login 对齐：
   * - 状态码异常直接失败
   * - 不再因为“看起来像登录页”就立刻失败
   * - 最终成功与否交给 ensureLexueSession 判定
   */
  private async loginSso(username: string, password: string): Promise<void> {
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

    // 不在这里因为“像登录页”就直接失败，后面交给 ensureLexueSession 兜底
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

  /**
   * 确保乐学端会话已建立：
   * - 手动完成重定向链，拿到最终页面
   * - 要求 HTTP 200
   * - 最终不能是统一身份认证登录页
   * - Cookie 中必须包含 MoodleSession
   */
  private async ensureLexueSession(): Promise<void> {
    const resp: RcpResponseData = await this.getWithManualRedirects(`${LEXUE_BASE}/`, 20);

    if (this.debug) {
      console.log(
        '[BitSsoSession] ensureLexueSession final status =',
        resp.statusCode,
        'effectiveUrl =',
        resp.effectiveUrl,
      );
      console.log('[BitSsoSession] cookies snapshot =', JSON.stringify(this.jar.dump()));
    }

    if (resp.statusCode !== 200) {
      throw new Error(`[BitSsoSession] 访问乐学首页失败：HTTP ${resp.statusCode}`);
    }

    // 如果最终又被重定向回统一身份认证登录页，说明 SSO 实际未生效
    if (isLoginPage(resp.bodyText)) {
      throw new Error(
        '[BitSsoSession] 最终页面仍然是统一身份认证登录页，说明 SSO 登录失败或被重定向回登录',
      );
    }

    const hasMoodle = this.hasMoodleSession();
    if (!hasMoodle) {
      throw new Error(
        '[BitSsoSession] 未找到 MoodleSession，乐学单点登录可能失败（账号错误或需要验证码）',
      );
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
