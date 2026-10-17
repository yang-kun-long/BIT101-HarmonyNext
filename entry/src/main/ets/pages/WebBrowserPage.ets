import { WebNavigationState, webBackward } from '../components/web/WebNavigationModel';
import { WebPage } from '../components/web/WebPage';
import { uiBack, uiGetParams } from '../utils/uiContextBridge';
import web_webview from '@ohos.web.webview';

@Entry
@Component
struct WebBrowserPage {
  private readonly navigation: WebNavigationState = new WebNavigationState();
  onBackPress(): boolean { return webBackward(this.controller); }
  @State url: string = '';
  @State title: string = '详情';
  private readonly controller: web_webview.WebviewController = new web_webview.WebviewController();

  aboutToAppear(): void {
    const params = uiGetParams(this.getUIContext()) as Record<string, string>;
    if (params) {
      this.url = params['url'] || '';
      this.title = params['title'] || '外部链接';
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_public_back'))
          .width(24)
          .height(24)
          .margin({ right: 16 })
          .onClick(() => {
            if (!webBackward(this.controller)) {
              uiBack(this.getUIContext());
            }
          })

        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))

        Text('×')
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .fontSize(24)
          .textAlign(TextAlign.Center)
          .onClick(() => uiBack(this.getUIContext()))
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .shadow({ radius: 2, color: '#0F000000', offsetY: 1 })
      .zIndex(10)

      if (this.url.length > 0) {
        WebPage({
          url: this.url,
          navigation: this.navigation,
          allowInitialOrigin: true,
          controller: this.controller,
          onTitleChange: (nextTitle: string) => {
            this.title = nextTitle;
          },
        })
          .layoutWeight(1)
      } else {
        Column() {
          Text('链接无效')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
