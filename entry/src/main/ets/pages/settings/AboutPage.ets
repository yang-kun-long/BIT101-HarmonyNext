import { common, Want } from '@kit.AbilityKit';
import bundleManager from '@ohos.bundle.bundleManager';
import { util } from '@kit.ArkTS';
import { uiBack, uiShowToast } from '../../utils/uiContextBridge';
import { Logger } from '../../utils/Logger';
import { UpdateChecker } from '../../components/settings/UpdateChecker';
import { createAboutSettingsStore } from '../../services/storage/AboutSettingsStore';
import { LogExportService } from '../../services/log/LogExportService';
import { LogShareTarget } from '../../services/log/LogShareTarget';

const PROJECT_NAME: string = 'BIT101-HarmonyNext';
const PROJECT_URL: string = 'https://github.com/yang-kun-long/BIT101-HarmonyNext';

// ----------------------------------------------------------------------------
// 1. 主页面结构
// ----------------------------------------------------------------------------

@Entry
@Component
struct AboutPage {
  private logger: Logger = new Logger('AboutPage');

  // --- 状态管理 ---
  @State versionName: string = "";
  @State autoDetectUpgrade: boolean = true;
  @State isDetectingUpgrade: boolean = false;
  @State updateRequestId: number = 0;
  @State isSavingSettings: boolean = false;
  @State settingsReady: boolean = false;
  @State isExportingLogs: boolean = false;
  private logExportService: LogExportService | null = null;
  @State licensesText: string = "正在加载开源声明...";

