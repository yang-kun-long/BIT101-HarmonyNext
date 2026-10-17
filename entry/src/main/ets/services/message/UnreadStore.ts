import { UnreadCounts, emptyUnread } from './MessageModels';
import { MessageSource, MessageRepository } from './MessageRepository';

export interface UnreadSnapshot { total: number; counts: UnreadCounts; error: string; }
export class UnreadStore {
  private state: UnreadSnapshot = { total: 0, counts: emptyUnread(), error: '' };
  private listeners: Set<(state: UnreadSnapshot) => void> = new Set();
  private generation: number = 0;
  constructor(private source: MessageSource) {}
  snapshot(): UnreadSnapshot { return { total: this.state.total, counts: { ...this.state.counts }, error: this.state.error }; }
  observe(listener: (state: UnreadSnapshot) => void): () => void {
    this.listeners.add(listener); listener(this.snapshot());
    return () => { this.listeners.delete(listener); };
  }
  private publish(): void { for (const listener of this.listeners) listener(this.snapshot()); }
  reset(): void {
    this.generation++; this.state = { total: 0, counts: emptyUnread(), error: '' }; this.publish();
  }
  async refresh(): Promise<void> {
    const generation = ++this.generation;
    try {
      const total = await this.source.getUnreadTotal();
      const counts = await this.source.getUnreadCounts();
      if (generation !== this.generation) return;
      this.state = { total, counts, error: '' };
    } catch (_) {
      if (generation !== this.generation) return;
      this.state = { ...this.state, error: '未读数更新失败，点击重试' };
    }
    this.publish();
  }
}
export const unreadStore = new UnreadStore(new MessageRepository());
