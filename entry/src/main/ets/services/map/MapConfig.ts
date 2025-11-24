// entry/src/main/ets/services/map/MapConfig.ts
// 定义位置接口
export interface MapPosition {
  x: number;      // 相对坐标 X (0-1)
  y: number;      // 相对坐标 Y (0-1)
  scale: number;  // 默认缩放比例
}

// 对应 Android 代码中的常量
export const MapConstants = {
  // 地图瓦片源的基础配置
  TILE_SIZE: 256,
  MIN_ZOOM: 1,
  MAX_ZOOM: 19, // Android 代码里 MapState(19, ...)

  // 预定义位置 (直接从 Android MapViewModel 复制过来的数据)
  LiangXiang: {
    x: 0.822685,
    y: 0.37956,
    scale: 0.25
  } as MapPosition,

  ZhongGuanCun: {
    x: 0.823083,
    y: 0.37873,
    scale: 0.25
  } as MapPosition
};