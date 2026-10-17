import { ThemeSettingsStore } from '../storage/ThemeSettingsStore';
import { defaultThemeSettings, normalizeThemeSettings, ThemeSettings } from './ThemeSettingsModel';

export interface ThemeSettingsTarget {
  apply(settings: ThemeSettings): Promise<void>;
}

/** Serialize changes and restore the previous runtime mode when apply/save fails. */
export class ThemeSettingsController {
  private readonly store: ThemeSettingsStore;
  private readonly target: ThemeSettingsTarget;
  private current: ThemeSettings = defaultThemeSettings();
  private busy: boolean = false;

  constructor(store: ThemeSettingsStore, target: ThemeSettingsTarget) {
    this.store = store;
    this.target = target;
  }

  snapshot(): ThemeSettings { return normalizeThemeSettings(this.current); }

  async load(): Promise<ThemeSettings> {
    const settings = await this.store.load();
    await this.target.apply(settings);
    this.current = settings;
    return normalizeThemeSettings(settings);
  }

  async save(settings: ThemeSettings): Promise<ThemeSettings> {
    if (this.busy) throw new Error('Theme settings are busy');
    this.busy = true;
    const next = normalizeThemeSettings(settings);
    try {
      await this.target.apply(next);
      await this.store.save(next);
      this.current = next;
      return normalizeThemeSettings(next);
    } catch (error) {
      try { await this.target.apply(this.current); } catch (_) { /* Preserve the original failure. */ }
      throw error;
    } finally { this.busy = false; }
  }
}
