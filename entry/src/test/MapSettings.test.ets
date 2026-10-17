import { describe, it, expect } from '@ohos/hypium';
import { normalizeMapViewport, mapViewportScript, normalizeMapZoom } from '../main/ets/services/map/MapSettingsModel';
import { MapConstants } from '../main/ets/services/map/MapConfig';
import { TileCacheBackend, TileCacheEntry, TileCacheService, TileNetworkSource, tileKey,
  TILE_CACHE_TTL_MS, isPngTile } from '../main/ets/services/map/TileCacheService';

function png(): ArrayBuffer { return new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0]).buffer; }
const firstUrl = 'https://map.bit101.flwfdd.xyz/tile/16/53914/24874.png';
const secondUrl = 'https://map.bit101.flwfdd.xyz/tile/16/53915/24874.png';

class MemoryTiles implements TileCacheBackend {
  entries: TileCacheEntry[] = [];
  data: Map<string, ArrayBuffer> = new Map();
  failWrite: boolean = false;
  failRead: boolean = false;
  failRemove: boolean = false;
  async list(): Promise<TileCacheEntry[]> { return this.entries.slice(); }
  async read(entry: TileCacheEntry): Promise<ArrayBuffer> {
    if (this.failRead) throw new Error('read failed');
    const data = this.data.get(entry.key); if (!data) throw new Error('missing');
    return data;
  }
  async write(entry: TileCacheEntry, data: ArrayBuffer): Promise<void> {
    if (this.failWrite) throw new Error('write failed');
    this.entries.push(entry); this.data.set(entry.key, data);
  }
  async remove(entry: TileCacheEntry): Promise<void> {
    if (this.failRemove) throw new Error('remove failed');
    this.entries = this.entries.filter(item => item !== entry); this.data.delete(entry.key);
  }
}

class FixtureTileNetwork implements TileNetworkSource {
  calls: number = 0;
  offline: boolean = false;
  data: ArrayBuffer = png();
  async fetch(url: string): Promise<ArrayBuffer> {
    this.calls++; if (this.offline) throw new Error('offline'); return this.data;
  }
}

