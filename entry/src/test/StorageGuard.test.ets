import { describe, it, expect } from '@ohos/hypium';
import { guardAsyncStorage, guardAsyncStorageOrDefault } from '../main/ets/services/storage/storageGuard';

export default function storageGuardTest() {
  describe('storage guard', () => {
    it('returns async result when storage operation succeeds', 0, async (done: () => void) => {
      const value = await guardAsyncStorage('token get', async () => 'ok');
      expect(value).assertEqual('ok');
      done();
    });

    it('wraps async storage failure with operation name', 0, async (done: () => void) => {
      let message = '';
      try {
        await guardAsyncStorage('token get', async () => {
          throw new Error('boom');
        });
      } catch (e) {
        message = String(e);
      }
      expect(message).assertContain('token get failed');
      expect(message).assertContain('boom');
      done();
    });

    it('returns default value when guarded read fails', 0, async (done: () => void) => {
      const value = await guardAsyncStorageOrDefault('token fallback', async () => {
        throw new Error('boom');
      }, 'fallback');
      expect(value).assertEqual('fallback');
      done();
    });
  });
}
