import { Logger } from '../utils/Logger';
import router from '@ohos.router';
import { isAuthedBit101 } from '../services/auth/authGuard';
// 引入 PageEnum 用于和设置页数据对接
import { PageShowOnNav } from './PageEnum';

import ScheduleShellPage from './ScheduleShellPage';
import MapPage from './MapPage';
import MapPage2 from './MapPage2';
import ForumPage from './ForumPage';
import PostPage from './PostPage';
import MePage from './MePage';

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

  // --- 接入设置页数据 (仅用于控制底部栏显示顺序) ---
  @StorageLink('pages_order') storagePages: PageShowOnNav[] = [];
  @StorageLink('pages_hidden') storageHidden: PageShowOnNav[] = [];

  // 4. 核心映射：将设置页的 String 枚举映射回 TabKey 数字枚举
  private tabMapping: Record<string, TabKey> = {
    [PageShowOnNav.Home]: TabKey.Schedule,     // 首页 -> 卷
    [PageShowOnNav.Schedule]: TabKey.Schedule, // 课表 -> 卷
    [PageShowOnNav.DDL]: TabKey.Schedule,      // DDL  -> 卷
    [PageShowOnNav.Map]: TabKey.Map,           // 地图 -> 图
    [PageShowOnNav.Forum]: TabKey.Forum,       // 论坛 -> 网
    [PageShowOnNav.Post]: TabKey.Post,         // 发帖 -> 话
    [PageShowOnNav.Mine]: TabKey.Me            // 我的 -> 我
  };

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    const tabParam = params?.['tab'] as number | undefined;

    if (tabParam !== undefined) {
      const t = tabParam as TabKey;
      this.goto(t, false);
    } else {
      // 默认加载首页
      this.goto(TabKey.Schedule, false);
    }
  }

  // 切换逻辑 (保持原样)
  private async goto(tab: TabKey, checkAuth: boolean = true) {
    // 权限检查
    const needAuth = (tab === TabKey.Schedule || tab === TabKey.Forum || tab === TabKey.Post);
    if (checkAuth && needAuth && !(await isAuthedBit101())) {
      await router.pushUrl({ url: 'pages/LoginPage', params: { redirect: 'pages/Index' } });
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
    // 1. 获取原始数据，如果没有就用硬编码的完整默认值 (防止数据丢失导致Tab消失)
    let pages = this.storagePages;
    if (!pages || pages.length === 0) {
      pages = [
        PageShowOnNav.Home,
        PageShowOnNav.Map,
        PageShowOnNav.Forum,
        PageShowOnNav.Post,
        PageShowOnNav.Mine
      ];
    }

    // 2. 获取隐藏列表
    const hidden = this.storageHidden || [];

    // 3. 过滤逻辑
    const result: PageShowOnNav[] = [];
    const seenTabKeys = new Set<TabKey>();

    for (const p of pages) {
      if (hidden.includes(p)) continue; // 如果被隐藏了就跳过

      const mappedKey = this.tabMapping[p];
      // 只有当映射存在，且该 TabKey 还没显示过时，才加入
      // (避免 Home, Schedule, DDL 同时出现导致底部有3个“卷”图标)
      if (mappedKey !== undefined && !seenTabKeys.has(mappedKey)) {
        result.push(p);
        seenTabKeys.add(mappedKey);
      }
    }
    return result;
  }

  // 获取图标文字
  getTabLabel(page: PageShowOnNav): string {
    const key = this.tabMapping[page];
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
        .fontSize(this.current === this.tabMapping[page] ? 16 : 14)
        .fontWeight(this.current === this.tabMapping[page] ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === this.tabMapping[page] ? '#2563EB' : '#6B7280')
    }
    .padding({ top: 10, bottom: 6 })
    .layoutWeight(1)
    .onClick(() => {
      const key = this.tabMapping[page];
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
    .backgroundColor('#FFFFFF')
    .padding({ left: 8, right: 8 })
    .border({ width: { top: 0.5 }, color: '#E5E7EB' })
  }

  build() {
    Column() {
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
    .backgroundColor('#F7F7F7')
    .height('100%')
    .width('100%')
  }
}