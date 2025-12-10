import { router, promptAction } from '@kit.ArkUI';

// ----------------------------------------------------------------------------
// 1. 数据模型定义
// ----------------------------------------------------------------------------
class SettingData {
  showSaturday: boolean = true;
  showSunday: boolean = true;
  showBorder: boolean = false;
  showHighlightToday: boolean = true;
  showDivider: boolean = true;
  showCurrentTime: boolean = true;

  static copy(origin: SettingData, changes: Partial<SettingData>): SettingData {
    const newData = new SettingData();
    newData.showSaturday = changes.showSaturday ?? origin.showSaturday;
    newData.showSunday = changes.showSunday ?? origin.showSunday;
    newData.showBorder = changes.showBorder ?? origin.showBorder;
    newData.showHighlightToday = changes.showHighlightToday ?? origin.showHighlightToday;
    newData.showDivider = changes.showDivider ?? origin.showDivider;
    newData.showCurrentTime = changes.showCurrentTime ?? origin.showCurrentTime;
    return newData;
  }
}

// ----------------------------------------------------------------------------
// 2. 主页面结构
// ----------------------------------------------------------------------------

@Entry
@Component
struct CalendarSettingPage {
  @State currentTerm: string = "2024-2025-1";
  @State firstDay: string = "2024-08-26";
  @State settingData: SettingData = new SettingData();

  @State isGettingFirstDay: boolean = false;
  @State isGettingCourses: boolean = false;
  @State isGettingTermList: boolean = false;

  @State termList: string[] = [];
  @State timeTableString: string =
    "08:00-08:45\n08:50-09:35\n09:50-10:35\n10:40-11:25\n11:30-12:15\n" +
      "13:20-14:05\n14:10-14:55\n15:15-16:00\n16:05-16:50\n17:00-17:45\n" +
      "18:30-19:15\n19:20-20:05\n20:10-20:55";

