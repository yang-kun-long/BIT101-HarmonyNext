import type { CookieDump } from '../../core/network/cookieJar';

export interface RestoredBitSsoState {
  hasSso: boolean;
  hasLexue: boolean;
  requiresTicketRefresh: boolean;
}

export function isBitSsoSessionReady(
  useWebvpn: boolean,
  loggedInSso: boolean,
  loggedInLexue: boolean,
): boolean {
  if (useWebvpn) {
    return loggedInLexue;
  }
  return loggedInSso && loggedInLexue;
}

function looksLikeSsoLoginPage(html: string): boolean {
  if (!html) {
    return false;
  }
  return html.includes('统一身份认证') || html.includes('帐号登录或动态码登录');
}

export function extractLexueSesskey(html: string): string {
  let m = html.match(
    /<input[^>]+name=["']sesskey["'][^>]+value=["']([^"']+)["']/i,
  );
  if (m && m[1]) {
    return m[1];
  }

  m = html.match(/M\.cfg\s*=\s*\{[^}]*"sesskey"\s*:\s*"([^"]+)"/i);
  if (m && m[1]) {
    return m[1];
  }

  m = html.match(/"sesskey"\s*:\s*"([^"]+)"/i);
  if (m && m[1]) {
    return m[1];
  }

  return '';
}

function hasCookie(dump: CookieDump, name: string): boolean {
  return dump.some((item) => !!item && item.name === name && typeof item.value === 'string' && item.value.length > 0);
}

export function inferRestoredBitSsoState(
  useWebvpn: boolean,
  dump: CookieDump | null | undefined,
): RestoredBitSsoState {
  const cookies = Array.isArray(dump) ? dump : [];
  const hasMoodle = hasCookie(cookies, 'MoodleSession');
  if (!useWebvpn) {
    return {
      hasSso: hasMoodle,
      hasLexue: hasMoodle,
      requiresTicketRefresh: false,
    };
  }

  const hasVpnTicket = hasCookie(cookies, 'wengine_vpn_ticketwebvpn_bit_edu_cn');
  return {
    hasSso: false,
    hasLexue: hasVpnTicket,
    requiresTicketRefresh: hasVpnTicket,
  };
}

export function isRestoredLexueExportUsable(
  statusCode: number,
  effectiveUrl: string | undefined,
  bodyText: string | undefined,
): boolean {
  if (statusCode !== 200) {
    return false;
  }

  const url = effectiveUrl ?? '';
  const body = bodyText ?? '';
  if (url.includes('/cas/login') || looksLikeSsoLoginPage(body)) {
    return false;
  }

  return extractLexueSesskey(body).length > 0;
}
