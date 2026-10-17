import { createTileCache } from '../services/map/TileCachePlatform';
import { TileNetworkSource, isPngTile } from '../services/map/TileCacheService';
import { normalizeMapViewport } from '../services/map/MapSettingsModel';
import { DebugCase } from './DebugCase';
import { MapConstants } from '../services/map/MapConfig';
import { calculateVisibleTiles, getTileUrl } from '../services/map/TileUtils';

export class MapDebugCase extends DebugCase {
  readonly name = 'Map Logic Debug';

  async run(): Promise<void> {
    this.logInfo('=== Map Debug START ===');

    // ... (之前的测试可以保留，也可以删掉) ...

    // 3. 测试核心算法
    this.logInfo('----- 3. Check Visible Tiles Calculation -----');

    // 模拟场景：
    // 地点：良乡校区 (MapConstants.LiangXiang)
    // 缩放：16级 (为了方便查看结果)
    // 屏幕：1080 x 2340 (常见手机分辨率)
    const lx = MapConstants.LiangXiang;
    const zoom = 16;
    const screenW = 1080;
    const screenH = 2340;

    this.logInfo(`Simulating View: LiangXiang @ Zoom ${zoom}`);
    this.logInfo(`Center: (${lx.x}, ${lx.y})`);

    const tiles = calculateVisibleTiles(
      lx.x,
      lx.y,
      zoom,
      screenW,
      screenH
    );

    this.logInfo(`Calculated Tiles Count: ${tiles.length}`);

    if (tiles.length > 0) {
      // 打印中间那张瓦片的信息来看看
      const centerTile = tiles[Math.floor(tiles.length / 2)];
      this.logInfo('Sample Tile:', centerTile);
      this.logInfo('First Tile URL:', tiles[0].url);
    } else {
      this.logError('❌ No tiles calculated! Something is wrong.');
    }

    const viewport = normalizeMapViewport({ x: NaN, y: Infinity, zoom: 99 });
    this.assertTrue(viewport.x === lx.x && viewport.y === lx.y && viewport.zoom === 19, 'Viewport normalization');
    const cacheDir = AppStorage.get<string>('cacheDir');
    this.assertTrue(!!cacheDir, 'Ability cache directory available');
    const tileUrl = getTileUrl(Math.floor(lx.x * Math.pow(2, 16)), Math.floor(lx.y * Math.pow(2, 16)), 16);
    const data = await createTileCache(cacheDir as string).get(tileUrl);
    this.assertTrue(isPngTile(data), 'Network or cached response is PNG');
    let networkCalls = 0;
    const offline: TileNetworkSource = { fetch: async (url: string): Promise<ArrayBuffer> => {
      networkCalls++; throw new Error('Offline cache probe');
    } };
    const restored = await createTileCache(cacheDir as string, offline).get(tileUrl);
    this.assertTrue(isPngTile(restored) && networkCalls === 0, 'Persistent tile available without network');
    this.logInfo('Map disk cache offline restore SUCCESS, bytes=' + restored.byteLength);
    this.logInfo('=== Map Debug END ===');
  }
}