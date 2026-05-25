import preferences from '@ohos.data.preferences';
import type { CookieDump } from '../../core/network/cookieJar';
import { Logger } from '../../utils/Logger';
import { guardAsyncStorage } from './storageGuard';

const PREF_FILE = 'bit101_prefs';
const KEY_SCHOOL_COOKIE_JAR_WEBVPN = 'school_cookie_jar_webvpn';
const KEY_SCHOOL_COOKIE_JAR_INNER = 'school_cookie_jar_inner';

export type SchoolCookieScope = 'inner' | 'webvpn';

export class SchoolCookieStore {
  private logger = new Logger('SchoolCookieStore');
  private static abilityContext: any | null = null;
  private readonly scope: SchoolCookieScope;

  constructor(scope: SchoolCookieScope = 'webvpn') {
    this.scope = scope;
  }

  static setAbilityContext(ctx: any): void {
    SchoolCookieStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = SchoolCookieStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error('[SchoolCookieStore] abilityContext is not set. Call SchoolCookieStore.setAbilityContext(context) at startup.');
    }
    return ctx;
  }

  private async getPref() {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage('SchoolCookieStore.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  private key(): string {
    return this.scope === 'webvpn' ? KEY_SCHOOL_COOKIE_JAR_WEBVPN : KEY_SCHOOL_COOKIE_JAR_INNER;
  }

  async saveCookieDump(dump: CookieDump): Promise<void> {
    const pref = await this.getPref();
    const key = this.key();
    await guardAsyncStorage('SchoolCookieStore.saveCookieDump', async () => {
      await pref.put(key, JSON.stringify(dump ?? []));
      await pref.flush();
    });
  }

  async loadCookieDump(): Promise<CookieDump | null> {
    const pref = await this.getPref();
    const raw = await guardAsyncStorage('SchoolCookieStore.loadCookieDump', async () =>
      (await pref.get(this.key(), null)) as string | null,
    );
    if (!raw) return null;

    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed as CookieDump;
      }
    } catch (e) {
      this.logger.warn('parse cookie dump failed:', e);
    }
    return null;
  }

  async clearCookieDump(): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('SchoolCookieStore.clearCookieDump', async () => {
      await pref.delete(this.key());
      await pref.flush();
    });
  }
}

export function initSchoolCookieStore(ctx: any): void {
  SchoolCookieStore.setAbilityContext(ctx);
}
