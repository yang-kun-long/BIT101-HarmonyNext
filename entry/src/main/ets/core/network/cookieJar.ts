// entry/src/main/ets/core/network/cookieJar.ts
// 一个简单的 CookieJar 实现：
// - 解析 Set-Cookie 字符串
// - 按 domain + path 存储 cookie
// - 为指定 URL 生成 Cookie 头
import ohosUrl from '@ohos.url'; // <-- 改成这行
import type { CookieJarLike } from './rcpSession';

interface CookieItem {
  name: string;
  value: string;
  domain: string;
  path: string;
  secure: boolean;
  httpOnly: boolean;
  // 过期时间（毫秒时间戳），undefined 表示会话 Cookie
  expires?: number;
}
interface CookieItem {
  name: string;
  value: string;
  domain: string;
  path: string;
  secure: boolean;
  httpOnly: boolean;
  // 过期时间（毫秒时间戳），undefined 表示会话 Cookie
  expires?: number;
}

// ✅ 新增：导出 dump 类型，方便别的模块引用
export type CookieDump = CookieItem[];

function parseUrl(url: string): { host: string; path: string } {
  try {
    const u = new ohosUrl.URL(url); // <-- 使用 ohosUrl.URL
    const host = u.hostname;
    let path = u.pathname || '/';
    if (!path.startsWith('/')) path = '/' + path;
    return { host, path };
  } catch {
    // 兜底：尽量不让报错
    return { host: '', path: '/' };
  }
}

function domainMatch(host: string, cookieDomain: string): boolean {
  if (!host || !cookieDomain) return false;
  if (host === cookieDomain) return true;
  // 子域名匹配：如 host=lexue.bit.edu.cn, cookieDomain=bit.edu.cn
  return host.endsWith('.' + cookieDomain);
}

function defaultPath(path: string): string {
  if (!path || !path.startsWith('/')) return '/';
  const idx = path.lastIndexOf('/');
  if (idx <= 0) return '/';
  return path.slice(0, idx + 1);
}

export class SimpleCookieJar implements CookieJarLike {
  private cookies: CookieItem[] = [];

  getCookieHeader(url: string): string | undefined {
    const { host, path } = parseUrl(url);
    const now = Date.now();

    // 先清理过期 cookie
    this.cookies = this.cookies.filter((c) => !c.expires || c.expires > now);

    const usable = this.cookies.filter((c) => {
      if (!domainMatch(host, c.domain)) return false;
      if (!path.startsWith(c.path)) return false;
      return true;
    });

    if (!usable.length) return undefined;

    // 可选：按 path 长度排序，让更具体的 path 在前（对服务端一般无影响，只是习惯）
    usable.sort((a, b) => b.path.length - a.path.length);

    return usable.map((c) => `${c.name}=${c.value}`).join('; ');
  }

  updateFromSetCookie(url: string, setCookie: string | string[]): void {
    const { host, path } = parseUrl(url);
    const baseDomain = host;
    const basePath = defaultPath(path);

    const lines = Array.isArray(setCookie) ? setCookie : [setCookie];

    for (const line of lines) {
      if (!line) continue;
      // 形如：name=value; Path=/; Domain=xxx; HttpOnly; Secure; Expires=...
      const parts = line.split(';');
      if (!parts.length) continue;

      const [nameValue, ...attrParts] = parts;
      const nv = nameValue.trim();
      const eqIdx = nv.indexOf('=');
      if (eqIdx <= 0) continue;

      const name = nv.slice(0, eqIdx).trim();
      const value = nv.slice(eqIdx + 1).trim();

      if (!name) continue;

      let domain = baseDomain;
      let cPath = basePath;
      let secure = false;
      let httpOnly = false;
      let expires: number | undefined = undefined;

      for (const rawAttr of attrParts) {
        const attr = rawAttr.trim();
        if (!attr) continue;
        const [kRaw, ...vRest] = attr.split('=');
        const k = kRaw.trim().toLowerCase();
        const v = vRest.join('=').trim(); // 有些值里会有 '='

        if (k === 'domain' && v) {
          // 去掉开头的 .
          domain = v.startsWith('.') ? v.slice(1) : v;
        } else if (k === 'path' && v) {
          cPath = v;
        } else if (k === 'secure') {
          secure = true;
        } else if (k === 'httponly') {
          httpOnly = true;
        } else if (k === 'expires' && v) {
          const ts = Date.parse(v);
          if (!isNaN(ts)) {
            expires = ts;
          }
        } else if (k === 'max-age' && v) {
          const sec = parseInt(v, 10);
          if (!isNaN(sec) && sec >= 0) {
            expires = Date.now() + sec * 1000;
          }
        }
      }

      // 更新 / 插入 cookie
      const existingIdx = this.cookies.findIndex(
        (c) =>
        c.name === name &&
          c.domain === domain &&
          c.path === cPath,
      );

      const item: CookieItem = {
        name,
        value,
        domain,
        path: cPath || '/',
        secure,
        httpOnly,
        expires,
      };

      if (existingIdx >= 0) {
        this.cookies[existingIdx] = item;
      } else {
        this.cookies.push(item);
      }
    }
  }
  restoreFromDump(dump: CookieDump | null | undefined): void {
    if (!dump || !Array.isArray(dump)) return;

    const now = Date.now();
    const restored: CookieItem[] = [];

    for (const raw of dump) {
      if (!raw || typeof raw.name !== 'string' || typeof raw.value !== 'string') {
        continue;
      }

      const expires =
        typeof raw.expires === 'number' && raw.expires > 0 ? raw.expires : undefined;

      // 跳过已经过期的 cookie
      if (expires && expires <= now) continue;

      restored.push({
        name: raw.name,
        value: raw.value,
        domain: raw.domain || '',
        path: raw.path || '/',
        secure: !!raw.secure,
        httpOnly: !!raw.httpOnly,
        expires,
      });
    }

    this.cookies = restored;
  }
  /**
   * 调试用：返回当前 cookie 快照
   */
  dump(): CookieItem[] {
    return [...this.cookies];
  }

  /**
   * 清空所有 cookie（比如登出时）
   */
  clear(): void {
    this.cookies = [];
  }
}

export default SimpleCookieJar;
