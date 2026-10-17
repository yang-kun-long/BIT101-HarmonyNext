import { describe, it, expect } from '@ohos/hypium';
import { GallerySettingsBackend, GallerySettingsStore, defaultGallerySettings } from '../main/ets/services/storage/GallerySettingsStore';

class MemoryGalleryBackend implements GallerySettingsBackend {
  value: string = '';
  fail: boolean = false;
  async read(): Promise<string> { return this.value; }
  async write(value: string): Promise<void> { if (this.fail) throw new Error('disk'); this.value = value; }
}

export default function gallerySettingsTest() {
  describe('Gallery settings', () => {
    it('restores defaults and all preferences across store instances', 0, async () => {
      const backend = new MemoryGalleryBackend();
      const store = new GallerySettingsStore(backend);
      const defaults = await store.load();
      expect(defaults.allowHorizontalScroll).assertTrue();
      expect(defaults.hideBot || defaults.hideBotInSearch || defaults.hideAnonymous || defaults.strict).assertFalse();
      expect(defaults.hiddenUids.length).assertEqual(0);
      defaults.hideBot = true; defaults.hideBotInSearch = true; defaults.hideAnonymous = true;
      defaults.strict = true; defaults.allowHorizontalScroll = false; defaults.hiddenUids = ['42', '42', '-1', 'bad'];
      await store.save(defaults);
      const restored = await new GallerySettingsStore(backend).load();
      expect(restored.hideBot && restored.hideBotInSearch && restored.hideAnonymous && restored.strict).assertTrue();
      expect(restored.allowHorizontalScroll).assertFalse();
      expect(restored.hiddenUids.join(',')).assertEqual('42');
      const snapshot = store.snapshot(); snapshot.hiddenUids.push('99');
      expect(store.snapshot().hiddenUids.join(',')).assertEqual('42');
    });

    it('recovers corrupt values and publishes only successful saves', 0, async () => {
      const backend = new MemoryGalleryBackend(); backend.value = '{';
      const store = new GallerySettingsStore(backend);
      expect((await store.load()).allowHorizontalScroll).assertTrue();
      backend.value = '{"hideBot":"true","hiddenUids":null,"allowHorizontalScroll":null}';
      expect((await store.load()).hideBot).assertFalse();
      let calls = 0; const release = store.subscribe(() => { calls++; });
      const next = defaultGallerySettings(); next.hideBot = true;
      backend.fail = true;
      let failed = false; try { await store.save(next); } catch (_) { failed = true; }
      expect(failed).assertTrue(); expect(calls).assertEqual(0); expect(store.snapshot().hideBot).assertFalse();
      backend.fail = false; await store.save(next); expect(calls).assertEqual(1);
      release(); await store.save(defaultGallerySettings()); expect(calls).assertEqual(1);
    });
  });
}
