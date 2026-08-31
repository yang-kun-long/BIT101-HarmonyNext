import { describe, it, expect } from '@ohos/hypium';
import {
  buildWebSessionInjectionScript,
  isAllowedInWebView,
  shouldInjectBit101Session,
  WebSessionModel,
  WebSessionState,
  WebSessionStore,
} from '../main/ets/components/web/WebSessionModel';

class FakeWebSessionStore implements WebSessionStore {
  fakeCookieCalls: number = 0;
  usernameCalls: number = 0;
  fakeCookie: string | null = 'cookie-from-token-store';
  username: string | null = '3220240001';

  async getFakeCookie(): Promise<string | null> {
    this.fakeCookieCalls += 1;
    return this.fakeCookie;
  }

  async getUsername(): Promise<string | null> {
    this.usernameCalls += 1;
    return this.username;
  }
}

export default function webSessionModelTest() {
  describe('Web session model', () => {
    it('loads BIT101 session only through the injected TokenStore contract', 0, async () => {
      const store = new FakeWebSessionStore();
      const model = new WebSessionModel(store);

      const state: WebSessionState = await model.load();

      expect(state.fakeCookie).assertEqual('cookie-from-token-store');
      expect(state.username).assertEqual('3220240001');
      expect(state.credentialState).assertEqual('unavailable');
      expect(store.fakeCookieCalls).assertEqual(1);
      expect(store.usernameCalls).assertEqual(1);
    });

    it('serializes special characters as JSON data instead of direct JavaScript string interpolation', 0, () => {
      const dangerousCookie: string = 'cookie\";window.compromised=true;\\n\\\\tail';
      const state: WebSessionState = {
        fakeCookie: dangerousCookie,
        username: 'sid\";window.sidLeak=true',
        credentialState: 'unavailable',
      };

      const script: string = buildWebSessionInjectionScript(state, 'dark');

      expect(script.indexOf(JSON.stringify(dangerousCookie)) >= 0).assertTrue();
      expect(script.indexOf(dangerousCookie)).assertEqual(-1);
      expect(script.indexOf(state.username)).assertEqual(-1);
      expect(script.indexOf('password')).assertEqual(-1);
    });

    it('removes stale fake_cookie from localStorage after logout', 0, () => {
      const state: WebSessionState = {
        fakeCookie: '',
        username: '',
        credentialState: 'unavailable',
      };

      const script: string = buildWebSessionInjectionScript(state, 'light');

      expect(script).assertContain('delete store.fake_cookie');
    });

    it('accepts trusted BIT hosts without substring bypasses', 0, () => {
      expect(isAllowedInWebView('https://bit101.cn/post/1', 'https://bit101.cn', false)).assertTrue();
      expect(isAllowedInWebView('https://webvpn.bit.edu.cn/', 'https://bit101.cn', false)).assertTrue();
      expect(isAllowedInWebView('https://evil.example/?next=bit101.cn', 'https://bit101.cn', false)).assertFalse();
      expect(isAllowedInWebView('https://bit101.cn.evil.example/', 'https://bit101.cn', false)).assertFalse();
    });

    it('allows a generic browser initial origin but does not leak BIT101 session into it', 0, () => {
      expect(isAllowedInWebView('https://docs.example.com/next', 'https://docs.example.com/start', true)).assertTrue();
      expect(isAllowedInWebView('https://other.example.com/', 'https://docs.example.com/start', true)).assertFalse();
      expect(shouldInjectBit101Session('https://docs.example.com/start')).assertFalse();
      expect(shouldInjectBit101Session('https://bit101.cn/')).assertTrue();
    });
  });
}
