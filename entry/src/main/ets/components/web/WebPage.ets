// entry/src/main/ets/components/web/WebPage.ets
import { Logger } from '../../utils/Logger';
import web_webview from '@ohos.web.webview';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
// 引入工具类
import { handleFileSelect, WebFileSelectorEvent } from './WebUtils';
import { uiShowToast } from '../../utils/uiContextBridge';

@Component
export struct WebPage {
  private logger = new Logger('WebPage');
  // --- 外部参数 ---
  @Prop url: string;

  // --- 全局状态订阅 ---
  @StorageLink('themeIsDark') themeIsDark: boolean = false;
  @StorageLink('fakeCookie') fakeCookie: string = '';
  @StorageLink('studentId') studentId: string = '';
  @StorageLink('password') password: string = '';

  // --- 内部状态 ---
  @State progress: number = 0;
  @State isLoading: boolean = true;

  // Web 控制器
  controller: web_webview.WebviewController = new web_webview.WebviewController();

  // 上下文
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // === Layer 1: 浏览器核心 ===
      Web({
        src: this.url,
        controller: this.controller
      })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .mixedMode(MixedMode.All)
        .onlineImageAccess(true)
        .zoomAccess(false)
        .databaseAccess(true)

        // 2. 页面开始加载
        .onPageBegin(() => {
          this.isLoading = true;
          this.injectState();
        })

        // 3. 页面加载结束
        .onPageEnd(() => {
          this.isLoading = false;
          this.autoFillScore();
        })

        // 4. 链接拦截
        .onLoadIntercept((event) => {
          if (!event) {
            return false;
          }
          const url = event.data.getRequestUrl();
          // 白名单
          if (url.includes('bit.edu.cn') || url.includes('flwfdd.xyz') || url.includes('bit101.cn')) {
            return false;
          }

          // 拦截处理：拉起系统浏览器
          // 【修复点】增加 try-catch 处理潜在异常
          try {
            let want: Want = {
              action: 'ohos.want.action.viewData',
              entities: ['entity.system.browsable'],
              uri: url
            };
            this.context.startAbility(want);
          } catch (error) {
            this.logger.error('StartAbility failed:', error);
          }
          return true;
        })

        // 5. 文件上传支持
        .onShowFileSelector((event) => {
          if (event) {
            // 【修复点】使用 ESObject 替代 unknown，解决红色报错
            // ESObject 是 ArkTS 允许的“任意类型”，专门用于桥接原生对象
            handleFileSelect((event as ESObject) as WebFileSelectorEvent);
            return true;
          }
          return false;
        })
        .onConsole((event) => {
          if (event) {
            const msg = event.message.getMessage();
            const level = event.message.getMessageLevel();
            // level枚举: 1: Debug, 2: Info, 3: Warn, 4: Error, 0: Tip

            // 转发给 Logger，这样就能受黑/白名单控制了
            // 加个 [Web] 前缀方便区分
            if (level === 4) {
              this.logger.error('[Web]', msg);
            } else if (level === 3) {
              this.logger.warn('[Web]', msg);
            } else {
              // Info/Debug/Log 全部降级为 Debug，保持清爽
              this.logger.debug('[Web]', msg);
            }
            // 返回 true 表示“消费掉这个事件”，阻止系统默认的 ARKWEB-CONSOLE 打印
            return true;
          }
          return false;
        })

        // 6. 进度条更新
        .onProgressChange((event) => {
          if (event) {
            this.progress = event.newProgress;
            if (this.progress === 100) {
              this.isLoading = false;
            }
          }
        })
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeIsDark ? '#000000' : '#FFFFFF')

      // === Layer 2: 顶部进度条 ===
      if (this.isLoading && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .color(this.themeIsDark ? '#FFD700' : '#007DFF')
          .width('100%')
          .height(2)
      }
    }
  }

  /**
   * 注入状态到 H5
   */
  injectState() {
    const mode = this.themeIsDark ? 'dark' : 'light';
    const cookie = this.fakeCookie;

    const injectScript = `
      try {
        let store = {};
        const oldStore = window.localStorage.getItem("store");
        if (oldStore) {
          store = JSON.parse(oldStore);
        }
        store.theme_mode = "${mode}";
        if ("${cookie}" !== "") {
          store.fake_cookie = "${cookie}";
        }
        window.localStorage.setItem("store", JSON.stringify(store));
      } catch (e) {
        console.error("BIT101 Injection Error: " + e);
      }
    `;

    // 【修复点】增加 try-catch，消除黄色警告
    try {
      this.controller.runJavaScript(injectScript);
    } catch (error) {
      this.logger.error('InjectState failed:', error);
    }
  }

  /**
   * 成绩单自动填充
   */
  autoFillScore() {
    if (this.url.includes('/score') && this.studentId && this.password) {
      const fillScript = `
        var sidInput = document.getElementById("sid");
        var pwdInput = document.getElementById("password");
        if (sidInput && pwdInput) {
          sidInput.value = "${this.studentId}";
          sidInput.dispatchEvent(new Event('input'));
          pwdInput.value = "${this.password}";
          pwdInput.dispatchEvent(new Event('input'));
        }
      `;
      // 【修复点】增加 try-catch，消除黄色警告
      try {
        this.controller.runJavaScript(fillScript);
        uiShowToast(this.getUIContext(), { message: '已为您自动填充学号密码' });
      } catch (error) {
        this.logger.error('AutoFill failed:', error);
      }
    }
  }
}
