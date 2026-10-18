import { describe, it, expect } from '@ohos/hypium';
import { ApiError, HttpRequest, HttpResponse } from '../main/ets/core/network/httpClient';
import { User, UserProfileHttpClient, UserProfileTokenStore, UserRepository } from '../main/ets/services/user/userRepository';
import { FollowListModel, FollowListSource, parseFollowUsers } from '../main/ets/services/user/FollowListModel';
import { notifyUserRelationsChanged, observeUserRelations } from '../main/ets/services/user/UserRelationEvents';

function makeUser(id: number, nickname: string = '测试用户'): User {
  return { id, nickname, create_time: '', motto: '',
    avatar: { mid: 'avatar', url: 'https://example.org/avatar', low_url: '' },
    identity: { id: 0, color: '', text: '' } };
}

class FollowHttpClient implements UserProfileHttpClient {
  requests: HttpRequest[] = [];
  response: HttpResponse<Object> = { status: 200, headers: {}, text: '[]' };
  async request<T = Object>(request: HttpRequest): Promise<HttpResponse<T>> {
    this.requests.push(request);
    return this.response as HttpResponse<T>;
  }
}

class FollowTokenStore implements UserProfileTokenStore {
  cookie: string | null = 'test-cookie';
  async getFakeCookie(): Promise<string | null> { return this.cookie; }
}

class FollowSource implements FollowListSource {
  requested: number[] = [];
  followerRequests: number = 0;
  pages: User[][] = [[makeUser(1)], [makeUser(1, '新昵称'), makeUser(2)], []];
  failure: Error | null = null;
  expired: boolean = false;
  pending: Promise<User[]> | null = null;
  async getFollowers(page: number): Promise<User[]> { this.followerRequests++; return await this.getFollowings(page); }
  async getFollowings(page: number): Promise<User[]> {
    this.requested.push(page);
    if (this.expired) throw new ApiError('expired', 401);
    if (this.failure) throw this.failure;
    if (this.pending) return await this.pending;
    return this.pages[page] ?? [];
  }
}

