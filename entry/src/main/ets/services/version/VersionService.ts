import type { HttpRequest, HttpResponse } from '../../core/network/httpClient';
import { ApiError, HttpClient } from '../../core/network/httpClient';
import { evaluateVersion, isHarmonyPlatform, parseVersionInfo, VersionCheckResult, VersionInfo } from './VersionModels';

export interface VersionHttpClient {
  request<T = unknown>(request: HttpRequest): Promise<HttpResponse<T>>;
}

export interface VersionServiceOptions {
  httpClient?: VersionHttpClient;
  baseUrl?: string;
}

export class VersionService {
  private readonly http: VersionHttpClient;

  constructor(options?: VersionServiceOptions) {
    this.http = options?.httpClient ?? new HttpClient(options?.baseUrl ?? 'https://bit101.flwfdd.xyz');
  }

  async fetchLatest(): Promise<VersionInfo> {
    const response = await this.http.request<unknown>({
      url: '/version',
      method: 'GET',
      headers: {
        Accept: 'application/json',
      },
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError(`HTTP ${response.status}`, response.status);
    }
    const payload: unknown = response.data !== undefined
      ? response.data
      : (response.text.length > 0 ? JSON.parse(response.text) : null);
    const latest = parseVersionInfo(payload);
    if (!isHarmonyPlatform(latest.platform)) {
      throw new Error('Version channel is not confirmed for harmonyos');
    }
    return latest;
  }

  async check(currentVersionCode: number, ignoredVersionCode: number | null = null): Promise<VersionCheckResult> {
    return evaluateVersion(currentVersionCode, await this.fetchLatest(), ignoredVersionCode);
  }
}
