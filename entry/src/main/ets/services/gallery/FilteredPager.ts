export interface FilteredPageSnapshot<T> {
  items: T[];
  loading: boolean;
  hasMore: boolean;
  error: string;
}

/** Only a server empty page ends pagination. Failed batches never advance the cursor. */
export class FilteredPager<T> {
  private fetchPage: (page: number) => Promise<T[]>;
  private filter: (items: T[]) => T[];
  private key: (item: T) => number;
  private changed: (state: FilteredPageSnapshot<T>) => void;
  private state: FilteredPageSnapshot<T> = { items: [], loading: false, hasMore: true, error: '' };
  private nextPage: number = 0;
  private generation: number = 0;
  private failedRefresh: boolean = true;

  constructor(fetchPage: (page: number) => Promise<T[]>, filter: (items: T[]) => T[],
    key: (item: T) => number, changed: (state: FilteredPageSnapshot<T>) => void) {
    this.fetchPage = fetchPage; this.filter = filter; this.key = key; this.changed = changed;
  }

  snapshot(): FilteredPageSnapshot<T> {
    return { items: this.state.items.slice(), loading: this.state.loading, hasMore: this.state.hasMore, error: this.state.error };
  }
  replaceItems(items: T[]): void {
    this.state.items = items.slice();
  }
  cancel(): void { this.generation++; this.state.loading = false; }
  async refresh(): Promise<void> { await this.load(true); }
  async loadMore(): Promise<void> { await this.load(false); }
  async retry(): Promise<void> { await this.load(this.failedRefresh); }

  private async load(refresh: boolean): Promise<void> {
    if (!refresh && (this.state.loading || !this.state.hasMore)) return;
    const generation = ++this.generation;
    let page = refresh ? 0 : this.nextPage;
    this.state.loading = true; this.state.error = ''; this.changed(this.snapshot());
    try {
      const result = refresh ? [] : this.state.items.slice();
      const initialSize = result.length;
      let hasMore = true;
      // Fill one server page of visible entries, even if several pages are hidden.
      let target = 1;
      do {
        const raw = await this.fetchPage(page);
        if (generation !== this.generation) return;
        target = Math.max(target, raw.length);
        hasMore = raw.length > 0;
        for (const item of this.filter(raw)) {
          const index = result.findIndex(current => this.key(current) === this.key(item));
          if (index < 0) result.push(item); else result[index] = item;
        }
        page++;
      } while (hasMore && result.length - initialSize < target);
      this.nextPage = page;
      this.state = { items: result, loading: false, hasMore, error: '' };
    } catch (_) {
      if (generation !== this.generation) return;
      this.failedRefresh = refresh;
      this.state.loading = false; this.state.error = '加载失败，点击重试';
    }
    if (generation === this.generation) this.changed(this.snapshot());
  }
}
