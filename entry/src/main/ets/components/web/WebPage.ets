import web_webview from '@ohos.web.webview';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { Logger } from '../../utils/Logger';
import { handleFileSelect, WebFileSelectorEvent } from './WebUtils';
import {
  buildWebSessionInjectionScript,
  isAllowedInWebView,
  shouldInjectBit101Session,
  WebSessionModel,
  WebSessionState,
  WebThemeMode,
} from './WebSessionModel';

@Component
export struct WebPage {
  @Prop url: string;
  @Prop allowInitialOrigin: boolean = false;
  @StorageLink('themeIsDark') themeIsDark: boolean = false;
  @State progress: number = 0;
  @State isLoading: boolean = true;
  @State sessionReady: boolean = false;
  @State errorMessage: string = '';
  @State sessionState: WebSessionState = {
    fakeCookie: '',
    username: '',
    credentialState: 'unavailable',
  };

  controller: web_webview.WebviewController = new web_webview.WebviewController();
  onTitleChange: (title: string) => void = () => {};

  private readonly logger: Logger = new Logger('WebPage');
  private readonly sessionModel: WebSessionModel = new WebSessionModel();
  private readonly context: common.UIAbilityContext =
    this.getUIContext().getHostContext() as common.UIAbilityContext;
  private hasReloadedForSession: boolean = false;

  aboutToAppear(): void {
    this.prepareSession();
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.sessionReady) {
        Web({
          src: this.url,
          controller: this.controller,
        })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .imageAccess(true)
          .mixedMode(MixedMode.None)
          .onlineImageAccess(true)
          .zoomAccess(false)
          .databaseAccess(true)
          .onPageBegin((event) => {
            this.isLoading = true;
            this.progress = 0;
            this.errorMessage = '';
            this.logger.debug('Page loading started');
          })
          .onPageEnd((event) => {
            this.isLoading = false;
            this.progress = 100;
            this.errorMessage = '';
            this.syncSessionAfterLoad(event.url);
          })
          .onLoadIntercept((event) => {
            if (!event) {
              return false;
            }
            const targetUrl: string = event.data.getRequestUrl();
            if (isAllowedInWebView(targetUrl, this.url, this.allowInitialOrigin)) {
              return false;
            }
            this.openExternal(targetUrl);
            return true;
          })
          .onShowFileSelector((event) => {
            if (!event) {
              return false;
            }
            handleFileSelect((event as ESObject) as WebFileSelectorEvent);
            return true;
          })
          .onProgressChange((event) => {
            if (event) {
              this.progress = event.newProgress;
              if (this.progress === 100) {
                this.isLoading = false;
              }
            }
          })
          .onTitleReceive((event) => {
            if (event && event.title) {
              this.onTitleChange(event.title);
            }
          })
          .onErrorReceive((event) => {
            this.isLoading = false;
            this.errorMessage = '页面加载失败';
            this.logger.error('Web resource error, code=' + event.error.getErrorCode());
          })
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeIsDark ? '#000000' : '#FFFFFF')
      } else {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(this.themeIsDark ? '#FF9A57' : '#007DFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.isLoading && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .color(this.themeIsDark ? '#FF9A57' : '#007DFF')
          .width('100%')
          .height(2)
      }

      if (this.errorMessage.length > 0) {
        Column({ space: 16 }) {
          Text(this.errorMessage)
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Button('重试')
            .onClick(() => {
              this.errorMessage = '';
              this.isLoading = true;
              this.controller.refresh();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_background'))
      }
    }
    .width('100%')
    .height('100%')
  }

  private async prepareSession(): Promise<void> {
    try {
      this.sessionState = await this.sessionModel.load();
    } catch (error) {
      this.logger.error('Load Web session failed', error);
      this.sessionState = {
        fakeCookie: '',
        username: '',
        credentialState: 'unavailable',
      };
    } finally {
      this.sessionReady = true;
    }
  }

  private async syncSessionAfterLoad(pageUrl: string): Promise<void> {
    if (!shouldInjectBit101Session(pageUrl)) {
      return;
    }
    try {
      this.sessionState = await this.sessionModel.load();
      const themeMode: WebThemeMode = this.themeIsDark ? 'dark' : 'light';
      const script: string = buildWebSessionInjectionScript(this.sessionState, themeMode);
      await this.controller.runJavaScript(script);
      if (!this.hasReloadedForSession) {
        this.hasReloadedForSession = true;
        this.controller.refresh();
      }
    } catch (error) {
      this.logger.error('Sync Web session failed', error);
    }
  }

  private async openExternal(targetUrl: string): Promise<void> {
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: targetUrl,
      };
      await this.context.startAbility(want);
    } catch (error) {
      this.logger.error('Open external URL failed', error);
    }
  }
}
