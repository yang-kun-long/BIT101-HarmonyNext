// entry/src/main/ets/services/storage/LexueCookieStore.ts

import preferences from '@ohos.data.preferences';
import type { CookieDump } from '../../core/network/cookieJar';

const PREF_FILE = 'bit101_prefs';
const KEY_LEXUE_COOKIE_JAR = 'lexue_cookie_jar';

export class LexueCookieStore {
  // 和 TokenStore 一样的能力上下文注入方案
  private static abilityContext: any | null = null;

  /**
   * 在应用初始化时调用：
   *   LexueCookieStore.setAbilityContext(this.context);
   * 或者只在 EntryAbility.onCreate 里全局挂一次 globalThis.abilityContext 也行
   */
  static setAbilityContext(ctx: any) {
    LexueCookieStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = LexueCookieStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error(
        '[LexueCookieStore] abilityContext is not set. ' +
          'Call LexueCookieStore.setAbilityContext(context) at startup.'
      );
    }
    return ctx;
  }

  private async getPref() {
    const ctx = this.getAbilityContextOrThrow();
    return await preferences.getPreferences(ctx, PREF_FILE);
  }

  // ---------- 保存 / 读取 cookie dump ----------

  async saveCookieDump(dump: CookieDump): Promise<void> {
    const pref = await this.getPref();
    await pref.put(KEY_LEXUE_COOKIE_JAR, JSON.stringify(dump ?? []));
    await pref.flush();
  }

  async loadCookieDump(): Promise<CookieDump | null> {
    const pref = await this.getPref();
    const raw = (await pref.get(KEY_LEXUE_COOKIE_JAR, null)) as string | null;
    if (!raw) return null;

    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed as CookieDump;
      }
    } catch (e) {
      console.warn('[LexueCookieStore] 解析 cookie dump 失败，将忽略：', e);
    }
    return null;
  }

  async clearCookieDump(): Promise<void> {
    const pref = await this.getPref();
    await pref.delete(KEY_LEXUE_COOKIE_JAR);
    await pref.flush();
  }
}

/**
 * 可选：和 TokenStore 一样的初始化工具函数
 */
export function initLexueCookieStore(ctx: any) {
  LexueCookieStore.setAbilityContext(ctx);
}
