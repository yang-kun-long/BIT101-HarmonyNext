import { describe, it, expect } from '@ohos/hypium';
import {
  Bit101LoginFlowAuth,
  Bit101LoginFlowParams,
  loginBit101AndVerifyWebvpn,
} from '../main/ets/services/auth/bit101LoginFlow';
import { VerifyResult } from '../main/ets/services/auth/authRepository';

class FakeAuth implements Bit101LoginFlowAuth {
  readonly calls: string[] = [];

  async loginBit101(params: Bit101LoginFlowParams): Promise<string> {
    this.calls.push(`loginBit101:${params.sid}:${params.password}`);
    return 'fake-cookie';
  }

  async loginViaWebVpnVerify(params: Bit101LoginFlowParams): Promise<VerifyResult> {
    this.calls.push(`loginViaWebVpnVerify:${params.sid}:${params.password}:${params.captcha ?? ''}`);
    return {
      ok: true,
      status: 200,
      body: '',
    };
  }
}

export default function bit101LoginFlowTest() {
  describe('BIT101 login flow', () => {
    it('runs webvpn verify after BIT101 login so schedule cookie is persisted by AuthRepository', 0, async () => {
      const auth = new FakeAuth();

      const result = await loginBit101AndVerifyWebvpn(auth, {
        sid: ' 1120230036 ',
        password: 'pw',
        captcha: 'captcha-code',
      });

      expect(result.ok).assertTrue();
      expect(result.fakeCookie).assertEqual('fake-cookie');
      expect(auth.calls.join('|')).assertEqual(
        'loginBit101:1120230036:pw|loginViaWebVpnVerify:1120230036:pw:captcha-code',
      );
    });
  });
}
