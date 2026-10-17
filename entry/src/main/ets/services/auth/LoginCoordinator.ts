import type { CookieDump } from '../../core/network/cookieJar';
import { ApiError } from '../../core/network/httpClient';
import { Logger } from '../../utils/Logger';
import { AuthRepository, VerifyResult } from './authRepository';
import {
  Bit101LoginFlowParams,
  Bit101LoginFlowResult,
  loginBit101AndVerifyWebvpn,
} from './bit101LoginFlow';
import { AuthFlowError, classifyAuthFailure, toAuthFlowError } from './AuthFailure';
import {
  BitSsoLoginMode,
  createBitSsoSessionAuto,
} from '../lexue/BitSsoAuto';
import BitSsoSession from '../lexue/BitSsoSession';
import { syncUserCalendar } from '../lexue/CalendarService';
import { LoginSessionState, TokenStore } from '../storage/tokenStore';
import { LexueCookieStore } from '../storage/LexueCookieStore';
import { prepareFreeClassroomSession } from '../jw/freeClassroomSession';
import {
  globalSmsChallengeCoordinator,
  SmsCodeHandler,
} from './SmsChallengeCoordinator';

export const LOGIN_WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
export const LOGIN_WEBVPN_PORTAL_URL = 'https://webvpn.bit.edu.cn/';
export const LOGIN_INNER_LEXUE_BASE = 'https://lexue.bit.edu.cn';

export interface LoginCoordinatorSso {
  loginToLexue(username: string, password: string): Promise<void>;
  isFullyLoggedIn(): boolean;
  getCookieHeaderFor(url: string): string | undefined;
  getCookieDump(): CookieDump;
}

export interface LoginCoordinatorStage {
  username: string;
  mode: BitSsoLoginMode;
  fakeCookie: string;
  webvpnCookie: string;
  lexueCookieDump: CookieDump;
  bit101: Bit101LoginFlowResult;
}

export interface LoginCoordinatorDeps {
  loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult>;
  createBitSsoSessionAuto(): Promise<LoginCoordinatorSsoCreateResult>;
  commitCoreSession(stage: LoginCoordinatorStage): Promise<void>;
  prepareFreeClassroomSession(
    username: string,
    password: string,
    mode: BitSsoLoginMode,
  ): Promise<void>;
  syncUserCalendar(
    username: string,
    mode: BitSsoLoginMode,
    sso: LoginCoordinatorSso,
  ): Promise<number>;
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

function asError(error: Object): Error {
  return error instanceof Error ? error : new Error(String(error));
}

function verificationFailure(verify: VerifyResult): AuthFlowError {
  const apiError = new ApiError(
    'BIT101 WebVPN verification failed',
    verify.status,
    typeof verify.body === 'string' ? verify.body : JSON.stringify(verify.body),
  );
  return new AuthFlowError(classifyAuthFailure(apiError), apiError.message, apiError);
}

class DefaultLoginCoordinatorDeps implements LoginCoordinatorDeps {
  private readonly auth: AuthRepository;
  private readonly tokenStore: TokenStore;
  private readonly debug: boolean;
  private readonly logger: Logger = new Logger('LoginCoordinator');
  private readonly smsCodeHandler: SmsCodeHandler;

  constructor(
    auth: AuthRepository,
    tokenStore: TokenStore,
    debug: boolean,
    smsCodeHandler: SmsCodeHandler,
  ) {
    this.auth = auth;
    this.tokenStore = tokenStore;
    this.debug = debug;
    this.smsCodeHandler = smsCodeHandler;
  }

  async loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult> {
    return await loginBit101AndVerifyWebvpn(this.auth, params, false);
  }

  async createBitSsoSessionAuto(): Promise<LoginCoordinatorSsoCreateResult> {
    return await createBitSsoSessionAuto({
      debug: this.debug,
      webvpnLexueBase: LOGIN_WEBVPN_LEXUE_BASE,
      persistCookies: false,
      smsCodeHandler: this.smsCodeHandler,
    });
  }

  async commitCoreSession(stage: LoginCoordinatorStage): Promise<void> {
    const previousTokens: LoginSessionState = await this.tokenStore.getLoginSessionState();
    const lexueStore = new LexueCookieStore(stage.mode);
    const previousLexue: CookieDump | null = await lexueStore.loadCookieDump();
    const nextTokens: LoginSessionState = this.buildTokenState(stage);

    try {
      await lexueStore.replaceCookieDump(stage.lexueCookieDump);
      await this.tokenStore.replaceLoginSession(nextTokens);
    } catch (error) {
      try {
        await lexueStore.replaceCookieDump(previousLexue);
        await this.tokenStore.replaceLoginSession(previousTokens);
      } catch (rollbackError) {
        this.logger.error('Core login rollback failed', rollbackError);
      }
      throw error;
    }
  }

  async prepareFreeClassroomSession(
    username: string,
    password: string,
    mode: BitSsoLoginMode,
  ): Promise<void> {
    await prepareFreeClassroomSession(username, password, mode, this.debug);
  }

