export interface VersionInfo {
  minVersionCode: number;
  minVersionName: string;
  versionCode: number;
  versionName: string;
  url: string;
  message: string;
  platform: string | null;
}

export type VersionDecision = 'up_to_date' | 'update_available' | 'forced_update' | 'ignored';

export interface VersionCheckResult {
  decision: VersionDecision;
  currentVersionCode: number;
  latest: VersionInfo;
}

export const HARMONY_PROJECT_URL: string = 'https://github.com/yang-kun-long/BIT101-HarmonyNext';

export function resolveUpdateUrl(value: string): string {
  const trimmed = value.trim();
  if (!/^https?:\/\/[a-z0-9.-]+(?::[0-9]+)?(?:[/?#][^\s\\]*)?$/i.test(trimmed)) return HARMONY_PROJECT_URL;
  let decoded = trimmed;
  try { decoded = decodeURIComponent(trimmed); } catch (_) { return HARMONY_PROJECT_URL; }
  if (/\.apk(?:[/?&#]|$)/i.test(decoded)) return HARMONY_PROJECT_URL;
  return trimmed;
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string') {
    throw new Error(`Invalid version response field: ${field}`);
  }
  return value;
}

function requiredNonNegativeInteger(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw new Error(`Invalid version response field: ${field}`);
  }
  return value;
}

/**
 * Parse the backend's snake_case /version payload without silently accepting
 * missing fields. The optional platform field is retained so callers can
 * reject an Android-only response before presenting it in the HarmonyOS UI.
 */
export function parseVersionInfo(payload: unknown): VersionInfo {
  if (payload === null || typeof payload !== 'object') {
    throw new Error('Invalid version response: expected an object');
  }
  const body = payload as Record<string, unknown>;
  const platformValue: unknown = body['platform'] ?? body['target'] ?? null;
  if (platformValue !== null && typeof platformValue !== 'string') {
    throw new Error('Invalid version response field: platform');
  }
  return {
    minVersionCode: requiredNonNegativeInteger(body['min_version_code'], 'min_version_code'),
    minVersionName: requiredString(body['min_version_name'], 'min_version_name'),
    versionCode: requiredNonNegativeInteger(body['version_code'], 'version_code'),
    versionName: requiredString(body['version_name'], 'version_name'),
    url: requiredString(body['url'], 'url'),
    message: requiredString(body['msg'], 'msg'),
    platform: platformValue as string | null,
  };
}

export function evaluateVersion(
  currentVersionCode: number,
  latest: VersionInfo,
  ignoredVersionCode: number | null = null,
): VersionCheckResult {
  if (!Number.isInteger(currentVersionCode) || currentVersionCode < 0) {
    throw new Error('currentVersionCode must be a non-negative integer');
  }
  if (currentVersionCode < latest.minVersionCode) {
    return { decision: 'forced_update', currentVersionCode, latest };
  }
  if (latest.versionCode > currentVersionCode && latest.versionCode === ignoredVersionCode) {
    return { decision: 'ignored', currentVersionCode, latest };
  }
  if (latest.versionCode > currentVersionCode) {
    return { decision: 'update_available', currentVersionCode, latest };
  }
  return { decision: 'up_to_date', currentVersionCode, latest };
}

export function isHarmonyPlatform(platform: string | null): boolean {
  if (platform === null || platform.trim().length === 0) {
    return false;
  }
  const normalized = platform.trim().toLowerCase();
  return normalized === 'harmonyos' || normalized === 'ohos' || normalized === 'openharmony';
}
