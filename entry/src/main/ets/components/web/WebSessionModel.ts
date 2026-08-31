import ohosUrl from '@ohos.url';
import { TokenStore } from '../../services/storage/tokenStore';

export type WebCredentialState = 'unavailable';
export type WebThemeMode = 'light' | 'dark';

export interface WebSessionState {
  fakeCookie: string;
  username: string;
  credentialState: WebCredentialState;
}

export interface WebSessionStore {
  getFakeCookie(): Promise<string | null>;
  getUsername(): Promise<string | null>;
}

interface ParsedWebUrl {
  protocol: string;
  hostname: string;
  origin: string;
}

interface WebInjectionPayload {
  theme_mode: WebThemeMode;
  fake_cookie: string;
}

const TRUSTED_HOSTS: string[] = [
  'bit101.cn',
  'bit.edu.cn',
  'flwfdd.xyz',
];

function parseWebUrl(value: string): ParsedWebUrl | null {
  const input: string = value.trim();
  try {
    const parsed: ohosUrl.URL = new ohosUrl.URL(input);
    const platformResult: ParsedWebUrl = {
      protocol: parsed.protocol.toLowerCase(),
      hostname: parsed.hostname.toLowerCase(),
      origin: parsed.origin.toLowerCase(),
    };
    if (platformResult.protocol.length > 0 && platformResult.hostname.length > 0) {
      return platformResult;
    }
  } catch (error) {
  }

  // The host-side Hypium runtime does not implement @ohos.url. Keep a strict
  // http(s)-only fallback so policy tests exercise the same hostname rules.
  const matched: RegExpMatchArray | null = input.match(/^(https?):\/\/([^/?#]+)(?:[/?#]|$)/i);
  if (!matched) {
    return null;
  }
  let authority: string = matched[2].toLowerCase();
  const userInfoEnd: number = authority.lastIndexOf('@');
  if (userInfoEnd >= 0) {
    authority = authority.slice(userInfoEnd + 1);
  }
  if (authority.length === 0 || authority.includes('\\') || /\s/.test(authority)) {
    return null;
  }
  const colonIndex: number = authority.lastIndexOf(':');
  const hostname: string = colonIndex >= 0 ? authority.slice(0, colonIndex) : authority;
  const port: string = colonIndex >= 0 ? authority.slice(colonIndex + 1) : '';
  if (!/^[a-z0-9.-]+$/.test(hostname) || (port.length > 0 && !/^\d+$/.test(port))) {
    return null;
  }
  const protocol: string = matched[1].toLowerCase() + ':';
  const origin: string = protocol + '//' + hostname + (port.length > 0 ? ':' + port : '');
  return {
    protocol,
    hostname,
    origin,
  };
}

function hostMatches(hostname: string, expectedHost: string): boolean {
  return hostname === expectedHost || hostname.endsWith('.' + expectedHost);
}

export function isTrustedWebUrl(value: string): boolean {
  const parsed: ParsedWebUrl | null = parseWebUrl(value);
  if (!parsed || (parsed.protocol !== 'https:' && parsed.protocol !== 'http:')) {
    return false;
  }
  return TRUSTED_HOSTS.some((host: string): boolean => hostMatches(parsed.hostname, host));
}

export function isAllowedInWebView(
  targetUrl: string,
  initialUrl: string,
  allowInitialOrigin: boolean,
): boolean {
  if (targetUrl === 'about:blank') {
    return true;
  }
  if (isTrustedWebUrl(targetUrl)) {
    return true;
  }
  if (!allowInitialOrigin) {
    return false;
  }
  const target: ParsedWebUrl | null = parseWebUrl(targetUrl);
  const initial: ParsedWebUrl | null = parseWebUrl(initialUrl);
  if (!target || !initial) {
    return false;
  }
  return target.origin.length > 0 && target.origin === initial.origin;
}

export function shouldInjectBit101Session(value: string): boolean {
  const parsed: ParsedWebUrl | null = parseWebUrl(value);
  return !!parsed &&
    parsed.protocol === 'https:' &&
    hostMatches(parsed.hostname, 'bit101.cn');
}

export function buildWebSessionInjectionScript(
  state: WebSessionState,
  themeMode: WebThemeMode,
): string {
  const payload: WebInjectionPayload = {
    theme_mode: themeMode,
    fake_cookie: state.fakeCookie,
  };
  const payloadJson: string = JSON.stringify(payload)
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');

  return '(function () {\n' +
    '  const payload = ' + payloadJson + ';\n' +
    '  let store = {};\n' +
    '  const oldStore = window.localStorage.getItem(\"store\");\n' +
    '  if (oldStore) {\n' +
    '    try {\n' +
    '      const parsed = JSON.parse(oldStore);\n' +
    '      if (parsed && typeof parsed === \"object\" && !Array.isArray(parsed)) {\n' +
    '        store = parsed;\n' +
    '      }\n' +
    '    } catch (error) {}\n' +
    '  }\n' +
    '  store.theme_mode = payload.theme_mode;\n' +
    '  if (payload.fake_cookie) {\n' +
    '    store.fake_cookie = payload.fake_cookie;\n' +
    '  } else {\n' +
    '    delete store.fake_cookie;\n' +
    '  }\n' +
    '  const nextStore = JSON.stringify(store);\n' +
    '  window.localStorage.setItem(\"store\", nextStore);\n' +
    '  return true;\n' +
    '})();';
}

export class WebSessionModel {
  private readonly store: WebSessionStore;

  constructor(store?: WebSessionStore) {
    this.store = store ?? new TokenStore();
  }

  async load(): Promise<WebSessionState> {
    const fakeCookie: string | null = await this.store.getFakeCookie();
    const username: string | null = await this.store.getUsername();
    return {
      fakeCookie: fakeCookie ?? '',
      username: username ?? '',
      credentialState: 'unavailable',
    };
  }
}
