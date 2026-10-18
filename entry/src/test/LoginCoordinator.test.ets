import { describe, it, expect } from '@ohos/hypium';
import type { CookieDump } from '../main/ets/core/network/cookieJar';
import {
  LoginCoordinator,
  LoginCoordinatorDeps,
  LoginCoordinatorSso,
  LoginCoordinatorSsoCreateResult,
  LoginCoordinatorStage,
} from '../main/ets/services/auth/LoginCoordinator';
import {
  Bit101LoginFlowParams,
  Bit101LoginFlowResult,
} from '../main/ets/services/auth/bit101LoginFlow';
import { AuthFlowError, AuthFailureKind } from '../main/ets/services/auth/AuthFailure';
import { VerifyResult } from '../main/ets/services/auth/authRepository';
import { BitSsoLoginMode } from '../main/ets/services/lexue/BitSsoAuto';
import { SmsChallengeCoordinator, SmsCodeHandler } from '../main/ets/services/auth/SmsChallengeCoordinator';

class FakeSso implements LoginCoordinatorSso {
  readonly calls: string[];
  ready: boolean = true;
  loginError: AuthFlowError | null = null;
  smsHandler: SmsCodeHandler | null = null;

  constructor(calls: string[]) {
    this.calls = calls;
  }

  async loginToLexue(username: string, password: string): Promise<void> {
    this.calls.push('sso.loginToLexue:' + username + ':' + password);
    if (this.smsHandler) {
      const code = await this.smsHandler({ phone: '13800000000', maskedPhone: '138****0000', purpose: 'password_second_factor' });
      if (code !== '123456') throw new AuthFlowError('sms_required', '短信验证码错误，请重试');
    }
    if (this.loginError) {
      throw this.loginError;
    }
  }

  isFullyLoggedIn(): boolean {
    this.calls.push('sso.isFullyLoggedIn');
    return this.ready;
  }

  getCookieHeaderFor(url: string): string | undefined {
    this.calls.push('sso.getCookieHeaderFor:' + url);
    return 'webvpn-cookie=ok';
  }

  getCookieDump(): CookieDump {
    this.calls.push('sso.getCookieDump');
    return [];
  }
}

class FakeDeps implements LoginCoordinatorDeps {
  readonly calls: string[] = [];
  readonly sso: FakeSso = new FakeSso(this.calls);
  bit101Error: AuthFlowError | null = null;
  freeClassroomError: Error | null = null;
  calendarError: Error | null = null;
  loginDelayMs: number = 0;
  commitCount: number = 0;

  async loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult> {
    this.calls.push('bit101:' + params.sid + ':' + params.password + ':' + (params.captcha ?? ''));
    if (this.loginDelayMs > 0) {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, this.loginDelayMs));
    }
    if (this.bit101Error) {
      throw this.bit101Error;
    }
    const webvpn: VerifyResult = {
      ok: true,
      status: 200,
      body: '',
      sessionCookie: 'verify-cookie=ok',
    };
    return {
      fakeCookie: 'fake-cookie',
      webvpn,
      ok: true,
    };
  }

  async createBitSsoSessionAuto(): Promise<LoginCoordinatorSsoCreateResult> {
    this.calls.push('createSso');
    return {
      mode: 'webvpn' as BitSsoLoginMode,
      sso: this.sso,
    };
  }

  async commitCoreSession(stage: LoginCoordinatorStage): Promise<void> {
    this.commitCount += 1;
    this.calls.push(
      'commit:' + stage.username + ':' + stage.mode + ':' +
        stage.fakeCookie + ':' + stage.webvpnCookie,
    );
  }

  async prepareFreeClassroomSession(
    username: string,
    password: string,
    mode: BitSsoLoginMode,
  ): Promise<void> {
    this.calls.push('freeClassroom:' + username + ':' + password + ':' + mode);
    if (this.freeClassroomError) {
      throw this.freeClassroomError;
    }
  }

  async syncUserCalendar(
    username: string,
    mode: BitSsoLoginMode,
    sso: LoginCoordinatorSso,
  ): Promise<number> {
    this.calls.push('syncCalendar:' + username + ':' + mode + ':' + (sso === this.sso));
    if (this.calendarError) {
      throw this.calendarError;
    }
    return 3;
  }
}

async function captureFailureKind(action: () => Promise<void>): Promise<AuthFailureKind | null> {
  try {
    await action();
  } catch (error) {
    if (error instanceof AuthFlowError) {
      return error.kind;
    }
  }
  return null;
}

