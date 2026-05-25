import { SchoolAuthService } from '../school/SchoolAuthService';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import { Logger } from '../../utils/Logger';
import { detectSchoolLoginMode } from '../school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import { JXZXEHALLAPP_INNER_BASE, JXZXEHALLAPP_WEBVPN_BASE } from './freeClassroomRepository';

const logger = new Logger('FreeClassroomSession');

export async function prepareFreeClassroomSession(
  username: string,
  password: string,
  mode: SchoolLoginMode,
  debug: boolean = false,
): Promise<void> {
  const auth = new SchoolAuthService({ debug });
  const targetUrl = mode === 'inner'
    ? `${JXZXEHALLAPP_INNER_BASE}/jwapp/sys/kxjasbyMobile/*default/index.do`
    : `${JXZXEHALLAPP_WEBVPN_BASE}/jwapp/sys/kxjasbyMobile/*default/index.do`;
  const target = mode === 'inner'
    ? await auth.loginInnerTarget(targetUrl, 'jxzxehallapp', username, password)
    : await (async () => {
      await auth.loginWebvpnPortal(username, password);
      return await auth.loginWebvpnTarget(targetUrl, 'jxzxehallapp');
    })();
  const store = new SchoolCookieStore(mode);
  await store.saveCookieDump(auth.getCookieDump());
  logger.info('prepared free classroom session mode =', mode, 'effectiveUrl =', target.effectiveUrl);
}

export async function prepareFreeClassroomSessionAuto(
  username: string,
  password: string,
  debug: boolean = false,
): Promise<SchoolLoginMode> {
  const mode = await detectSchoolLoginMode({ debug });
  await prepareFreeClassroomSession(username, password, mode, debug);
  return mode;
}
