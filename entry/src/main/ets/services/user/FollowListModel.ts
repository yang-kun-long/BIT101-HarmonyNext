import type { User } from './userRepository';
import { ApiError } from '../../core/network/httpClient';

export type FollowListMode = 'followers' | 'followings';

export interface FollowListSource {
  getFollowers(page: number): Promise<User[]>;
  getFollowings(page: number): Promise<User[]>;
}

export interface FollowListSnapshot {
  users: User[];
  loading: boolean;
  hasMore: boolean;
  error: string;
  requiresLogin: boolean;
}

export function emptyFollowList(): FollowListSnapshot {
  return { users: [], loading: false, hasMore: true, error: '', requiresLogin: false };
}

/** Android returns arrays with no total/page size: only an empty page means end. */
export class FollowListModel {
  private readonly source: FollowListSource;
  private readonly mode: FollowListMode;
  private state: FollowListSnapshot = emptyFollowList();
  private nextPage: number = 0;
  private generation: number = 0;
  private failedRefresh: boolean = true;
  private readonly changed: (state: FollowListSnapshot) => void;

  constructor(source: FollowListSource, mode: FollowListMode, changed: (state: FollowListSnapshot) => void) {
    this.source = source;
    this.mode = mode;
    this.changed = changed;
  }

  snapshot(): FollowListSnapshot {
    return { users: this.state.users.slice(), loading: this.state.loading, hasMore: this.state.hasMore, error: this.state.error, requiresLogin: this.state.requiresLogin };
  }

  cancel(): void { this.generation++; this.state.loading = false; }

  async refresh(): Promise<void> { await this.load(true); }
  async loadMore(): Promise<void> { await this.load(false); }
  async retry(): Promise<void> { await this.load(this.failedRefresh); }

  private async load(refresh: boolean): Promise<void> {
    if (!refresh && (this.state.loading || !this.state.hasMore || this.nextPage === 0)) return;
    const generation = ++this.generation;
    const page = refresh ? 0 : this.nextPage;
    this.state = { users: this.state.users, loading: true, hasMore: this.state.hasMore, error: '', requiresLogin: false };
    this.changed(this.snapshot());
    try {
      const incoming = this.mode === 'followers' ? await this.source.getFollowers(page) : await this.source.getFollowings(page);
      if (generation !== this.generation) return;
      const users = refresh ? [] : this.state.users.slice();
      for (const user of incoming) {
        const index = users.findIndex(item => item.id === user.id);
        if (index < 0) users.push(user); else users[index] = user;
      }
      this.nextPage = page + 1;
      this.state = { users, loading: false, hasMore: incoming.length > 0, error: '', requiresLogin: false };
    } catch (error) {
      if (generation !== this.generation) return;
      this.failedRefresh = refresh;
      this.state = { users: this.state.users, loading: false, hasMore: this.state.hasMore, error: '加载失败，请重试', requiresLogin: error instanceof ApiError && error.status === 401 };
    }
    if (generation === this.generation) this.changed(this.snapshot());
  }
}

/** Validate the array contract rather than accepting an error object as an empty list. */
export function parseFollowUsers(payload: unknown): User[] {
  if (!Array.isArray(payload)) throw new Error('关注列表返回格式异常');
  return payload.map((value: unknown) => {
    if (value === null || typeof value !== 'object') throw new Error('关注列表用户格式异常');
    const user = value as User;
    if (!Number.isSafeInteger(user.id) || user.id <= 0 || typeof user.nickname !== 'string' ||
      !user.avatar || typeof user.avatar.url !== 'string') throw new Error('关注列表用户格式异常');
    return user;
  });
}
