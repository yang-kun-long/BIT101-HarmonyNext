import { describe, it, expect } from '@ohos/hypium';
import { ApiError, HttpRequest, HttpResponse } from '../main/ets/core/network/httpClient';
import { UserProfileHttpClient, UserProfileTokenStore } from '../main/ets/services/user/userRepository';
import { Message, MessageType, UnreadCounts, badgeText, parseMessages, messageTarget } from '../main/ets/services/message/MessageModels';
import { MessageSource, MessageRepository } from '../main/ets/services/message/MessageRepository';
import { MessageListModel } from '../main/ets/services/message/MessageListModel';
import { UnreadStore } from '../main/ets/services/message/UnreadStore';
function message(id: number): Message {
  return { id, from_user: { id: 3, nickname: '用户', create_time: '', motto: '', avatar: { mid: '', url: '', low_url: '' }, identity: { id: 0, color: '', text: '' } }, link_obj: 'poster12', obj: 'comment8', text: '消息', update_time: '' };
}
class TestHttp implements UserProfileHttpClient {
  requests: HttpRequest[] = [];
  response: HttpResponse<Object> = { status: 200, headers: {}, text: '[]' };
  async request<T = Object>(request: HttpRequest): Promise<HttpResponse<T>> { this.requests.push(request); return this.response as HttpResponse<T>; }
}
class Tokens implements UserProfileTokenStore {
  cookie: string | null = 'fixture';
  async getFakeCookie(): Promise<string | null> { return this.cookie; }
}
class Source implements MessageSource {
  requests: string[] = []; rows: Message[] = [message(10)]; failure: Error | null = null; pending: Promise<Message[]> | null = null; total: number = 5; expired: boolean = false;
  async getMessages(type: MessageType, id?: number): Promise<Message[]> {
    this.requests.push(type + ':' + String(id)); if (this.expired) throw new ApiError('expired', 401); if (this.failure) throw this.failure; return this.pending ? await this.pending : this.rows;
  }
  async getUnreadTotal(): Promise<number> { if (this.failure) throw this.failure; return this.total; }
  async getUnreadCounts(): Promise<UnreadCounts> { return { like: this.total, comment: 0, follow: 0, system: 0 }; }
}
export default function messageTest() {
  describe('Message center', () => {
    it('requests authenticated snake_case contracts and cursor', 0, async () => {
      const http = new TestHttp(); const repo = new MessageRepository(http, new Tokens());
      http.response.text = JSON.stringify([message(10)]);
      expect((await repo.getMessages('like'))[0].from_user.id).assertEqual(3); await repo.getMessages('comment', 10);
      expect(http.requests[0].url).assertEqual('/messages?type=like');
      expect(http.requests[1].url).assertEqual('/messages?type=comment&last_id=10');
      expect(http.requests[0].headers?.['fake-cookie']).assertEqual('fixture');
      http.response.text = JSON.stringify({ unread_num: 101 }); expect(await repo.getUnreadTotal()).assertEqual(101);
      http.response.text = JSON.stringify({ like: 1, comment: 2, follow: 3, system: 4 }); expect((await repo.getUnreadCounts()).system).assertEqual(4);
      expect(http.requests[2].url).assertEqual('/messages/unread_num'); expect(http.requests[3].url).assertEqual('/messages/unread_nums');
    });
    it('rejects absent auth, invalid cursor, non-2xx and malformed payloads', 0, async () => {
      const http = new TestHttp(); const tokens = new Tokens(); const repo = new MessageRepository(http, tokens); let failures = 0;
      tokens.cookie = null; try { await repo.getMessages('like'); } catch (_) { failures++; } expect(http.requests.length).assertEqual(0);
      tokens.cookie = 'test'; try { await repo.getMessages('like', -1); } catch (_) { failures++; }
      http.response.status = 500; try { await repo.getMessages('like'); } catch (_) { failures++; }
      http.response.status = 200; http.response.text = '{}';
      try { await repo.getMessages('like'); } catch (_) { failures++; }
      try { await repo.getUnreadTotal(); } catch (_) { failures++; }
      try { await repo.getUnreadCounts(); } catch (_) { failures++; }
      try { parseMessages([null]); } catch (_) { failures++; } expect(failures).assertEqual(7);
    });
    it('resolves link then object then follow sender and bounds badges', 0, () => {
      const item = message(10); expect(messageTarget('like', item)?.id).assertEqual(12);
      item.link_obj = 'https://evil/poster1'; item.obj = 'user4'; expect(messageTarget('system', item)?.id).assertEqual(4);
      item.obj = 'poster9007199254740992'; expect(messageTarget('follow', item)?.id).assertEqual(3); expect(messageTarget('comment', item)).assertNull();
      expect(badgeText(0)).assertEqual(''); expect(badgeText(100)).assertEqual('99+'); expect(badgeText(9)).assertEqual('9');
    });
    it('caches each category and deduplicates pages until empty', 0, async () => {
      const source = new Source(); let reads = 0;
      const likes = new MessageListModel(source, 'like', () => {}, () => { reads++; });
      const comments = new MessageListModel(source, 'comment', () => {}, () => {});
      await likes.ensureLoaded(); await likes.ensureLoaded(); await comments.ensureLoaded();
      source.rows = [message(10), message(8)]; await likes.loadMore(); expect(likes.snapshot().items.length).assertEqual(2); expect(comments.snapshot().items.length).assertEqual(1);
      source.rows = []; await likes.loadMore(); await likes.loadMore(); expect(likes.snapshot().hasMore).assertFalse(); expect(reads).assertEqual(3);
      expect(source.requests.join(',')).assertEqual('like:undefined,comment:undefined,like:10,like:8');
    });
    it('retains data and cursor after failure and stops repeated cursor', 0, async () => {
      const source = new Source(); const model = new MessageListModel(source, 'system', () => {}, () => {});
      await model.refresh(); source.failure = new Error('offline'); await model.loadMore(); expect(model.snapshot().items.length).assertEqual(1);
      source.failure = null; source.rows = [message(8)]; await model.retry(); expect(source.requests.join(',')).assertEqual('system:undefined,system:10,system:10');
      await model.loadMore(); expect(model.snapshot().hasMore).assertFalse();
    });
    it('ignores cancelled requests and prevents duplicate load more', 0, async () => {
      const source = new Source(); const model = new MessageListModel(source, 'like', () => {}, () => {}); await model.refresh();
      let resolve: (rows: Message[]) => void = () => {}; source.pending = new Promise<Message[]>(done => { resolve = done; });
      const pending = model.loadMore(); await model.loadMore(); model.cancel(); resolve([message(8)]); await pending;
      expect(source.requests.length).assertEqual(2); expect(model.snapshot().items.length).assertEqual(1);
    });
    it('replaces old pages on refresh and reports expired login', 0, async () => {
      const source = new Source(); const model = new MessageListModel(source, 'follow', () => {}, () => {});
      await model.refresh(); source.rows = [message(4)]; await model.refresh(); expect(model.snapshot().items[0].id).assertEqual(4);
      source.expired = true; await model.refresh(); expect(model.snapshot().requiresLogin).assertTrue();
    });
    it('ignores a superseded refresh result', 0, async () => {
      const source = new Source(); const model = new MessageListModel(source, 'system', () => {}, () => {});
      let resolve: (rows: Message[]) => void = () => {};
      source.pending = new Promise<Message[]>(done => { resolve = done; });
      const old = model.refresh(); source.pending = null; source.rows = [message(4)];
      await model.refresh(); resolve([message(10)]); await old;
      expect(model.snapshot().items[0].id).assertEqual(4);
    });
    it('updates unread observers, preserves counts on failure and clears logout', 0, async () => {
      const source = new Source(); const store = new UnreadStore(source); let observed = -1; const stop = store.observe(state => { observed = state.total; });
      await store.refresh(); expect(observed).assertEqual(5); source.failure = new Error('offline'); await store.refresh();
      expect(store.snapshot().total).assertEqual(5); expect(store.snapshot().error.length > 0).assertTrue();
      store.reset(); expect(observed).assertEqual(0); stop(); source.failure = null; source.total = 2; await store.refresh(); expect(observed).assertEqual(0);
    });
  });
}
