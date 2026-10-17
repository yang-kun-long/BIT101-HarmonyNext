import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import { common } from '@kit.AbilityKit';
import { TileCacheBackend, TileCacheEntry, TileCacheService, TileNetworkSource, TILE_MAX_BYTES } from './TileCacheService';

class DiskTileCache implements TileCacheBackend {
  private directory: string;
  constructor(directory: string) { this.directory = directory + '/map_tiles_v1'; }

  private path(entry: TileCacheEntry): string {
    if (!/^\d{1,2}_\d{1,6}_\d{1,6}$/.test(entry.key) || !Number.isSafeInteger(entry.savedAt) || entry.savedAt < 0) {
      throw new Error('无效瓦片缓存记录');
    }
    return this.directory + '/' + entry.key + '_' + entry.savedAt + '.png';
  }

  async list(): Promise<TileCacheEntry[]> {
    if (!await fs.access(this.directory)) await fs.mkdir(this.directory);
    const names = await fs.listFile(this.directory);
    const entries: TileCacheEntry[] = [];
    for (const name of names) {
      const match = name.match(/^(\d{1,2}_\d{1,6}_\d{1,6})_(\d{1,16})\.png$/);
      if (!match) continue;
      const entry: TileCacheEntry = { key: match[1], savedAt: Number(match[2]), size: 0 };
      const stat = await fs.stat(this.path(entry));
      if (stat.isFile()) { entry.size = stat.size; entries.push(entry); }
    }
    return entries;
  }

  async read(entry: TileCacheEntry): Promise<ArrayBuffer> {
    if (entry.size > TILE_MAX_BYTES) throw new Error('缓存瓦片过大');
    const file = await fs.open(this.path(entry), fs.OpenMode.READ_ONLY);
    try {
      const data = new ArrayBuffer(entry.size);
      const length = await fs.read(file.fd, data);
      if (length !== entry.size) throw new Error('缓存瓦片不完整');
      return data;
    } finally { await fs.close(file); }
  }

  async write(entry: TileCacheEntry, data: ArrayBuffer): Promise<void> {
    const file = await fs.open(this.path(entry), fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    let complete = false;
    try {
      const length = await fs.write(file.fd, data);
      if (length !== data.byteLength) throw new Error('缓存瓦片写入不完整');
      complete = true;
    } finally {
      await fs.close(file);
      if (!complete) await this.remove(entry);
    }
  }

  async remove(entry: TileCacheEntry): Promise<void> {
    const path = this.path(entry);
    try { await fs.unlink(path); }
    catch (error) { if (await fs.access(path)) throw error; }
  }
}

class HttpTileNetwork implements TileNetworkSource {
  async fetch(url: string): Promise<ArrayBuffer> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, { method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false,
        connectTimeout: 10000, readTimeout: 15000, maxLimit: TILE_MAX_BYTES });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) throw new Error('地图瓦片加载失败');
      return response.result;
    } finally { request.destroy(); }
  }
}

export function createTileCache(directory: string, network?: TileNetworkSource): TileCacheService {
  return new TileCacheService(new DiskTileCache(directory), network ?? new HttpTileNetwork());
}

let cache: TileCacheService | null = null;
export function getTileCache(context: common.Context): TileCacheService {
  if (!cache) cache = createTileCache(context.cacheDir);
  return cache;
}
