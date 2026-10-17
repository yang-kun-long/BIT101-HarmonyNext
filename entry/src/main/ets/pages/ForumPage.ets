import web_webview from '@ohos.web.webview';
import { WebNavigationState } from '../components/web/WebNavigationModel';
import { WebPage } from '../components/web/WebPage';

@Component
export default struct ForumPage {
  controller: web_webview.WebviewController = new web_webview.WebviewController();
  private readonly navigation: WebNavigationState = new WebNavigationState();
  private readonly forumUrl: string = 'https://bit101.cn/';

  build() {
    Column() {
      WebPage({ url: this.forumUrl, controller: this.controller, navigation: this.navigation })
    }
    .width('100%')
    .height('100%')
  }
}