export default function mapSettingsTest() {
  describe('Map viewport and bounded tile cache', () => {
    it('preserves valid decimal zoom and normalizes invalid legacy viewport values', 0, () => {
      const valid = normalizeMapViewport({ x: 0.82, y: 0.37, zoom: 16.23 });
      expect(valid.x).assertEqual(0.82); expect(valid.y).assertEqual(0.37); expect(valid.zoom).assertEqual(16.2);
      const invalid = normalizeMapViewport({ x: NaN, y: 3, zoom: Infinity });
      expect(invalid.x).assertEqual(MapConstants.LiangXiang.x); expect(invalid.y).assertEqual(MapConstants.LiangXiang.y);
      expect(invalid.zoom).assertEqual(16); expect(normalizeMapZoom(-1)).assertEqual(1);
      expect(normalizeMapZoom(30)).assertEqual(19);
      expect(mapViewportScript(invalid)).assertEqual('flyToPosition(' + invalid.x + ',' + invalid.y + ',16)');
    });

    it('accepts only exact tile origins and valid coordinate ranges', 0, () => {
      expect(tileKey(firstUrl)).assertEqual('16_53914_24874');
      for (const url of [firstUrl + '?token=secret', firstUrl.replace('https:', 'http:'),
        firstUrl.replace('map.bit101.flwfdd.xyz', 'map.bit101.flwfdd.xyz.evil'),
        'https://map.bit101.flwfdd.xyz/tile/20/1/1.png', 'https://map.bit101.flwfdd.xyz/tile/1/2/1.png',
        'https://map.bit101.flwfdd.xyz/tile/16/../1.png']) {
        expect(tileKey(url)).assertNull();
      }
    });

    it('uses a valid persistent tile while offline without contacting the network', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork();
      const first = new TileCacheService(backend, network, () => 1000);
      await first.get(firstUrl); network.offline = true;
      const restored = new TileCacheService(backend, network, () => 1001);
      expect(isPngTile(await restored.get(firstUrl))).assertTrue(); expect(network.calls).assertEqual(1);
    });

    it('expires entries at seven days and rejects stale data during network failure', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork();
      let now = 1000; const cache = new TileCacheService(backend, network, () => now);
      await cache.get(firstUrl); now += TILE_CACHE_TTL_MS; network.offline = true;
      let failed = false; try { await cache.get(firstUrl); } catch (_) { failed = true; }
      expect(failed).assertTrue(); expect(backend.entries.length).assertEqual(0);
      network.offline = false; await cache.get(firstUrl); expect(backend.entries[0].savedAt).assertEqual(now);
    });

    it('evicts oldest tiles within the byte budget and recovers a backwards clock', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork(); let now = 1000;
      const cache = new TileCacheService(backend, network, () => now, png().byteLength);
      await cache.get(firstUrl); now++; await cache.get(secondUrl);
      expect(backend.entries.length).assertEqual(1); expect(backend.entries[0].key).assertEqual(tileKey(secondUrl));
      now = 0; await cache.get(secondUrl); expect(network.calls).assertEqual(3);
    });

    it('recovers corrupt cache entries and tolerates storage write failures', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork();
      const cache = new TileCacheService(backend, network, () => 1000);
      await cache.get(firstUrl); backend.data.set(tileKey(firstUrl)!, new ArrayBuffer(9));
      backend.failWrite = true;
      expect(isPngTile(await cache.get(firstUrl))).assertTrue(); expect(network.calls).assertEqual(2);
      expect(backend.entries.length).assertEqual(0);
    });

    it('rejects non-image responses without poisoning the cache', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork(); network.data = new ArrayBuffer(8);
      const cache = new TileCacheService(backend, network);
      let failed = false; try { await cache.get(firstUrl); } catch (_) { failed = true; }
      expect(failed).assertTrue(); expect(backend.entries.length).assertEqual(0);
      network.data = png(); expect(isPngTile(await cache.get(firstUrl))).assertTrue();
    });

    it('merges concurrent tile requests', 0, async () => {
      const backend = new MemoryTiles(); let resolve: (data: ArrayBuffer) => void = () => {}; let calls = 0;
      const network: TileNetworkSource = { fetch: async (url: string) => {
        calls++; return new Promise<ArrayBuffer>(done => { resolve = done; });
      } };
      const cache = new TileCacheService(backend, network);
      const one = cache.get(firstUrl); const two = cache.get(firstUrl);
      await new Promise<void>(done => { setTimeout(done, 0); });
      resolve(png()); await one; await two; expect(calls).assertEqual(1);
    });

    it('retries failed requests and avoids new writes when eviction cannot free space', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork();
      const cache = new TileCacheService(backend, network, () => 1000, png().byteLength);
      network.offline = true; let failed = false;
      try { await cache.get(firstUrl); } catch (_) { failed = true; }
      expect(failed).assertTrue(); network.offline = false; await cache.get(firstUrl);
      backend.failRemove = true; expect(isPngTile(await cache.get(secondUrl))).assertTrue();
      expect(backend.entries.length).assertEqual(1);
      expect(backend.entries[0].key).assertEqual(tileKey(firstUrl));
      expect(network.calls).assertEqual(3);
    });

    it('fetches again after an unreadable cache file and does not cache over-budget tiles', 0, async () => {
      const backend = new MemoryTiles(); const network = new FixtureTileNetwork();
      const cache = new TileCacheService(backend, network, () => 1000);
      await cache.get(firstUrl); backend.failRead = true;
      expect(isPngTile(await cache.get(firstUrl))).assertTrue(); expect(network.calls).assertEqual(2);
      const smallBackend = new MemoryTiles();
      const noRoom = new TileCacheService(smallBackend, network, () => 1000, 1);
      expect(isPngTile(await noRoom.get(firstUrl))).assertTrue(); expect(smallBackend.entries.length).assertEqual(0);
    });
  });
}
