// entry/src/main/ets/services/gallery/GalleryService.ts
import { Logger } from '../../utils/Logger';
import { bit101Session } from '../../core/network/bit101Session';
import { Poster, GalleryUser, GalleryImage, PosterDetail, PosterClaim, PosterPostRequest } from './GalleryModels';
export enum PostersMode {
  Recommend = 'recommend',
  Hot = 'hot',
  Follow = 'follow',
  Newest = 'newest',
  Search = 'search'
}

class GalleryService {
  private logger = new Logger('GalleryService');
  private apiPath = '/posters';

  async getPosters(
    mode: PostersMode,
    page: number = 0,
    // keyword?: string  <-- 旧的删掉
    options?: { keyword?: string, order?: string, uid?: number } // <-- 新的
  ): Promise<Poster[]> {
    try {
      const queryParams: Record<string, string | number> = { page: page };

      switch (mode) {
        case PostersMode.Hot: queryParams['mode'] = 'hot'; break;
        case PostersMode.Follow: queryParams['mode'] = 'follow'; break;
        case PostersMode.Newest:
          queryParams['mode'] = 'search';
          queryParams['order'] = 'NEW';
          queryParams['uid'] = -1;
          break;
        case PostersMode.Search:
          queryParams['mode'] = 'search';
          // [修改] 从 options 里取值
          if (options?.keyword) queryParams['search'] = options.keyword;
          if (options?.order) queryParams['order'] = options.order;
          // 默认为 -1 (全站搜索)，如果 options 里有传则用 options 的
          queryParams['uid'] = options?.uid !== undefined ? options.uid : -1;
          break;
        default: break; // Recommend 模式
      }

      this.logger.debug('Requesting page', page, 'mode:', mode, 'params:', queryParams);

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
      this.logger.error('Exception:', e);
      return [];
    }
  }
  async getPosterById(id: number): Promise<PosterDetail | null> {
    try {
      const resp = await bit101Session.get(`${this.apiPath}/${id}`, {});

      if (resp.statusCode !== 200 || !resp.bodyText) {
        this.logger.warn('getPosterById failed status=', resp.statusCode, 'id=', id);
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
      this.logger.error('getPosterById error:', e);
      return null;
    }
  }
  // ==============================================================
  // [新增] 获取创作者声明列表
  // ==============================================================
  async getClaims(): Promise<PosterClaim[]> {
    try {
      // 猜测路径为 /posters/claims (参考安卓逻辑)
      const resp = await bit101Session.get(`${this.apiPath}/claims`);

      if (resp.statusCode === 200 && resp.bodyText) {
        const json = JSON.parse(resp.bodyText);
        // 兼容处理：可能返回数组，也可能返回 { data: [] }
        const list = Array.isArray(json) ? json : (json.data || []);

        return list.map((item: any) => ({
          id: Number(item.id ?? 0),
          text: String(item.text ?? '')
        }));
      }
    } catch (e) {
      this.logger.error('getClaims error:', e);
    }
    return [];
  }

  // ==============================================================
  // [新增] 发布帖子 (POST)
  // ==============================================================
  async postPoster(req: PosterPostRequest): Promise<boolean> {
    try {
      this.logger.debug('Sending request body:', req);

      // 🚩 终极修正：按照报错提示，先转 unknown 再转 Record
      // 只有这样写，ArkTS 才会允许把 Interface 传给 Record 类型
      const resp = await bit101Session.post(this.apiPath, req as unknown as Record<string, unknown>);

      if (resp.statusCode === 200) {
        return true;
      } else {
        this.logger.warn('Post failed:', resp.statusCode, resp.bodyText);
        return false;
      }
    } catch (e) {
      this.logger.error('postPoster exception:', e);
      return false;
    }
  }

  // ==============================================================
  // [新增] 修改帖子 (PUT)
  // ==============================================================
  async updatePoster(id: number, req: PosterPostRequest): Promise<boolean> {
    try {
      // 🚩 update 同理，但在 RcpSession.ts 里没有定义 put 方法的快捷方式
      // 所以我们要用 fetch 或者去 bit101Session 补全 put
      // 之前我们在 bit101Session 补过 put，但签名可能不一样。
      // 为了稳妥，这里用 fetch 或者检查一下 bit101Session 的 put 定义

      // 假设 bit101Session.put 的定义是 async put(url, options)
      // (根据之前补全的代码: async put(url, options) { return this.fetch('PUT', url, options); })

      // 注意：之前补的 put 方法签名是 (url, options)，和 post 不一样！
      // 所以 updatePoster 这里的写法要对应 put 的定义：
      const resp = await bit101Session.put(`${this.apiPath}/${id}`, {
        body: req
        // ⚠️ 注意：如果你的 bit101Session.put 是接收 options 的，那这里要保留 body: req
        // 建议去检查一下 entry/src/main/ets/core/network/bit101Session.ts 里的 put 实现
      });

      if (resp.statusCode === 200) {
        return true;
      } else {
        this.logger.warn('Update failed:', resp.statusCode, resp.bodyText);
        return false;
      }
    } catch (e) {
      this.logger.error('updatePoster exception:', e);
      return false;
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
    this.logger.debug('raw time check:', {
      id: raw.id,
      create: raw.create_time,
      edit: raw.edit_time,
      update: raw.update_time
    });

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