export default function followListTest() {
  describe('Follow list', () => {
    it('distinguishes an empty list from empty or unauthorized responses', 0, async () => {
      const http = new FollowHttpClient();
      const repo = new UserRepository({ httpClient: http, tokenStore: new FollowTokenStore() });
      expect((await repo.getFollowers(0)).length).assertEqual(0);
      expect((await repo.getFollowings(1)).length).assertEqual(0);
      for (const status of [200, 204, 401, 503]) {
        http.response = { status, headers: {}, text: '' };
        let failures = 0;
        try { await repo.getFollowers(); } catch (_) { failures++; }
        try { await repo.getFollowings(); } catch (_) { failures++; }
        expect(failures).assertEqual(2);
      }
    });
    it('requests the Android array contract with explicit page and session header', 0, async () => {
      const http = new FollowHttpClient();
      const repo = new UserRepository({ httpClient: http, tokenStore: new FollowTokenStore() });
      http.response.text = JSON.stringify([makeUser(1)]);
      expect((await repo.getFollowers(0))[0].id).assertEqual(1);
      await repo.getFollowings(3);
      expect(http.requests[0].url).assertEqual('/user/followers?page=0');
      expect(http.requests[1].url).assertEqual('/user/followings?page=3');
      expect(http.requests[0].headers?.['fake-cookie']).assertEqual('test-cookie');
    });

    it('rejects missing auth, bad pages, non-2xx and malformed payloads', 0, async () => {
      const http = new FollowHttpClient();
      const tokens = new FollowTokenStore();
      const repo = new UserRepository({ httpClient: http, tokenStore: tokens });
      let failures = 0;
      tokens.cookie = null;
      try { await repo.getFollowers(); } catch (_) { failures++; }
      expect(http.requests.length).assertEqual(0);
      tokens.cookie = 'test';
      try { await repo.getFollowers(-1); } catch (_) { failures++; }
      try { await repo.getFollowings(0.5); } catch (_) { failures++; }
      http.response.status = 500;
      try { await repo.getFollowers(); } catch (_) { failures++; }
      http.response.status = 200;
      http.response.text = '{"error":"bad"}';
      try { await repo.getFollowers(); } catch (_) { failures++; }
      try { parseFollowUsers([null]); } catch (_) { failures++; }
      expect(failures).assertEqual(6);
    });

    it('deduplicates pages, updates repeated users and only ends at an empty page', 0, async () => {
      const source = new FollowSource();
      const model = new FollowListModel(source, 'followings', () => {});
      await model.refresh();
      expect(model.snapshot().hasMore).assertTrue();
      await model.loadMore();
      expect(model.snapshot().users.length).assertEqual(2);
      expect(model.snapshot().users[0].nickname).assertEqual('新昵称');
      await model.loadMore();
      await model.loadMore();
      expect(model.snapshot().hasMore).assertFalse();
      expect(source.requested.join(',')).assertEqual('0,1,2');
    });

    it('refreshes followers from page zero and removes users no longer returned', 0, async () => {
      const source = new FollowSource();
      const model = new FollowListModel(source, 'followers', () => {});
      await model.refresh();
      await model.loadMore();
      source.pages[0] = [makeUser(2)];
      await model.refresh();
      expect(model.snapshot().users.length).assertEqual(1);
      expect(model.snapshot().users[0].id).assertEqual(2);
      expect(source.followerRequests).assertEqual(3);
      expect(source.requested.join(',')).assertEqual('0,1,0');
    });

    it('preserves loaded users and retries the same failed page', 0, async () => {
      const source = new FollowSource();
      const model = new FollowListModel(source, 'followings', () => {});
      await model.refresh();
      source.failure = new Error('offline');
      await model.loadMore();
      expect(model.snapshot().users.length).assertEqual(1);
      expect(model.snapshot().error.length > 0).assertTrue();
      source.failure = null;
      await model.retry();
      expect(source.requested.join(',')).assertEqual('0,1,1');
      expect(model.snapshot().users.length).assertEqual(2);
      source.failure = new Error('offline');
      await model.refresh();
      source.failure = null;
      await model.retry();
      expect(source.requested.join(',')).assertEqual('0,1,1,0,0');
    });

    it('ignores old in-flight results after refresh and cancellation', 0, async () => {
      const source = new FollowSource();
      let complete: (users: User[]) => void = () => {};
      source.pending = new Promise<User[]>(resolve => { complete = resolve; });
      const model = new FollowListModel(source, 'followings', () => {});
      const old = model.refresh();
      source.pending = null;
      source.pages[0] = [makeUser(2)];
      await model.refresh();
      complete([makeUser(1)]);
      await old;
      expect(model.snapshot().users[0].id).assertEqual(2);
      source.pending = new Promise<User[]>(resolve => { complete = resolve; });
      const more = model.loadMore();
      model.cancel();
      complete([makeUser(3)]);
      await more;
      expect(model.snapshot().users.length).assertEqual(1);
    });

    it('suppresses duplicate load-more calls while a request is pending', 0, async () => {
      const source = new FollowSource();
      const model = new FollowListModel(source, 'followings', () => {});
      await model.refresh();
      let complete: (users: User[]) => void = () => {};
      source.pending = new Promise<User[]>(resolve => { complete = resolve; });
      const first = model.loadMore();
      await model.loadMore();
      complete([]);
      await first;
      expect(source.requested.join(',')).assertEqual('0,1');
    });

    it('marks expired sessions for login and releases relation observers', 0, async () => {
      const source = new FollowSource();
      source.expired = true;
      const model = new FollowListModel(source, 'followers', () => {});
      await model.refresh();
      expect(model.snapshot().requiresLogin).assertTrue();
      let changes = 0;
      const stop = observeUserRelations(() => { changes++; });
      notifyUserRelationsChanged();
      stop();
      notifyUserRelationsChanged();
      expect(changes).assertEqual(1);
    });

    it('notifies counts and list observers only after a successful follow request', 0, async () => {
      const http = new FollowHttpClient();
      const repo = new UserRepository({ httpClient: http, tokenStore: new FollowTokenStore() });
      let changes = 0;
      const stop = observeUserRelations(() => { changes++; });
      try {
        http.response.text = '{"following":true,"follower":false,"following_num":1,"follower_num":2}';
        expect((await repo.followUser(2))?.following).assertTrue();
        http.response.status = 500;
        expect(await repo.followUser(2)).assertNull();
        expect(changes).assertEqual(1);
      } finally { stop(); }
    });
  });
}
