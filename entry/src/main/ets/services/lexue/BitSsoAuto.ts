// entry/src/main/ets/services/lexue/BitSsoAuto.ts
import { Logger } from '../../utils/Logger';
import BitSsoSession from './BitSsoSession';
import { detectSchoolLoginMode } from '../school/SchoolNetworkProbe';
const logger = new Logger('BitSsoAuto');

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
  const mode = await detectSchoolLoginMode(options);
  if (options?.debug) {
    logger.info('detectBitSsoLoginMode result =', mode);
  }
  return mode;
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
    logger.info('createBitSsoSessionAuto result: mode=', mode, 'useWebvpn=', useWebvpn);
  }

  return { mode, sso };
}
