// entry/src/main/ets/components/gallery/PostersTabPage.ets
import { PosterCard } from './PosterCard';
import { PosterListState } from '../../services/gallery/PosterListState';
import { Poster } from '../../services/gallery/GalleryModels';
import promptAction from '@ohos.promptAction';


@Component
export struct PostersTabPage {
  // 必须使用 @ObjectLink 配合 PosterListState 的 @Observed 装饰器
  @ObjectLink state: PosterListState;

  // 外部传入的回调
  onOpenPoster?: (id: number) => void;
  // 新增：发帖/编辑回调 (对应 Android onOpenPostOrEdit)
  onOpenPostOrEdit?: () => void;

  // 列表滚动控制器，用于“回到顶部”
  private listScroller: Scroller = new Scroller();

  // 状态：是否显示“回到顶部”按钮
  @State showBackToTop: boolean = false;

  aboutToAppear() {
    // 如果列表为空，自动触发一次刷新
    if (this.state.items.length === 0 && !this.state.isLoading && !this.state.isRefreshing) {
      this.state.refresh();
    }
  }

  // --- 交互逻辑：发帖点击 ---
  private handlePostClick() {
    if (this.onOpenPostOrEdit) {
      this.onOpenPostOrEdit();
    } else {
      promptAction.showToast({
        message: '发帖功能开发中...\nUI 已对齐',
        duration: 1500,
        bottom: 400
      });
    }
  }

  // --- 交互逻辑：回到顶部 ---
  private handleBackToTop() {
    // 带有动画的滚动回顶部
    this.listScroller.scrollToIndex(0, true);
  }

  build() {
    // 1. 使用 Stack (类似 Compose Box) 实现层叠布局
    Stack({ alignContent: Alignment.BottomEnd }) {

      // === 列表区域 ===
      Column() {
        Refresh({ refreshing: $$this.state.isRefreshing, offset: 64, friction: 62 }) {
          List({ scroller: this.listScroller }) {
            // 渲染数据列表
            ForEach(this.state.items, (item: Poster, index: number) => {
              ListItem() {
                PosterCard({
                  poster: item,
                  onClickPoster: () => {
                    if (this.onOpenPoster) {
                      this.onOpenPoster(item.id);
                    }
                  }
                })
              }
            }, (item: Poster, index: number) => item.id + "_" + index)

            // 底部加载状态条
            if (this.state.items.length > 0) {
              ListItem() {
                Row() {
                  if (this.state.isLoading) {
                    LoadingProgress().width(24).height(24).color('#999999')
                    Text(' 正在加载...').fontSize(14).fontColor('#999999')
                  } else if (!this.state.hasMore) {
                    Text('--- 我是有底线的 ---').fontSize(12).fontColor('#CCCCCC')
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding(16)
              }
            }
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          // 2. 分割线 (UI 对齐 Android Divider)
          .divider({
            strokeWidth: 0.5,
            color: '#14000000', // 对应 Android: onSurface.copy(alpha = 0.08f)
            startMargin: 0,
            endMargin: 0
          })
          // 3. 监听滚动，控制“回到顶部”按钮显隐
          .onScrollIndex((firstIndex: number) => {
            // Android 逻辑: firstVisibleItemIndex > 1
            const shouldShow = firstIndex > 1;
            if (this.showBackToTop !== shouldShow) {
              this.showBackToTop = shouldShow; // 触发动画
            }
          })
          .onReachEnd(() => {
            this.state.loadMore();
          })
        }
        .onStateChange((refreshStatus: RefreshStatus) => {
          if (refreshStatus === RefreshStatus.Refresh) {
            this.state.refresh();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F7F7')

      // === 悬浮按钮区域 (UI 对齐 Android FAB Column) ===
      Column() {
        // 4. 回到顶部按钮 (带显隐动画)
        if (this.showBackToTop) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.arrow_up')) // 系统向上箭头图标
              .fontSize(24)
              .fontColor([$r('sys.color.font_primary')]) // Android: primary color
          }
          .width(56) // Android FAB size
          .height(56)
          .backgroundColor('#E6E0E9') // Android: primaryContainer copy(0.8) 模拟色
          .shadow({ radius: 6, color: '#33000000', offsetY: 4 }) // Elevation
          .onClick(() => this.handleBackToTop())
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 })) // 淡入淡出动画
          .margin({ bottom: 16 })
        }

        // 5. 发帖按钮 (常驻)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.plus')) // 系统加号图标
            .fontSize(24)
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(56)
        .height(56)
        .backgroundColor('#E6E0E9') // Android: primaryContainer copy(0.8)
        .shadow({ radius: 6, color: '#33000000', offsetY: 4 })
        .onClick(() => this.handlePostClick())

      }
      .padding({ right: 16, bottom: 32 }) // Android: padding(10.dp, 20.dp) + alignment
    }
    .width('100%')
    .height('100%')
  }
}