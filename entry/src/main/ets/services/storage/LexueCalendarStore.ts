// entry/src/main/ets/services/storage/LexueCalendarStore.ts

import preferences from '@ohos.data.preferences';
import type { LexueCalendarEvent } from '../lexue/LexueCalendarParser';
import { guardAsyncStorage } from './storageGuard';

const PREF_FILE = 'bit101_prefs';

const KEY_ICS_RAW = 'lexue_calendar_ics_raw';
const KEY_EVENTS_JSON = 'lexue_calendar_events_json';
const KEY_LAST_SYNC_TS = 'lexue_calendar_last_sync_ts';
const KEY_SUBSCRIBE_URL_CACHE = 'lexue_calendar_subscribe_url_cache';
interface CalendarUrlCacheItem {
  url: string;
  ts: number; // 毫秒时间戳
}

type CalendarUrlCache = Record<string, CalendarUrlCacheItem>;

// 缓存有效期：30 天
const URL_CACHE_TTL_MS = 30 * 24 * 3600 * 1000;

export class LexueCalendarStore {
  private static abilityContext: any | null = null;

  static setAbilityContext(ctx: any) {
    LexueCalendarStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = LexueCalendarStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error(
        '[LexueCalendarStore] abilityContext is not set. ' +
          'Call LexueCalendarStore.setAbilityContext(context) at startup.',
      );
    }
    return ctx;
  }

  private async getPref() {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage('preferences.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  async saveRawIcs(ics: string): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('LexueCalendarStore.saveRawIcs', async () => {
      await pref.put(KEY_ICS_RAW, ics ?? '');
      await pref.flush();
    });
  }

  async getRawIcs(): Promise<string | null> {
    const pref = await this.getPref();
    return await guardAsyncStorage('LexueCalendarStore.getRawIcs', async () =>
      (await pref.get(KEY_ICS_RAW, null)) as string | null,
    );
  }

  async saveEvents(events: LexueCalendarEvent[]): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('LexueCalendarStore.saveEvents', async () => {
      await pref.put(KEY_EVENTS_JSON, JSON.stringify(events ?? []));
      await pref.put(KEY_LAST_SYNC_TS, Date.now().toString());
      await pref.flush();
    });
  }

  async getEvents(): Promise<LexueCalendarEvent[]> {
    const pref = await this.getPref();
    const raw = await guardAsyncStorage('LexueCalendarStore.getEvents', async () =>
      (await pref.get(KEY_EVENTS_JSON, '[]')) as string,
    );
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed as LexueCalendarEvent[];
      }
      return [];
    } catch {
      return [];
    }
  }
  private makeCacheKey(userKey: string, baseUrl: string): string {
    return `${userKey}|${baseUrl}`;
  }
  private async loadUrlCache(): Promise<CalendarUrlCache> {
    const pref = await this.getPref();
    const raw = await guardAsyncStorage('LexueCalendarStore.loadUrlCache', async () =>
      (await pref.get(KEY_SUBSCRIBE_URL_CACHE, '')) as string,
    );
    if (!raw) return {};
    try {
      const obj = JSON.parse(raw);
      if (obj && typeof obj === 'object') {
        return obj as CalendarUrlCache;
      }
      return {};
    } catch {
      return {};
    }
  }

  private async saveUrlCache(cache: CalendarUrlCache): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('LexueCalendarStore.saveUrlCache', async () => {
      await pref.put(KEY_SUBSCRIBE_URL_CACHE, JSON.stringify(cache));
      await pref.flush();
    });
  }
  /**
   * 读缓存订阅 URL：
   * - 用 userKey + baseUrl 做 key
   * - 超过 TTL（30 天）自动失效
   */
  async getCachedSubscribeUrl(userKey: string, baseUrl: string): Promise<string | null> {
    if (!userKey) return null;
    const cache = await this.loadUrlCache();
    const key = this.makeCacheKey(userKey, baseUrl);
    const item = cache[key];
    if (!item || !item.url) return null;

    if (Date.now() - item.ts > URL_CACHE_TTL_MS) {
      // 过期，顺手删掉
      delete cache[key];
      await this.saveUrlCache(cache);
      return null;
    }
    return item.url;
  }

  /**
   * 写缓存订阅 URL
   */
  async setCachedSubscribeUrl(userKey: string, baseUrl: string, url: string): Promise<void> {
    if (!userKey || !url) return;
    const cache = await this.loadUrlCache();
    const key = this.makeCacheKey(userKey, baseUrl);
    cache[key] = { url, ts: Date.now() };
    await this.saveUrlCache(cache);
  }
  async getLastSyncTimestamp(): Promise<number | null> {
    const pref = await this.getPref();
    const raw = await guardAsyncStorage('LexueCalendarStore.getLastSyncTimestamp', async () =>
      (await pref.get(KEY_LAST_SYNC_TS, null)) as string | null,
    );
    if (!raw) return null;
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }

  async clear(): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('LexueCalendarStore.clear', async () => {
      await pref.delete(KEY_ICS_RAW);
      await pref.delete(KEY_EVENTS_JSON);
      await pref.delete(KEY_LAST_SYNC_TS);
      await pref.delete(KEY_SUBSCRIBE_URL_CACHE); // 新增这一行，顺便清掉 URL 缓存
      await pref.flush();
    });
  }
}

export function initLexueCalendarStore(ctx: any) {
  LexueCalendarStore.setAbilityContext(ctx);
}
