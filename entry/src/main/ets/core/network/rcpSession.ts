// entry/src/main/ets/core/network/RcpSession.ts
// 基于 Remote Communication Kit 的轻量封装：GET / POST +（可选）CookieJar + 调试日志

import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';

// ================= 对外类型定义 =================

export interface RcpSessionOptions {
  baseUrl?: string;
  defaultHeaders?: Record<string, string>;
  autoRedirect?: boolean;
  maxAutoRedirects?: number;
  timeoutMs?: number;
  collectTimeInfo?: boolean;
  debug?: boolean;
  cookieJar?: CookieJarLike;
}

export interface RcpRequestOptions {
  headers?: Record<string, string>;
  query?: Record<string, string | number | boolean | undefined | null>;
  autoRedirect?: boolean;
  maxAutoRedirects?: number;
  collectTimeInfo?: boolean;
  timeoutMs?: number;
}

export interface RcpResponseData {
  statusCode: number;
  headers: rcp.ResponseHeaders;
  bodyText: string;
  // rcp.Response.effectiveUrl 实际类型是 URL，这里用 any 避免类型冲突
  effectiveUrl?: any;
  timeInfo?: rcp.TimeInfo;
}

export interface CookieJarLike {
  getCookieHeader(url: string): string | undefined;
  updateFromSetCookie(url: string, setCookie: string | string[]): void;
}

// ================= 工具函数 =================

function buildQueryString(query?: RcpRequestOptions['query']): string {
  if (!query) return '';
  const parts: string[] = [];
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null) continue;
    parts.push(
      encodeURIComponent(k) + '=' + encodeURIComponent(String(v)),
    );
  }
  return parts.length ? `?${parts.join('&')}` : '';
}

function isAbsoluteUrl(url: string): boolean {
  return /^https?:\/\//i.test(url);
}

function logDebug(enabled: boolean, ...args: unknown[]) {
  if (!enabled) return;
  console.log('[RcpSession]', ...args);
}

// ================= 核心类 =================

export class RcpSession {
  private readonly baseUrl?: string;
  private readonly defaultHeaders: Record<string, string>;
  private readonly defaultAutoRedirect: boolean;
  private readonly defaultMaxRedirects: number;
  private readonly defaultTimeoutMs?: number;
  private readonly defaultCollectTimeInfo: boolean;
  private readonly debug: boolean;
  private readonly cookieJar?: CookieJarLike;

  constructor(options?: RcpSessionOptions) {
    this.baseUrl = options?.baseUrl;
    this.defaultHeaders = options?.defaultHeaders ?? {};
    this.defaultAutoRedirect = options?.autoRedirect ?? true;
    this.defaultMaxRedirects = options?.maxAutoRedirects ?? 10;
    this.defaultTimeoutMs = options?.timeoutMs;
    this.defaultCollectTimeInfo = options?.collectTimeInfo ?? false;
    this.debug = !!options?.debug;
    this.cookieJar = options?.cookieJar;
  }

  async get(url: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    return this.fetch('GET', url, options);
  }

  async post(
    url: string,
    body?: string | ArrayBuffer | Uint8Array | Record<string, unknown>,
    options?: RcpRequestOptions,
  ): Promise<RcpResponseData> {
    return this.fetch('POST', url, { ...(options || {}), body });
  }

