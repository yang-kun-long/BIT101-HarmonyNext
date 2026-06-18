import { Logger } from '../../utils/Logger';
import { AuthRepository } from './authRepository';
import {
  Bit101LoginFlowParams,
  Bit101LoginFlowResult,
  loginBit101AndVerifyWebvpn,
} from './bit101LoginFlow';
import {
  BitSsoLoginMode,
  createBitSsoSessionAuto,
} from '../lexue/BitSsoAuto';
import BitSsoSession from '../lexue/BitSsoSession';
import { syncUserCalendar } from '../lexue/CalendarService';
import { TokenStore } from '../storage/tokenStore';
import { prepareFreeClassroomSession } from '../jw/freeClassroomSession';

export const LOGIN_WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
export const LOGIN_WEBVPN_PORTAL_URL = 'https://webvpn.bit.edu.cn/';
export const LOGIN_INNER_LEXUE_BASE = 'https://lexue.bit.edu.cn';

export interface LoginCoordinatorSso {
  loginToLexue(username: string, password: string): Promise<void>;
  isFullyLoggedIn(): boolean;
  getCookieHeaderFor(url: string): string | undefined;
}

export interface LoginCoordinatorDeps {
  loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult>;
  createBitSsoSessionAuto(): Promise<LoginCoordinatorSsoCreateResult>;
  saveWebvpnCookie(cookie: string): Promise<void>;
  prepareFreeClassroomSession(username: string, password: string, mode: BitSsoLoginMode): Promise<void>;
  syncUserCalendar(username: string, mode: BitSsoLoginMode, sso: LoginCoordinatorSso): Promise<number>;
  saveUsername(username: string): Promise<void>;
}

export interface LoginCoordinatorSsoCreateResult {
  mode: BitSsoLoginMode;
  sso: LoginCoordinatorSso;
}

export interface LoginCoordinatorParams {
  sid: string;
  password: string;
  captcha?: string;
}

export interface LoginCoordinatorResult {
  ok: boolean;
  bit101Ok: boolean;
  schoolOk: boolean;
  mode: BitSsoLoginMode;
  sso: LoginCoordinatorSso;
  bit101: Bit101LoginFlowResult;
  syncedCalendarCount: number;
}

class DefaultLoginCoordinatorDeps implements LoginCoordinatorDeps {
  private readonly auth: AuthRepository;
  private readonly tokenStore: TokenStore;
  private readonly debug: boolean;

  constructor(auth: AuthRepository, tokenStore: TokenStore, debug: boolean) {
    this.auth = auth;
    this.tokenStore = tokenStore;
    this.debug = debug;
  }

  async loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult> {
    return await loginBit101AndVerifyWebvpn(this.auth, params);
  }

  async createBitSsoSessionAuto(): Promise<LoginCoordinatorSsoCreateResult> {
    return await createBitSsoSessionAuto({
      debug: this.debug,
      webvpnLexueBase: LOGIN_WEBVPN_LEXUE_BASE,
    });
  }

  async saveWebvpnCookie(cookie: string): Promise<void> {
    await this.tokenStore.saveWebvpnCookie(cookie);
  }

  async prepareFreeClassroomSession(username: string, password: string, mode: BitSsoLoginMode): Promise<void> {
    await prepareFreeClassroomSession(username, password, mode, this.debug);
  }

  async syncUserCalendar(username: string, mode: BitSsoLoginMode, sso: LoginCoordinatorSso): Promise<number> {
    const baseUrl = mode === 'inner' ? LOGIN_INNER_LEXUE_BASE : LOGIN_WEBVPN_LEXUE_BASE;
    return await syncUserCalendar({
      sso: sso as BitSsoSession,
      username,
      webvpnLexueBase: baseUrl,
    });
  }

  async saveUsername(username: string): Promise<void> {
    await this.tokenStore.saveUsername(username);
  }
}

export class LoginCoordinator {
  private readonly deps: LoginCoordinatorDeps;
  private readonly logger = new Logger('LoginCoordinator');

  constructor(deps?: LoginCoordinatorDeps) {
    this.deps = deps ?? new DefaultLoginCoordinatorDeps(
      new AuthRepository(),
      new TokenStore(),
      true,
    );
  }

  async login(params: LoginCoordinatorParams): Promise<LoginCoordinatorResult> {
    const username = params.sid.trim();
    const normalized: Bit101LoginFlowParams = {
      sid: username,
      password: params.password,
      captcha: params.captcha,
    };

    const bit101 = await this.deps.loginBit101AndVerifyWebvpn(normalized);
    const bit101Ok = bit101.ok;

    const created = await this.deps.createBitSsoSessionAuto();
    const mode = created.mode;
    const sso = created.sso;

    await sso.loginToLexue(username, params.password);
    const schoolOk = sso.isFullyLoggedIn();

    if (mode === 'webvpn') {
      const webvpnCookie = sso.getCookieHeaderFor(LOGIN_WEBVPN_PORTAL_URL) ?? '';
      if (webvpnCookie) {
        await this.deps.saveWebvpnCookie(webvpnCookie);
        this.logger.info('已写入 WebVPN cookie 到 TokenStore');
      } else {
        this.logger.warn('WebVPN 模式下未取到 cookie header');
      }
    }

    try {
      await this.deps.prepareFreeClassroomSession(username, params.password, mode);
      this.logger.info('空教室教务 session 已准备 mode=', mode);
    } catch (freeRoomErr) {
      this.logger.warn('空教室教务 session 准备失败，不阻断登录:', freeRoomErr);
    }

    let syncedCalendarCount = 0;
    if (bit101Ok && schoolOk) {
      try {
        syncedCalendarCount = await this.deps.syncUserCalendar(username, mode, sso);
        this.logger.info('日历同步完成，共', syncedCalendarCount, '条数据');
      } catch (syncErr) {
        this.logger.error('日历同步失败详情:', syncErr);
      }
      await this.deps.saveUsername(username);
    }

    return {
      ok: bit101Ok && schoolOk,
      bit101Ok,
      schoolOk,
      mode,
      sso,
      bit101,
      syncedCalendarCount,
    };
  }
}
