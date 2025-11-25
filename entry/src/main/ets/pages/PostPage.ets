import { PostersTabPage } from '../components/gallery/PostersTabPage';
import { PosterListState } from '../services/gallery/PosterListState';
import { PostersMode } from '../services/gallery/GalleryService';

@Component
export default struct PostPage {
  // 1. 初始化 4 个数据流
  // 使用 @State 装饰器确保页面重绘时状态不丢失
  // new PosterListState(...) 创建了 ViewModel 实例
  @State recommendState: PosterListState = new PosterListState(PostersMode.Recommend);
  @State hotState: PosterListState = new PosterListState(PostersMode.Hot);
  @State newestState: PosterListState = new PosterListState(PostersMode.Newest);
  @State followState: PosterListState = new PosterListState(PostersMode.Follow);

  // 当前选中的 Tab 索引
  @State currentIndex: number = 1; // 默认显示 "推荐" (索引1)

  // Tabs 控制器，用于代码控制切换（如有需要）
  private controller: TabsController = new TabsController();

  build() {
    Column() {
      // 2. 使用 Tabs 组件实现顶部导航 + 页面切换
      Tabs({ barPosition: BarPosition.Start, controller: this.controller, index: this.currentIndex }) {

        // Tab 1: 关注
        TabContent() {
          PostersTabPage({ state: this.followState })
        }.tabBar(this.TabBuilder('关注', 0))

        // Tab 2: 推荐
        TabContent() {
          PostersTabPage({ state: this.recommendState })
        }.tabBar(this.TabBuilder('推荐', 1))

        // Tab 3: 最新
        TabContent() {
          PostersTabPage({ state: this.newestState })
        }.tabBar(this.TabBuilder('最新', 2))

        // Tab 4: 最热
        TabContent() {
          PostersTabPage({ state: this.hotState })
        }.tabBar(this.TabBuilder('最热', 3))
      }
      .vertical(false)
      .barMode(BarMode.Fixed) // 固定宽度，平分屏幕
      .barWidth('100%')
      .barHeight(44)
      .animationDuration(200) // 切换动画时长
      .backgroundColor(Color.White)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }

  // 3. 自定义 Tab 样式（带下划线动画）
  @Builder
  TabBuilder(title: string, targetIndex: number) {
    Column() {
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? '#2563EB' : '#6B7280') // 选中蓝，未选灰
        .fontWeight(this.currentIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
        .fontSize(16)
        .margin({ top: 10 })
        .animation({ duration: 300 }) // 字体颜色过渡动画

      // 下划线
      Line()
        .width(20)
        .height(3)
        .backgroundColor(this.currentIndex === targetIndex ? '#2563EB' : Color.Transparent)
        .margin({ top: 4 })
        .borderRadius(1.5)
        .animation({ duration: 300 }) // 下划线显隐动画
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.controller.changeIndex(targetIndex);
    })
  }
}