import { createBitSsoSessionAuto, BitSsoLoginMode } from '../lexue/BitSsoAuto';
import { syncUserCalendar } from '../lexue/CalendarService';
import BitSsoSession from '../lexue/BitSsoSession';
import LexueCalendarClient from '../lexue/LexueCalendarClient';

const INNER_LEXUE_BASE = 'https://lexue.bit.edu.cn';
const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

interface SsoUsernameSource {
  username?: string;
  getUsername?: () => string;
}

interface DdlSyncSession {
  mode: BitSsoLoginMode;
  sso: BitSsoSession;
}

interface RestoredDdlSyncSession {
  baseUrl: string;
  sso: BitSsoSession;
  username: string;
}

export function resolveDdlSyncBaseUrl(mode: BitSsoLoginMode): string {
  return mode === 'inner' ? INNER_LEXUE_BASE : WEBVPN_LEXUE_BASE;
}

export function resolveDdlSyncUsername(currentUsername: string, sso: SsoUsernameSource): string {
  const trimmedCurrent: string = currentUsername.trim();
  if (trimmedCurrent.length > 0) {
    return trimmedCurrent;
  }

  if (sso.username && sso.username.length > 0) {
    return sso.username;
  }

  if (sso.getUsername) {
    const username: string = sso.getUsername();
    if (username.length > 0) {
      return username;
    }
  }

  return 'default';
}

export async function syncDdlFromLexue(currentUsername: string): Promise<number> {
  const restoredSession: RestoredDdlSyncSession = await createRestoredDdlSyncSession(currentUsername);

  return syncUserCalendar({
    sso: restoredSession.sso,
    username: restoredSession.username,
    webvpnLexueBase: restoredSession.baseUrl,
  });
}

export async function refreshDdlSubscribeUrl(currentUsername: string): Promise<string> {
  const restoredSession: RestoredDdlSyncSession = await createRestoredDdlSyncSession(currentUsername);
  const client = new LexueCalendarClient(restoredSession.sso, {
    baseUrl: restoredSession.baseUrl,
    username: restoredSession.username,
  });
  const result = await client.exportCalendar({
    what: 'all',
    time: 'recentupcoming',
    forceRefreshSubscribeUrl: true,
  });

  return result.subscribeUrl;
}

async function createRestoredDdlSyncSession(currentUsername: string): Promise<RestoredDdlSyncSession> {
  const session: DdlSyncSession = await createBitSsoSessionAuto({
    debug: true,
    webvpnLexueBase: WEBVPN_LEXUE_BASE,
  });
  const sso: BitSsoSession = session.sso;

  await sso.restoreFromStorage();

  if (!sso.isFullyLoggedIn()) {
    throw new Error('乐学登录态不可用，请重新登录后再刷新');
  }

  const baseUrl: string = resolveDdlSyncBaseUrl(session.mode);
  const username: string = resolveDdlSyncUsername(currentUsername, sso as SsoUsernameSource);

  return {
    baseUrl,
    sso,
    username,
  };
}
