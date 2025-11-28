// entry/src/main/ets/services/storage/LexueCookieStore.ts
import { Logger } from '../../utils/Logger';
import preferences from '@ohos.data.preferences';
import type { CookieDump } from '../../core/network/cookieJar';

const PREF_FILE = 'bit101_prefs';

// 拆成两套 key，内网 / WebVPN 分开存
const KEY_LEXUE_COOKIE_JAR_INNER = 'lexue_cookie_jar_inner';
const KEY_LEXUE_COOKIE_JAR_WEBVPN = 'lexue_cookie_jar_webvpn';
// 兼容旧版本的 key（之前所有 cookie 都存在这个下面）
const KEY_LEXUE_COOKIE_JAR_LEGACY = 'lexue_cookie_jar';

export type LexueCookieScope = 'inner' | 'webvpn';

export class LexueCookieStore {
  private logger = new Logger('LexueCookieStore');
  // 和 TokenStore 一样的能力上下文注入方案
  private static abilityContext: any | null = null;

  private readonly scope: LexueCookieScope;

  constructor(scope: LexueCookieScope = 'inner') {
    this.scope = scope;
  }

  /**
   * 在应用初始化时调用：
   *   LexueCookieStore.setAbilityContext(this.context);
   * 或者只在 EntryAbility.onCreate 里全局挂一次 globalThis.abilityContext 也行
   */
  static setAbilityContext(ctx: any) {
    LexueCookieStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx =
      LexueCookieStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error(
        '[LexueCookieStore] abilityContext is not set. ' +
          'Call LexueCookieStore.setAbilityContext(context) at startup.',
      );
    }
    return ctx;
  }

  private async getPref() {
    const ctx = this.getAbilityContextOrThrow();
    return await preferences.getPreferences(ctx, PREF_FILE);
  }

  private getKeyForScope(): string {
    return this.scope === 'webvpn'
      ? KEY_LEXUE_COOKIE_JAR_WEBVPN
      : KEY_LEXUE_COOKIE_JAR_INNER;
  }

  // ---------- 保存 / 读取 cookie dump ----------

  async saveCookieDump(dump: CookieDump): Promise<void> {
    const pref = await this.getPref();
    const key = this.getKeyForScope();
    await pref.put(key, JSON.stringify(dump ?? []));
    await pref.flush();
  }

  async loadCookieDump(): Promise<CookieDump | null> {
    const pref = await this.getPref();
    const key = this.getKeyForScope();

    // 先按作用域的 key 读
    let raw = (await pref.get(key, null)) as string | null;

    // 为了兼容旧版本：inner 模式下如果新 key 没有数据，再尝试读老 key
    if (!raw && this.scope === 'inner') {
      raw = (await pref.get(
        KEY_LEXUE_COOKIE_JAR_LEGACY,
        null,
      )) as string | null;
    }

    if (!raw) return null;

    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed as CookieDump;
      }
    } catch (e) {
      this.logger.warn('解析 cookie dump 失败，将忽略：', e);
    }
    return null;
  }

  async clearCookieDump(): Promise<void> {
    const pref = await this.getPref();
    const key = this.getKeyForScope();

    await pref.delete(key);

    // inner 模式顺带把老 key 一起清掉，防止脏数据残留
    if (this.scope === 'inner') {
      await pref.delete(KEY_LEXUE_COOKIE_JAR_LEGACY);
    }

    await pref.flush();
  }
}

/**
 * 可选：和 TokenStore 一样的初始化工具函数
 */
export function initLexueCookieStore(ctx: any) {
  LexueCookieStore.setAbilityContext(ctx);
}
