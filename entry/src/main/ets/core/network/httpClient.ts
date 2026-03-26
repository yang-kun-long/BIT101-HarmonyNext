// entry/src/main/ets/core/network/httpClient.ts
import http from '@ohos.net.http';
import { guardAsyncStorage } from '../../services/storage/storageGuard';

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

export interface HttpRequest {
  url: string;
  method?: HttpMethod;
  headers?: Record<string, string>;
  json?: any;              // 传对象则自动 JSON.stringify
  rawBody?: string | Uint8Array; // 特殊场景直传原始体
  connectTimeoutMs?: number;
  readTimeoutMs?: number;
}

export interface HttpResponse<T = unknown> {
  status: number;
  headers: Record<string, string | string[]>;
  text: string;
  data?: T; // 若能 JSON.parse 则赋值
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly bodyText?: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export class HttpClient {
  constructor(
    private readonly baseUrl: string,
    private readonly defaultHeaders: Record<string, string> = {}
  ) {}

  buildUrl(pathOrUrl: string) {
    if (/^https?:\/\//i.test(pathOrUrl)) return pathOrUrl;
    return this.baseUrl.replace(/\/$/, '') + '/' + pathOrUrl.replace(/^\//, '');
  }

  async request<T = unknown>(req: HttpRequest): Promise<HttpResponse<T>> {
    const url = this.buildUrl(req.url);
    const method = (req.method || 'GET') as http.RequestMethod;

    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*',
      ...this.defaultHeaders,
      ...(req.headers || {})
    };

    // 自动 JSON
    let extraData: string | Uint8Array | undefined = undefined;
    if (req.json !== undefined) {
      headers['Content-Type'] = headers['Content-Type'] || 'application/json;charset=UTF-8';
      extraData = JSON.stringify(req.json);
    } else if (req.rawBody !== undefined) {
      extraData = req.rawBody as any;
    }

    const client = http.createHttp();
    try {
      const res = await guardAsyncStorage('HttpClient.request', async () =>
        await client.request(url, {
          method,
          header: headers,
          extraData,
          connectTimeout: req.connectTimeoutMs ?? 15000,
          readTimeout: req.readTimeoutMs ?? 15000
        }),
      );

      const status = res.responseCode ?? 0;
      const text = (res.result as string) ?? '';
      const headersRaw = res.header || {};
      const headersNorm: Record<string, string | string[]> = {};
      Object.keys(headersRaw).forEach(k => {
        const v = (headersRaw as any)[k];
        headersNorm[k.toLowerCase()] = v;
      });

      let data: any = undefined;
      if (text) {
        try { data = JSON.parse(text); } catch { /* not json, keep text */ }
      }

      if (status < 200 || status >= 300) {
        throw new ApiError(`HTTP ${status}`, status, text);
      }

      return { status, headers: headersNorm, text, data };
    } finally {
      client.destroy();
    }
  }
}
