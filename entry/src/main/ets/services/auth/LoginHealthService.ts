import { ApiError, HttpClient } from '../../core/network/httpClient';
import { Logger } from '../../utils/Logger';
import { createBitSsoSessionAuto } from '../lexue/BitSsoAuto';
import { FreeClassroomRepository } from '../jw/freeClassroomRepository';
import { detectSchoolLoginMode } from '../school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import { TokenStore } from '../storage/tokenStore';
import { classifyAuthFailure } from './AuthFailure';
import { clearWebLoginData } from './WebLogout';
import { refreshSavedLogin } from './AutomaticLogin';
import { RefreshResult } from './LoginRefreshCoordinator';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

export interface LoginDomainHealth {
  ok: boolean;
  status?: LoginHealthStatus;
  message: string;
}

export type LoginHealthStatus = 'valid' | 'invalid' | 'unknown' | 'degraded';

export interface LoginHealthSummary {
  ok: boolean;
  statusText: string;
  toastText: string;
  detail: string;
  bit101: LoginDomainHealth;
  school: LoginDomainHealth;
  jxzx: LoginDomainHealth;
}

export interface LoginHealthCheckOptions {
  clearWhenInvalid?: boolean;
}

function domainStatus(health: LoginDomainHealth): LoginHealthStatus {
  return health.status ?? (health.ok ? 'valid' : 'invalid');
}

export function shouldClearLoginDomain(health: LoginDomainHealth): boolean {
  return domainStatus(health) === 'invalid';
}

export type LoginRequiredOperation<T> = () => Promise<T>;
export type LoginRequiredHealthCheck = () => Promise<LoginHealthSummary>;
export type LoginHealthRequirement = 'all' | 'core' | 'jxzx';

function canRetryForRequirement(summary: LoginHealthSummary, requirement: LoginHealthRequirement): boolean {
  if (requirement === 'core') {
    return summary.bit101.ok && summary.school.ok;
  }
  if (requirement === 'jxzx') {
    return summary.bit101.ok && summary.school.ok && summary.jxzx.ok;
  }
  return summary.ok;
}

function failureMessageForRequirement(summary: LoginHealthSummary, requirement: LoginHealthRequirement): string {
  if (
    domainStatus(summary.bit101) === 'unknown' ||
    domainStatus(summary.bit101) === 'degraded' ||
    domainStatus(summary.school) === 'unknown' ||
    domainStatus(summary.school) === 'degraded'
  ) {
    return '网络异常，登录状态暂时无法确认';
  }
  if (requirement === 'jxzx' && summary.bit101.ok && summary.school.ok && !summary.jxzx.ok) {
    return '教务应用登录态不可用，请重新登录后再试';
  }
  if (requirement === 'core' && (!summary.bit101.ok || !summary.school.ok)) {
    return '学校登录态不可用，请重新登录后再试';
  }
  return 'check login failed';
}

export async function doOperationRequiresLogin<T>(
  operation: LoginRequiredOperation<T>,
  checkLogin: LoginRequiredHealthCheck,
  requirement: LoginHealthRequirement = 'all',
  refresh: () => Promise<RefreshResult> = refreshSavedLogin,
): Promise<T> {
  try {
    return await operation();
  } catch (_) {
    let summary: LoginHealthSummary = await checkLogin();
    if (!canRetryForRequirement(summary, requirement) &&
      (summary.bit101.status === 'invalid' || summary.school.status === 'invalid' ||
        (requirement !== 'core' && summary.jxzx.status === 'invalid'))) {
      if (await refresh() === 'SUCCESS') summary = await checkLogin();
    }
    if (!canRetryForRequirement(summary, requirement)) {
      throw new Error(failureMessageForRequirement(summary, requirement));
    }
    return await operation();
  }
}

export function buildLoginHealthSummary(
  bit101: LoginDomainHealth,
  school: LoginDomainHealth,
  jxzx?: LoginDomainHealth,
): LoginHealthSummary {
  const jxzxHealth: LoginDomainHealth = jxzx ?? {
    ok: true,
    message: '教务应用登录态有效',
  };
  const ok: boolean = bit101.ok && school.ok && jxzxHealth.ok;
  const coreOk: boolean = bit101.ok && school.ok;
  const coreUnknown: boolean =
    domainStatus(bit101) === 'unknown' ||
    domainStatus(bit101) === 'degraded' ||
    domainStatus(school) === 'unknown' ||
    domainStatus(school) === 'degraded';
  const detailParts: string[] = [];

  if (!bit101.ok && bit101.message.length > 0) {
    detailParts.push(bit101.message);
  }
  if (!school.ok && school.message.length > 0) {
    detailParts.push(school.message);
  }
  if (!jxzxHealth.ok && jxzxHealth.message.length > 0) {
    detailParts.push(jxzxHealth.message);
  }

  return {
    ok,
    statusText: ok ? '已登录' : (coreUnknown ? '状态未知' : (coreOk ? '部分异常' : '未登录')),
    toastText: ok
      ? '登录状态检查成功'
      : (
        coreUnknown
          ? '网络异常，登录状态未改变'
          : (coreOk ? '部分登录态异常，请重新登录后再试考试/空教室' : '登录状态检查失败')
      ),
    detail: detailParts.join('；'),
    bit101,
    school,
    jxzx: jxzxHealth,
  };
}

export class LoginHealthService {
  private static inFlight: Promise<LoginHealthSummary> | null = null;
  private readonly logger = new Logger('LoginHealthService');
  private readonly store = new TokenStore();
  private readonly http: HttpClient;

