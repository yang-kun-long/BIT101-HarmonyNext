import { describe, it, expect } from '@ohos/hypium';
import { defaultGallerySettings } from '../main/ets/services/storage/GallerySettingsStore';
import { filterPosters, filterComments, hideBotForMode } from '../main/ets/services/gallery/GalleryFilter';
import { Poster, Comment } from '../main/ets/services/gallery/GalleryModels';
import { PosterHttpSource, PosterRepository } from '../main/ets/services/gallery/PosterRepository';
import { RcpRequestOptions, RcpResponseData } from '../main/ets/core/network/rcpSession';

class GalleryHttpFixture implements PosterHttpSource {
  path: string = '';
  options: RcpRequestOptions = {};
  status: number = 200;
  body: string = '[]';
  async get(path: string, options?: RcpRequestOptions): Promise<RcpResponseData> {
    this.path = path; this.options = options ?? {};
    return { statusCode: this.status, headers: {}, bodyText: this.body };
  }
}

export default function galleryFilterTest() {
  describe('Gallery filtering and request contract', () => {
    it('requests user post pages zero and one explicitly and surfaces failed responses', 0, async () => {
      const source = new GalleryHttpFixture();
      const repo = new PosterRepository(source, async () => 'fixture', () => defaultGallerySettings());
      expect((await repo.getPostersOfUser(42, 0)).length).assertEqual(0);
      expect(source.options.query!['page']).assertEqual(0);
      await repo.getPostersOfUser(42, 1);
      expect(source.options.query!['page']).assertEqual(1);
      expect(source.options.query!['uid']).assertEqual(42);
      expect(source.options.headers!['fake-cookie']).assertEqual('fixture');
      for (const body of ['', '{', '{}', '[{}]']) {
        source.body = body; let failed = false;
        try { await repo.getPostersOfUser(42, 2); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
      source.status = 503; source.body = '[]'; let failed = false;
      try { await repo.getPostersOfUser(42, 2); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });
    it('filters UID and anonymous posts while preserving follow stream', 0, () => {
      const items: Poster[] = JSON.parse('[{"id":1,"user":{"id":"42"},"anonymous":false},{"id":2,"user":{"id":"3"},"anonymous":true},{"id":3,"user":{"id":"3"},"anonymous":false}]');
      const settings = defaultGallerySettings(); settings.hiddenUids = ['42']; settings.hideAnonymous = true;
      for (const mode of ['recommend', 'hot', 'newest', 'search']) {
        expect(filterPosters(items, mode, settings).map(item => item.id).join(',')).assertEqual('3');
      }
      expect(filterPosters(items, 'follow', settings).length).assertEqual(3);
      settings.hiddenUids = []; settings.hideAnonymous = false;
      expect(filterPosters(items, 'recommend', settings).length).assertEqual(3);
    });

    it('filters nested comments and strict replies without mutating source', 0, () => {
      const comments: Comment[] = JSON.parse('[{"id":1,"user":{"id":"3"},"sub":[{"id":2,"user":{"id":"42"},"sub":[]},{"id":3,"user":{"id":"4"},"replyUser":{"id":"42"},"sub":[]}]}]');
      const settings = defaultGallerySettings(); settings.hiddenUids = ['42'];
      expect(filterComments(comments, settings)[0].sub.length).assertEqual(1);
      settings.strict = true;
      expect(filterComments(comments, settings)[0].sub.length).assertEqual(0);
      expect(comments[0].sub.length).assertEqual(2);
    });

    it('uses Android hide_bot semantics and exact pagination/search parameters', 0, async () => {
      const settings = defaultGallerySettings(); settings.hideBot = true;
      expect(hideBotForMode('search', settings)).assertFalse();
      settings.hideBotInSearch = true;
      const source = new GalleryHttpFixture();
      const repo = new PosterRepository(source, async () => 'fixture', () => settings);
      await repo.getPosters('recommend', 0);
      expect(source.path).assertEqual('/posters'); expect(source.options.query!['hide_bot']).assertEqual('true');
      expect(source.options.headers!['fake-cookie']).assertEqual('fixture');
      await repo.getPosters('follow', 2); expect(source.options.query!['hide_bot']).assertEqual('false');
      await repo.getPosters('newest', 3);
      expect(source.options.query!['mode']).assertEqual('search'); expect(source.options.query!['order']).assertEqual('new');
      expect(source.options.query!['uid']).assertEqual(-1); expect(source.options.query!['page']).assertEqual(3);
      await repo.getSearchPosters('word', 4, 'comment', -1);
      expect(source.options.query!['search']).assertEqual('word'); expect(source.options.query!['hide_bot']).assertEqual('true');
      settings.hideBot = false;
      await repo.getSearchPosters('word', 0); expect(source.options.query!['hide_bot']).assertEqual('false');
    });

    it('rejects HTTP and invalid payloads rather than reporting an empty end page', 0, async () => {
      const source = new GalleryHttpFixture();
      const repo = new PosterRepository(source, async () => null, () => defaultGallerySettings());
      for (const body of ['{', '{}', '[{"id":1}]']) {
        source.body = body; let failed = false;
        try { await repo.getPosters('recommend', 0); } catch (_) { failed = true; }
        expect(failed).assertTrue();
      }
      source.status = 503; source.body = '[]'; let failed = false;
      try { await repo.getSearchPosters('word', 0); } catch (_) { failed = true; }
      expect(failed).assertTrue();
    });

    it('maps backend post fields and retains an explicit empty-page result', 0, async () => {
      const source = new GalleryHttpFixture();
      const repo = new PosterRepository(source, async () => null, () => defaultGallerySettings());
      source.body = '[{"id":10,"text":"body","create_time":"today","like_num":7,"comment_num":9,"anonymous":false,"public":true,"user":{"id":42,"nickname":"name","avatar":{"url":"avatar"}},"images":[{"mid":"image","url":"url","w":80,"h":60}]}]';
      const items = await repo.getPosters('hot', 0);
      expect(items[0].id).assertEqual(10); expect(items[0].user.id).assertEqual('42');
      expect(items[0].likeNum).assertEqual(7); expect(items[0].commentNum).assertEqual(9);
      expect(items[0].images[0].id).assertEqual('image'); expect(items[0].createTime).assertEqual('today');
      source.body = '[]'; expect((await repo.getPosters('hot', 1)).length).assertEqual(0);
    });
  });
}
