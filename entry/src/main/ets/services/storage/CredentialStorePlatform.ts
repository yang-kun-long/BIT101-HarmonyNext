import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { CredentialBackend, CredentialCodec, SecureCredentialStore } from './SecureCredentialStore';
import { HuksCredentialCipher } from './HuksCredentialCipher';

class Utf8CredentialCodec implements CredentialCodec {
  encode(value: string): Uint8Array { return new util.TextEncoder().encodeInto(value); }
  decode(value: Uint8Array): string { return util.TextDecoder.create('utf-8').decodeToString(value); }
}
/** Cache directory is excluded from application backup; eviction requires a new login. */
class LocalCredentialBackend implements CredentialBackend {
  private path: string;
  constructor(context: common.Context) { this.path = context.cacheDir + '/secure-credentials-v1.json'; }
  async read(): Promise<string> {
    if (!fileIo.accessSync(this.path)) return '';
    return fileIo.readTextSync(this.path);
  }
  async write(encrypted: string): Promise<void> {
    const temporary = this.path + '.tmp';
    const file = fileIo.openSync(temporary, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const bytes = new util.TextEncoder().encodeInto(encrypted);
      if (fileIo.writeSync(file.fd, bytes.buffer) !== bytes.byteLength) throw new Error('安全凭据写入不完整');
      fileIo.fsyncSync(file.fd);
    } finally { fileIo.closeSync(file); }
    fileIo.renameSync(temporary, this.path);
  }
  async remove(): Promise<void> {
    if (fileIo.accessSync(this.path)) fileIo.unlinkSync(this.path);
    if (fileIo.accessSync(this.path + '.tmp')) fileIo.unlinkSync(this.path + '.tmp');
  }
}
let sharedStore: SecureCredentialStore | null = null;
export function createSecureCredentialStore(context: common.Context): SecureCredentialStore {
  if (!sharedStore) sharedStore = new SecureCredentialStore(new LocalCredentialBackend(context), new HuksCredentialCipher(), new Utf8CredentialCodec());
  return sharedStore;
}
