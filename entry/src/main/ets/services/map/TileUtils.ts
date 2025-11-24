// entry/src/main/ets/services/map/WebShim.ts
import { MapConstants } from './MapConfig';

export interface Tile {
  col: number;
  row: number;
  zoom: number;
  url: string;
  key: string; // 用于 ForEach 的唯一键

  // 核心：计算这张瓦片在屏幕上的偏移量 (px)
  offsetX: number;
  offsetY: number;
}

export function getTileUrl(col: number, row: number, zoom: number): string {
  return `https://map.bit101.flwfdd.xyz/tile/${zoom}/${col}/${row}.png`;
}

/**
 * 核心算法：计算屏幕范围内需要加载哪些瓦片
 * * @param centerX 地图中心点 X (0.0 - 1.0)
 * @param centerY 地图中心点 Y (0.0 - 1.0)
 * @param zoom 当前缩放级别 (整数，例如 16)
 * @param screenWidth 屏幕宽度 (px)
 * @param screenHeight 屏幕高度 (px)
 */
export function calculateVisibleTiles(
  centerX: number,
  centerY: number,
  zoom: number,
  screenWidth: number,
  screenHeight: number
): Tile[] {
  const TILE_SIZE = MapConstants.TILE_SIZE;

  // 1. 世界总宽度（以瓦片为单位）: 2^zoom
  // 例如 zoom=1, world=2x2; zoom=16, world=65536x65536
  const totalTiles = 1 << zoom;

  // 2. 当前中心点在“瓦片坐标系”中的绝对位置 (例如: 第 54620.5 列)
  const centerTileX = centerX * totalTiles;
  const centerTileY = centerY * totalTiles;

  // 3. 屏幕的一半包含了多少个瓦片？
  // 比如屏幕宽 1080，一半是 540，除以 256 ≈ 2.1 个瓦片
  // 多加 1 是为了防止边缘留白
  const halfScreenTilesX = (screenWidth / 2) / TILE_SIZE + 1;
  const halfScreenTilesY = (screenHeight / 2) / TILE_SIZE + 1;

  // 4. 计算可视范围的起始和结束索引
  const minCol = Math.floor(centerTileX - halfScreenTilesX);
  const maxCol = Math.floor(centerTileX + halfScreenTilesX);
  const minRow = Math.floor(centerTileY - halfScreenTilesY);
  const maxRow = Math.floor(centerTileY + halfScreenTilesY);

  const tiles: Tile[] = [];

  // 5. 遍历范围，生成 Tile 对象
  for (let col = minCol; col <= maxCol; col++) {
    for (let row = minRow; row <= maxRow; row++) {
      // 处理循环世界（如果支持左右无限滚动），这里暂时简单处理边界
      // 如果 col < 0 或 col >= totalTiles，通常地图会重复或者空白
      // BIT101 主要是校区，我们暂时忽略环绕世界的情况
      if (col < 0 || col >= totalTiles || row < 0 || row >= totalTiles) {
        continue;
      }

      tiles.push({
        col: col,
        row: row,
        zoom: zoom,
        url: getTileUrl(col, row, zoom),
        key: `${zoom}_${col}_${row}`,
        // 计算这张图片相对于屏幕中心应当偏移多少像素
        // 公式：(瓦片索引 - 中心索引) * 256
        offsetX: (col - centerTileX) * TILE_SIZE,
        offsetY: (row - centerTileY) * TILE_SIZE
      });
    }
  }

  return tiles;
}