  async fetch(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'HEAD' | 'OPTIONS' | 'PATCH',
    url: string,
    options?: RcpRequestOptions & {
      body?: string | ArrayBuffer | Uint8Array | Record<string, unknown>;
    },
  ): Promise<RcpResponseData> {
    const {
      headers,
      query,
      autoRedirect,
      maxAutoRedirects,
      collectTimeInfo,
      timeoutMs,
      body,
    } = options ?? {};

    // 1) 拼 URL
    let finalUrl = url;
    if (!isAbsoluteUrl(finalUrl) && this.baseUrl) {
      finalUrl =
        this.baseUrl.replace(/\/+$/, '') +
          '/' +
        finalUrl.replace(/^\/+/, '');
    }
    const qs = buildQueryString(query);
    if (qs) {
      finalUrl += finalUrl.includes('?') ? '&' + qs.slice(1) : qs;
    }

    // 2) 合并 headers
    const mergedHeaders: Record<string, string> = {
      ...this.defaultHeaders,
      ...(headers ?? {}),
    };

    // CookieJar（如果有的话）
    if (this.cookieJar) {
      const cookie = this.cookieJar.getCookieHeader(finalUrl);
      if (cookie) {
        mergedHeaders['Cookie'] = cookie;
      }
    }

    logDebug(this.debug, 'REQ', method, finalUrl, 'headers=', mergedHeaders);

    // 3) 构造 Request content
    let content: any = undefined;
    if (body !== undefined && body !== null) {
      if (
        typeof body === 'string' ||
          body instanceof ArrayBuffer ||
          body instanceof Uint8Array
      ) {
        content = body;
      } else {
        // 默认 JSON
        content = JSON.stringify(body);
        if (!mergedHeaders['Content-Type']) {
          mergedHeaders['Content-Type'] = 'application/json;charset=utf-8';
        }
      }
    }

    // 4) 计算本次请求的控制参数
    const finalAutoRedirect =
      autoRedirect !== undefined ? autoRedirect : this.defaultAutoRedirect;
    const finalMaxRedirects =
      maxAutoRedirects !== undefined
        ? maxAutoRedirects
        : this.defaultMaxRedirects;
    const finalTimeoutMs =
      timeoutMs !== undefined ? timeoutMs : this.defaultTimeoutMs;
    const finalCollectTimeInfo =
      collectTimeInfo !== undefined
        ? collectTimeInfo
        : this.defaultCollectTimeInfo;

    // 5) 创建 Request，并设置 configuration
    const request = new rcp.Request(
      finalUrl,
      method,
      mergedHeaders as rcp.RequestHeaders,
      content as any,
    );

    const cfg: any = {
      transfer: {
        autoRedirect: finalAutoRedirect,
        maxAutoRedirects: finalMaxRedirects,
      },
    };

    if (finalTimeoutMs && finalTimeoutMs > 0) {
      cfg.transfer.timeout = {
        connectMs: finalTimeoutMs,
        transferMs: finalTimeoutMs,
        inactivityMs: finalTimeoutMs,
      };
    }

    if (finalCollectTimeInfo) {
      cfg.tracing = {
        collectTimeInfo: true,
      };
    }

    (request as any).configuration = cfg; // 使用 any，避免依赖未导出的 RequestConfiguration 类型

    // 6) 创建 session，发请求
    const session = rcp.createSession(); // 先用默认配置；后面如果需要拦截器等再扩展

    try {
      const resp: rcp.Response = await session.fetch(request);

      // 7) 回写 Cookie 到 CookieJar
      if (this.cookieJar && resp.headers) {
        const setCookieKey = Object.keys(resp.headers).find(
          (k) => k.toLowerCase() === 'set-cookie',
        );
        if (setCookieKey) {
          const raw: any = (resp.headers as any)[setCookieKey];
          if (Array.isArray(raw)) {
            this.cookieJar.updateFromSetCookie(finalUrl, raw);
          } else if (typeof raw === 'string') {
            this.cookieJar.updateFromSetCookie(finalUrl, raw);
          }
        }
      }

      const bodyText = resp.toString();
      logDebug(
        this.debug,
        'RESP',
        method,
        finalUrl,
        'status=',
        resp.statusCode,
        'effectiveUrl=',
        resp.effectiveUrl,
      );

      return {
        statusCode: resp.statusCode,
        headers: resp.headers,
        bodyText,
        effectiveUrl: resp.effectiveUrl,
        timeInfo: resp.timeInfo,
      };
    } catch (e) {
      const err = e as BusinessError;
      logDebug(this.debug, 'ERROR', method, finalUrl, err?.code, err?.message);
      throw err;
    } finally {
      try {
        session.close();
      } catch {
        // ignore
      }
    }
  }
}

export default RcpSession;
