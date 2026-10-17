import { describe, it, expect } from '@ohos/hypium';
import { AboutSettingsBackend, AboutSettingsStore } from '../main/ets/services/storage/AboutSettingsStore';

class MemoryAboutSettingsBackend implements AboutSettingsBackend {
  value: string = '';
  failWrite: boolean = false;

  async read(): Promise<string> { return this.value; }
  async write(value: string): Promise<void> {
    if (this.failWrite) throw new Error('disk unavailable');
    this.value = value;
  }
}

export default function aboutSettingsTest() {
  describe('About settings persistence', () => {
    it('loads defaults then retains settings across store instances', 0, async () => {
      const backend = new MemoryAboutSettingsBackend();
      const first = new AboutSettingsStore(backend);
      expect((await first.load()).autoDetectUpgrade).assertTrue();
      await first.save({ autoDetectUpgrade: false, ignoredVersion: 9, lastCheckTime: 123 });
      const restored = await new AboutSettingsStore(backend).load();
      expect(restored.autoDetectUpgrade).assertFalse();
      expect(restored.ignoredVersion).assertEqual(9);
      expect(restored.lastCheckTime).assertEqual(123);
    });

    it('recovers from corrupt storage and normalizes invalid persisted values', 0, async () => {
      const backend = new MemoryAboutSettingsBackend();
      backend.value = '{';
      expect((await new AboutSettingsStore(backend).load()).autoDetectUpgrade).assertTrue();
      backend.value = '{"autoDetectUpgrade":"false","ignoredVersion":-1,"lastCheckTime":null}';
      const restored = await new AboutSettingsStore(backend).load();
      expect(restored.autoDetectUpgrade).assertTrue();
      expect(restored.ignoredVersion).assertEqual(0);
      expect(restored.lastCheckTime).assertEqual(0);
    });

    it('reports a write failure and preserves previously persisted settings', 0, async () => {
      const backend = new MemoryAboutSettingsBackend();
      const store = new AboutSettingsStore(backend);
      await store.save({ autoDetectUpgrade: true, ignoredVersion: 0, lastCheckTime: 0 });
      backend.failWrite = true;
      let failed = false;
      try {
        await store.save({ autoDetectUpgrade: false, ignoredVersion: 8, lastCheckTime: 42 });
      } catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect((await store.load()).autoDetectUpgrade).assertTrue();
    });
  });
}
