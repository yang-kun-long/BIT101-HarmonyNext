import { Logger } from '../../utils/Logger';
import RcpSession from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { SchoolCasClient } from './SchoolCasClient';
import { SchoolServiceResolutionError, SchoolWebvpnLandingError } from './SchoolAuthErrors';
import { extractPortalServiceFromLocation, resolveAbsoluteUrl, resolveServiceFromRedirect } from './SchoolServiceResolver';
import { buildWebvpnJumpUrl } from './WebvpnJumpBuilder';
import type { SchoolLoginMode, SchoolLoginResult } from './SchoolAuthTypes';
import type { SchoolSessionState } from './SchoolSessionState';

const logger = new Logger('SchoolAuthService');
const WEBVPN_PORTAL_ENTRY = 'https://webvpn.bit.edu.cn/login?cas_login=true';
const WEBVPN_PORTAL_HOME = 'https://webvpn.bit.edu.cn/';
const DEFAULT_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

function findHeader(headers: Record<string, Object> | undefined, wanted: string): string {
  if (!headers) return '';
  const keys = Object.keys(headers);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (key.toLowerCase() !== wanted.toLowerCase()) continue;
    const value = headers[key];
    return typeof value === 'string' ? value : '';
  }
  return '';
}

function looksLikeCasLoginUrl(url: string): boolean {
  return url.includes('/cas/login');
}

export interface SchoolAuthServiceOptions {
  debug?: boolean;
  userAgent?: string;
}

export class SchoolAuthService {
  private readonly debug: boolean;
  private readonly userAgent: string;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;
  private readonly casClient: SchoolCasClient;
  private lastTgtUrl?: string;

  constructor(options?: SchoolAuthServiceOptions) {
    this.debug = !!options?.debug;
    this.userAgent = options?.userAgent ?? DEFAULT_UA;
    this.jar = new SimpleCookieJar();
    this.client = new RcpSession({
      debug: this.debug,
      timeoutMs: 15000,
      defaultHeaders: {
        'User-Agent': this.userAgent,
      },
      cookieJar: this.jar,
    });
    this.casClient = new SchoolCasClient(this.userAgent);
  }

  getCookieDump(): CookieDump {
    return this.jar.dump();
  }

  getSessionState(mode: SchoolLoginMode, portalService?: string, effectiveUrl?: string): SchoolSessionState {
    return {
      mode,
      cookies: this.jar.dump(),
      portalService,
      effectiveUrl,
    };
  }

  async resolveWebvpnPortalService(): Promise<string> {
    const resp = await this.client.get(WEBVPN_PORTAL_ENTRY, {
      autoRedirect: false,
      collectTimeInfo: false,
    });
    const location = findHeader(resp.headers as Record<string, Object>, 'location');
    const service = extractPortalServiceFromLocation(location);
    logger.debug('resolveWebvpnPortalService location =', location, 'service =', service);
    if (!service) {
      throw new SchoolServiceResolutionError('Cannot resolve WebVPN portal service');
    }
    return service;
  }

  async loginWebvpnPortal(username: string, password: string): Promise<SchoolLoginResult> {
    const portalService = await this.resolveWebvpnPortalService();
    const tgtUrl = await this.casClient.getTgt(username, password);
    this.lastTgtUrl = tgtUrl;
    const st = await this.casClient.getSt(tgtUrl, portalService);
    const jumpUrl = buildWebvpnJumpUrl(portalService, st);
    logger.info('loginWebvpnPortal portalService =', portalService);

    const resp = await this.client.get(jumpUrl, {
      autoRedirect: true,
      collectTimeInfo: false,
    });

    const cookieDump = this.jar.dump();
    const hasPortalTicket = cookieDump.some((c) => c.name === 'wengine_vpn_ticketwebvpn_bit_edu_cn' && !!c.value);
    const effectiveUrl = String(resp.effectiveUrl ?? '');
    logger.debug('loginWebvpnPortal effectiveUrl =', effectiveUrl, 'cookies =', cookieDump.map((c) => c.name));

    if (!hasPortalTicket) {
      throw new SchoolWebvpnLandingError('WebVPN portal login succeeded without required portal cookie');
    }
    if (resp.statusCode >= 400) {
      throw new SchoolWebvpnLandingError(`Unexpected WebVPN landing status: ${resp.statusCode}`);
    }
    if (looksLikeCasLoginUrl(effectiveUrl)) {
      throw new SchoolWebvpnLandingError(`WebVPN jump returned to CAS login page: ${effectiveUrl}`);
    }

    return {
      mode: 'webvpn',
      portalLoggedIn: true,
      targetLoggedIn: effectiveUrl.startsWith(WEBVPN_PORTAL_HOME) && !looksLikeCasLoginUrl(effectiveUrl),
      targetName: 'webvpn-portal',
      effectiveUrl,
    };
  }

  async resolveWebvpnTargetService(targetUrl: string, maxRedirects: number = 10): Promise<string> {
    let currentUrl = targetUrl;

    for (let i = 0; i < maxRedirects; i++) {
      const resp = await this.client.get(currentUrl, {
        autoRedirect: false,
        collectTimeInfo: false,
        headers: {
          Referer: WEBVPN_PORTAL_HOME,
        },
      });

      const location = findHeader(resp.headers as Record<string, Object>, 'location');
      logger.debug('resolveWebvpnTargetService step =', i, 'status =', resp.statusCode, 'currentUrl =', currentUrl, 'location =', location);

      if (!location) {
        break;
      }

      const service = resolveServiceFromRedirect(currentUrl, location);
      if (service) {
        return service;
      }

      currentUrl = resolveAbsoluteUrl(currentUrl, location);
    }

    throw new SchoolServiceResolutionError(`Cannot resolve target service from ${targetUrl}`);
  }

  async loginWebvpnTarget(targetUrl: string, targetName: string, username?: string, password?: string): Promise<SchoolLoginResult> {
    const tgtUrl = this.lastTgtUrl ?? ((username && password) ? await this.casClient.getTgt(username, password) : '');
    if (!tgtUrl) {
      throw new SchoolServiceResolutionError('No TGT available for target login');
    }

    const targetService = await this.resolveWebvpnTargetService(targetUrl);
    const st = await this.casClient.getSt(tgtUrl, targetService);
    const jumpUrl = buildWebvpnJumpUrl(targetService, st);
    logger.info('loginWebvpnTarget targetName =', targetName, 'targetService =', targetService);

    const resp = await this.client.get(jumpUrl, {
      autoRedirect: true,
      collectTimeInfo: false,
      headers: {
        Referer: WEBVPN_PORTAL_HOME,
      },
    });

    const effectiveUrl = String(resp.effectiveUrl ?? '');
    logger.debug('loginWebvpnTarget effectiveUrl =', effectiveUrl, 'status =', resp.statusCode);

    if (resp.statusCode >= 400) {
      throw new SchoolWebvpnLandingError(`Target landing failed: ${resp.statusCode}`);
    }
    if (looksLikeCasLoginUrl(effectiveUrl)) {
      throw new SchoolWebvpnLandingError(`Target jump returned to CAS login page: ${effectiveUrl}`);
    }

    return {
      mode: 'webvpn',
      portalLoggedIn: true,
      targetLoggedIn: true,
      targetName,
      effectiveUrl,
    };
  }
}
