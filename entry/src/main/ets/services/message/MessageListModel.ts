import { ApiError } from '../../core/network/httpClient';
import { Message, MessageType } from './MessageModels';
import { MessageSource } from './MessageRepository';

export interface MessageListSnapshot {
  items: Message[]; loading: boolean; loaded: boolean; hasMore: boolean; error: string; requiresLogin: boolean;
}
export function emptyMessages(): MessageListSnapshot {
  return { items: [], loading: false, loaded: false, hasMore: true, error: '', requiresLogin: false };
}
export class MessageListModel {
  private state: MessageListSnapshot = emptyMessages();
  private generation: number = 0;
  private cursor: number | undefined = undefined;
  private failedRefresh: boolean = true;
  constructor(private source: MessageSource, private type: MessageType,
    private changed: (state: MessageListSnapshot) => void, private read: () => void) {}
  snapshot(): MessageListSnapshot { return { ...this.state, items: this.state.items.slice() }; }
  cancel(): void { this.generation++; this.state.loading = false; }
  async ensureLoaded(): Promise<void> { if (!this.state.loaded && !this.state.loading) await this.refresh(); }
  async refresh(): Promise<void> { await this.load(true); }
  async loadMore(): Promise<void> { await this.load(false); }
  async retry(): Promise<void> { await this.load(this.failedRefresh); }
  private async load(refresh: boolean): Promise<void> {
    if (!refresh && (this.state.loading || !this.state.hasMore || !this.state.loaded || this.cursor === undefined)) return;
    const generation = ++this.generation;
    const cursor = refresh ? undefined : this.cursor;
    this.state = { ...this.state, loading: true, error: '', requiresLogin: false };
    this.changed(this.snapshot());
    try {
      const incoming = await this.source.getMessages(this.type, cursor);
      if (generation !== this.generation) return;
      const items: Message[] = refresh ? [] : this.state.items.slice();
      for (const item of incoming) {
        const index = items.findIndex(existing => existing.id === item.id);
        if (index < 0) items.push(item); else items[index] = item;
      }
      const next = incoming.length > 0 ? incoming[incoming.length - 1].id : undefined;
      this.cursor = next;
      this.state = { items, loading: false, loaded: true, hasMore: next !== undefined && (cursor === undefined || next < cursor), error: '', requiresLogin: false };
      this.read();
    } catch (error) {
      if (generation !== this.generation) return;
      this.failedRefresh = refresh;
      this.state = { ...this.state, loading: false, error: '消息加载失败，点击重试', requiresLogin: error instanceof ApiError && error.status === 401 };
    }
    if (generation === this.generation) this.changed(this.snapshot());
  }
}
