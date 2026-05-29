import preferences from '@ohos.data.preferences';
import type { LexueCalendarEvent } from '../lexue/LexueCalendarParser';
import {
  buildDdlItemFromManualInput,
  createManualDdlUid,
  deleteDdlItem,
  listVisibleDdlItems,
  mergeLexueEventsWithDdlItems,
  parseDdlItemsJson,
  toggleDdlDone,
  upsertManualDdlItem,
} from '../deadline/DdlModels';
import type { DdlItem, ManualDdlInput } from '../deadline/DdlModels';
import { guardAsyncStorage } from './storageGuard';

const PREF_FILE = 'ddl_store';
const KEY_ITEMS_JSON = 'ddl_items_json';

export class DdlStore {
  private static abilityContext: any | null = null;

  static setAbilityContext(ctx: any): void {
    DdlStore.abilityContext = ctx;
  }

  private getAbilityContextOrThrow(): any {
    const ctx = DdlStore.abilityContext ?? (globalThis as any)?.abilityContext;
    if (!ctx) {
      throw new Error('[DdlStore] abilityContext is not set.');
    }
    return ctx;
  }

  private async getPref(): Promise<preferences.Preferences> {
    const ctx = this.getAbilityContextOrThrow();
    return await guardAsyncStorage<preferences.Preferences>('DdlStore.getPreferences', async () =>
      await preferences.getPreferences(ctx, PREF_FILE),
    );
  }

  async getItems(): Promise<DdlItem[]> {
    const pref = await this.getPref();
    const raw = await guardAsyncStorage('DdlStore.getItems', async () =>
      (await pref.get(KEY_ITEMS_JSON, '[]')) as string,
    );
    return parseDdlItemsJson(raw);
  }

  async saveItems(items: DdlItem[]): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('DdlStore.saveItems', async () => {
      await pref.put(KEY_ITEMS_JSON, JSON.stringify(items));
      await pref.flush();
    });
  }

  async getVisibleItems(nowMs: number, retentionDays: number = 0): Promise<DdlItem[]> {
    const items = await this.getItems();
    return listVisibleDdlItems(items, nowMs, retentionDays);
  }

  async syncLexueEvents(events: LexueCalendarEvent[], updatedAt: number = Date.now()): Promise<DdlItem[]> {
    const items = await this.getItems();
    const merged = mergeLexueEventsWithDdlItems(items, events, updatedAt);
    await this.saveItems(merged);
    return merged;
  }

  async addManual(input: ManualDdlInput, updatedAt: number = Date.now()): Promise<DdlItem> {
    const items = await this.getItems();
    const uid = createManualDdlUid(updatedAt, items.length + 1);
    const item = buildDdlItemFromManualInput(input, uid, updatedAt);
    const updated = upsertManualDdlItem(items, input, uid, updatedAt);
    await this.saveItems(updated);
    return item;
  }

  async updateManual(uid: string, input: ManualDdlInput, updatedAt: number = Date.now()): Promise<void> {
    const items = await this.getItems();
    const updated = upsertManualDdlItem(items, input, uid, updatedAt);
    await this.saveItems(updated);
  }

  async setDone(uid: string, done: boolean, updatedAt: number = Date.now()): Promise<void> {
    const items = await this.getItems();
    const updated = toggleDdlDone(items, uid, done, updatedAt);
    await this.saveItems(updated);
  }

  async delete(uid: string): Promise<void> {
    const items = await this.getItems();
    await this.saveItems(deleteDdlItem(items, uid));
  }

  async clear(): Promise<void> {
    const pref = await this.getPref();
    await guardAsyncStorage('DdlStore.clear', async () => {
      await pref.delete(KEY_ITEMS_JSON);
      await pref.flush();
    });
  }
}

export function initDdlStore(ctx: any): void {
  DdlStore.setAbilityContext(ctx);
}
