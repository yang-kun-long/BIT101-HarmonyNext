// entry/src/main/ets/services/gallery/PosterListState.ets
import { Logger } from '../../utils/Logger';
import { PostersMode } from './GalleryService';
import { Poster } from './GalleryModels';
import { PosterRepository } from './PosterRepository'; // ✅ 引入 Repo

/**
 * 帖子列表的状态管理类
 * 负责：分页加载、下拉刷新、数据存储、搜索状态维护
 */
@Observed
export class PosterListState {
  private logger = new Logger('PosterListState');

  // UI 绑定的数据源
  public items: Poster[] = [];

  // 状态位
  public isLoading: boolean = false;   // 是否正在加载更多
  public isRefreshing: boolean = false; // 是否正在下拉刷新
  public hasMore: boolean = true;       // 是否还有下一页

  // 内部参数
  private page: number = 0; // 注意：根据 API 习惯，如果第一页是 0，这里初始为 -1 或者刷新时置为 0
  private mode: PostersMode;

  // ✅ 核心依赖：使用 Repository 而不是直接用 Service
  private repo = new PosterRepository();

  // ✅ 搜索专用状态
  private searchKeyword: string = '';
  private searchOrder: string = 'new';
  private searchUid: number = -1;

  constructor(mode: PostersMode) {
    this.mode = mode;
  }

  // ==========================================================
  // [新增] 执行搜索 (供 SearchPage 调用)
  // ==========================================================
  async doSearch(keyword: string, order: string, uid: number = -1) {
    this.searchKeyword = keyword;
    this.searchOrder = order;
    this.searchUid = uid;

    // 强制切换当前状态为 Search 模式
    this.mode = PostersMode.Search;

    // 触发刷新加载新数据
    await this.refresh();
  }

  // ==========================================================
  // 下拉刷新 / 重新搜索
  // ==========================================================
  async refresh() {
    if (this.isLoading) return;

    this.isRefreshing = true;
    this.page = 0; // 假设 API 第一页是 0
    this.hasMore = true;

    try {
      let newItems: Poster[] = [];

      // ✅ 根据模式分流：是搜索还是普通列表？
      if (this.mode === PostersMode.Search) {
        newItems = await this.repo.getSearchPosters(
          this.searchKeyword,
          0, // page
          this.searchOrder,
          this.searchUid
        );
      } else {
        newItems = await this.repo.getPosters(this.mode, 0);
      }

      // 去重逻辑
      const seen = new Set<number>();
      this.items = newItems.filter(item => {
        const duplicate = seen.has(item.id);
        seen.add(item.id);
        return !duplicate;
      });

      // 如果第一页就为空，说明没数据
      if (newItems.length === 0) {
        this.hasMore = false;
      }
    } catch (e) {
      this.logger.error('Refresh failed', e);
    } finally {
      this.isRefreshing = false;
    }
  }

  // ==========================================================
  // 加载更多
  // ==========================================================
  async loadMore() {
    if (this.isLoading || !this.hasMore || this.isRefreshing) return;

    this.isLoading = true;
    const nextPage = this.page + 1;

    try {
      let newItems: Poster[] = [];

      // ✅ 同样根据模式分流
      if (this.mode === PostersMode.Search) {
        newItems = await this.repo.getSearchPosters(
          this.searchKeyword,
          nextPage,
          this.searchOrder,
          this.searchUid
        );
      } else {
        newItems = await this.repo.getPosters(this.mode, nextPage);
      }

      if (newItems.length > 0) {
        // 简单去重 (防止追加了重复数据)
        const currentIds = new Set(this.items.map(p => p.id));
        const uniqueNewItems = newItems.filter(p => !currentIds.has(p.id));

        this.items = this.items.concat(uniqueNewItems);
        this.page = nextPage;
      } else {
        this.hasMore = false;
      }
    } catch (e) {
      this.logger.error('LoadMore failed', e);
    } finally {
      this.isLoading = false;
    }
  }
}