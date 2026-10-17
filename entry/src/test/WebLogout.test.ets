import { describe, it, expect } from '@ohos/hypium';
import { clearWebLoginData, observeWebLogout, webSessionRevision } from '../main/ets/services/auth/WebLogout';

export default function webLogoutTest() {
  describe('Web logout', () => {
    it('invalidates old page sessions and waits for live pages', 0, async () => {
      const before = webSessionRevision(); let calls = 0;
      const stop = observeWebLogout(async () => { calls++; expect(webSessionRevision() > before).assertTrue(); });
      await clearWebLoginData(); expect(calls).assertEqual(1);
      stop(); await clearWebLoginData(); expect(calls).assertEqual(1);
    });
    it('attempts every page even when one fails and reports failure', 0, async () => {
      let calls = 0;
      const stopFail = observeWebLogout(async () => { throw new Error('page failed'); });
      const stopOther = observeWebLogout(async () => { calls++; });
      let failed = false;
      try { await clearWebLoginData(); } catch (_) { failed = true; }
      finally { stopFail(); stopOther(); }
      expect(failed).assertTrue(); expect(calls).assertEqual(1);
    });
  });
}
