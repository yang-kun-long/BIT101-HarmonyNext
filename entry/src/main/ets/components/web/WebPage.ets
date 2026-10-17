import { canOpenExternalWebUrl, isHttpWebUrl, shouldShowWebError, WebNavigationState, WebScrollPosition } from './WebNavigationModel';
import { uiShowToast } from '../../utils/uiContextBridge';
import { observeWebLogout, webSessionRevision } from '../../services/auth/WebLogout';
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
  navigation: WebNavigationState = new WebNavigationState();
  @State initialUrl: string = '';
  private restoreScroll: WebScrollPosition | null = null;
  private restoreUrl: string = '';
  private attached: boolean = false;
  private alive: boolean = true;
  private loadGeneration: number = 0;
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
  private stopLogout: () => void = () => {};
  private sessionRevision: number = webSessionRevision();

  aboutToAppear(): void {
    this.stopLogout = observeWebLogout(async () => {
      this.loadGeneration++;
      this.sessionRevision = webSessionRevision();
      this.navigation.clear();
      this.restoreScroll = null; this.restoreUrl = '';
      this.hasReloadedForSession = false;
      if (this.attached) this.controller.stop();
      this.sessionReady = false;
      this.errorMessage = '已退出登录，点击重试以重新打开网页';
      this.isLoading = false;
    });
    if (this.sessionRevision !== webSessionRevision()) {
      this.navigation.clear();
      this.sessionRevision = webSessionRevision();
    }
    this.alive = true;
    this.initialUrl = this.navigation.url || this.url;
    if (!isHttpWebUrl(this.initialUrl) || !isAllowedInWebView(this.initialUrl, this.url, this.allowInitialOrigin)) {
      this.errorMessage = '链接无效'; this.isLoading = false; return;
    }
    if (this.navigation.url) {
      this.restoreUrl = this.navigation.url;
      this.restoreScroll = { x: this.navigation.scroll.x, y: this.navigation.scroll.y };
    }
    this.prepareSession();
  }

  aboutToDisappear(): void {
    this.stopLogout();
    this.alive = false; this.loadGeneration++;
    if (!this.attached || this.sessionRevision !== webSessionRevision() || !this.sessionReady) return;
    try {
      this.navigation.recordUrl(this.controller.getUrl());
      this.navigation.recordHistory(this.controller.serializeWebState());
    } catch (error) { this.logger.error('Save Web browsing state failed', error); }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.sessionReady) {
        Web({
          src: this.initialUrl,
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
          .onControllerAttached(() => {
            this.attached = true;
            if (this.navigation.history) {
              try { this.controller.restoreWebState(this.navigation.history); }
              catch (_) { this.navigation.history = null; }
            }
          })
          .onScroll((event) => {
            if (event) this.navigation.recordScroll(event.xOffset, event.yOffset);
          })
          .onRefreshAccessedHistory((event) => {
            if (event) this.navigation.recordUrl(event.url);
          })
          .onPageBegin((event) => {
            this.loadGeneration++;
            this.isLoading = true;
            this.progress = 0;
            this.errorMessage = '';
            this.logger.debug('Page loading started');
          })
          .onPageEnd((event) => {
            this.isLoading = false;
            this.progress = 100;
            this.navigation.recordUrl(event.url);
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
            if (event.data.isMainFrame()) this.openExternal(targetUrl);
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
          .onDownloadStart((event) => {
            if (!event) return;
            if (isHttpWebUrl(event.url)) this.openExternal(event.url);
            else uiShowToast(this.getUIContext(), { message: '此下载链接暂无法打开' });
          })
          .onHttpErrorReceive((event) => {
            if (event && shouldShowWebError(event.request.isMainFrame(), event.response.getResponseCode())) {
              this.isLoading = false; this.errorMessage = '页面暂时无法访问，请重试';
            }
          })
          .onErrorReceive((event) => {
            if (!event || !shouldShowWebError(event.request.isMainFrame())) return;
            this.isLoading = false;
            this.errorMessage = '页面加载失败';
            this.logger.error('Web resource error, code=' + event.error.getErrorCode());
          })
          .width('100%')
          .height('100%')
          .backgroundColor($r('sys.color.ohos_id_color_background'))
      } else {
        Column() {
          if (!this.errorMessage) {
            LoadingProgress()
              .width(32)
              .height(32)
              .color(this.themeIsDark ? '#FF9A57' : '#007DFF')
          }
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
              if (this.attached) this.controller.refresh();
              else this.prepareSession();
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
    const revision = webSessionRevision();
    if (!isHttpWebUrl(this.initialUrl) || !isAllowedInWebView(this.initialUrl, this.url, this.allowInitialOrigin)) {
      this.isLoading = false; this.errorMessage = '链接无效'; return;
    }
    try {
      const session = await this.sessionModel.load();
      if (!this.alive || revision !== webSessionRevision()) return;
      this.sessionState = session;
    } catch (error) {
      this.logger.error('Load Web session failed', error);
      this.sessionState = {
        fakeCookie: '',
        username: '',
        credentialState: 'unavailable',
      };
    } finally {
      if (this.alive && revision === webSessionRevision()) this.sessionReady = true;
    }
  }

  private async syncSessionAfterLoad(pageUrl: string): Promise<void> {
    const generation = this.loadGeneration;
    if (shouldInjectBit101Session(pageUrl)) {
      try {
        const session = await this.sessionModel.load();
        if (!this.alive || generation !== this.loadGeneration || this.controller.getUrl() !== pageUrl) return;
        this.sessionState = session;
        const themeMode: WebThemeMode = this.themeIsDark ? 'dark' : 'light';
        await this.controller.runJavaScript(buildWebSessionInjectionScript(session, themeMode));
        if (!this.alive || generation !== this.loadGeneration) return;
        if (!this.hasReloadedForSession) {
          this.hasReloadedForSession = true;
          this.controller.refresh();
          return;
        }
      } catch (error) { this.logger.error('Sync Web session failed', error); }
    }
    if (this.restoreScroll && this.restoreUrl === pageUrl && generation === this.loadGeneration) {
      try { this.controller.scrollTo(this.restoreScroll.x, this.restoreScroll.y); }
      catch (error) { this.logger.error('Restore Web scroll failed', error); }
    }
    if (generation === this.loadGeneration) this.restoreScroll = null;
  }

  private async openExternal(targetUrl: string): Promise<void> {
    if (!canOpenExternalWebUrl(targetUrl)) {
      uiShowToast(this.getUIContext(), { message: '此链接暂无法打开' }); return;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: targetUrl,
      };
      await this.context.startAbility(want);
    } catch (error) {
      this.logger.error('Open external URL failed', error);
      uiShowToast(this.getUIContext(), { message: '未能打开外部链接，请重试' });
    }
  }
}