  // --- 弹窗控制器 ---
  licenseDialogController: CustomDialogController = new CustomDialogController({
    builder: LicenseDialog({ text: this.licensesText }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  aboutAppDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutAppDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  // --- 生命周期 ---
  aboutToAppear() {
    this.getAppVersion();
    this.loadLicenses();
    this.loadUpdateSettings();
  }

  build() {
    Column() {
      UpdateChecker({
        automatic: false,
        requestId: this.updateRequestId,
        onChecking: (checking: boolean) => { this.isDetectingUpgrade = checking; },
      })
      // 1. 顶部导航栏
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("关于")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. 内容区域
      Scroll() {
        Column() {
          // --- Logo 区域 ---
          Column() {
            Image($r('app.media.startIcon')) // 使用应用图标
              .width(80)
              .height(80)
              .margin({ bottom: 8 })

            Text("BIT101")
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 24, bottom: 24 })

          // --- 版本信息组 ---
          // 【修复点 1】使用 Column 包裹来设置 padding，避免编译错误
          Column() {
            SettingsGroup({ title: "版本信息" }) {
              Column() {
                SettingItem({
                  title: "当前版本",
                  subTitle: "点击检查更新",
                  valueText: this.versionName,
                  enable: !this.isDetectingUpgrade,
                  onItemClick: () => { this.updateRequestId++; }
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                SwitchSettingItem({
                  title: "自动检查更新",
                  subTitle: "在启动时自动检查更新",
                  checked: this.autoDetectUpgrade,
                  onChange: (isOn) => { this.saveAutoUpdate(isOn); }
                })
                .enabled(this.settingsReady && !this.isSavingSettings)
              }
            }
          }
          .padding({ left: 16, right: 16 }) // 在这里设置 padding

          // --- 联系我们组 ---
          Column() {
            SettingsGroup({ title: "联系我们" }) {
              Column() {
                SettingItem({
                  title: "导出诊断日志",
                  subTitle: "分享本次运行的最近日志，敏感字段已省略",
                  valueText: this.isExportingLogs ? "正在导出…" : "",
                  enable: !this.isExportingLogs,
                  onItemClick: () => { this.exportLogs(); }
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                SettingItem({
                  title: "GitHub",
                  subTitle: PROJECT_NAME,
                  onItemClick: () => { this.openUrl(PROJECT_URL) }
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                SettingItem({
                  title: "QQ交流群",
                  subTitle: "726965926",
                  onItemClick: () => { this.openUrl("https://jq.qq.com/?_wv=1027&k=OTttwrzb") }
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                SettingItem({
                  title: "邮箱",
                  subTitle: "admin@bit101.cn",
                  onItemClick: () => { this.openUrl("mailto:admin@bit101.cn") }
                })
              }
            }
          }
          .padding({ left: 16, right: 16, top: 16 })

          // --- 关于本APP组 ---
          Column() {
            SettingsGroup({ title: "关于本APP" }) {
              Column() {
                SettingItem({
                  title: "开源声明",
                  onItemClick: () => { this.licenseDialogController.open() }
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                SettingItem({
                  title: "关于 BIT101 HarmonyOS",
                  onItemClick: () => { this.aboutAppDialogController.open() }
                })
              }
            }
          }
          .padding({ left: 16, right: 16, top: 16 })

          // --- 底部 Footer ---
          Column() {
            // 富文本区域
            Text() {
              Span("欢迎到 ")
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
              Span("GitHub")
                .fontColor($r('sys.color.ohos_id_color_text_primary_activated')) // 蓝色
                .onClick(() => {
                  this.openUrl(PROJECT_URL)
                })
              Span(" 查看源码与提交问题")
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
            }
            .fontSize(14)
            .margin({ bottom: 4 })

            Text("Built by BIT101 contributors.")
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 32, bottom: 40 })

        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- 逻辑处理 ---

  // 1. 获取版本号
  async getAppVersion() {
    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleFlags);
      this.versionName = bundleInfo.versionName;
    } catch (err) {
      this.versionName = "Unknown";
    }
  }

  // 2. 读取开源声明文件 (RawFile)
  async loadLicenses() {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const resourceManager = context.resourceManager;
      const fileData = await resourceManager.getRawFileContent("open_source_licenses.txt");
      const textDecoder = util.TextDecoder.create("utf-8");
      this.licensesText = textDecoder.decodeToString(fileData);
    } catch (err) {
      this.licensesText = "暂无开源声明或文件读取失败。\n(请确保 resources/rawfile/ 目录下存在 open_source_licenses.txt)";
    }
  }

  private async loadUpdateSettings(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const settings = await createAboutSettingsStore(context).load();
      this.autoDetectUpgrade = settings.autoDetectUpgrade;
      this.settingsReady = true;
    } catch (_) {
      this.logger.warn('Failed to load update settings');
      uiShowToast(this.getUIContext(), { message: '读取更新设置失败，请重新进入此页' });
    }
  }

  private async saveAutoUpdate(enabled: boolean): Promise<void> {
    if (!this.settingsReady || this.isSavingSettings) return;
    this.isSavingSettings = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const store = createAboutSettingsStore(context);
      const settings = await store.load();
      settings.autoDetectUpgrade = enabled;
      await store.save(settings);
      this.autoDetectUpgrade = enabled;
    } catch (_) {
      uiShowToast(this.getUIContext(), { message: '保存更新设置失败，请重试' });
    } finally {
      this.isSavingSettings = false;
    }
  }

  private async exportLogs(): Promise<void> {
    if (this.isExportingLogs) return;
    this.isExportingLogs = true;
    try {
      if (this.logExportService === null) {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        this.logExportService = new LogExportService(new LogShareTarget(context));
      }
      await this.logExportService.exportAndShare(this.versionName);
    } catch (_) {
      this.logger.error('Diagnostic log export failed');
      uiShowToast(this.getUIContext(), { message: '日志导出失败，请重试' });
    } finally {
      this.isExportingLogs = false;
    }
  }

  // 4. 打开外部链接
  openUrl(url: string) {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    context.startAbility(want).catch((err: object) => {
      this.logger.error('Start ability failed', err);
      uiShowToast(this.getUIContext(), { message: "无法打开链接" });
    });
  }
}

// ----------------------------------------------------------------------------
// 2. 弹窗组件
// ----------------------------------------------------------------------------

/**
 * 开源声明弹窗
 */
@CustomDialog
struct LicenseDialog {
  controller: CustomDialogController;
  @Prop text: string;

  build() {
    Column() {
      Text("吃水不忘挖井人")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .padding(24)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      Scroll() {
        Text(this.text)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .lineHeight(20)
      }
      .height(300)
      .padding({ left: 24, right: 24 })
      .align(Alignment.TopStart)

      // 【修复点 2】ButtonType.Text 改为 Normal 并设为透明背景
      Button("关闭", { type: ButtonType.Normal })
        .onClick(() => { this.controller.close() })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
        .width('100%')
        .margin({ top: 8, bottom: 8 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('90%')
  }
}

/**
 * 关于 APP 弹窗
 */
@CustomDialog
struct AboutAppDialog {
  controller: CustomDialogController;
  private logger: Logger = new Logger('AboutPage');
  private links: Record<string, string> = {
    "726965926": "https://jq.qq.com/?_wv=1027&k=OTttwrzb",
    "GitHub": PROJECT_URL,
    "admin@bit101.cn": "mailto:admin@bit101.cn"
  };

  build() {
    Column() {
      Text("关于 BIT101 HarmonyOS")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .padding(24)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))

      Scroll() {
        Column() {
          Text("BIT101 HarmonyOS 是 BIT101 在 HarmonyOS 上的原生客户端，提供课程表、DDL、校园服务和社区功能。\n\n项目仍在持续完善，欢迎通过 GitHub、QQ 群或邮件反馈问题。\n\n")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Text() {
            Span("现在设计和功能上仍然有很多不足，欢迎加入我们的QQ交流群 ")
            Span("726965926")
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .onClick(() => this.openUrl(this.links["726965926"]))
            Span(" 、在 ")
            Span("GitHub")
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .onClick(() => this.openUrl(this.links["GitHub"]))
            Span(" 提交 issue 或邮件联系 ")
            Span("admin@bit101.cn")
              .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
              .onClick(() => this.openUrl(this.links["admin@bit101.cn"]))
            Span(" ，BIT101期待你的贡献～\n\n")
          }
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Text(this.generatePyramid())
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 20, bottom: 20 })

          Text("这里什么也没有哦╮(￣▽￣)╭\n但既然你都辛辛苦苦翻到这里了，就送你一束花吧💐")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 20 })
        }
      }
      .height(350)
      .padding({ left: 24, right: 24 })
      .align(Alignment.TopStart)

      // 【修复点 2】ButtonType.Text 改为 Normal 并设为透明背景
      Button("关闭", { type: ButtonType.Normal })
        .onClick(() => { this.controller.close() })
        .backgroundColor(Color.Transparent)
        .fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
        .width('100%')
        .margin({ top: 8, bottom: 8 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('90%')
  }

  openUrl(url: string) {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url
    };
    context.startAbility(want).catch((err: object) => {
      this.logger.error('Start ability failed', err);
      uiShowToast(this.getUIContext(), { message: "无法打开链接" });
    });
  }

  generatePyramid(): string {
    let res = "";
    res += "BIT101\n";
    res += "BIT10 1\n";
    res += "BIT1 0 1\n";
    res += "BIT 1 0 1\n";
    res += "BI T 1 0 1\n";
    res += "B I T 1 0 1\n";
    res += "BI T 1 0 1\n";
    res += "BIT 1 0 1\n";
    res += "BIT1 0 1\n";
    res += "BIT10 1\n";
    res += "BIT101\n";
    res += "IT101\n";
    res += "T101\n";
    res += "101\n";
    res += "1\n";
    return res;
  }
}

// ----------------------------------------------------------------------------
// 3. 复用组件
// ----------------------------------------------------------------------------

@Component
struct SettingsGroup {
  @Prop title: string;
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title) {
        Text(this.title)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 8, left: 4 })
          .width('100%')
      }
      Column() {
        this.content()
      }
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
  }
}

@Component
struct SettingItem {
  @Prop title: string;
  @Prop subTitle: string = "";
  @Prop valueText: string = "";
  @Prop showArrow: boolean = true;
  @Prop enable: boolean = true;

  onItemClick: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.enable ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary'))

        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.valueText) {
        Text(this.valueText)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ right: 8 })
      }

      if (this.showArrow) {
        Image($r('app.media.ic_chevron_right'))
          .width(20)
          .height(20)
          .fillColor(this.enable ? $r('sys.color.ohos_id_color_text_tertiary') : Color.Transparent)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
    .opacity(this.enable ? 1 : 0.6)
    .enabled(this.enable)
    .onClick(() => {
      if (this.enable) {
        this.onItemClick();
      }
    })
  }
}

@Component
struct SwitchSettingItem {
  @Prop title: string;
  @Prop subTitle: string;
  @Prop checked: boolean;
  onChange: (isOn: boolean) => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((isOn) => {
          this.onChange(isOn);
        })
        .selectedColor($r('sys.color.ohos_id_color_text_primary_activated'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
  }
}
