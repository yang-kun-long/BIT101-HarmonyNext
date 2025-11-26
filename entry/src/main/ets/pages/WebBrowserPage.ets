// entry/src/main/ets/pages/WebBrowserPage.ets
import router from '@ohos.router';
import web_webview from '@ohos.web.webview';

@Entry
@Component
struct WebBrowserPage {
  @State url: string = '';
  @State title: string = '详情';
  @State progress: number = 0; // 加载进度 0-100
  @State isLoading: boolean = true;

  // Web控制器，用于控制网页行为
  controller: web_webview.WebviewController = new web_webview.WebviewController();

  aboutToAppear() {
    // 获取传递过来的参数
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.url = params['url'] || '';
      // 如果没有传标题，默认显示 "加载中..."，等网页加载完再更新标题
      this.title = params['title'] || '外部链接';
    }
  }

  build() {
    Column() {
      // 1. 顶部标题栏
      Row() {
        // 返回按钮
        Image($r('app.media.ic_public_back')) // 请确保你有这个图标，没有就用 Text('<')
          .width(24)
          .height(24)
          .margin({ right: 16 })
          .onClick(() => {
            // 如果网页能后退，优先网页后退；否则退出页面
            if (this.controller.accessBackward()) {
              this.controller.backward();
            } else {
              router.back();
            }
          })

        // 标题
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .fontColor('#1F2937')

        // 关闭按钮 (直接退出页面，不处理网页后退)
        Text('×') // 请确保你有这个图标，没有就用 Text('×')
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => router.back())
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .shadow({ radius: 2, color: '#0F000000', offsetY: 1 })
      .zIndex(10)

      // 2. 进度条 (加载时显示)
      if (this.isLoading && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color('#2563EB') // 你的主题蓝色
          .backgroundColor(Color.Transparent)
      }

      // 3. Web 容器
      Web({ src: this.url, controller: this.controller })
        .width('100%')
        .layoutWeight(1)
        .domStorageAccess(true) // 允许本地存储
        .javaScriptAccess(true) // 允许 JS 执行
        .databaseAccess(true)
        .fileAccess(false) // 安全起见，通常禁止访问本地文件
        .darkMode(WebDarkMode.Auto) // 跟随系统深色模式

        // 监听加载进度
        .onProgressChange((event) => {
          if (event) {
            this.progress = event.newProgress;
            if (this.progress === 100) {
              this.isLoading = false;
            }
          }
        })
        // 监听网页标题变化，自动更新标题栏
        .onTitleReceive((event) => {
          if (event && event.title) {
            this.title = event.title;
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}