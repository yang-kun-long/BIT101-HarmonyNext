import { describe, it, expect } from '@ohos/hypium';
import {
  Bit101LoginFlowAuth,
  Bit101LoginFlowParams,
  loginBit101AndVerifyWebvpn,
} from '../main/ets/services/auth/bit101LoginFlow';
import { AuthHttpSource, AuthRepository, VerifyResult } from '../main/ets/services/auth/authRepository';
import { HttpRequest, HttpResponse } from '../main/ets/core/network/httpClient';

class AuthHttpFixture implements AuthHttpSource {
  calls: HttpRequest[] = [];
  response: string = '{"fake_cookie":"fixture-session"}';

  async request<T>(req: HttpRequest): Promise<HttpResponse<T>> {
    this.calls.push(req);
    return { status: 200, headers: {}, text: this.response, data: JSON.parse(this.response) as T };
  }
}

class FakeAuth implements Bit101LoginFlowAuth {
  readonly calls: string[] = [];
  webvpnOk: boolean = true;

  async loginBit101(params: Bit101LoginFlowParams): Promise<string> {
    this.calls.push(`loginBit101:${params.sid}:${params.password}`);
    return 'fake-cookie';
  }

  async loginViaWebVpnVerify(params: Bit101LoginFlowParams): Promise<VerifyResult> {
    this.calls.push(`loginViaWebVpnVerify:${params.sid}:${params.password}:${params.captcha ?? ''}`);
    return {
      ok: this.webvpnOk,
      status: this.webvpnOk ? 200 : 500,
      body: '',
    };
  }

  async loginBit101Staged(params: Bit101LoginFlowParams): Promise<string> {
    this.calls.push(`loginBit101Staged:${params.sid}:${params.password}`);
    return 'staged-fake-cookie';
  }

  async loginViaWebVpnVerifyStaged(params: Bit101LoginFlowParams): Promise<VerifyResult> {
    this.calls.push(`loginViaWebVpnVerifyStaged:${params.sid}:${params.password}:${params.captcha ?? ''}`);
    return {
      ok: this.webvpnOk,
      status: this.webvpnOk ? 200 : 500,
      body: '',
      sessionCookie: 'staged-cookie',
    };
  }

  async registerBit101(params: Bit101LoginFlowParams, verify: VerifyResult): Promise<string> {
    this.calls.push('registerBit101:' + params.password);
    return 'fake-cookie';
  }

  async registerBit101Staged(params: Bit101LoginFlowParams, verify: VerifyResult): Promise<string> {
    this.calls.push('registerBit101Staged:' + params.password);
    return 'staged-fake-cookie';
  }
}

export default function bit101LoginFlowTest() {
  describe('BIT101 login flow', () => {
    it('exchanges verification token and code with loginMode without persisting staged cookies', 0, async () => {
      const http = new AuthHttpFixture();
      const auth = new AuthRepository({ http });
      const verify: VerifyResult = { ok: true, status: 200, body: { token: 'fixture-token', code: '123456' } };
      expect(await auth.registerBit101Staged({ password: 'pw' }, verify)).assertEqual('fixture-session');
      expect(http.calls.length).assertEqual(1);
      expect(http.calls[0].url).assertEqual('/user/register');
      expect(http.calls[0].method).assertEqual('POST');
      const body = http.calls[0].json as Record<string, Object>;
      expect(body['password']).assertEqual('8fe4c11451281c094a6578e6ddbf5eed');
      expect(body['token']).assertEqual('fixture-token');
      expect(body['code']).assertEqual('123456');
      expect(body['loginMode']).assertTrue();
    });

    it('rejects missing verification fields before sending register and malformed fake cookies', 0, async () => {
      const http = new AuthHttpFixture();
      const auth = new AuthRepository({ http });
      const verify: VerifyResult = { ok: true, status: 200, body: { token: 'fixture-token' } };
      let failed = false;
      try { await auth.registerBit101Staged({ password: 'pw' }, verify); } catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect(http.calls.length).assertEqual(0);
      verify.body = { token: 'fixture-token', code: '123456' };
      for (const response of ['{}', '{"fake_cookie":{}}', '{"fake_cookie":" "}']) {
        http.response = response;
        failed = false;
        try { await auth.registerBit101Staged({ password: 'pw' }, verify); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
    });

    it('exchanges a successful WebVPN verification for a BIT101 fake cookie', 0, async () => {
      const auth = new FakeAuth();

      const result = await loginBit101AndVerifyWebvpn(auth, {
        sid: ' 1120230036 ',
        password: 'pw',
        captcha: 'captcha-code',
      });

      expect(result.ok).assertTrue();
      expect(result.fakeCookie).assertEqual('fake-cookie');
      expect(auth.calls.join('|')).assertEqual(
        'loginViaWebVpnVerify:1120230036:pw:captcha-code|registerBit101:pw',
      );
    });

    it('does not register a BIT101 session when WebVPN verification fails', 0, async () => {
      const auth = new FakeAuth();
      auth.webvpnOk = false;

      const result = await loginBit101AndVerifyWebvpn(auth, {
        sid: '1120230036',
        password: 'pw',
      });

      expect(result.ok).assertFalse();
      expect(result.fakeCookie).assertEqual('');
      expect(auth.calls.join('|')).assertEqual('loginViaWebVpnVerify:1120230036:pw:');
    });

    it('keeps staged login results in memory when persistence is disabled', 0, async () => {
      const auth = new FakeAuth();

      const result = await loginBit101AndVerifyWebvpn(auth, {
        sid: '1120230036',
        password: 'pw',
      }, false);

      expect(result.fakeCookie).assertEqual('staged-fake-cookie');
      expect(result.webvpn.sessionCookie).assertEqual('staged-cookie');
      expect(auth.calls.join('|')).assertEqual(
        'loginViaWebVpnVerifyStaged:1120230036:pw:|registerBit101Staged:pw',
      );
    });
  });
}
