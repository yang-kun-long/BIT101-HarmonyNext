import { describe, it, expect } from '@ohos/hypium';
import { defaultPageSettings, LegacyPageSettings, migratePageSettings, NavigationPage, resolveStartupTab, validatePageSettings } from '../main/ets/services/settings/PageSettingsModel';
import { PageSettingsBackend, PageSettingsStore } from '../main/ets/services/storage/PageSettingsStore';

class MemoryPageSettingsBackend implements PageSettingsBackend {
  value: string = '';
  failWrite: boolean = false;
  async read(): Promise<string> { return this.value; }
  async write(value: string): Promise<void> {
    if (this.failWrite) throw new Error('disk unavailable');
    this.value = value;
  }
}

export default function pageSettingsTest() {
  describe('Page settings', () => {
    it('merges legacy aliases, preserves order and keeps home and mine visible', 0, () => {
      const legacy: LegacyPageSettings = {
        order: ['Post', 'DDL', 'Home', 'Schedule', 'unknown', 'Map', 'Post'],
        hidden: ['DDL', 'Home', 'Mine', 'Forum', 'Forum'],
        home: 'Home',
      };
      const settings = migratePageSettings(legacy);
      expect(settings.order.join(',')).assertEqual('Post,Schedule,Map,Forum,Mine');
      expect(settings.hidden.join(',')).assertEqual('Forum');
      expect(settings.home).assertEqual(NavigationPage.Schedule);
    });

    it('uses the chosen cold-start home and lets valid explicit routes take priority', 0, () => {
      expect(resolveStartupTab(NavigationPage.Post)).assertEqual(3);
      expect(resolveStartupTab(NavigationPage.Mine)).assertEqual(4);
      expect(resolveStartupTab(NavigationPage.Post, 1)).assertEqual(1);
      expect(resolveStartupTab(NavigationPage.Post, -1)).assertEqual(3);
      expect(resolveStartupTab(NavigationPage.Post, 5)).assertEqual(3);
      expect(resolveStartupTab(NavigationPage.Post, 1.5)).assertEqual(3);
      expect(resolveStartupTab(NavigationPage.Post, Number.NaN)).assertEqual(3);
    });

    it('persists migration and restores it independently of legacy keys', 0, async () => {
      const backend = new MemoryPageSettingsBackend();
      const legacy: LegacyPageSettings = { order: ['Map', 'Home'], hidden: ['Forum'], home: 'Map' };
      await new PageSettingsStore(backend).load(legacy);
      const restored = await new PageSettingsStore(backend).load();
      expect(restored.home).assertEqual(NavigationPage.Map);
      expect(restored.order[0]).assertEqual(NavigationPage.Map);
      expect(restored.hidden.join(',')).assertEqual('Forum');
    });

    it('recovers malformed and incomplete storage without losing navigation entries', 0, async () => {
      const backend = new MemoryPageSettingsBackend();
      const store = new PageSettingsStore(backend);
      backend.value = '{';
      expect((await store.load()).order.length).assertEqual(5);
      backend.value = 'null';
      expect((await store.load()).home).assertEqual(NavigationPage.Schedule);
      backend.value = '{"order":false,"hidden":{},"home":"invalid"}';
      expect((await store.load()).order.join(',')).assertEqual(defaultPageSettings().order.join(','));
      backend.value = '{"order":["Mine",17,null],"hidden":["Mine","Map"],"home":"Mine"}';
      const settings = await store.load();
      expect(settings.order[0]).assertEqual(NavigationPage.Mine);
      expect(settings.hidden.join(',')).assertEqual('Map');
    });

    it('rejects hidden home, hidden mine and duplicate entries', 0, () => {
      const settings = defaultPageSettings();
      settings.hidden = [settings.home];
      let failures = 0;
      try { validatePageSettings(settings); } catch (_) { failures++; }
      settings.hidden = [NavigationPage.Mine];
      try { validatePageSettings(settings); } catch (_) { failures++; }
      settings.hidden = [];
      settings.order[1] = settings.order[0];
      try { validatePageSettings(settings); } catch (_) { failures++; }
      expect(failures).assertEqual(3);
    });

    it('reports failed saves and migrations without overwriting the previous value', 0, async () => {
      const backend = new MemoryPageSettingsBackend();
      const store = new PageSettingsStore(backend);
      const settings = defaultPageSettings();
      await store.save(settings);
      const original = backend.value;
      backend.failWrite = true;
      settings.home = NavigationPage.Map;
      let failures = 0;
      try { await store.save(settings); } catch (_) { failures++; }
      try { await store.load(); } catch (_) { failures++; }
      expect(failures).assertEqual(2);
      expect(backend.value).assertEqual(original);
    });
  });
}
