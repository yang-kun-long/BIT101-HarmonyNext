export const TILE_CACHE_MAX_BYTES: number = 10 * 1024 * 1024;
export const TILE_CACHE_TTL_MS: number = 7 * 24 * 60 * 60 * 1000;
export const TILE_MAX_BYTES: number = 1024 * 1024;

export interface TileCacheEntry {
  key: string;
  savedAt: number;
  size: number;
}

export interface TileCacheBackend {
  list(): Promise<TileCacheEntry[]>;
  read(entry: TileCacheEntry): Promise<ArrayBuffer>;
  write(entry: TileCacheEntry, data: ArrayBuffer): Promise<void>;
  remove(entry: TileCacheEntry): Promise<void>;
}

export interface TileNetworkSource {
  fetch(url: string): Promise<ArrayBuffer>;
}

export function tileKey(url: string): string | null {
  const match = url.match(/^https:\/\/map\.bit101\.flwfdd\.xyz\/tile\/(\d{1,2})\/(\d{1,6})\/(\d{1,6})\.png$/);
  if (!match) return null;
  const z = Number(match[1]); const x = Number(match[2]); const y = Number(match[3]);
  if (z < 1 || z > 19 || x >= Math.pow(2, z) || y >= Math.pow(2, z)) return null;
  return z + '_' + x + '_' + y;
}

export function isPngTile(data: ArrayBuffer): boolean {
  if (data.byteLength < 8 || data.byteLength > TILE_MAX_BYTES) return false;
  const bytes = new Uint8Array(data);
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  return signature.every((value: number, index: number) => bytes[index] === value);
}

/** Public map images only. No cookies or user data enter this cache. */
export class TileCacheService {
  private backend: TileCacheBackend;
  private network: TileNetworkSource;
  private now: () => number;
  private maxBytes: number;
  private entries: TileCacheEntry[] = [];
  private initialized: boolean = false;
  private queue: Promise<void> = Promise.resolve();
  private pending: Map<string, Promise<ArrayBuffer>> = new Map();

  constructor(backend: TileCacheBackend, network: TileNetworkSource, now: () => number = () => Date.now(),
    maxBytes: number = TILE_CACHE_MAX_BYTES) {
    this.backend = backend; this.network = network; this.now = now; this.maxBytes = maxBytes;
  }

  get(url: string): Promise<ArrayBuffer> {
    const key = tileKey(url);
    if (!key) return Promise.reject(new Error('无效地图瓦片地址'));
    const existing = this.pending.get(key);
    if (existing) return existing;
    const operation = this.load(url, key);
    this.pending.set(key, operation);
    return operation.finally(() => { this.pending.delete(key); });
  }

  private exclusive<T>(action: () => Promise<T>): Promise<T> {
    const result = this.queue.then(action);
    this.queue = result.then(() => {}, () => {});
    return result;
  }

  private async prune(): Promise<void> {
    const now = this.now();
    const sorted = this.entries.slice().sort((a, b) => b.savedAt - a.savedAt);
    const kept: TileCacheEntry[] = []; const keys = new Set<string>();
    let bytes = 0;
    for (const entry of sorted) {
      const age = now - entry.savedAt;
      if (Number.isFinite(entry.savedAt) && age >= 0 && age < TILE_CACHE_TTL_MS &&
        entry.size > 0 && entry.size <= TILE_MAX_BYTES && bytes + entry.size <= this.maxBytes && !keys.has(entry.key)) {
        kept.push(entry); keys.add(entry.key); bytes += entry.size;
      } else {
        await this.backend.remove(entry);
      }
    }
    this.entries = kept;
  }

  private async load(url: string, key: string): Promise<ArrayBuffer> {
    let cached: ArrayBuffer | null = null;
    try {
      cached = await this.exclusive(async () => {
        if (!this.initialized) { this.entries = await this.backend.list(); this.initialized = true; }
        await this.prune();
        const entry = this.entries.find(item => item.key === key);
        if (!entry) return null;
        try {
          const data = await this.backend.read(entry);
          if (data.byteLength === entry.size && isPngTile(data)) return data;
        } catch (_) {}
        await this.backend.remove(entry);
        this.entries = this.entries.filter(item => item !== entry);
        return null;
      });
    } catch (_) { /* A cache failure must not prevent a network request. */ }
    if (cached) return cached;
    const data = await this.network.fetch(url);
    if (!isPngTile(data)) throw new Error('地图瓦片响应格式异常');
    try {
      await this.exclusive(async () => {
        if (!this.initialized) { this.entries = await this.backend.list(); this.initialized = true; }
        await this.prune();
        if (data.byteLength > this.maxBytes) return;
        // Reserve disk space first, so eviction failures cannot grow the cache.
        while (this.entries.reduce((bytes, item) => bytes + item.size, 0) + data.byteLength > this.maxBytes) {
          const oldest = this.entries[this.entries.length - 1];
          await this.backend.remove(oldest);
          this.entries = this.entries.filter(item => item !== oldest);
        }
        const entry: TileCacheEntry = { key, size: data.byteLength, savedAt: this.now() };
        await this.backend.write(entry, data);
        this.entries.push(entry);
        await this.prune();
      });
    } catch (_) { /* The fresh tile remains usable when storage is unavailable. */ }
    return data;
  }
}
