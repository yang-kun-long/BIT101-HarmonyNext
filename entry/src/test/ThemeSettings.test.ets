import { describe, it, expect } from '@ohos/hypium';
import { DarkThemeMode, defaultThemeSettings, ThemeSettings } from '../main/ets/services/settings/ThemeSettingsModel';
import { ThemeSettingsBackend, ThemeSettingsStore } from '../main/ets/services/storage/ThemeSettingsStore';
import { ThemeSettingsController, ThemeSettingsTarget } from '../main/ets/services/settings/ThemeSettingsController';

class MemoryThemeSettingsBackend implements ThemeSettingsBackend {
  value: string = '';
  failWrite: boolean = false;
  async read(): Promise<string> { return this.value; }
  async write(value: string): Promise<void> {
    if (this.failWrite) throw new Error('disk unavailable');
    this.value = value;
  }
}

class RecordingThemeTarget implements ThemeSettingsTarget {
  applied: ThemeSettings[] = [];
  failDark: boolean = false;
  pending: Promise<void> | null = null;
  async apply(settings: ThemeSettings): Promise<void> {
    this.applied.push(settings);
    if (this.failDark && settings.darkThemeMode === DarkThemeMode.Dark) throw new Error('window unavailable');
    if (this.pending) await this.pending;
  }
}

export default function themeSettingsTest() {
  describe('Theme settings', () => {
    it('restores persisted mode and orientation before applying them', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const store = new ThemeSettingsStore(backend);
      await store.save({ darkThemeMode: DarkThemeMode.Dark, autoRotate: true });
      const target = new RecordingThemeTarget();
      const controller = new ThemeSettingsController(new ThemeSettingsStore(backend), target);
      const settings = await controller.load();
      expect(settings.darkThemeMode).assertEqual(DarkThemeMode.Dark);
      expect(target.applied[0].autoRotate).assertTrue();
      expect(controller.snapshot().darkThemeMode).assertEqual(DarkThemeMode.Dark);
    });

    it('defaults missing and malformed values without coercing string booleans', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const store = new ThemeSettingsStore(backend);
      expect((await store.load()).darkThemeMode).assertEqual(DarkThemeMode.System);
      backend.value = '{';
      expect((await store.load()).autoRotate).assertFalse();
      backend.value = 'null';
      expect((await store.load()).darkThemeMode).assertEqual(DarkThemeMode.System);
      backend.value = '{"darkThemeMode":"unknown","autoRotate":"true"}';
      expect((await store.load()).autoRotate).assertFalse();
      expect((await store.load()).darkThemeMode).assertEqual(DarkThemeMode.System);
    });

    it('applies all three modes and retains changes across controller instances', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const store = new ThemeSettingsStore(backend);
      const target = new RecordingThemeTarget();
      const controller = new ThemeSettingsController(store, target);
      await controller.load();
      await controller.save({ darkThemeMode: DarkThemeMode.Light, autoRotate: true });
      expect((await store.load()).darkThemeMode).assertEqual(DarkThemeMode.Light);
      await controller.save({ darkThemeMode: DarkThemeMode.Dark, autoRotate: false });
      expect((await store.load()).darkThemeMode).assertEqual(DarkThemeMode.Dark);
      await controller.save(defaultThemeSettings());
      const restored = await new ThemeSettingsController(store, new RecordingThemeTarget()).load();
      expect(restored.darkThemeMode).assertEqual(DarkThemeMode.System);
      expect(restored.autoRotate).assertFalse();
    });

    it('rolls back runtime changes and keeps the previous disk value when saving fails', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const store = new ThemeSettingsStore(backend);
      const target = new RecordingThemeTarget();
      const controller = new ThemeSettingsController(store, target);
      await controller.load();
      backend.failWrite = true;
      let failed = false;
      try { await controller.save({ darkThemeMode: DarkThemeMode.Dark, autoRotate: true }); }
      catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect(target.applied[target.applied.length - 1].darkThemeMode).assertEqual(DarkThemeMode.System);
      expect(controller.snapshot().autoRotate).assertFalse();
      expect((await store.load()).autoRotate).assertFalse();
    });

    it('rolls back partial window changes and does not persist a rejected mode', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const target = new RecordingThemeTarget();
      const controller = new ThemeSettingsController(new ThemeSettingsStore(backend), target);
      await controller.load();
      target.failDark = true;
      let failed = false;
      try { await controller.save({ darkThemeMode: DarkThemeMode.Dark, autoRotate: true }); }
      catch (_) { failed = true; }
      expect(failed).assertTrue();
      expect(backend.value).assertEqual('');
      expect(target.applied[target.applied.length - 1].darkThemeMode).assertEqual(DarkThemeMode.System);
    });

    it('rejects overlapping changes and returns independent snapshots', 0, async () => {
      const backend = new MemoryThemeSettingsBackend();
      const target = new RecordingThemeTarget();
      const controller = new ThemeSettingsController(new ThemeSettingsStore(backend), target);
      await controller.load();
      let release: () => void = () => {};
      target.pending = new Promise<void>(resolve => { release = resolve; });
      const first = controller.save({ darkThemeMode: DarkThemeMode.Light, autoRotate: true });
      let failed = false;
      try { await controller.save(defaultThemeSettings()); } catch (_) { failed = true; }
      release();
      await first;
      expect(failed).assertTrue();
      const snapshot = controller.snapshot();
      snapshot.autoRotate = false;
      expect(controller.snapshot().autoRotate).assertTrue();
    });
  });
}
