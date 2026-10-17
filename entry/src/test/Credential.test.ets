import { describe, it, expect } from '@ohos/hypium';
import { AuthFlowError } from '../main/ets/services/auth/AuthFailure';
import { CredentialStore, SavedCredentials, RefreshLogin, LoginRefreshCoordinator, retryAfterLoginRefresh } from '../main/ets/services/auth/LoginRefreshCoordinator';
import { HuksCredentialCipher } from '../main/ets/services/storage/HuksCredentialCipher';
import { CredentialBackend, CredentialCipher, CredentialCodec, SecureCredentialStore } from '../main/ets/services/storage/SecureCredentialStore';
import { util } from '@kit.ArkTS';
import { applyLoginCredentialChoice } from '../main/ets/services/auth/LoginCredentialPolicy';
class Backend implements CredentialBackend {
  value: string = '';
  async read(): Promise<string> { return this.value; }
  async write(value: string): Promise<void> { this.value = value; }
  async remove(): Promise<void> { this.value = ''; }
}
class Cipher implements CredentialCipher {
  bytes: Uint8Array = new Uint8Array();
  async encrypt(value: Uint8Array): Promise<string> { this.bytes = value.slice(); return 'encrypted'; }
  async decrypt(value: string): Promise<Uint8Array> { return this.bytes.slice(); }
}
class Codec implements CredentialCodec {
  encode(value: string): Uint8Array { return new Uint8Array(value.split('').map(char => char.charCodeAt(0))); }
  decode(value: Uint8Array): string { let result = ''; for (const byte of value) result += String.fromCharCode(byte); return result; }
}
class Credentials implements CredentialStore {
  present: boolean = true; clears: number = 0;
  async save(value: SavedCredentials): Promise<void> {}
  async get(): Promise<SavedCredentials | null> { return this.present ? { username: 'fixture', password: 'fixture' } : null; }
  async clear(): Promise<void> { this.clears++; this.present = false; }
}
class Login implements RefreshLogin {
  failure: AuthFlowError | null = null; calls: number = 0; pending: Promise<void> | null = null;
  async login(value: SavedCredentials): Promise<void> { this.calls++; if (this.failure) throw this.failure; if (this.pending) await this.pending; }
}
export default function credentialTest() {
  describe('Credential refresh', () => {
    it('clears the previous identity before opt-in and clears on opt-out', 0, async () => {
      const backend = new Backend(); const store = new SecureCredentialStore(backend, new Cipher(), new Codec());
      await applyLoginCredentialChoice(store, true, { username: 'next-user', password: 'fixture' });
      expect((await store.get())?.username).assertEqual('next-user');
      await applyLoginCredentialChoice(store, false, { username: 'next-user', password: 'fixture' });
      expect(await store.get()).assertNull();
    });
    it('writes only ciphertext and serializes clear after save', 0, async () => {
      const backend = new Backend(); const store = new SecureCredentialStore(backend, new Cipher(), new Codec());
      await store.save({ username: 'fixture', password: 'test-secret' });
      expect(backend.value).assertEqual('encrypted');
      expect((await store.get())?.password).assertEqual('test-secret');
      const save = store.save({ username: 'fixture', password: 'test-secret' });
      const clear = store.clear(); await save; await clear; expect(await store.get()).assertNull();
    });
    it('preserves credentials on transient and interaction failures', 0, async () => {
      const credentials = new Credentials(); const login = new Login(); const model = new LoginRefreshCoordinator(credentials, login);
      credentials.present = false; expect(await model.refresh()).assertEqual('INTERACTION_REQUIRED'); credentials.present = true;
      login.failure = new AuthFlowError('network_transient', 'offline'); expect(await model.refresh()).assertEqual('FAILED');
      login.failure = new AuthFlowError('sms_required', 'sms'); expect(await model.refresh()).assertEqual('INTERACTION_REQUIRED'); expect(credentials.clears).assertEqual(0);
      login.failure = new AuthFlowError('invalid_credentials', 'rejected'); expect(await model.refresh()).assertEqual('FAILED'); expect(credentials.clears).assertEqual(1);
    });
    it('returns BUSY without destroying valid state', 0, async () => {
      const credentials = new Credentials(); const login = new Login(); let resolve: () => void = () => {};
      login.pending = new Promise<void>(done => { resolve = done; }); const model = new LoginRefreshCoordinator(credentials, login);
      const pending = model.refresh(); expect(await model.refresh()).assertEqual('BUSY'); resolve(); expect(await pending).assertEqual('SUCCESS'); expect(credentials.clears).assertEqual(0);
    });
    it('retries authentication failures once and ignores network errors', 0, async () => {
      const login = new Login(); const model = new LoginRefreshCoordinator(new Credentials(), login); let calls = 0;
      try { await retryAfterLoginRefresh(async () => { calls++; throw new Error('auth'); }, error => error.message === 'auth', model); } catch (_) {}
      expect(calls).assertEqual(2); expect(login.calls).assertEqual(1);
      try { await retryAfterLoginRefresh(async () => { throw new Error('offline'); }, error => error.message === 'auth', model); } catch (_) {}
      expect(login.calls).assertEqual(1);
    });
    it('rejects unsupported HUKS envelopes before key operations', 0, async () => {
      let failed = false;
      try { await new HuksCredentialCipher().decrypt('{}'); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
  });
}
