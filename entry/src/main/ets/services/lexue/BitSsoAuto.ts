// entry/src/main/ets/services/lexue/BitSsoAuto.ts

import BitSsoSession from './BitSsoSession';
import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar from '../../core/network/cookieJar';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

// 用来「刺探」校内是否可直连的地址：这里选 lexue 首页
// 如果你有更合适的内网-only 地址，也可以换成别的。
const INNER_PROBE_URL = 'https://lexue.bit.edu.cn/';

export type BitSsoLoginMode = 'inner' | 'webvpn';

export interface DetectNetworkOptions {
  debug?: boolean;
}

/**
 * 先尝试直连 Lexue：
 *  - 能正常返回 2xx / 3xx，就认为在校内（或至少直连可用） -> 'inner'
 *  - 出异常 / 超时 / 拒绝连接，就认为需要走 WebVPN -> 'webvpn'
 */
export async function detectBitSsoLoginMode(
  options?: DetectNetworkOptions,
): Promise<BitSsoLoginMode> {
  const debug = !!options?.debug;

  const jar = new SimpleCookieJar();
  const client = new RcpSession({
    debug,
    timeoutMs: 5000, // 探测用短一点的超时
    defaultHeaders: {
      'User-Agent': UA,
    },
    cookieJar: jar,
  });

  try {
    const resp: RcpResponseData = await client.get(INNER_PROBE_URL, {
      autoRedirect: true,
      collectTimeInfo: false,
    });

    if (debug) {
      console.log(
        '[BitSsoAuto] probe inner: status =',
        resp.statusCode,
        'effectiveUrl =',
        resp.effectiveUrl,
      );
    }

    // 这里可以稍微宽松一点：2xx / 3xx 都当成功
    if (resp.statusCode >= 200 && resp.statusCode < 400) {
      if (debug) {
        console.log('[BitSsoAuto] 内网直连探测成功，使用 inner 模式');
      }
      return 'inner';
    }
  } catch (e) {
    if (debug) {
      console.warn('[BitSsoAuto] 内网直连探测异常，fallback 到 webvpn:', e);
    }
  }

  if (debug) {
    console.log('[BitSsoAuto] 内网探测失败，使用 webvpn 模式');
  }
  return 'webvpn';
}

export interface BitSsoAutoCreateOptions {
  debug?: boolean;
  /**
   * WebVPN 下乐学的 BASE，例如：
   *   https://webvpn.bit.edu.cn/https/7772...fcf25989...
   * 必须和 Python lexue_calendar.py 里的 BASE 一致。
   */
  webvpnLexueBase: string;
  /**
   * 强制指定模式（调试用），不传就真正“auto”。
   *  - 'inner'  : 强制直连
   *  - 'webvpn' : 强制 WebVPN
   */
  forceMode?: BitSsoLoginMode;
}

/**
 * 自动选择 inner / webvpn，并创建对应配置好的 BitSsoSession。
 *
 * 用法示例：
 *   const { mode, sso } = await createBitSsoSessionAuto({
 *     debug: true,
 *     webvpnLexueBase: WEBVPN_LEXUE_BASE,
 *   });
 *   this.logInfo('[auto] 实际选择的模式 =', mode);
 *   await sso.restoreFromStorage();
 *   if (!sso.isFullyLoggedIn()) {
 *     await sso.loginToLexue(username, password);
 *   }
 */
export async function createBitSsoSessionAuto(
  opts: BitSsoAutoCreateOptions,
): Promise<{ mode: BitSsoLoginMode; sso: BitSsoSession }> {
  const debug = !!opts.debug;

  const mode: BitSsoLoginMode =
    opts.forceMode ?? (await detectBitSsoLoginMode({ debug }));

  const useWebvpn = mode === 'webvpn';

  const sso = new BitSsoSession({
    debug,
    useWebvpn,
    webvpnLexueBase: useWebvpn ? opts.webvpnLexueBase : undefined,
  });

  if (debug) {
    console.log(
      '[BitSsoAuto] createBitSsoSessionAuto: mode =',
      mode,
      ', useWebvpn =',
      useWebvpn,
    );
  }

  return { mode, sso };
}
