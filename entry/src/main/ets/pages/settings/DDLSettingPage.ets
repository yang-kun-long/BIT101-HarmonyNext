import { uiBack, uiShowToast } from '../../utils/uiContextBridge';
import { refreshDdlSubscribeUrl, syncDdlFromLexue } from '../../services/deadline/DdlSyncService';
import { Logger } from '../../utils/Logger';
import {
  applyDdlDisplaySettingsToAppStorage,
  DdlSettingsStore,
} from '../../services/storage/DdlSettingsStore';
import {
  buildDdlSettingsDataItems,
  buildDdlSettingsResultToast,
} from '../../components/deadline/ddlListModel';
import type {
  DdlSettingsItem,
} from '../../components/deadline/ddlListModel';

// ----------------------------------------------------------------------------
// 1. Main Page Structure
// ----------------------------------------------------------------------------

@Entry
@Component
struct DDLSettingPage {
  // --- Simulated ViewModel State ---
  @State afterDay: number = 3; // Default retention days
  @State beforeDay: number = 7; // Default warning color days
  @StorageProp('current_username') currentUsername: string = '';
  private logger: Logger = new Logger('DDLSettingPage');
  private settingsStore: DdlSettingsStore = new DdlSettingsStore();

  // Loading States
  @State isUpdatingLexueCalendarUrl: boolean = false;
  @State isUpdatingLexueCalendar: boolean = false;

  private dataSettingItems(): DdlSettingsItem[] {
    return buildDdlSettingsDataItems(this.isUpdatingLexueCalendarUrl, this.isUpdatingLexueCalendar);
  }

