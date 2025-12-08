// entry/src/main/ets/pages/Index.ets
import { Logger } from '../utils/Logger';
import ScheduleShellPage from './ScheduleShellPage'
import MapPage from './MapPage'
import MapPage2 from './MapPage2'
import ForumPage from './ForumPage'
import PostPage from './PostPage'
import MePage from './MePage'
import router from '@ohos.router'
import { isAuthedBit101 } from '../services/auth/authGuard'

enum TabKey {
  Schedule = 0, // 卷：课表/DDL（受保护，需登录）
  Map = 1,      // 图：地图（游客可见）
  Forum = 2,    // 网：话廊（受保护，需登录）
  Post = 3,     // 话：发帖（受保护，需登录）
  Me = 4        // 我：个人信息（游客可见）
}

@Entry
@Component
struct Index {
  private logger = new Logger('Index');
  @State current: TabKey = TabKey.Schedule

  // 🔥 核心修改：添加状态位，用于实现“懒加载 + 保活”
  // 只有当用户点过一次后，该标志位变为 true，组件才会被创建
  // 创建后，即使切走，该标志位依然为 true，所以组件不会被销毁，只是被隐藏
  @State isMapLoaded: boolean = false
  @State isForumLoaded: boolean = false
  @State isPostLoaded: boolean = false
  @State isMeLoaded: boolean = false
  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    const tabParam = params?.['tab'] as number | undefined;

    if (tabParam !== undefined) {
      const t = tabParam as TabKey;
      this.current = t;

      // 同时把对应页面标记为已加载，避免 tab 切不过去
      if (t === TabKey.Map) this.isMapLoaded = true;
      if (t === TabKey.Forum) this.isForumLoaded = true;
      if (t === TabKey.Post) this.isPostLoaded = true;
      if (t === TabKey.Me) this.isMeLoaded = true;
    }
  }

  private async goto(tab: TabKey) {
    const needAuth = (tab === TabKey.Schedule || tab === TabKey.Forum || tab === TabKey.Post)
    if (needAuth && !(await isAuthedBit101())) {
      await router.pushUrl({ url: 'pages/LoginPage', params: { redirect: 'pages/Index' } })
      return
    }

    // 🔥 激活对应页面的加载标志位
    if (tab === TabKey.Map) this.isMapLoaded = true;
    if (tab === TabKey.Forum) this.isForumLoaded = true;
    if (tab === TabKey.Post) this.isPostLoaded = true;
    if (tab === TabKey.Me) this.isMeLoaded = true;

    this.current = tab
    this.logger.info('切换 Tab 至:', this.current);
  }

  @Builder
  TabButton(label: string, key: TabKey) {
    Column() {
      Text(label)
        .fontSize(this.current === key ? 16 : 14)
        .fontWeight(this.current === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === key ? '#2563EB' : '#6B7280')
    }
    .padding({ top: 10, bottom: 6 })
    .onClick(() => { this.goto(key) })
    .layoutWeight(1)
  }

  @Builder
  BottomBar() {
    Row() {
      this.TabButton('卷', TabKey.Schedule)
      this.TabButton('图', TabKey.Map)
      this.TabButton('网', TabKey.Forum)
      this.TabButton('话', TabKey.Post)
      this.TabButton('我', TabKey.Me)
    }
    .height(52)
    .backgroundColor('#FFFFFF')
    .padding({ left: 8, right: 8 })
  }

  build() {
    Column() {
      // 内容区
      // 🔥 改用 Stack 叠加模式，配合 Visibility 控制显隐
      Stack() {

        // 1. Schedule (首页，始终存在)
        ScheduleShellPage()
          .visibility(this.current === TabKey.Schedule ? Visibility.Visible : Visibility.None)
          .width('100%').height('100%')

        // 2. Map (懒加载 + 保活)
        // 只要 this.isMapLoaded 为 true，MapPage 就会一直存在于组件树中
        // 切走时，只是 Visibility 变为 None，WebView 进程依然活着，状态不丢失
        if (this.isMapLoaded) {
          MapPage()
            .visibility(this.current === TabKey.Map ? Visibility.Visible : Visibility.None)
            .width('100%').height('100%')
        }

        // 3. Forum
        if (this.isForumLoaded) {
          ForumPage()
            .visibility(this.current === TabKey.Forum ? Visibility.Visible : Visibility.None)
            .width('100%').height('100%')
        }

        // 4. Post
        if (this.isPostLoaded) {
          PostPage()
            .visibility(this.current === TabKey.Post ? Visibility.Visible : Visibility.None)
            .width('100%').height('100%')
        }

        // 5. Me
        if (this.isMeLoaded) {
          MePage()
            .visibility(this.current === TabKey.Me ? Visibility.Visible : Visibility.None)
            .width('100%').height('100%')
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