  async syncUserCalendar(
    username: string,
    mode: BitSsoLoginMode,
    sso: LoginCoordinatorSso,
  ): Promise<number> {
    const baseUrl = mode === 'inner' ? LOGIN_INNER_LEXUE_BASE : LOGIN_WEBVPN_LEXUE_BASE;
    return await syncUserCalendar({
      sso: sso as BitSsoSession,
      username,
      webvpnLexueBase: baseUrl,
    });
  }

  private buildTokenState(stage: LoginCoordinatorStage): LoginSessionState {
    const verifyBody = stage.bit101.webvpn.body;
    let accessToken: string | null = null;
    let userInfo: Object | null = null;

    if (typeof verifyBody === 'object' && verifyBody !== null) {
      const body = verifyBody as Record<string, Object>;
      const nested = body['data'] as Record<string, Object> | undefined;
      const tokenValue: Object | undefined = body['token'] ?? nested?.['token'];
      const userValue: Object | undefined = body['user'] ?? nested?.['user'];
      if (tokenValue !== undefined && tokenValue !== null) {
        accessToken = String(tokenValue);
      }
      if (userValue !== undefined && userValue !== null && typeof userValue === 'object') {
        userInfo = userValue;
      }
    }

    return {
      accessToken,
      userInfo,
      username: stage.username,
      fakeCookie: stage.fakeCookie,
      webvpnCookie: stage.webvpnCookie.length > 0 ? stage.webvpnCookie : null,
    };
  }
}

export class LoginCoordinator {
  private readonly deps: LoginCoordinatorDeps;
  private readonly logger: Logger = new Logger('LoginCoordinator');
  private inFlight: Promise<LoginCoordinatorResult> | null = null;

  constructor(deps?: LoginCoordinatorDeps, allowInteractive: boolean = true) {
    this.deps = deps ?? new DefaultLoginCoordinatorDeps(
      new AuthRepository(),
      new TokenStore(),
      false,
      globalSmsChallengeCoordinator.createHandler({
        allowInteractive,
        timeoutMs: 120000,
      }),
    );
  }

  async login(params: LoginCoordinatorParams): Promise<LoginCoordinatorResult> {
    if (this.inFlight !== null) {
      return await this.inFlight;
    }
    const operation: Promise<LoginCoordinatorResult> = this.performLogin(params);
    this.inFlight = operation;
    try {
      return await operation;
    } finally {
      if (this.inFlight === operation) {
        this.inFlight = null;
      }
    }
  }

  private async performLogin(params: LoginCoordinatorParams): Promise<LoginCoordinatorResult> {
    const username: string = params.sid.trim();
    if (username.length === 0 || params.password.length === 0) {
      throw new AuthFlowError('invalid_credentials', '请输入学号和密码');
    }
    const normalized: Bit101LoginFlowParams = {
      sid: username,
      password: params.password,
      captcha: params.captcha,
    };

    let bit101: Bit101LoginFlowResult;
    let created: LoginCoordinatorSsoCreateResult;
    try {
      bit101 = await this.deps.loginBit101AndVerifyWebvpn(normalized);
      if (!bit101.ok || bit101.fakeCookie.length === 0) {
        throw verificationFailure(bit101.webvpn);
      }

      created = await this.deps.createBitSsoSessionAuto();
      await created.sso.loginToLexue(username, params.password);
      if (!created.sso.isFullyLoggedIn()) {
        throw new AuthFlowError('invalid_credentials', '学校登录未建立可用会话');
      }

      let webvpnCookie: string = bit101.webvpn.sessionCookie ?? '';
      if (created.mode === 'webvpn') {
        webvpnCookie = created.sso.getCookieHeaderFor(LOGIN_WEBVPN_PORTAL_URL) ?? '';
        if (webvpnCookie.length === 0) {
          throw new AuthFlowError('server_transient', 'WebVPN 登录成功但未返回会话 Cookie');
        }
      }

      const stage: LoginCoordinatorStage = {
        username,
        mode: created.mode,
        fakeCookie: bit101.fakeCookie,
        webvpnCookie,
        lexueCookieDump: created.sso.getCookieDump(),
        bit101,
      };
      await this.deps.commitCoreSession(stage);
    } catch (error) {
      throw toAuthFlowError(asError(error as Object));
    }

    try {
      await this.deps.prepareFreeClassroomSession(username, params.password, created.mode);
      this.logger.info('JXZX session prepared, mode=', created.mode);
    } catch (error) {
      this.logger.warn('JXZX warmup failed without blocking core login', error);
    }

    let syncedCalendarCount: number = 0;
    try {
      syncedCalendarCount = await this.deps.syncUserCalendar(username, created.mode, created.sso);
      this.logger.info('Calendar sync completed, count=', syncedCalendarCount);
    } catch (error) {
      this.logger.warn('Calendar sync failed without blocking core login', error);
    }

    return {
      ok: true,
      bit101Ok: true,
      schoolOk: true,
      mode: created.mode,
      sso: created.sso,
      bit101,
      syncedCalendarCount,
    };
  }
}