  constructor(baseUrl: string = 'https://bit101.flwfdd.xyz') {
    this.http = new HttpClient(baseUrl, {
      'User-Agent': 'BIT101 HarmonyOS/1.0 (ArkTS)',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    });
  }

  async checkLogin(options?: LoginHealthCheckOptions): Promise<LoginHealthSummary> {
    if (LoginHealthService.inFlight === null) {
      LoginHealthService.inFlight = this.performHealthCheck();
    }
    const operation: Promise<LoginHealthSummary> = LoginHealthService.inFlight;
    let summary: LoginHealthSummary;
    try {
      summary = await operation;
    } finally {
      if (LoginHealthService.inFlight === operation) {
        LoginHealthService.inFlight = null;
      }
    }

    if (options?.clearWhenInvalid !== false) {
      await this.clearExplicitlyInvalidDomains(summary);
    }
    return summary;
  }

  private async performHealthCheck(): Promise<LoginHealthSummary> {
    const bit101: LoginDomainHealth = await this.checkBit101Login();
    const school: LoginDomainHealth = await this.checkSchoolLogin();
    const jxzx: LoginDomainHealth = await this.checkJxzxLogin();
    return buildLoginHealthSummary(bit101, school, jxzx);
  }

  async clearLoginState(): Promise<void> {
    await this.store.clear();
    await new LexueCookieStore('inner').clearCookieDump();
    await new LexueCookieStore('webvpn').clearCookieDump();
    await new SchoolCookieStore('inner').clearCookieDump();
    await new SchoolCookieStore('webvpn').clearCookieDump();
    await clearWebLoginData();
  }

  private async clearExplicitlyInvalidDomains(summary: LoginHealthSummary): Promise<void> {
    if (shouldClearLoginDomain(summary.bit101)) {
      await this.store.clearBit101Session();
    }
    if (shouldClearLoginDomain(summary.school)) {
      await this.store.clearSchoolSession();
      await new LexueCookieStore('inner').clearCookieDump();
      await new LexueCookieStore('webvpn').clearCookieDump();
    }
    if (
      shouldClearLoginDomain(summary.school) ||
      shouldClearLoginDomain(summary.jxzx)
    ) {
      await new SchoolCookieStore('inner').clearCookieDump();
      await new SchoolCookieStore('webvpn').clearCookieDump();
    }
  }

  private async checkBit101Login(): Promise<LoginDomainHealth> {
    const fakeCookie: string | null = await this.store.getFakeCookie();
    if (!fakeCookie || fakeCookie.length === 0) {
      return {
        ok: false,
        status: 'invalid',
        message: 'BIT101 登录态不可用',
      };
    }

    try {
      await this.http.request<void>({
        url: '/user/check',
        method: 'GET',
        headers: {
          'fake-cookie': fakeCookie,
        },
        connectTimeoutMs: 8000,
        readTimeoutMs: 8000,
      });

      return {
        ok: true,
        status: 'valid',
        message: 'BIT101 登录态有效',
      };
    } catch (error) {
      this.logger.warn('BIT101 login health check failed', error);
      const failure = classifyAuthFailure(
        error instanceof Error ? error : new Error(String(error)),
      );
      const invalid = error instanceof ApiError &&
        (error.status === 401 || error.status === 403);
      return {
        ok: false,
        status: invalid ? 'invalid' : (failure === 'server_transient' ? 'degraded' : 'unknown'),
        message: invalid ? 'BIT101 登录态不可用' : 'BIT101 状态暂时无法确认',
      };
    }
  }

  private async checkSchoolLogin(): Promise<LoginDomainHealth> {
    try {
      const session = await createBitSsoSessionAuto({
        debug: false,
        webvpnLexueBase: WEBVPN_LEXUE_BASE,
      });
      const stored = await new LexueCookieStore(session.mode).loadCookieDump();
      if (!stored || stored.length === 0) {
        return {
          ok: false,
          status: 'invalid',
          message: '学校登录态不可用',
        };
      }
      await session.sso.restoreFromStorage();

      if (!session.sso.isFullyLoggedIn()) {
        return {
          ok: false,
          status: 'unknown',
          message: '学校登录态暂时无法确认',
        };
      }

      return {
        ok: true,
        status: 'valid',
        message: '学校登录态有效',
      };
    } catch (error) {
      this.logger.warn('school login health check failed', error);
      return {
        ok: false,
        status: 'unknown',
        message: '学校登录态暂时无法确认',
      };
    }
  }

  private async checkJxzxLogin(): Promise<LoginDomainHealth> {
    try {
      const mode: SchoolLoginMode = await detectSchoolLoginMode({ debug: false });
      const stored = await new SchoolCookieStore(mode).loadCookieDump();
      if (!stored || stored.length === 0) {
        return {
          ok: false,
          status: 'invalid',
          message: '教务应用登录态不可用',
        };
      }

      const repo = new FreeClassroomRepository({
        mode,
        debug: false,
        timeoutMs: 8000,
      });
      await repo.restoreWebvpnCookiesFromStorage();
      const campuses = await repo.getCampusInfos();
      if (campuses.length === 0) {
        return {
          ok: false,
          status: 'degraded',
          message: '教务应用状态暂时无法确认',
        };
      }

      return {
        ok: true,
        status: 'valid',
        message: '教务应用登录态有效',
      };
    } catch (error) {
      this.logger.warn('JXZX login health check failed', error);
      return {
        ok: false,
        status: 'unknown',
        message: '教务应用状态暂时无法确认',
      };
    }
  }
}
