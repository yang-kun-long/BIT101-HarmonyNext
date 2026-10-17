import { PostersMode } from './GalleryService';
import { Poster } from './GalleryModels';
import { PosterRepository } from './PosterRepository';
import { FilteredPager, FilteredPageSnapshot } from './FilteredPager';
import { filterPosters } from './GalleryFilter';
import { getGallerySettingsStore } from '../storage/GallerySettingsStore';

@Observed
export class PosterListState {
  items: Poster[] = [];
  isLoading: boolean = false;
  isRefreshing: boolean = false;
  hasMore: boolean = true;
  error: string = '';
  private mode: PostersMode;
  private repo = new PosterRepository();
  private searchKeyword: string = '';
  private searchOrder: string = 'new';
  private searchUid: number = -1;
  private pager: FilteredPager<Poster>;
  private unsubscribe: (() => void) | null = null;

  constructor(mode: PostersMode) {
    this.mode = mode;
    this.pager = new FilteredPager<Poster>((page: number) => this.mode === PostersMode.Search
      ? this.repo.getSearchPosters(this.searchKeyword, page, this.searchOrder, this.searchUid)
      : this.repo.getPosters(this.mode, page),
      (items: Poster[]) => filterPosters(items, this.mode, getGallerySettingsStore().snapshot()),
      (item: Poster) => item.id, (state: FilteredPageSnapshot<Poster>) => {
        this.items = filterPosters(state.items, this.mode, getGallerySettingsStore().snapshot()); this.isLoading = state.loading; this.hasMore = state.hasMore;
        this.error = state.error;
      });
  }

  activate(): void {
    if (this.unsubscribe) return;
    this.unsubscribe = getGallerySettingsStore().subscribe(() => {
      this.items = filterPosters(this.items, this.mode, getGallerySettingsStore().snapshot());
      if (this.mode !== PostersMode.Search || this.searchKeyword) this.refresh();
    });
  }
  deactivate(): void {
    if (this.unsubscribe) this.unsubscribe();
    this.unsubscribe = null; this.pager.cancel(); this.isLoading = false; this.isRefreshing = false;
  }
  async doSearch(keyword: string, order: string, uid: number = -1): Promise<void> {
    this.searchKeyword = keyword; this.searchOrder = order; this.searchUid = uid;
    this.mode = PostersMode.Search; await this.refresh();
  }
  async refresh(): Promise<void> {
    this.isRefreshing = true;
    await this.pager.refresh();
    this.isRefreshing = false;
  }
  async loadMore(): Promise<void> { if (!this.error) await this.pager.loadMore(); }
  async retry(): Promise<void> { await this.pager.retry(); }
}
