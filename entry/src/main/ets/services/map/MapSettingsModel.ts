import { MapConstants } from './MapConfig';

export interface MapViewport {
  x: number;
  y: number;
  zoom: number;
}

export function normalizeMapZoom(value: number): number {
  return Number.isFinite(value) ? Math.round(Math.max(1, Math.min(19, value)) * 10) / 10 : 16;
}

export function normalizeMapViewport(value: MapViewport): MapViewport {
  return {
    x: Number.isFinite(value.x) && value.x >= 0 && value.x <= 1 ? value.x : MapConstants.LiangXiang.x,
    y: Number.isFinite(value.y) && value.y >= 0 && value.y <= 1 ? value.y : MapConstants.LiangXiang.y,
    zoom: normalizeMapZoom(value.zoom),
  };
}

export function mapViewportScript(viewport: MapViewport): string {
  const safe = normalizeMapViewport(viewport);
  return 'flyToPosition(' + safe.x + ',' + safe.y + ',' + safe.zoom + ')';
}