  // --- Dialog Controllers ---
  // 1. Warning Color Days Dialog
  beforeDayDialogController: CustomDialogController = new CustomDialogController({
    builder: InputNumberDialog({
      title: '变色天数',
      text: '临近日程会改变颜色',
      initValue: this.beforeDay,
      onConfirm: (val: number) => {
        this.saveBeforeDay(val);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  // 2. Retention Days Dialog
  afterDayDialogController: CustomDialogController = new CustomDialogController({
    builder: InputNumberDialog({
      title: '滞留天数',
      text: '过期日程会继续显示',
      initValue: this.afterDay,
      onConfirm: (val: number) => {
        this.saveAfterDay(val);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  aboutToAppear(): void {
    this.loadDisplaySettings();
  }

  build() {
    Column() {
      // 1. Top Navigation Bar
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("DDL设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. Content List
      List() {
        // --- Group 1: Data Settings ---
        ListItem() {
          SettingsGroup({ title: "数据设置", subTitle: "如果获取失败可以尝试在账号设置中“检查登录状态”哦" }) {
            Column() {
              // 1. Fetch Subscription Link
              SettingItem({
                title: this.dataSettingItems()[0].title,
                subTitle: this.dataSettingItems()[0].subTitle,
                enable: this.dataSettingItems()[0].enabled,
                onItemClick: () => { this.handleUpdateLexueCalendarUrl() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              // 2. Fetch Schedule
              SettingItem({
                title: this.dataSettingItems()[1].title,
                subTitle: this.dataSettingItems()[1].subTitle,
                enable: this.dataSettingItems()[1].enabled,
                onItemClick: () => { this.handleUpdateLexueCalendar() }
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16 })

        // --- Group 2: Display Settings ---
        ListItem() {
          SettingsGroup({ title: "显示设置" }) {
            Column() {
              // 1. Warning Color Days
              SettingItem({
                title: "变色天数",
                subTitle: "临近日程会改变颜色",
                valueText: this.beforeDay.toString(),
                onItemClick: () => { this.beforeDayDialogController.open() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              // 2. Retention Days
              SettingItem({
                title: "滞留天数",
                subTitle: "过期日程会继续显示",
                valueText: this.afterDay.toString(),
                onItemClick: () => { this.afterDayDialogController.open() }
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .height('100%')
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- Actions ---

  handleUpdateLexueCalendarUrl() {
    if (this.isUpdatingLexueCalendarUrl) {
      return;
    }
    this.isUpdatingLexueCalendarUrl = true;
    uiShowToast(this.getUIContext(), { message: "正在获取订阅链接..." });
    refreshDdlSubscribeUrl(this.currentUsername)
      .then((_url: string) => {
        uiShowToast(this.getUIContext(), {
          message: buildDdlSettingsResultToast('refreshSubscribeUrl', true),
        });
      })
      .catch((err: Error) => {
        this.logger.error('refresh DDL subscribe URL failed', err);
        uiShowToast(this.getUIContext(), {
          message: buildDdlSettingsResultToast('refreshSubscribeUrl', false),
        });
      })
      .finally(() => {
        this.isUpdatingLexueCalendarUrl = false;
      });
  }

  handleUpdateLexueCalendar() {
    if (this.isUpdatingLexueCalendar) {
      return;
    }
    this.isUpdatingLexueCalendar = true;
    uiShowToast(this.getUIContext(), { message: "正在拉取日程..." });
    syncDdlFromLexue(this.currentUsername)
      .then((_count: number) => {
        uiShowToast(this.getUIContext(), {
          message: buildDdlSettingsResultToast('refreshLexueCalendar', true),
        });
      })
      .catch((err: Error) => {
        this.logger.error('sync DDL from Lexue failed', err);
        uiShowToast(this.getUIContext(), {
          message: buildDdlSettingsResultToast('refreshLexueCalendar', false),
        });
      })
      .finally(() => {
        this.isUpdatingLexueCalendar = false;
      });
  }

  private loadDisplaySettings(): void {
    this.settingsStore.load()
      .then((settings) => {
        this.beforeDay = settings.warningDays;
        this.afterDay = settings.retentionDays;
        applyDdlDisplaySettingsToAppStorage(settings);
      })
      .catch((err: Error) => {
        this.logger.error('load DDL display settings failed', err);
      });
  }

  private saveBeforeDay(value: number): void {
    this.settingsStore.saveWarningDays(value)
      .then((settings) => {
        this.beforeDay = settings.warningDays;
        this.afterDay = settings.retentionDays;
        applyDdlDisplaySettingsToAppStorage(settings);
        uiShowToast(this.getUIContext(), { message: "设置成功OvO" });
      })
      .catch((err: Error) => {
        this.logger.error('save DDL warning days failed', err);
        uiShowToast(this.getUIContext(), { message: "设置失败" });
      });
  }

  private saveAfterDay(value: number): void {
    this.settingsStore.saveRetentionDays(value)
      .then((settings) => {
        this.beforeDay = settings.warningDays;
        this.afterDay = settings.retentionDays;
        applyDdlDisplaySettingsToAppStorage(settings);
        uiShowToast(this.getUIContext(), { message: "设置成功OvO" });
      })
      .catch((err: Error) => {
        this.logger.error('save DDL retention days failed', err);
        uiShowToast(this.getUIContext(), { message: "设置失败" });
      });
  }
}

// ----------------------------------------------------------------------------
// 2. Reusable Components
// ----------------------------------------------------------------------------

/**
 * Number Input Dialog (Replicates Android's InputNumberDialog)
 */
@CustomDialog
struct InputNumberDialog {
  controller: CustomDialogController;
  title: string = '';
  text: string = '';
  initValue: number = 0;
  onConfirm: (val: number) => void = () => {};

  @State inputValue: string = '';
  @State errorMessage: string = '';

  aboutToAppear() {
    this.inputValue = this.initValue.toString();
  }

  build() {
    Column() {
      // Title
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, left: 24, right: 24, bottom: 8 })
        .width('100%')

      // Description
      Text(this.text)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .padding({ left: 24, right: 24, bottom: 16 })
        .width('100%')

      // Input Field
      TextInput({ text: this.inputValue })
        .width('90%')
        .height(56)
        .type(InputType.Number) // Only allow numbers
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_text_tertiary'), radius: 8 })
        .onChange((value) => {
          this.inputValue = value;
          this.errorMessage = ""; // Clear error on typing
        })
        .margin({ bottom: 4 })

      // Error Message (Animated Visibility Logic)
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor(Color.Red)
          .padding({ left: 24, bottom: 8 })
          .width('100%')
      } else {
        // Spacer to prevent layout jumping
        Blank().height(22)
      }

      // Buttons
      Row() {
        Button("取消", { type: ButtonType.Normal })
          .onClick(() => { this.controller.close() })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        Button("确定", { type: ButtonType.Normal })
          .onClick(() => {
            const num = parseInt(this.inputValue);
            if (!isNaN(num) && num >= 0) {
              this.onConfirm(num);
              this.controller.close();
            } else {
              this.errorMessage = "格式校验失败Orz";
            }
          })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(52)
      .margin({ bottom: 8 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('80%')
  }
}

// Reuse SettingsGroup and SettingItem
@Component
struct SettingsGroup {
  @Prop title: string;
  @Prop subTitle: string = "";
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title) {
        Column() {
          Text(this.title)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
            .width('100%')

          if (this.subTitle) {
            Text(this.subTitle)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
              .width('100%')
          }
        }
        .margin({ bottom: 8, left: 4 })
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
