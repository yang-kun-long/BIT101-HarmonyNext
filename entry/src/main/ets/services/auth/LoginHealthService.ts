import { HttpClient } from '../../core/network/httpClient';
import { Logger } from '../../utils/Logger';
import { createBitSsoSessionAuto } from '../lexue/BitSsoAuto';
import { FreeClassroomRepository } from '../jw/freeClassroomRepository';
import { detectSchoolLoginMode } from '../school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../school/SchoolAuthTypes';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { SchoolCookieStore } from '../storage/SchoolCookieStore';
import { TokenStore } from '../storage/tokenStore';

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

export interface LoginDomainHealth {
  ok: boolean;
  message: string;
}

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
): Promise<T> {
  try {
    return await operation();
  } catch (_) {
    const summary: LoginHealthSummary = await checkLogin();
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
    statusText: ok ? '已登录' : (coreOk ? '部分异常' : '未登录'),
    toastText: ok
      ? '登录状态检查成功'
      : (coreOk ? '部分登录态异常，请重新登录后再试考试/空教室' : '登录状态检查失败'),
    detail: detailParts.join('；'),
    bit101,
    school,
    jxzx: jxzxHealth,
  };
}

export class LoginHealthService {
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
    const bit101: LoginDomainHealth = await this.checkBit101Login();
    const school: LoginDomainHealth = await this.checkSchoolLogin();
    const jxzx: LoginDomainHealth = await this.checkJxzxLogin();
    const summary: LoginHealthSummary = buildLoginHealthSummary(bit101, school, jxzx);

    if ((!bit101.ok || !school.ok) && options?.clearWhenInvalid !== false) {
      await this.clearLoginState();
    }

    return summary;
  }

  async clearLoginState(): Promise<void> {
    await this.store.clear();
    await new LexueCookieStore('inner').clearCookieDump();
    await new LexueCookieStore('webvpn').clearCookieDump();
    await new SchoolCookieStore('inner').clearCookieDump();
    await new SchoolCookieStore('webvpn').clearCookieDump();
  }

  private async checkBit101Login(): Promise<LoginDomainHealth> {
    const fakeCookie: string | null = await this.store.getFakeCookie();
    if (!fakeCookie || fakeCookie.length === 0) {
      return {
        ok: false,
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
        message: 'BIT101 登录态有效',
      };
    } catch (error) {
      this.logger.warn('BIT101 login health check failed', error);
      return {
        ok: false,
        message: 'BIT101 登录态不可用',
      };
    }
  }

  private async checkSchoolLogin(): Promise<LoginDomainHealth> {
    try {
      const session = await createBitSsoSessionAuto({
        debug: true,
        webvpnLexueBase: WEBVPN_LEXUE_BASE,
      });
      await session.sso.restoreFromStorage();

      if (!session.sso.isFullyLoggedIn()) {
        return {
          ok: false,
          message: '学校登录态不可用',
        };
      }

      return {
        ok: true,
        message: '学校登录态有效',
      };
    } catch (error) {
      this.logger.warn('school login health check failed', error);
      return {
        ok: false,
        message: '学校登录态不可用',
      };
    }
  }

  private async checkJxzxLogin(): Promise<LoginDomainHealth> {
    try {
      let mode: SchoolLoginMode = 'inner';
      try {
        mode = await detectSchoolLoginMode({ debug: true });
      } catch (_) {
        mode = 'inner';
      }

      const repo = new FreeClassroomRepository({
        mode,
        debug: true,
        timeoutMs: 8000,
      });
      await repo.restoreWebvpnCookiesFromStorage();
      const campuses = await repo.getCampusInfos();
      if (campuses.length === 0) {
        return {
          ok: false,
          message: '教务应用登录态不可用',
        };
      }

      return {
        ok: true,
        message: '教务应用登录态有效',
      };
    } catch (error) {
      this.logger.warn('JXZX login health check failed', error);
      return {
        ok: false,
        message: '教务应用登录态不可用',
      };
    }
  }
}
