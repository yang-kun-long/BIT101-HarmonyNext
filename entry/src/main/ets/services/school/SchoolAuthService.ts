import { Logger } from '../../utils/Logger';
import RcpSession, { RcpResponseData } from '../../core/network/rcpSession';
import SimpleCookieJar, { CookieDump } from '../../core/network/cookieJar';
import { SchoolCasClient } from './SchoolCasClient';
import { SchoolServiceResolutionError, SchoolWebvpnLandingError } from './SchoolAuthErrors';
import { extractPortalServiceFromLocation, resolveAbsoluteUrl, resolveServiceFromRedirect } from './SchoolServiceResolver';
import { buildWebvpnJumpUrl } from './WebvpnJumpBuilder';
import type { SchoolLoginMode, SchoolLoginResult } from './SchoolAuthTypes';
import type { SchoolSessionState } from './SchoolSessionState';
import type { SmsCodeHandler } from '../auth/SmsChallengeCoordinator';
import { loginSchoolSsoPassword } from './SchoolSmsProtocol';

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
    if (typeof value === 'string') return value;
    if (Array.isArray(value) && value.length > 0) {
      const first = value[0];
      return typeof first === 'string' ? first : String(first);
    }
    if (value !== null && value !== undefined) {
      return String(value);
    }
    return '';
  }
  return '';
}

function looksLikeCasLoginUrl(url: string): boolean {
  return url.includes('/cas/login');
}

export function appendTicketToServiceUrl(service: string, ticket: string): string {
  if (!service || !ticket) {
    throw new Error('service and ticket are required');
  }
  return service.includes('?')
    ? `${service}&ticket=${encodeURIComponent(ticket)}`
    : `${service}?ticket=${encodeURIComponent(ticket)}`;
}

export function resolveWebvpnCasCallback(currentUrl: string, location: string): string {
  if (!location) return '';
  return location.startsWith('/')
    ? `https://webvpn.bit.edu.cn${location}`
    : resolveAbsoluteUrl(currentUrl, location);
}

export interface SchoolAuthServiceOptions {
  debug?: boolean;
  userAgent?: string;
  smsCodeHandler?: SmsCodeHandler;
}

export class SchoolAuthService {
  private readonly debug: boolean;
  private readonly userAgent: string;
  private readonly jar: SimpleCookieJar;
  private readonly client: RcpSession;
  private readonly casClient: SchoolCasClient;
  private readonly smsCodeHandler?: SmsCodeHandler;
  private lastTgtUrl?: string;

  constructor(options?: SchoolAuthServiceOptions) {
    this.debug = !!options?.debug;
    this.userAgent = options?.userAgent ?? DEFAULT_UA;
    this.smsCodeHandler = options?.smsCodeHandler;
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
    const loginResponse = await loginSchoolSsoPassword(
      this.client,
      username,
      password,
      portalService,
      this.smsCodeHandler,
    );
    this.lastTgtUrl = undefined;
    const location = findHeader(loginResponse.headers as Record<string, Object>, 'location');
    if (!location) {
      throw new SchoolWebvpnLandingError('CAS login did not return a WebVPN callback');
    }
    const jumpUrl = resolveWebvpnCasCallback(String(loginResponse.effectiveUrl ?? ''), location);
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
    const targetService = await this.resolveWebvpnTargetService(targetUrl);
    let st: string;
    if (this.lastTgtUrl) {
      st = await this.casClient.getSt(this.lastTgtUrl, targetService);
    } else {
      st = await this.getServiceTicketFromSsoSession(targetService);
    }
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

  private async getServiceTicketFromSsoSession(service: string): Promise<string> {
    const casUrl = `https://sso.bit.edu.cn/cas/login?service=${encodeURIComponent(service)}`;
    const response = await this.client.get(casUrl, {
      autoRedirect: false,
      collectTimeInfo: false,
    });
    const location = findHeader(response.headers as Record<string, Object>, 'location');
    const ticketMatch = location.match(/[?&]ticket=([^&#]+)/i);
    if (!ticketMatch || !ticketMatch[1]) {
      throw new SchoolServiceResolutionError('The active SSO session did not issue a service ticket');
    }
    return decodeURIComponent(ticketMatch[1]);
  }

  async resolveInnerTargetService(targetUrl: string, maxRedirects: number = 10): Promise<string> {
    let currentUrl = targetUrl;

    for (let i = 0; i < maxRedirects; i++) {
      const resp = await this.client.get(currentUrl, {
        autoRedirect: false,
        collectTimeInfo: false,
      });

      const location = findHeader(resp.headers as Record<string, Object>, 'location');
      logger.debug('resolveInnerTargetService step =', i, 'status =', resp.statusCode, 'currentUrl =', currentUrl, 'location =', location);

      if (!location) {
        return currentUrl;
      }

      const nextUrl = resolveAbsoluteUrl(currentUrl, location);
      if (looksLikeCasLoginUrl(nextUrl)) {
        const service = resolveServiceFromRedirect(currentUrl, location);
        return service;
      }
      currentUrl = nextUrl;
    }

    throw new SchoolServiceResolutionError(`Cannot resolve inner target service from ${targetUrl}`);
  }

  async loginInnerTarget(targetUrl: string, targetName: string, username: string, password: string): Promise<SchoolLoginResult> {
    const targetService = await this.resolveInnerTargetService(targetUrl);
    const tgtUrl = await this.casClient.getTgt(username, password);
    this.lastTgtUrl = tgtUrl;
    const st = await this.casClient.getSt(tgtUrl, targetService);
    const jumpUrl = appendTicketToServiceUrl(targetService, st);
    logger.info('loginInnerTarget targetName =', targetName, 'targetService =', targetService);

    const resp = await this.getWithManualRedirects(jumpUrl, 15);
    const effectiveUrl = String(resp.effectiveUrl ?? '');
    logger.debug('loginInnerTarget effectiveUrl =', effectiveUrl, 'status =', resp.statusCode);

    if (resp.statusCode >= 400) {
      throw new SchoolWebvpnLandingError(`Inner target landing failed: ${resp.statusCode}`);
    }
    if (looksLikeCasLoginUrl(effectiveUrl)) {
      throw new SchoolWebvpnLandingError(`Inner target jump returned to CAS login page: ${effectiveUrl}`);
    }

    return {
      mode: 'inner',
      portalLoggedIn: false,
      targetLoggedIn: true,
      targetName,
      effectiveUrl,
    };
  }

  private async getWithManualRedirects(initialUrl: string, maxRedirects: number): Promise<RcpResponseData> {
    let currentUrl = initialUrl;
    for (let i = 0; i <= maxRedirects; i++) {
      const resp = await this.client.get(currentUrl, {
        autoRedirect: false,
        collectTimeInfo: false,
      });
      const location = findHeader(resp.headers as Record<string, Object>, 'location');
      logger.debug('manual redirect step =', i, 'status =', resp.statusCode, 'url =', currentUrl, 'location =', location);

      if (
        resp.statusCode === 301 ||
          resp.statusCode === 302 ||
          resp.statusCode === 303 ||
          resp.statusCode === 307 ||
          resp.statusCode === 308
      ) {
        if (!location) {
          return resp;
        }
        currentUrl = resolveAbsoluteUrl(currentUrl, location);
        continue;
      }
      return resp;
    }
    throw new SchoolServiceResolutionError(`Manual redirect exceeded ${maxRedirects}: ${initialUrl}`);
  }
}
