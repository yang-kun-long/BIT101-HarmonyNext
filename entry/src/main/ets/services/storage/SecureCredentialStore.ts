import { CredentialStore, SavedCredentials } from '../auth/LoginRefreshCoordinator';

export interface CredentialCipher {
  encrypt(plaintext: Uint8Array): Promise<string>;
  decrypt(envelope: string): Promise<Uint8Array>;
}
export interface CredentialBackend {
  read(): Promise<string>;
  write(encrypted: string): Promise<void>;
  remove(): Promise<void>;
}
export interface CredentialCodec {
  encode(value: string): Uint8Array;
  decode(value: Uint8Array): string;
}
/** Serialization prevents a slow save from resurrecting credentials after clear. */
export class SecureCredentialStore implements CredentialStore {
  private tail: Promise<void> = Promise.resolve();
  constructor(private backend: CredentialBackend, private cipher: CredentialCipher, private codec: CredentialCodec) {}
  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.tail.then(operation);
    this.tail = result.then(() => {}, () => {});
    return result;
  }
  async save(credentials: SavedCredentials): Promise<void> {
    if (!credentials.username.trim() || !credentials.password) throw new Error('凭据不能为空');
    const plaintext = this.codec.encode(JSON.stringify({ username: credentials.username.trim(), password: credentials.password }));
    return this.enqueue(async () => {
      try { await this.backend.write(await this.cipher.encrypt(plaintext)); }
      finally { plaintext.fill(0); }
    });
  }
  async get(): Promise<SavedCredentials | null> {
    return this.enqueue(async () => {
      const envelope = await this.backend.read();
      if (!envelope) return null;
      const plaintext = await this.cipher.decrypt(envelope);
      try {
        const value: SavedCredentials = JSON.parse(this.codec.decode(plaintext));
        if (!value || typeof value.username !== 'string' || !value.username.trim() || typeof value.password !== 'string' || !value.password) throw new Error('安全凭据格式异常');
        return value;
      } finally { plaintext.fill(0); }
    });
  }
  async clear(): Promise<void> { return this.enqueue(async () => { await this.backend.remove(); }); }
}
