import { router } from '@kit.ArkUI';
import { uiBack } from '../../utils/uiContextBridge';

// 对应 Android 的 DarkThemeMode 枚举
enum DarkThemeMode {
  System = 0,
  Light = 1,
  Dark = 2
}

// 获取模式对应的显示文本
function getDarkThemeName(mode: DarkThemeMode): string {
  switch (mode) {
    case DarkThemeMode.System: return "跟随系统";
    case DarkThemeMode.Light: return "亮色模式";
    case DarkThemeMode.Dark: return "深色模式";
    default: return "";
  }
}

@Entry
@Component
struct ThemeSettingPage {
  // 对应 Android ViewModel 中的状态
  @State dynamic: boolean = false;
  // 【修复 1】重命名 rotate -> autoRotate，避免与系统旋转属性冲突
  @State autoRotate: boolean = false;
  @State darkMode: DarkThemeMode = DarkThemeMode.System;

  // 暗黑模式选择弹窗控制器
  darkModeDialogController: CustomDialogController = new CustomDialogController({
    builder: DarkModeDialog({
      currentMode: this.darkMode,
      onConfirm: (mode: DarkThemeMode) => {
        this.darkMode = mode;
        // TODO: 这里添加实际切换主题的逻辑
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  build() {
    Column() {
      // 1. 顶部标题栏
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("外观设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. 设置项列表
      List() {
        ListItem() {
          Column() {
            // Item 1: 动态适配系统主题
            SwitchSettingItem({
              title: "动态适配系统主题",
              subTitle: "需要Android 12及以上",
              checked: this.dynamic,
              onChange: (isOn) => { this.dynamic = isOn; }
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // Item 2: 暗黑模式
            SelectionSettingItem({
              title: "暗黑模式",
              subTitle: "跟随系统，亮色，暗色",
              valueText: getDarkThemeName(this.darkMode),
              // 【修复 2】这里对应下面的重命名
              onItemClick: () => {
                this.darkModeDialogController.open();
              }
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // Item 3: 自动旋转
            SwitchSettingItem({
              title: "自动旋转",
              subTitle: "设置是否自动旋转",
              checked: this.autoRotate, // 【修复 1】使用新名字
              onChange: (isOn) => { this.autoRotate = isOn; }
            })
          }
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          .borderRadius(12)
          .clip(true)
        }
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

// -----------------------------------------------------------
// 下面是封装的组件
// -----------------------------------------------------------

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

@Component
struct SelectionSettingItem {
  @Prop title: string;
  @Prop subTitle: string;
  @Prop valueText: string;
  // 【修复 2】重命名 onClick -> onItemClick，避免与组件自带点击事件冲突
  onItemClick: () => void = () => {};

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

      Text(this.valueText)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ right: 8 })

      Image($r('app.media.ic_chevron_right'))
        .width(20)
        .height(20)
        .fillColor($r('sys.color.ohos_id_color_text_tertiary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.onItemClick(); // 调用自定义的回调
    })
  }
}

@CustomDialog
struct DarkModeDialog {
  controller: CustomDialogController;
  @Prop currentMode: DarkThemeMode;
  onConfirm: (mode: DarkThemeMode) => void = () => {};

  build() {
    Column() {
      Text("暗黑模式")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, bottom: 16, left: 24, right: 24 })
        .width('100%')

      Column() {
        this.RadioItem(DarkThemeMode.System, "跟随系统")
        this.RadioItem(DarkThemeMode.Light, "亮色模式")
        this.RadioItem(DarkThemeMode.Dark, "深色模式")
      }
      .padding({ bottom: 16 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(24)
    .width('80%')
  }

  @Builder
  RadioItem(mode: DarkThemeMode, text: string) {
    Row() {
      Radio({ value: mode.toString(), group: 'darkModeGroup' })
        .checked(this.currentMode === mode)
        .height(24)
        .width(24)
        .hitTestBehavior(HitTestMode.None)

      Text(text)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ left: 16 })
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: 24, right: 24 })
    .onClick(() => {
      this.onConfirm(mode);
      this.controller.close();
    })
  }
}
