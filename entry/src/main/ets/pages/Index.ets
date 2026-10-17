import { Logger } from '../utils/Logger';
import { isAuthedBit101 } from '../services/auth/authGuard';
// 引入 PageEnum 用于和设置页数据对接
import { PageShowOnNav } from './PageEnum';
import { defaultPageSettings, migratePageSettings, navigationTabIndex, resolveStartupTab } from '../services/settings/PageSettingsModel';
import { uiGetParams, uiPushUrl } from '../utils/uiContextBridge';

import ScheduleShellPage from './ScheduleShellPage';
import MapPage from './MapPage';
import ForumPage from './ForumPage';
import PostPage from './PostPage';
import MePage from './MePage';
import { SmsChallengeDialogHost } from '../components/auth/SmsVerificationDialog';
import { UpdateChecker } from '../components/settings/UpdateChecker';

// 1. 保持你原有的数字枚举，这是页面切换的核心
enum TabKey {
  Schedule = 0, // 卷
  Map = 1,      // 图
  Forum = 2,    // 网
  Post = 3,     // 话
  Me = 4        // 我
}

@Entry
@Component
struct Index {
  private logger = new Logger('Index');

  // 2. 当前选中的 Tab，默认为 卷
  @State current: TabKey = TabKey.Schedule;

  // 3. 懒加载保活标志位 (Stack + if 控制)
  @State isMapLoaded: boolean = false;
  @State isForumLoaded: boolean = false;
  @State isPostLoaded: boolean = false;
  @State isMeLoaded: boolean = false;

  @StorageLink('pages_order') storagePages: PageShowOnNav[] = defaultPageSettings().order;
  @StorageLink('pages_hidden') @Watch('onNavigationChanged') storageHidden: PageShowOnNav[] = [];
  @StorageLink('home_page') homePage: PageShowOnNav = PageShowOnNav.Schedule;

  aboutToAppear() {
    const params = uiGetParams(this.getUIContext()) as Record<string, Object>;
    const tabParam = params?.['tab'] as number | undefined;
    this.goto(resolveStartupTab(this.homePage, tabParam) as TabKey, false);
  }

  private onNavigationChanged(): void {
    if (this.storageHidden.some(page => navigationTabIndex(page) === this.current)) {
      this.goto(resolveStartupTab(this.homePage) as TabKey, false);
    }
  }

  // 切换逻辑 (保持原样)
  private async goto(tab: TabKey, checkAuth: boolean = true) {
    // 权限检查
    const needAuth = (tab === TabKey.Schedule || tab === TabKey.Forum || tab === TabKey.Post);
    if (checkAuth && needAuth && !(await isAuthedBit101())) {
      await uiPushUrl(this.getUIContext(), { url: 'pages/LoginPage', params: { redirect: 'pages/Index' } });
      return;
    }

    // 激活对应的懒加载标志位
    if (tab === TabKey.Map) this.isMapLoaded = true;
    if (tab === TabKey.Forum) this.isForumLoaded = true;
    if (tab === TabKey.Post) this.isPostLoaded = true;
    if (tab === TabKey.Me) this.isMeLoaded = true;

    this.current = tab;
    this.logger.info('切换 Tab 至:', this.current);
  }

  // 计算底部应该显示哪些 Tab (动态列表)
  getVisibleTabs(): PageShowOnNav[] {
    const settings = migratePageSettings({ order: this.storagePages, hidden: this.storageHidden, home: this.homePage });
    return settings.order.filter(page => !settings.hidden.includes(page));
  }

  // 获取图标文字
  getTabLabel(page: PageShowOnNav): string {
    const key = navigationTabIndex(page);
    switch (key) {
      case TabKey.Schedule: return '卷';
      case TabKey.Map: return '图';
      case TabKey.Forum: return '网';
      case TabKey.Post: return '话';
      case TabKey.Me: return '我';
      default: return '?';
    }
  }

  // 单个 Tab 按钮组件
  @Builder
  TabButton(page: PageShowOnNav) {
    // 找到对应的 TabKey 用于判断高亮
    Column() {
      Text(this.getTabLabel(page))
        .fontSize(this.current === navigationTabIndex(page) ? 16 : 14)
        .fontWeight(this.current === navigationTabIndex(page) ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === navigationTabIndex(page) ? $r('sys.color.ohos_id_color_primary') : $r('sys.color.ohos_id_color_text_secondary'))
    }
    .padding({ top: 10, bottom: 6 })
    .layoutWeight(1)
    .onClick(() => {
      const key = navigationTabIndex(page);
      if (key !== undefined) this.goto(key);
    })
  }

  // 底部导航栏
  @Builder
  BottomBar() {
    Row() {
      // 动态遍历
      ForEach(this.getVisibleTabs(), (page: PageShowOnNav) => {
        this.TabButton(page)
      })
    }
    .height(52)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .padding({ left: 8, right: 8 })
    .border({ width: { top: 0.5 }, color: $r('sys.color.ohos_id_color_list_separator') })
  }

  build() {
    Column() {
      SmsChallengeDialogHost()
      UpdateChecker()

      // 内容区 (Stack + Visibility)
      Stack() {
        // 1. Schedule (卷) - 始终存在，只控制显隐
        // 包裹 Column 以避免语法检查错误
        Column() {
          ScheduleShellPage()
        }
        .width('100%')
        .height('100%')
        .visibility(this.current === TabKey.Schedule ? Visibility.Visible : Visibility.None)

        // 2. Map (图)
        if (this.isMapLoaded) {
          Column() {
            MapPage()
          }
          .width('100%')
          .height('100%')
          .visibility(this.current === TabKey.Map ? Visibility.Visible : Visibility.None)
        }

        // 3. Forum (网)
        if (this.isForumLoaded) {
          Column() {
            ForumPage()
          }
          .width('100%')
          .height('100%')
          .visibility(this.current === TabKey.Forum ? Visibility.Visible : Visibility.None)
        }

        // 4. Post (话)
        if (this.isPostLoaded) {
          Column() {
            PostPage()
          }
          .width('100%')
          .height('100%')
          .visibility(this.current === TabKey.Post ? Visibility.Visible : Visibility.None)
        }

        // 5. Me (我)
        if (this.isMeLoaded) {
          Column() {
            MePage()
          }
          .width('100%')
          .height('100%')
          .visibility(this.current === TabKey.Me ? Visibility.Visible : Visibility.None)
        }
      }
      .layoutWeight(1)
      .width('100%')

      // 底部导航
      this.BottomBar()
    }
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .height('100%')
    .width('100%')
  }
}
