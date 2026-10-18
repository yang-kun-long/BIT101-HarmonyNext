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
  // Reuse the authenticated school/CAS session created by the main login.
  // Android keeps one cookie jar across target bootstrap; a fresh jar here
  // causes a second TGT request (often rejected with HTTP 403).
  const existingStore = new SchoolCookieStore(mode);
  const existingDump = await existingStore.loadCookieDump();
  auth.restoreCookieDump(existingDump);
  const targetUrl = mode === 'inner'
    ? `${JXZXEHALLAPP_INNER_BASE}/jwapp/sys/kxjasbyMobile/*default/index.do`
    : `${JXZXEHALLAPP_WEBVPN_BASE}/jwapp/sys/kxjasbyMobile/*default/index.do`;
  const target = mode === 'inner'
    ? await auth.loginInnerTarget(targetUrl, 'jxzxehallapp', username, password)
    : await (async () => {
      try {
        return await auth.loginWebvpnTarget(targetUrl, 'jxzxehallapp');
      } catch (error) {
        logger.warn('existing WebVPN session target bootstrap failed, retrying portal login', error);
        await auth.loginWebvpnPortal(username, password);
        return await auth.loginWebvpnTarget(targetUrl, 'jxzxehallapp');
      }
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
