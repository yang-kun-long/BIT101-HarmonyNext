import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DarkThemeMode, defaultThemeSettings, ThemeSettings } from './ThemeSettingsModel';
import { ThemeSettingsController, ThemeSettingsTarget } from './ThemeSettingsController';
import { createThemeSettingsStore } from '../storage/ThemeSettingsStore';
import { guardAsyncStorage } from '../storage/storageGuard';

export class WindowThemeTarget implements ThemeSettingsTarget {
  private readonly context: common.UIAbilityContext;
  private readonly mainWindow: window.Window;

  constructor(context: common.UIAbilityContext, mainWindow: window.Window) {
    this.context = context;
    this.mainWindow = mainWindow;
  }

  async apply(settings: ThemeSettings): Promise<void> {
    let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (settings.darkThemeMode === DarkThemeMode.Light) mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    if (settings.darkThemeMode === DarkThemeMode.Dark) mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    await guardAsyncStorage('WindowThemeTarget.apply', async () => {
      this.context.getApplicationContext().setColorMode(mode);
      await this.mainWindow.setPreferredOrientation(settings.autoRotate
        ? window.Orientation.AUTO_ROTATION_RESTRICTED : window.Orientation.PORTRAIT);
    });
  }
}

let controller: ThemeSettingsController | null = null;

export async function initializeWindowTheme(context: common.UIAbilityContext, mainWindow: window.Window): Promise<void> {
  const target = new WindowThemeTarget(context, mainWindow);
  controller = new ThemeSettingsController(createThemeSettingsStore(context), target);
  try {
    await controller.load();
  } catch (error) {
    await target.apply(defaultThemeSettings());
    throw error;
  }
}

export function getThemeSettingsController(): ThemeSettingsController {
  if (controller === null) throw new Error('Window theme is not initialized');
  return controller;
}

export function releaseWindowTheme(): void { controller = null; }
