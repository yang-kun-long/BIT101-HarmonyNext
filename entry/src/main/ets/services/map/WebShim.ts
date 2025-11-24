// entry/src/main/ets/services/map/WebShim.ts
// @ts-nocheck  // 整个文件不做类型检查（方便我们用到 SDK 里“不公开”的构造）

import { MapConstants } from './MapConfig';
import web_webview from '@ohos.web.webview';

// ===================
// 瓦片相关工具（如果以后要用 ArkTS 纯实现地图，可直接复用）
// ===================

export interface Tile {
  col: number;
  row: number;
  zoom: number;
  url: string;
  key: string;    // ForEach 用的唯一 key
  offsetX: number;
  offsetY: number;
}

export function getTileUrl(col: number, row: number, zoom: number): string {
  return `https://map.bit101.flwfdd.xyz/tile/${zoom}/${col}/${row}.png`;
}

/**
 * 计算当前视野内显示哪些瓦片（配合 MapConstants.TILE_SIZE 使用）
 */
export function calculateVisibleTiles(
  centerX: number,
  centerY: number,
  zoom: number,
  screenWidth: number,
  screenHeight: number
): Tile[] {
  const TILE_SIZE = MapConstants.TILE_SIZE;

  // 世界一圈一共有多少瓦片：2^zoom
  const totalTiles = 1 << zoom;

  // 中心点在“瓦片坐标系”中的绝对位置
  const centerTileX = centerX * totalTiles;
  const centerTileY = centerY * totalTiles;

  // 屏幕半宽 / 半高占多少个瓦片 +1 防止出现间隙
  const halfScreenTilesX = (screenWidth / 2) / TILE_SIZE + 1;
  const halfScreenTilesY = (screenHeight / 2) / TILE_SIZE + 1;

  const minCol = Math.floor(centerTileX - halfScreenTilesX);
  const maxCol = Math.floor(centerTileX + halfScreenTilesX);
  const minRow = Math.floor(centerTileY - halfScreenTilesY);
  const maxRow = Math.floor(centerTileY + halfScreenTilesY);

  const tiles: Tile[] = [];

  for (let col = minCol; col <= maxCol; col++) {
    for (let row = minRow; row <= maxRow; row++) {
      // 这里只做简单边界裁剪（不做“环世界”）
      if (col < 0 || col >= totalTiles || row < 0 || row >= totalTiles) {
        continue;
      }

      tiles.push({
        col,
        row,
        zoom,
        url: getTileUrl(col, row, zoom),
        key: `${zoom}_${col}_${row}`,
        offsetX: (col - centerTileX) * TILE_SIZE,
        offsetY: (row - centerTileY) * TILE_SIZE,
      });
    }
  }

  return tiles;
}

// ===================
// WebView Response Hack
// ===================

/**
 * ⚠️ 法外之地：
 * 利用 WebResourceResponse 构造一个“从 fd 读图片数据”的响应，
 * 这样 ArkTS 侧就可以直接把本地文件伪装成网络返回值。
 */
export function createWebResourceResponse(fd: number): any {
  return new web_webview.WebResourceResponse(
    'image/png', // mimeType
    'utf-8',     // encoding（图片其实不需要，但构造函数要求）
    200,         // statusCode
    'OK',        // reasonPhrase
    [],          // headers
    fd           // 关键：文件描述符
  );
}
