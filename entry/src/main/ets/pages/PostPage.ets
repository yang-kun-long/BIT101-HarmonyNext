// entry/src/main/ets/pages/PostPage.ets
import { Logger } from '../utils/Logger';
import { PostersTabPage } from '../components/gallery/PostersTabPage';
import { PosterListState } from '../services/gallery/PosterListState';
import { PostersMode } from '../services/gallery/GalleryService';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router'; // 确保引入 router

@Component
export default struct PostPage {
  private logger = new Logger('PostPage');
  // --- 1. 数据流保持不变 ---
  @State recommendState: PosterListState = new PosterListState(PostersMode.Recommend);
  @State hotState: PosterListState = new PosterListState(PostersMode.Hot);
  @State newestState: PosterListState = new PosterListState(PostersMode.Newest);
  @State followState: PosterListState = new PosterListState(PostersMode.Follow);

  // 当前选中的 Tab 索引，默认选中 "推荐"
  @State currentIndex: number = 1;

  // Tab 控制器
  private controller: TabsController = new TabsController();

  // Tab 标题配置
  private tabItems: string[] = ['关注', '推荐', '最新', '最热'];

  // --- 业务逻辑：打开详情 ---
  openPosterDetail(id: number): void {
    router.pushUrl({
      url: 'pages/PosterDetailPage',
      params: { id }
    });
  }

  // ============================================
  // [新增] 业务逻辑：跳转去发帖页面
  // ============================================
  onPostClick(): void {
    router.pushUrl({
      url: 'pages/PostEditorPage'
    }).catch((err: Error) => {
      // 如果跳转失败，通常是 main_pages.json 没配置好
      this.logger.error('Jump to PostEditorPage failed:', err);
    });
  }

  // --- 业务逻辑：搜索 ---
  onSearchClick(): void {
    // [修改] 之前是弹窗，现在改为跳转到 SearchPage
    router.pushUrl({
      url: 'pages/SearchPage'
    }).catch((err: Error) => {
      this.logger.error('Jump to SearchPage failed:', err);
    });
  }

  build() {
    Column() {
      // ============================================================
      // 2. 顶部栏 (UI 不变)
      // ============================================================
      Row() {
        // Tab 标题
        Row() {
          ForEach(this.tabItems, (item: string, index: number) => {
            Column() {
              Text(item)
                .fontColor(this.currentIndex === index ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                .fontSize(18)
                .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium)
                .animation({ duration: 200 })
            }
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.currentIndex = index;
              this.controller.changeIndex(index);
            })
            .width('25%')
          })
        }
        .width(280)
        .height('100%')

        Blank()

        // 搜索按钮
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(24)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .backgroundColor(Color.Transparent)
        .width(48)
        .height(48)
        .onClick(() => {
          this.onSearchClick();
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .zIndex(1)

      // ============================================================
      // 3. 内容区域
      // ============================================================
      Tabs({
        barPosition: BarPosition.Start,
        controller: this.controller,
        index: this.currentIndex
      }) {
        // Tab 0: 关注
        TabContent() {
          PostersTabPage({
            state: this.followState,
            onOpenPoster: (id: number) => this.openPosterDetail(id),
            // ✅ 绑定发帖事件
            onOpenPostOrEdit: () => this.onPostClick()
          })
        }.tabBar(null)

        // Tab 1: 推荐
        TabContent() {
          PostersTabPage({
            state: this.recommendState,
            onOpenPoster: (id: number) => this.openPosterDetail(id),
            // ✅ 绑定发帖事件
            onOpenPostOrEdit: () => this.onPostClick()
          })
        }.tabBar(null)

        // Tab 2: 最新
        TabContent() {
          PostersTabPage({
            state: this.newestState,
            onOpenPoster: (id: number) => this.openPosterDetail(id),
            // ✅ 绑定发帖事件
            onOpenPostOrEdit: () => this.onPostClick()
          })
        }.tabBar(null)

        // Tab 3: 最热
        TabContent() {
          PostersTabPage({
            state: this.hotState,
            onOpenPoster: (id: number) => this.openPosterDetail(id),
            // ✅ 绑定发帖事件
            onOpenPostOrEdit: () => this.onPostClick()
          })
        }.tabBar(null)
      }
      .barHeight(0)
      .vertical(false)
      .scrollable(true)
      .animationDuration(200)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}