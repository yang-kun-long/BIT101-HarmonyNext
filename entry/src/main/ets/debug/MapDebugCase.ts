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

    this.logInfo('=== Map Debug END ===');
  }
}