// entry/src/main/ets/services/storage/tokenStore.ts
// 持久化存储：BIT101 会话（fake_cookie）、WebVPN 会话（cookie）、业务 token 与用户信息
// 依赖：@ohos.data.preferences

import preferences from '@ohos.data.preferences';

const PREF_FILE = 'bit101_prefs';

// 业务 token（若后端在 /user/webvpn_verify 或其他登录接口返回）
const KEY_TOKEN = 'access_token';
// 用户信息（JSON 字符串）
const KEY_USER = 'user_info';

// BIT101 自身后台使用的会话 cookie
const KEY_FAKE_COOKIE = 'bit101_fake_cookie';
// 教务(WebVPN)使用的会话 cookie（只有 verify 成功后才写入）
const KEY_WEBVPN_COOKIE = 'webvpn_cookie';

// 可选：其它会话字段，按需扩展
// const KEY_REFRESH_TOKEN = 'refresh_token';

function redact(str: string | null | undefined, keepStart = 4, keepEnd = 3): string {
  if (!str) return '';
  const s = String(str);
  if (s.length <= keepStart + keepEnd) return '*'.repeat(s.length);
  return s.slice(0, keepStart) + '***' + s.slice(-keepEnd);
}

export class TokenStore {
  // 允许在应用启动时注入 stageAbility 上下文，避免某些环境下无法自动获取。
  private static abilityContext: any | null = null;

  /**
   * 在应用初始化（如 EntryAbility.onCreate）时调用：
   *   TokenStore.setAbilityContext(this.context);
   */
  static setAbilityContext(ctx: any) {
    TokenStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    // 优先使用显式注入的上下文；其次尝试 globalThis.abilityContext（如果你在入口处挂载过）
    const ctx = TokenStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      // 对于部分场景，DevEco 会把 context 暴露到全局。若没有，请在入口显式注入。
      // 例如在 EntryAbility.onCreate 中：
      //   globalThis.abilityContext = this.context;
      //   TokenStore.setAbilityContext(this.context);
      throw new Error('[TokenStore] abilityContext is not set. Call TokenStore.setAbilityContext(context) at startup.');
    }
    return ctx;
  }

  private async getPref() {
    const ctx = this.getAbilityContextOrThrow();
    return await preferences.getPreferences(ctx, PREF_FILE);
  }

  // ---------- Access Token ----------
  async saveToken(token: string) {
    const pref = await this.getPref();
    await pref.put(KEY_TOKEN, token);
    await pref.flush();
  }

  async getToken(): Promise<string | null> {
    const pref = await this.getPref();
    return (await pref.get(KEY_TOKEN, null)) as (string | null);
  }

  // ---------- User Info ----------
  async saveUserInfo(user: unknown) {
    const pref = await this.getPref();
    await pref.put(KEY_USER, JSON.stringify(user ?? {}));
    await pref.flush();
  }

  async getUserInfo<T = any>(): Promise<T | null> {
    const pref = await this.getPref();
    const raw = (await pref.get(KEY_USER, null)) as (string | null);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }

  // ---------- BIT101 fake_cookie ----------
  async saveFakeCookie(v: string) {
    const pref = await this.getPref();
    await pref.put(KEY_FAKE_COOKIE, v);
    await pref.flush();
  }

  async getFakeCookie(): Promise<string | null> {
    const pref = await this.getPref();
    return (await pref.get(KEY_FAKE_COOKIE, null)) as (string | null);
  }

  // ---------- WebVPN cookie ----------
  async saveWebvpnCookie(v: string) {
    const pref = await this.getPref();
    await pref.put(KEY_WEBVPN_COOKIE, v);
    await pref.flush();
  }

  async getWebvpnCookie(): Promise<string | null> {
    const pref = await this.getPref();
    console.info(KEY_WEBVPN_COOKIE);
    return (await pref.get(KEY_WEBVPN_COOKIE, null)) as (string | null);
  }

  // ---------- Helpers ----------
  async isLoggedInBit101(): Promise<boolean> {
    const fake = await this.getFakeCookie();
    return !!(fake && fake.length > 0);
  }

  async isLoggedInWebvpn(): Promise<boolean> {
    const cookie = await this.getWebvpnCookie();
    return !!(cookie && cookie.length > 0);
  }

  /**
   * 清空所有会话信息（登出）
   */
  async clear() {
    const pref = await this.getPref();
    await pref.delete(KEY_TOKEN);
    await pref.delete(KEY_USER);
    await pref.delete(KEY_FAKE_COOKIE);
    await pref.delete(KEY_WEBVPN_COOKIE);
    await pref.flush();
  }

  /**
   * 便于调试时查看当前存储快照（会对敏感字段脱敏）
   */
  async dumpSnapshot(): Promise<Record<string, string | null>> {
    const [token, fake, webvpn, userStr] = await Promise.all([
      this.getToken(),
      this.getFakeCookie(),
      this.getWebvpnCookie(),
      (async () => {
        const pref = await this.getPref();
        return (await pref.get(KEY_USER, null)) as (string | null);
      })()
    ]);

    return {
      access_token: token ? redact(token) : null,
      bit101_fake_cookie: fake ? redact(fake) : null,
      webvpn_cookie: webvpn ? redact(webvpn) : null,
      user_info_len: userStr ? String(userStr.length) : null
    };
  }
}

/**
 * 可选：在应用入口快速初始化上下文
 * 例：
 *   // EntryAbility.onCreate():
 *   initTokenStore(this.context);
 */
export function initTokenStore(ctx: any) {
  TokenStore.setAbilityContext(ctx);
}
