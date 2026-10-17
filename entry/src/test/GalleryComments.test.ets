import { describe, it, expect } from '@ohos/hypium';
import { FilteredPager } from '../main/ets/services/gallery/FilteredPager';
import { commentSendError } from '../main/ets/services/gallery/GalleryFilter';
import { ReactionService, ReactionHttpSource } from '../main/ets/services/gallery/ReactionService';
import { RcpRequestOptions, RcpResponseData } from '../main/ets/core/network/rcpSession';

class CommentHttpFixture implements ReactionHttpSource {
  path: string = '';
  options: RcpRequestOptions = {};
  body: Record<string, Object> = {};
  response: string = '[]';
  status: number = 200;
  async get(path: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    this.path = path; this.options = options ?? {};
    return { statusCode: this.status, headers: {}, bodyText: this.response };
  }
  async post(path: string, body: Record<string, Object>): Promise<RcpResponseData> {
    this.body = body; return this.get(path);
  }
  async fetch(method: string, path: string): Promise<RcpResponseData> { return this.get(path); }
}

export default function galleryCommentsTest() {
  describe('Filtered gallery pagination and comment submission', () => {
    it('requests page zero and sort explicitly and preserves image-only request bodies', 0, async () => {
      const source = new CommentHttpFixture();
      const service = new ReactionService(source);
      source.response = '[{"id":1,"user":{"id":42,"nickname":"name"},"sub":[],"text":"hello"}]';
      const comments = await service.getCommentsForPoster(17, 'like');
      expect(source.path).assertEqual('/reaction/comments');
      expect(source.options.query!['obj']).assertEqual('poster17');
      expect(source.options.query!['page']).assertEqual(0);
      expect(source.options.query!['order']).assertEqual('like');
      expect(comments[0].user.id).assertEqual('42');
      await service.getCommentsForComment(1, 3, 'old');
      expect(source.options.query!['obj']).assertEqual('comment1');
      expect(source.options.query!['page']).assertEqual(3);
      source.response = '{"id":2,"user":{"id":42},"sub":[],"text":""}';
      const posted = await service.postComment({ obj: 'poster17', text: '', image_mids: ['image-mid'] });
      expect(posted!.id).assertEqual(2);
      expect(source.body['text']).assertEqual('');
      expect((source.body['image_mids'] as string[]).join(',')).assertEqual('image-mid');
    });

    it('rejects comment HTTP and malformed array responses without marking pagination complete', 0, async () => {
      const source = new CommentHttpFixture();
      const service = new ReactionService(source);
      for (const response of ['{', '{}', '[{}]']) {
        source.response = response; let failed = false;
        try { await service.getCommentsForPoster(1); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
      source.status = 500; source.response = '[]'; let failed = false;
      try { await service.getCommentsForPoster(1); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
    it('fills a visible page across fully and partially filtered server pages', 0, async () => {
      const calls: number[] = [];
      const pages: number[][] = [[1, 2], [3, 4], [5, 6], []];
      const pager = new FilteredPager<number>(async (page: number) => { calls.push(page); return pages[page]; },
        (items: number[]) => items.filter(item => item >= 4), (item: number) => item, () => {});
      await pager.refresh();
      expect(calls.join(',')).assertEqual('0,1,2'); expect(pager.snapshot().items.join(',')).assertEqual('4,5,6');
      expect(pager.snapshot().hasMore).assertTrue();
      await pager.loadMore(); expect(pager.snapshot().hasMore).assertFalse();
    });

    it('deduplicates comments and retries the same page after failures', 0, async () => {
      let fail = true; const calls: number[] = [];
      const pager = new FilteredPager<number>(async (page: number) => {
        calls.push(page); if (page === 1 && fail) throw new Error('offline');
        return page === 0 ? [1] : page === 1 ? [1, 2] : [];
      }, (items: number[]) => items, (item: number) => item, () => {});
      await pager.refresh(); await pager.loadMore();
      expect(pager.snapshot().items.join(',')).assertEqual('1'); expect(pager.snapshot().hasMore).assertTrue();
      expect(pager.snapshot().error.length > 0).assertTrue();
      fail = false; await pager.retry();
      expect(calls.join(',')).assertEqual('0,1,1,2'); expect(pager.snapshot().items.join(',')).assertEqual('1,2');
      expect(pager.snapshot().error).assertEqual('');
      await pager.refresh(); expect(calls[calls.length - 1]).assertEqual(0);
    });

    it('ignores responses from old searches or sort order and cancels after leaving', 0, async () => {
      let resolveOld: (value: number[]) => void = () => {}; let first = true;
      const pager = new FilteredPager<number>(async () => {
        if (first) { first = false; return new Promise<number[]>(resolve => { resolveOld = resolve; }); }
        return [9];
      }, (items: number[]) => items, (item: number) => item, () => {});
      const old = pager.refresh(); await pager.refresh(); resolveOld([1]); await old;
      expect(pager.snapshot().items.join(',')).assertEqual('9');
      let finish: (value: number[]) => void = () => {};
      const cancelled = new FilteredPager<number>(() => new Promise<number[]>(resolve => { finish = resolve; }),
        (items: number[]) => items, (item: number) => item, () => {});
      const pending = cancelled.refresh(); cancelled.cancel(); finish([2]); await pending;
      expect(cancelled.snapshot().items.length).assertEqual(0);
    });

    it('allows image-only comments but blocks pending or failed uploads and empty content', 0, () => {
      expect(commentSendError('', []).length > 0).assertTrue();
      expect(commentSendError('  ', []).length > 0).assertTrue();
      expect(commentSendError('hello', [])).assertEqual('');
      expect(commentSendError('', [{ uri: 'photo', status: 'success', mid: 'mid' }])).assertEqual('');
      expect(commentSendError('hello', [{ uri: 'photo', status: 'uploading' }])).assertEqual('图片上传中，请稍候');
      expect(commentSendError('', [{ uri: 'photo', status: 'fail' }]).length > 0).assertTrue();
      expect(commentSendError('', [{ uri: 'photo', status: 'success' }]).length > 0).assertTrue();
    });

    it('preserves existing comments after a failed sort refresh and suppresses duplicate paging', 0, async () => {
      let fail = false; let requests = 0;
      let finish: (value: number[]) => void = () => {};
      const pager = new FilteredPager<number>(async (page: number) => {
        requests++;
        if (fail) throw new Error('offline');
        if (page === 0) return [7];
        return new Promise<number[]>(resolve => { finish = resolve; });
      }, (items: number[]) => items, (item: number) => item, () => {});
      await pager.refresh(); fail = true; await pager.refresh();
      expect(pager.snapshot().items.join(',')).assertEqual('7');
      fail = false; await pager.retry();
      const pending = pager.loadMore(); await pager.loadMore();
      expect(requests).assertEqual(4); finish([]); await pending;
      expect(pager.snapshot().hasMore).assertFalse();
    });
  });
}
