import { PosterCard } from './PosterCard';
import { PosterListState } from '../../services/gallery/PosterListState';
import { Poster } from '../../services/gallery/GalleryModels';

@Component
export struct PostersTabPage {
  // 必须使用 @ObjectLink 配合 PosterListState 的 @Observed 装饰器
  // 这样当 state 内部属性变化时，UI 才会更新
  @ObjectLink state: PosterListState;

  aboutToAppear() {
    // 如果列表为空，自动触发一次刷新
    if (this.state.items.length === 0 && !this.state.isLoading && !this.state.isRefreshing) {
      this.state.refresh();
    }
  }

  build() {
    Column() {
      // 下拉刷新组件
      // refreshing: $$this.state.isRefreshing (双向绑定)
      Refresh({ refreshing: $$this.state.isRefreshing, offset: 64, friction: 62 }) {
        List() {
          // 渲染数据列表
          ForEach(this.state.items, (item: Poster, index: number) => {
            ListItem() {
              PosterCard({ poster: item })
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
        // 触底加载更多
        .onReachEnd(() => {
          this.state.loadMore();
        })
      }
      .onStateChange((refreshStatus: RefreshStatus) => {
        // 当用户下拉动作触发刷新时调用
        if (refreshStatus === RefreshStatus.Refresh) {
          this.state.refresh();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7') // 列表背景色
  }
}