  // --- 弹窗控制器 ---
  termListDialogController: CustomDialogController = new CustomDialogController({
    builder: TermListDialog({
      currentTerm: this.currentTerm,
      termList: this.termList,
      isLoading: this.isGettingTermList,
      onSelect: (term: string) => {
        this.currentTerm = term;
        promptAction.showToast({ message: "切换学期成功" });
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  timeTableDialogController: CustomDialogController = new CustomDialogController({
    builder: TimeTableDialog({
      content: this.timeTableString,
      onConfirm: (val: string) => {
        this.timeTableString = val;
        promptAction.showToast({ message: "时间表已保存" });
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  build() {
    Column() {
      // 1. 顶部导航栏
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { router.back(); })

        Text("课程表设置")
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
      List() {
        // --- Group 1: 数据设置 ---
        ListItem() {
          SettingsGroup({ title: "数据设置", subTitle: "如果获取失败可以尝试在账号设置中“检查登录状态”哦" }) {
            Column() {
              SettingItem({
                title: "当前学期",
                subTitle: "设置当前学期",
                valueText: this.currentTerm,
                onItemClick: () => {
                  this.openTermListDialog();
                }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "学期起始日期",
                subTitle: "点击重新获取当前学期的起始日期",
                valueText: this.firstDay,
                enable: !this.isGettingFirstDay,
                onItemClick: () => { this.handleGetFirstDay() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "课表数据",
                subTitle: "点击重新获取当前学期的课表",
                enable: !this.isGettingCourses,
                onItemClick: () => { this.handleGetCourses() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "时间表",
                subTitle: "每节课的上课和下课时间",
                onItemClick: () => { this.timeTableDialogController.open() }
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16 })

        // --- Group 2: 显示设置 ---
        ListItem() {
          SettingsGroup({ title: "显示设置" }) {
            Column() {
              // 【修复核心】显式添加 : void 返回类型
              SwitchSettingItem({
                title: "显示周六",
                checked: this.settingData.showSaturday,
                onChange: (v: boolean): void => this.updateSetting({ showSaturday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示周日",
                checked: this.settingData.showSunday,
                onChange: (v: boolean): void => this.updateSetting({ showSunday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示课程卡片边框",
                checked: this.settingData.showBorder,
                onChange: (v: boolean): void => this.updateSetting({ showBorder: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "高亮今日",
                checked: this.settingData.showHighlightToday,
                onChange: (v: boolean): void => this.updateSetting({ showHighlightToday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示节次分割线",
                checked: this.settingData.showDivider,
                onChange: (v: boolean): void => this.updateSetting({ showDivider: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示当前时间线",
                checked: this.settingData.showCurrentTime,
                onChange: (v: boolean): void => this.updateSetting({ showCurrentTime: v })
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- 逻辑处理 ---

  updateSetting(changes: Partial<SettingData>) {
    this.settingData = SettingData.copy(this.settingData, changes);
  }

  handleGetFirstDay() {
    this.isGettingFirstDay = true;
    promptAction.showToast({ message: "正在获取学期起始日期..." });
    setTimeout(() => {
      this.isGettingFirstDay = false;
      this.firstDay = "2024-08-26";
      promptAction.showToast({ message: "获取成功" });
    }, 1500);
  }

  handleGetCourses() {
    this.isGettingCourses = true;
    promptAction.showToast({ message: "正在获取课表..." });
    setTimeout(() => {
      this.isGettingCourses = false;
      promptAction.showToast({ message: "获取成功" });
    }, 1500);
  }

  openTermListDialog() {
    this.termListDialogController.open();
    if (this.termList.length === 0) {
      this.isGettingTermList = true;
      setTimeout(() => {
        this.termList = ["2024-2025-1", "2023-2024-2", "2023-2024-1", "2022-2023-2"];
        this.isGettingTermList = false;
      }, 1000);
    }
  }
}

// ----------------------------------------------------------------------------
// 3. 弹窗组件
// ----------------------------------------------------------------------------

@CustomDialog
struct TermListDialog {
  controller: CustomDialogController;
  @Prop currentTerm: string;
  @Link termList: string[];
  @Link isLoading: boolean;
  onSelect: (term: string) => void = () => {};

  build() {
    Column() {
      Text("切换学期")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding(24)
        .width('100%')

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48).height(48)
            .color($r('sys.color.ohos_id_color_text_primary'))
        }
        .height(150)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.termList, (term: string) => {
            ListItem() {
              Row() {
                Radio({ value: term, group: 'termGroup' })
                  .checked(term === this.currentTerm)
                  .hitTestBehavior(HitTestMode.None)
                  .width(24).height(24)

                Text(term)
                  .fontSize(16)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .margin({ left: 16 })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 24, right: 24, top: 16, bottom: 16 })
              .onClick(() => {
                this.onSelect(term);
                this.controller.close();
              })
            }
          })
        }
        .height(240)
      }

      // 【修复】按钮使用 Normal + Transparent
      Row() {
        Blank()
        Button("取消", { type: ButtonType.Normal })
          .onClick(() => { this.controller.close() })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ right: 16, bottom: 16 })
      }
      .width('100%')
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('90%')
  }
}

@CustomDialog
struct TimeTableDialog {
  controller: CustomDialogController;
  @State content: string = "";
  onConfirm: (val: string) => void = () => {};

  build() {
    Column() {
      Text("设置时间表")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, left: 24, right: 24, bottom: 8 })
        .width('100%')

      Text("可调整每天课程节数和时间，格式照猫画虎即可")
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .padding({ left: 24, right: 24, bottom: 16 })
        .width('100%')

      TextArea({ text: this.content })
        .width('90%')
        .height(300)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_text_tertiary'), radius: 8 })
        .fontSize(14)
        .fontFamily('Monospace')
        .onChange((value) => {
          this.content = value;
        })
        .margin({ bottom: 8 })

      // 按钮组
      Row() {
        Button("取消", { type: ButtonType.Normal })
          .onClick(() => { this.controller.close() })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        Button("确定", { type: ButtonType.Normal })
          .onClick(() => {
            this.onConfirm(this.content);
            this.controller.close();
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
    .width('90%')
  }
}

// ----------------------------------------------------------------------------
// 4. 复用组件
// ----------------------------------------------------------------------------

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