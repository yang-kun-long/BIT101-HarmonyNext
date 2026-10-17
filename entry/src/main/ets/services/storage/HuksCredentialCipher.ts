import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { CredentialCipher } from './SecureCredentialStore';
import { BusinessError } from '@kit.BasicServicesKit';

interface CredentialEnvelope { version: number; nonce: string; ciphertext: string; }
const KEY_ALIAS = 'bit101.credentials.aesgcm.v1';

/** AES key is generated inside HUKS; this adapter never imports or exports it. */
export class HuksCredentialCipher implements CredentialCipher {
  private base64 = new util.Base64Helper();
  private properties(purpose: number): huks.HuksParam[] {
    return [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    ];
  }
  async encrypt(plaintext: Uint8Array): Promise<string> {
    let exists = false;
    try { exists = await huks.isKeyItemExist(KEY_ALIAS, { properties: [] }); }
    catch (error) { if ((error as BusinessError).code !== 12000011) throw error; }
    if (!exists) {
      await huks.generateKeyItem(KEY_ALIAS, { properties: this.properties(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT) });
    }
    const nonce = (await cryptoFramework.createRandom().generateRandom(12)).data;
    const encrypted = await this.run(plaintext, nonce, true);
    const envelope: CredentialEnvelope = { version: 1, nonce: this.base64.encodeToStringSync(nonce), ciphertext: this.base64.encodeToStringSync(encrypted) };
    return JSON.stringify(envelope);
  }
  async decrypt(raw: string): Promise<Uint8Array> {
    const envelope: CredentialEnvelope = JSON.parse(raw);
    if (!envelope || envelope.version !== 1 || typeof envelope.nonce !== 'string' || typeof envelope.ciphertext !== 'string') throw new Error('不支持的安全凭据版本');
    const nonce = this.base64.decodeSync(envelope.nonce);
    const ciphertext = this.base64.decodeSync(envelope.ciphertext);
    if (nonce.length !== 12 || ciphertext.length < 16 || ciphertext.length > 16384) throw new Error('安全凭据数据损坏');
    return await this.run(ciphertext, nonce, false);
  }
  private async run(input: Uint8Array, nonce: Uint8Array, encrypt: boolean): Promise<Uint8Array> {
    const properties = this.properties(encrypt ? huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT : huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT);
    properties.push({ tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce });
    properties.push({ tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: new util.TextEncoder().encodeInto('BIT101 credentials v1') });
    let data = input;
    if (!encrypt) {
      properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: input.slice(input.length - 16) });
      data = input.slice(0, input.length - 16);
    }
    const session = await huks.initSession(KEY_ALIAS, { properties });
    try {
      const result = await huks.finishSession(session.handle, { properties, inData: data });
      if (!result.outData) throw new Error('安全凭据操作没有返回数据');
      return result.outData;
    } catch (_) {
      try { await huks.abortSession(session.handle, { properties: [] }); } catch (_) {}
      throw new Error('安全凭据加解密失败');
    }
  }
}
