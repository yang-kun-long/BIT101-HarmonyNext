import { PostersTabPage } from '../components/gallery/PostersTabPage';
import { PosterListState } from '../services/gallery/PosterListState';
import { PostersMode } from '../services/gallery/GalleryService';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

@Component
export default struct PostPage {
  // --- 1. 数据流保持不变 ---
  @State recommendState: PosterListState = new PosterListState(PostersMode.Recommend);
  @State hotState: PosterListState = new PosterListState(PostersMode.Hot);
  @State newestState: PosterListState = new PosterListState(PostersMode.Newest);
  @State followState: PosterListState = new PosterListState(PostersMode.Follow);

  // 当前选中的 Tab 索引，默认选中 "推荐" (索引1，与安卓对齐)
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

  // --- 业务逻辑：搜索（未实现接口，使用弹窗占位） ---
  onSearchClick(): void {
    promptAction.showToast({
      message: '搜索功能开发中...\n用户ID: 待对接', // 模拟你的示例需求
      duration: 2000,
      bottom: 400
    });
  }

  build() {
    Column() {
      // ============================================================
      // 2. 自定义顶部栏 (完全复刻安卓 Scaffold TopAppBar 布局)
      // ============================================================
      Row() {
        // 2.1 左侧 Tab 区域：固定宽度 280vp，模拟安卓的 Modifier.width(280.dp)
        Row() {
          ForEach(this.tabItems, (item: string, index: number) => {
            Column() {
              // 文字
              Text(item)
                .fontColor(this.currentIndex === index ? $r('sys.color.font_primary') : $r('sys.color.font_secondary')) // 适配系统深色模式
                .fontSize(18) // 安卓 TitleMedium 大小约为 16-20sp
                .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Medium) // 选中加粗
                .animation({ duration: 200 }) // 字体变化动画

              // 这里的 UI 逻辑可以根据安卓是否显示下划线来调整
              // 安卓代码中 TabRow 默认有 Indicator，这里我们做一个简单的透明度/颜色切换即可
              // 如果需要严格对其安卓 Material3 Tab 的 Indicator，可以在这里加个 Line
            }
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.currentIndex = index;
              this.controller.changeIndex(index);
            })
            // 均分 280vp 的宽度
            .width('25%')
          })
        }
        .width(280) // 核心：限制宽度，实现左对齐
        .height('100%')

        // 2.2 占位符：把搜索按钮挤到最右边
        Blank()

        // 2.3 右侧搜索按钮
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          // 使用系统搜索图标，或者你可以换成具体的图片资源
          // 这里为了兼容性使用 SymbolGlyph (API 11+) 或 Image
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
      .height(56) // 标准 AppBar 高度
      .padding({ left: 16, right: 8 }) // 左右内边距
      .backgroundColor($r('sys.color.ohos_id_color_background')) // 保持背景一致
      .zIndex(1) // 确保阴影或层级在内容之上

      // ============================================================
      // 3. 内容区域 (隐藏原生 TabBar)
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
            onOpenPoster: (id: number) => this.openPosterDetail(id)
          })
        }.tabBar(null) // 隐藏原生 TabBar

        // Tab 1: 推荐
        TabContent() {
          PostersTabPage({
            state: this.recommendState,
            onOpenPoster: (id: number) => this.openPosterDetail(id)
          })
        }.tabBar(null)

        // Tab 2: 最新
        TabContent() {
          PostersTabPage({
            state: this.newestState,
            onOpenPoster: (id: number) => this.openPosterDetail(id)
          })
        }.tabBar(null)

        // Tab 3: 最热
        TabContent() {
          PostersTabPage({
            state: this.hotState,
            onOpenPoster: (id: number) => this.openPosterDetail(id)
          })
        }.tabBar(null)
      }
      .barHeight(0) // 彻底隐藏原生导航栏高度
      .vertical(false)
      .scrollable(true) // 允许手势滑动切换
      .animationDuration(200)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .layoutWeight(1) // 占满剩余高度
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background')) // 对应安卓 surfaceContainer
  }
}