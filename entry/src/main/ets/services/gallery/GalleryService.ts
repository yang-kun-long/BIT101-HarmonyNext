// entry/src/main/ets/services/gallery/GalleryService.ts
import { bit101Session } from '../../core/network/bit101Session';
import { Poster, GalleryUser, GalleryImage, PosterDetail, PosterClaim } from './GalleryModels';

export enum PostersMode {
  Recommend = 'recommend',
  Hot = 'hot',
  Follow = 'follow',
  Newest = 'newest',
  Search = 'search'
}

class GalleryService {
  private apiPath = '/posters';

  async getPosters(mode: PostersMode, page: number = 0, keyword?: string): Promise<Poster[]> {
    try {
      const queryParams: Record<string, string | number> = { page: page };

      switch (mode) {
        case PostersMode.Hot: queryParams['mode'] = 'hot'; break;
        case PostersMode.Follow: queryParams['mode'] = 'follow'; break;
        case PostersMode.Newest:
          queryParams['mode'] = 'search';
          queryParams['order'] = 'NEW';
          queryParams['uid'] = -1; // 修正：最新板块用 -1
          break;
        case PostersMode.Search:
          queryParams['mode'] = 'search';
          if (keyword) queryParams['search'] = keyword;
          break;
        default: break;
      }

      console.info(`[GalleryService] Requesting page ${page}, mode: ${mode}`);

      const resp = await bit101Session.get(this.apiPath, { query: queryParams });

      if (resp.statusCode !== 200 || !resp.bodyText) {
        return [];
      }

      const json = JSON.parse(resp.bodyText);
      let rawList: any[] = [];

      if (Array.isArray(json)) {
        rawList = json;
      } else if (json && Array.isArray((json as any).data)) {
        rawList = (json as any).data;
      }

      // 🔥 关键修改：手动清洗每一条数据，而不是直接强转
      return rawList.map((raw: any) => this.safeParsePoster(raw));

    } catch (e) {
      console.error('[GalleryService] Exception:', e);
      return [];
    }
  }
  async getPosterById(id: number): Promise<PosterDetail | null> {
    try {
      const resp = await bit101Session.get(`${this.apiPath}/${id}`, {});

      if (resp.statusCode !== 200 || !resp.bodyText) {
        console.warn('[GalleryService] getPosterById status=', resp.statusCode, 'id=', id);
        return null;
      }

      const raw = JSON.parse(resp.bodyText);

      // 先复用列表里的 safeParsePoster，拿到公共字段
      const base = this.safeParsePoster(raw);

      // claim
      const claimRaw = raw.claim;
      let claim: PosterClaim | null = null;
      if (claimRaw) {
        claim = {
          id: Number(claimRaw.id ?? 0),
          text: String(claimRaw.text ?? ''),
        };
      }

      const detail: PosterDetail = {
        ...base,
        like: Boolean(raw.like),
        own: Boolean(raw.own),
        claim,
        plugins: raw.plugins ? String(raw.plugins) : undefined,
        subscription: typeof raw.subscription === 'number' ? raw.subscription : undefined,
      };

      return detail;
    } catch (e) {
      console.error('[GalleryService] getPosterById error:', e);
      return null;
    }
  }


  // 🔥 新增：安全解析函数 (解决头像对象解析和空指针问题)
  private safeParsePoster(raw: any): Poster {
    const rawUser = raw.user || {};

    // 1. 头像处理 (保持不变)
    let avatarUrl = '';
    if (rawUser.avatar) {
      if (typeof rawUser.avatar === 'string') {
        avatarUrl = rawUser.avatar;
      } else if (typeof rawUser.avatar === 'object') {
        avatarUrl = rawUser.avatar.url || rawUser.avatar.lowUrl || rawUser.avatar.low_url || '';
      }
    }

    // ✅ 新增：解析 identity
    let userIdentity = undefined;
    if (rawUser.identity) {
      userIdentity = {
        id: Number(rawUser.identity.id ?? 0),
        color: String(rawUser.identity.color ?? ''),
        text: String(rawUser.identity.text ?? '')
      };
    }

    const safeUser: GalleryUser = {
      id: String(rawUser.id ?? '0'),
      nickname: String(rawUser.nickname ?? '匿名用户'),
      avatar: String(avatarUrl),
      identity: userIdentity, // ✅ 赋值回去！
    };

    // 2. 图片：后端是 { mid, url, low_url }，但你自己定义了 id/w/h/type，这里兼容一下
    const rawImages = Array.isArray(raw.images) ? raw.images : [];
    const safeImages: GalleryImage[] = rawImages.map((img: any) => ({
      id: String(img.id ?? img.mid ?? ''),    // 优先 id，其次 mid
      url: String(img.url ?? img.low_url ?? ''), // 优先原图，没有就用低清
      w: Number(img.w ?? 0),
      h: Number(img.h ?? 0),
      type: img.type,
    }));

    // 3. 时间字段：优先 edit_time，其次 update_time，再次 create_time
    const createTime = raw.create_time ? String(raw.create_time) : '';
    const editTime = raw.edit_time
      ? String(raw.edit_time)
      : raw.update_time
        ? String(raw.update_time)
        : createTime;

    // （可选）打日志看真实时间字段
    console.info(
      '[GalleryService] raw time',
      JSON.stringify({
        id: raw.id,
        create_time: raw.create_time,
        edit_time: raw.edit_time,
        update_time: raw.update_time,
      })
    );

    return {
      id: Number(raw.id ?? 0),
      text: String(raw.text ?? ''),
      title: raw.title ? String(raw.title) : undefined,
      user: safeUser,
      images: safeImages,

      // ⚠️ 关键：用 like_num / comment_num，而不是 likeNum / commentNum
      likeNum: Number(raw.like_num ?? 0),
      commentNum: Number(raw.comment_num ?? 0),

      createTime,
      editTime,               // ✅ Poster 里终于有 editTime 了！

      anonymous: Boolean(raw.anonymous),
      public: Boolean(raw.public),
      tags: Array.isArray(raw.tags) ? raw.tags : [],
    };
  }
}

export const galleryService = new GalleryService();