export default function loginCoordinatorTest() {
  describe('LoginCoordinator', () => {
    it('cancels an SMS login without committing any domain or starting optional work', 0, async () => {
      const deps = new FakeDeps();
      const sms = new SmsChallengeCoordinator();
      deps.sso.smsHandler = sms.createHandler({ timeoutMs: 0 });
      const stop = sms.subscribe(pending => { if (pending) sms.cancel(pending.id); });
      try {
        const kind = await captureFailureKind(async () => {
          await new LoginCoordinator(deps).login({ sid: 'fixture', password: 'fixture' });
        });
        expect(kind).assertEqual('interaction_cancelled');
        expect(deps.commitCount).assertEqual(0);
        expect(deps.calls.some(call => call.startsWith('freeClassroom:') || call.startsWith('syncCalendar:'))).assertFalse();
        expect(sms.getPending()).assertNull();
      } finally { stop(); }
    });

    it('reports an incorrect SMS code and safely retries with a new challenge', 0, async () => {
      const deps = new FakeDeps();
      const sms = new SmsChallengeCoordinator();
      deps.sso.smsHandler = sms.createHandler({ timeoutMs: 0 });
      let code = '000000';
      const stop = sms.subscribe(pending => { if (pending) sms.submit(pending.id, code); });
      const coordinator = new LoginCoordinator(deps);
      try {
        const kind = await captureFailureKind(async () => {
          await coordinator.login({ sid: 'fixture', password: 'fixture' });
        });
        expect(kind).assertEqual('sms_required');
        expect(deps.commitCount).assertEqual(0);
        code = '123456';
        expect((await coordinator.login({ sid: 'fixture', password: 'fixture' })).ok).assertTrue();
        expect(deps.commitCount).assertEqual(1);
        expect(sms.getPending()).assertNull();
      } finally { stop(); }
    });
    it('commits staged BIT101 and school state once before optional post-login work', 0, async () => {
      const deps = new FakeDeps();
      const coordinator = new LoginCoordinator(deps);

      const result = await coordinator.login({
        sid: ' 1120230036 ',
        password: 'pw',
        captcha: 'captcha-code',
      });

      expect(result.ok).assertTrue();
      expect(result.syncedCalendarCount).assertEqual(3);
      expect(deps.commitCount).assertEqual(1);
      expect(deps.calls.join('|')).assertEqual(
        'bit101:1120230036:pw:captcha-code|' +
          'createSso|' +
          'sso.loginToLexue:1120230036:pw|' +
          'sso.isFullyLoggedIn|' +
          'sso.getCookieHeaderFor:https://webvpn.bit.edu.cn/|' +
          'sso.getCookieDump|' +
          'commit:1120230036:webvpn:fake-cookie:webvpn-cookie=ok|' +
          'freeClassroom:1120230036:pw:webvpn|' +
          'syncCalendar:1120230036:webvpn:true',
      );
    });

    it('does not create or commit school state when BIT101 login fails', 0, async () => {
      const deps = new FakeDeps();
      deps.bit101Error = new AuthFlowError('invalid_credentials', '账号或密码错误');
      const coordinator = new LoginCoordinator(deps);

      const kind: AuthFailureKind | null = await captureFailureKind(async (): Promise<void> => {
        await coordinator.login({ sid: '1120230036', password: 'bad' });
      });

      expect(kind).assertEqual('invalid_credentials');
      expect(deps.commitCount).assertEqual(0);
      expect(deps.calls.join('|')).assertEqual('bit101:1120230036:bad:');
    });

    it('does not commit BIT101 staging when school login fails', 0, async () => {
      const deps = new FakeDeps();
      deps.sso.loginError = new AuthFlowError('network_transient', 'network unavailable');
      const coordinator = new LoginCoordinator(deps);

      const kind: AuthFailureKind | null = await captureFailureKind(async (): Promise<void> => {
        await coordinator.login({ sid: '1120230036', password: 'pw' });
      });

      expect(kind).assertEqual('network_transient');
      expect(deps.commitCount).assertEqual(0);
      expect(deps.calls.join('|')).assertEqual(
        'bit101:1120230036:pw:|createSso|sso.loginToLexue:1120230036:pw',
      );
    });

    it('keeps core login committed when JXZX warmup fails', 0, async () => {
      const deps = new FakeDeps();
      deps.freeClassroomError = new Error('JXZX unavailable');
      const coordinator = new LoginCoordinator(deps);

      const result = await coordinator.login({ sid: '1120230036', password: 'pw' });

      expect(result.ok).assertTrue();
      expect(deps.commitCount).assertEqual(1);
      expect(result.syncedCalendarCount).assertEqual(3);
    });

    it('keeps core login committed when calendar sync fails', 0, async () => {
      const deps = new FakeDeps();
      deps.calendarError = new Error('calendar unavailable');
      const coordinator = new LoginCoordinator(deps);

      const result = await coordinator.login({ sid: '1120230036', password: 'pw' });

      expect(result.ok).assertTrue();
      expect(deps.commitCount).assertEqual(1);
      expect(result.syncedCalendarCount).assertEqual(0);
    });

    it('shares one in-flight login across concurrent callers', 0, async () => {
      const deps = new FakeDeps();
      deps.loginDelayMs = 10;
      const coordinator = new LoginCoordinator(deps);

      const first = coordinator.login({ sid: '1120230036', password: 'pw' });
      const second = coordinator.login({ sid: '1120230036', password: 'pw' });
      const results = await Promise.all([first, second]);

      expect(results[0].ok).assertTrue();
      expect(results[1].ok).assertTrue();
      expect(deps.commitCount).assertEqual(1);
      expect(deps.calls.filter((item: string): boolean => item.startsWith('bit101:')).length).assertEqual(1);
    });
  });
}
