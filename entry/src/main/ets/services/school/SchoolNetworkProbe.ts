import { Logger } from '../../utils/Logger';
import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar from '../../core/network/cookieJar';
import type { SchoolLoginMode } from './SchoolAuthTypes';

const logger = new Logger('SchoolNetworkProbe');
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';
const INNER_PROBE_URL = 'https://lexue.bit.edu.cn/';

export interface DetectNetworkOptions {
  debug?: boolean;
}

export function inferSchoolLoginModeFromProbe(statusCode: number, errorCode?: number, errorMessage: string = ''): SchoolLoginMode {
  if (statusCode >= 200 && statusCode < 400) {
    return 'inner';
  }
  if (errorCode === 1007900047 || errorMessage.includes('Number of redirects hit maximum amount')) {
    return 'inner';
  }
  return 'webvpn';
}

export async function detectSchoolLoginMode(options?: DetectNetworkOptions): Promise<SchoolLoginMode> {
  const debug = !!options?.debug;
  const client = new RcpSession({
    debug,
    timeoutMs: 5000,
    defaultHeaders: {
      'User-Agent': UA,
    },
    cookieJar: new SimpleCookieJar(),
  });

  try {
    const resp: RcpResponseData = await client.get(INNER_PROBE_URL, {
      autoRedirect: false,
      collectTimeInfo: false,
    });

    if (debug) {
      logger.debug('probe inner: status =', resp.statusCode, 'effectiveUrl =', resp.effectiveUrl);
    }
    return inferSchoolLoginModeFromProbe(resp.statusCode);
  } catch (e: any) {
    if (debug) {
      logger.debug('probe failed, fallback to mode inference:', e);
    }
    return inferSchoolLoginModeFromProbe(0, e?.code ?? e?.errorCode, String(e?.data ?? e?.message ?? ''));
  }
}
