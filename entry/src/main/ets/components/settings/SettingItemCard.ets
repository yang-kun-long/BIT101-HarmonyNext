import { router } from '@kit.ArkUI';
import { uiPushUrl } from '../../utils/uiContextBridge';

@Component
export struct SettingItemCard {
  @Prop title: string;
  @Prop subTitle: string;
  // 这里暂时用 Resource，后续你可以替换为具体的 svg 资源引用
  @Prop icon: ResourceStr;
  // 点击跳转的路由地址，如果为空则由外部 onClick 处理
  @Prop targetUrl: string = '';

  build() {
    Row() {
      // 左侧图标
      Image(this.icon)
        .width(24)
        .height(24)
        .fillColor($r('sys.color.ohos_id_color_text_primary'))// 假设你有这个颜色资源，如果没有请改为 Color.Black
        .margin({ right: 16 })

      // 中间文字区域
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧箭头 (使用了你项目中已有的资源)
      Image($r('app.media.ic_chevron_right'))
        .width(20)
        .height(20)
        .fillColor($r('sys.color.ohos_id_color_text_tertiary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => {
      if (this.targetUrl) {
        uiPushUrl(this.getUIContext(), { url: this.targetUrl });
      }
    })
  }
}
