import { common, Want } from '@kit.AbilityKit';
import bundleManager from '@ohos.bundle.bundleManager';
import { createAboutSettingsStore } from '../../services/storage/AboutSettingsStore';
import { VersionService } from '../../services/version/VersionService';
import { VersionInfo } from '../../services/version/VersionModels';
import { uiShowToast } from '../../utils/uiContextBridge';
import { Logger } from '../../utils/Logger';

/** Mounted at startup and in About. A counter requests an explicit user check. */
@Component
export struct UpdateChecker {
  @Prop automatic: boolean = true;
  @Prop @Watch('onRequest') requestId: number = 0;
  onChecking: (checking: boolean) => void = () => {};
  private checking: boolean = false;
  private active: boolean = false;
  private logger: Logger = new Logger('AboutPage');
  @State latest: VersionInfo | null = null;
  @State forced: boolean = false;
  private dialog: CustomDialogController = new CustomDialogController({
    builder: UpdateDialog({
      latest: this.latest,
      forced: this.forced,
      onUpdate: () => { this.openUpdate(); },
      onIgnore: () => { this.ignoreUpdate(); },
    }),
    autoCancel: false,
  });

  aboutToAppear(): void {
    this.active = true;
    if (this.automatic) this.check(true);
  }

  aboutToDisappear(): void {
    this.active = false;
    this.dialog.close();
  }

  private onRequest(): void {
    if (this.requestId > 0) this.check(false);
  }

  private async check(isAuto: boolean): Promise<void> {
    if (this.checking) return;
    this.checking = true;
    this.onChecking(true);
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const store = createAboutSettingsStore(context);
      const settings = await store.load();
      if (isAuto && !settings.autoDetectUpgrade) return;
      const bundle = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const result = await new VersionService().check(bundle.versionCode, isAuto ? settings.ignoredVersion : null);
      settings.lastCheckTime = Date.now();
      await store.save(settings);
      if (!this.active) return;
      if (result.decision === 'up_to_date') {
        if (!isAuto) uiShowToast(this.getUIContext(), { message: '当前已是最新版本' });
        return;
      }
      if (result.decision === 'ignored') return;
      this.latest = result.latest;
      this.forced = result.decision === 'forced_update';
      this.dialog.open();
    } catch (error) {
      this.logger.warn('Version check failed');
      if (this.active && !isAuto) {
        const unsupported = error instanceof Error && error.message === 'Version channel is not confirmed for harmonyos';
        uiShowToast(this.getUIContext(), {
          message: unsupported ? '暂未提供鸿蒙版更新信息，请前往项目主页查看' : '检查更新失败，请稍后重试',
        });
      }
    } finally {
      this.checking = false;
      this.onChecking(false);
    }
  }

  private async ignoreUpdate(): Promise<void> {
    if (this.forced || this.latest === null) return;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const store = createAboutSettingsStore(context);
      const settings = await store.load();
      settings.ignoredVersion = this.latest.versionCode;
      await store.save(settings);
      this.dialog.close();
    } catch (_) {
      uiShowToast(this.getUIContext(), { message: '保存失败，请重试' });
    }
  }

  private async openUpdate(): Promise<void> {
    if (this.latest === null) return;
    if (!/^https?:\/\/[^\s]+$/i.test(this.latest.url) || /\.apk(?:[?#]|$)/i.test(this.latest.url)) {
      uiShowToast(this.getUIContext(), { message: '更新链接暂不可用，请前往项目主页查看' });
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: this.latest.url,
      };
      await context.startAbility(want);
      if (!this.forced) this.dialog.close();
    } catch (_) {
      uiShowToast(this.getUIContext(), { message: '无法打开更新链接，请重试' });
    }
  }

  build() {
    Blank().width(1).height(1).opacity(0).hitTestBehavior(HitTestMode.None)
  }
}

@CustomDialog
struct UpdateDialog {
  controller: CustomDialogController;
  @Prop latest: VersionInfo | null = null;
  @Prop forced: boolean = false;
  onUpdate: () => void = () => {};
  onIgnore: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text(`发现新版本 ${this.latest?.versionName ?? ''}`).fontSize(20).fontWeight(FontWeight.Bold)
      if (this.forced) {
        Text('当前版本已停止支持，请更新后继续使用。').fontSize(14)
      }
      Scroll() {
        Text(this.latest?.message ?? '').fontSize(16).width('100%')
      }.constraintSize({ maxHeight: 280 }).width('100%')
      Button('前往更新').onClick(() => { this.onUpdate(); })
      if (!this.forced) {
        Row({ space: 24 }) {
          Button('稍后').onClick(() => { this.controller.close(); })
          Button('忽略此版本').onClick(() => { this.onIgnore(); })
        }
      }
    }.padding(24).width('100%')
  }
}
