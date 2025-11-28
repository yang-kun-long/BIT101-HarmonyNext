// entry/src/main/ets/services/gallery/PosterListState.ets
import { Logger } from '../../utils/Logger';
import { galleryService, PostersMode } from './GalleryService';
import { Poster } from './GalleryModels';

/**
 * 帖子列表的状态管理类
 * 负责：分页加载、下拉刷新、数据存储
 */
@Observed
export class PosterListState {
  private logger = new Logger('PosterListState');
  // 数据源
  public items: Poster[] = [];

  // 状态位
  public isLoading: boolean = false;   // 是否正在加载更多
  public isRefreshing: boolean = false; // 是否正在下拉刷新
  public hasMore: boolean = true;       // 是否还有下一页

  // 内部参数
  private page: number = 0;
  private mode: PostersMode;

  constructor(mode: PostersMode) {
    this.mode = mode;
  }

  // 下拉刷新：重置页码，清空数据，重新请求
  async refresh() {
    if (this.isLoading) return;

    this.isRefreshing = true;
    this.page = 0;
    this.hasMore = true;

    try {
      // 请求第 0 页
      const newItems = await galleryService.getPosters(this.mode, 0);
      const seen = new Set<number>();
      this.items = newItems.filter(item => {
        const duplicate = seen.has(item.id);
        seen.add(item.id);
        return !duplicate;
      });

      // 如果第一次就没数据，说明没更多了
      if (newItems.length === 0) {
        this.hasMore = false;
      }
    } catch (e) {
      this.logger.error('Refresh failed', e);
    } finally {
      this.isRefreshing = false;
    }
  }

  // 加载更多：页码+1，追加数据
  async loadMore() {
    // 各种防御性检查：正在加载中、没有更多数据、正在刷新中 -> 都不处理
    if (this.isLoading || !this.hasMore || this.isRefreshing) return;

    this.isLoading = true;
    const nextPage = this.page + 1;

    try {
      const newItems = await galleryService.getPosters(this.mode, nextPage);

      if (newItems.length > 0) {
        // 简单去重 (以防后端下发重复数据)
        const currentIds = new Set(this.items.map(p => p.id));
        const uniqueNewItems = newItems.filter(p => !currentIds.has(p.id));

        // 追加数据
        this.items = this.items.concat(uniqueNewItems);
        this.page = nextPage;
      } else {
        // 没数据了
        this.hasMore = false;
      }
    } catch (e) {
      this.logger.error('LoadMore failed', e);
    } finally {
      this.isLoading = false;
    }
  }
}