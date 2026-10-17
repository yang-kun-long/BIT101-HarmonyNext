import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { guardAsyncStorage } from './storageGuard';

export interface GallerySettings {
  hideBot: boolean;
  hideBotInSearch: boolean;
  hiddenUids: string[];
  hideAnonymous: boolean;
  strict: boolean;
  allowHorizontalScroll: boolean;
}

export function defaultGallerySettings(): GallerySettings {
  return { hideBot: false, hideBotInSearch: false, hiddenUids: [], hideAnonymous: false,
    strict: false, allowHorizontalScroll: true };
}

export function normalizeGallerySettings(value: GallerySettings): GallerySettings {
  const ids = Array.isArray(value.hiddenUids) ? value.hiddenUids : [];
  return { hideBot: value.hideBot === true, hideBotInSearch: value.hideBotInSearch === true,
    hiddenUids: Array.from(new Set(ids.filter(id => typeof id === 'string' && /^[1-9]\d*$/.test(id) && Number.isSafeInteger(Number(id))))),
    hideAnonymous: value.hideAnonymous === true, strict: value.strict === true,
    allowHorizontalScroll: typeof value.allowHorizontalScroll === 'boolean' ? value.allowHorizontalScroll : true };
}

export interface GallerySettingsBackend {
  read(): Promise<string>;
  write(value: string): Promise<void>;
}

export class GallerySettingsStore {
  private backend: GallerySettingsBackend;
  private settings: GallerySettings = defaultGallerySettings();
  private listeners: Set<() => void> = new Set();
  private saving: boolean = false;

  constructor(backend: GallerySettingsBackend) { this.backend = backend; }

  snapshot(): GallerySettings { return normalizeGallerySettings(this.settings); }

  async load(): Promise<GallerySettings> {
    const raw = await this.backend.read();
    try {
      const parsed: GallerySettings | null = raw ? JSON.parse(raw) : null;
      this.settings = parsed ? normalizeGallerySettings(parsed) : defaultGallerySettings();
    } catch (_) { this.settings = defaultGallerySettings(); }
    return this.snapshot();
  }

  async save(value: GallerySettings): Promise<void> {
    if (this.saving) throw new Error('设置正在保存，请稍后重试');
    this.saving = true;
    const next = normalizeGallerySettings(value);
    try {
      await this.backend.write(JSON.stringify(next));
      this.settings = next;
    } finally { this.saving = false; }
    this.listeners.forEach(listener => listener());
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }
}

class PreferencesGalleryBackend implements GallerySettingsBackend {
  private context: common.Context;
  constructor(context: common.Context) { this.context = context; }
  async read(): Promise<string> {
    return guardAsyncStorage('GallerySettings.read', async () => {
      const pref = await preferences.getPreferences(this.context, 'gallery_settings');
      return String(await pref.get('settings', ''));
    });
  }
  async write(value: string): Promise<void> {
    await guardAsyncStorage('GallerySettings.write', async () => {
      const pref = await preferences.getPreferences(this.context, 'gallery_settings');
      await pref.put('settings', value);
      await pref.flush();
    });
  }
}

let sharedStore: GallerySettingsStore | null = null;
export async function initializeGallerySettings(context: common.Context): Promise<void> {
  sharedStore = new GallerySettingsStore(new PreferencesGalleryBackend(context));
  await sharedStore.load();
}
export function getGallerySettingsStore(): GallerySettingsStore {
  if (!sharedStore) throw new Error('话廊设置尚未初始化');
  return sharedStore;
}
