// entry/src/main/ets/services/lexue/BitSsoWebvpn.ts

import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import { encryptPassword } from '../auth/encryptPassword';

// ---------------- WebVPN 配置（与 Python bit_auth 对齐） ----------------

const SSO_WEBVPN_URL =
  'https://webvpn.bit.edu.cn/https/' +
    '77726476706e69737468656265737421e3e44ed225397c1e7b0c9ce29b5b/cas/login';

const WEBVPN_SERVICE = 'https://webvpn.bit.edu.cn/login?cas_login=true';

const WEBVPN_INIT_URL =
  SSO_WEBVPN_URL +
    '?service=' +
  encodeURIComponent(WEBVPN_SERVICE);

const WEBVPN_PORTAL = 'https://webvpn.bit.edu.cn/';

// ---------------- 小工具，与 BitSsoSession 中保持一致 ----------------

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
    throw new Error('[BitSsoWebvpn] 未能从登录页解析到 salt 或 execution');
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

// ---------------- 对外：WebVPN 登录 ----------------

export interface BitWebvpnLoginOptions {
  debug?: boolean;
}

/**
 * WebVPN 下的统一身份认证登录
 * - 逻辑参考 Python bit_auth._webvpn_login
 * - 只负责把 WebVPN SSO 跑通，不关心具体业务系统
 * - 使用传入的 RcpSession（内部已经挂好 CookieJar）
 */
export async function loginViaWebvpn(
  client: RcpSession,
  username: string,
  password: string,
  options?: BitWebvpnLoginOptions,
): Promise<void> {
  const debug = !!options?.debug;

  // 1. GET 登录页：保持 autoRedirect:true 问题不大（你现在就成功拿到了页面）
  const loginPage = await client.get(WEBVPN_INIT_URL, {
    autoRedirect: true,
    collectTimeInfo: false,
  });
  if (loginPage.statusCode !== 200) {
    throw new Error(
      `[BitSsoWebvpn] GET WebVPN 登录页失败：HTTP ${loginPage.statusCode}`,
    );
  }

  const { salt, execution } = extractSaltAndExecution(loginPage.bodyText);
  if (debug) {
    console.log('[BitSsoWebvpn] salt =', salt);
    console.log('[BitSsoWebvpn] execution =', execution);
  }

  const encryptedPassword = encryptPassword(password, salt);
  if (debug) {
    console.log(
      '[BitSsoWebvpn] encryptedPassword (length) =',
      encryptedPassword.length,
    );
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

  // 2. POST 登录：❗关闭自动重定向，避免 Rcp 自己疯跑
  const loginResp = await client.post(WEBVPN_INIT_URL, body, {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    autoRedirect: false,      // ✅ 关键修改点
    collectTimeInfo: false,
  });

  if (debug) {
    console.log(
      '[BitSsoWebvpn] loginResp status =',
      loginResp.statusCode,
      'effectiveUrl =',
      loginResp.effectiveUrl,
      'headers =',
      JSON.stringify(loginResp.headers || {}),
    );
  }

  // 允许 200 / 302 / 303 之类，只要不是 4xx/5xx 就先往后走
  if (loginResp.statusCode >= 400) {
    throw new Error(
      `[BitSsoWebvpn] WebVPN 登录提交失败：HTTP ${loginResp.statusCode}`,
    );
  }

  // 3. 和 Python 一样，访问 WebVPN 门户来最终确认是否登录成功
  const portalResp = await client.get('https://webvpn.bit.edu.cn/', {
    autoRedirect: true,          // 这里一般重定向不会太疯狂
    collectTimeInfo: false,
  });

  if (debug) {
    console.log(
      '[BitSsoWebvpn] portalResp status =',
      portalResp.statusCode,
      'effectiveUrl =',
      portalResp.effectiveUrl,
    );
  }

  if (portalResp.statusCode !== 200 || isLoginPage(portalResp.bodyText)) {
    throw new Error(
      '[BitSsoWebvpn] 访问 WebVPN 门户失败，统一认证可能未生效（账号错误或需要验证码）',
    );
  }


  // 成功时不返回任何内容，BitSsoSession 会继续跑 ensureLexueSession
}
