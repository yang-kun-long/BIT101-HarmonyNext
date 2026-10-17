import { DebugCase } from './DebugCase';
import { HuksCredentialCipher } from '../services/storage/HuksCredentialCipher';
import { util } from '@kit.ArkTS';
import { huks } from '@kit.UniversalKeystoreKit';
import { createSecureCredentialStore } from '../services/storage/CredentialStorePlatform';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export class CredentialCase extends DebugCase {
  readonly name = 'HUKS credential integration';
  async run(): Promise<void> {
    const plaintext = new util.TextEncoder().encodeInto('fixture-only-凭据');
    const cipher = new HuksCredentialCipher();
    const first = await cipher.encrypt(plaintext);
    const second = await cipher.encrypt(plaintext);
    this.assertTrue(first !== second, 'Fresh nonce for each encryption');
    const restored = await new HuksCredentialCipher().decrypt(first);
    this.assertTrue(restored.length === plaintext.length && restored.every((value: number, index: number) => value === plaintext[index]), 'Round trip with reconstructed adapter');
    const envelope: { version: number; nonce: string; ciphertext: string } = JSON.parse(first);
    const base64 = new util.Base64Helper();
    const ciphertext = base64.decodeSync(envelope.ciphertext);
    ciphertext[0] ^= 1;
    envelope.ciphertext = base64.encodeToStringSync(ciphertext);
    let rejected = false;
    try { await cipher.decrypt(JSON.stringify(envelope)); } catch (_) { rejected = true; }
    this.assertTrue(rejected, 'Tampered ciphertext rejected');
    let exportRejected = false;
    try { await huks.exportKeyItem('bit101.credentials.aesgcm.v1', { properties: [] }); } catch (_) { exportRejected = true; }
    this.assertTrue(exportRejected, 'Symmetric key cannot be exported');
    const context = getContext() as common.UIAbilityContext;
    const store = createSecureCredentialStore(context);
    // Never replace a real user's saved secret when running this case.
    if (!(await store.get())) {
      try {
        await store.save({ username: 'integration-fixture', password: 'fixture-only' });
        const disk = fileIo.readTextSync(context.cacheDir + '/secure-credentials-v1.json');
        this.assertTrue(!disk.includes('fixture'), 'Disk contains only encrypted envelope');
        const saved = await store.get();
        this.assertTrue(saved?.username === 'integration-fixture' && saved?.password === 'fixture-only', 'File-backed credential roundtrip');
      } finally { await store.clear(); }
      this.assertTrue((await store.get()) === null, 'Credential file cleared');
    }
    plaintext.fill(0); restored.fill(0);
    this.logInfo('HUKS roundtrip, random nonce and tamper rejection PASS');
  }
}
