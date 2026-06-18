import { describe, it, expect } from '@ohos/hypium';
import {
  LoginCoordinator,
  LoginCoordinatorDeps,
  LoginCoordinatorSso,
  LoginCoordinatorSsoCreateResult,
} from '../main/ets/services/auth/LoginCoordinator';
import {
  Bit101LoginFlowParams,
  Bit101LoginFlowResult,
} from '../main/ets/services/auth/bit101LoginFlow';
import { VerifyResult } from '../main/ets/services/auth/authRepository';
import { BitSsoLoginMode } from '../main/ets/services/lexue/BitSsoAuto';

class FakeSso implements LoginCoordinatorSso {
  readonly calls: string[];
  private readonly ready: boolean;

  constructor(calls: string[], ready: boolean) {
    this.calls = calls;
    this.ready = ready;
  }

  async loginToLexue(username: string, password: string): Promise<void> {
    this.calls.push(`sso.loginToLexue:${username}:${password}`);
  }

  isFullyLoggedIn(): boolean {
    this.calls.push('sso.isFullyLoggedIn');
    return this.ready;
  }

  getCookieHeaderFor(url: string): string | undefined {
    this.calls.push(`sso.getCookieHeaderFor:${url}`);
    return 'webvpn-cookie=ok';
  }
}

class FakeDeps implements LoginCoordinatorDeps {
  readonly calls: string[] = [];
  readonly sso: FakeSso;

  constructor(schoolReady: boolean = true) {
    this.sso = new FakeSso(this.calls, schoolReady);
  }

  async loginBit101AndVerifyWebvpn(params: Bit101LoginFlowParams): Promise<Bit101LoginFlowResult> {
    this.calls.push(`bit101:${params.sid}:${params.password}:${params.captcha ?? ''}`);
    const webvpn: VerifyResult = {
      ok: true,
      status: 200,
      body: '',
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

  async saveWebvpnCookie(cookie: string): Promise<void> {
    this.calls.push(`saveWebvpnCookie:${cookie}`);
  }

  async prepareFreeClassroomSession(username: string, password: string, mode: BitSsoLoginMode): Promise<void> {
    this.calls.push(`freeClassroom:${username}:${password}:${mode}`);
  }

  async syncUserCalendar(username: string, mode: BitSsoLoginMode, sso: LoginCoordinatorSso): Promise<number> {
    this.calls.push(`syncCalendar:${username}:${mode}:${sso === this.sso}`);
    return 3;
  }

  async saveUsername(username: string): Promise<void> {
    this.calls.push(`saveUsername:${username}`);
  }
}

export default function loginCoordinatorTest() {
  describe('LoginCoordinator', () => {
    it('keeps page orchestration out of UI by running login, persistence and post-login sync in order', 0, async () => {
      const deps = new FakeDeps();
      const coordinator = new LoginCoordinator(deps);

      const result = await coordinator.login({
        sid: ' 1120230036 ',
        password: 'pw',
        captcha: 'captcha-code',
      });

      expect(result.ok).assertTrue();
      expect(result.mode).assertEqual('webvpn');
      expect(result.syncedCalendarCount).assertEqual(3);
      expect(deps.calls.join('|')).assertEqual(
        'bit101:1120230036:pw:captcha-code|' +
          'createSso|' +
          'sso.loginToLexue:1120230036:pw|' +
          'sso.isFullyLoggedIn|' +
          'sso.getCookieHeaderFor:https://webvpn.bit.edu.cn/|' +
          'saveWebvpnCookie:webvpn-cookie=ok|' +
          'freeClassroom:1120230036:pw:webvpn|' +
          'syncCalendar:1120230036:webvpn:true|' +
          'saveUsername:1120230036',
      );
    });
  });
}
