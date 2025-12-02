// entry/src/main/ets/services/gallery/GalleryService.ts
import { Logger } from '../../utils/Logger';
import { bit101Session, RCP_BASE_URL } from '../../core/network/bit101Session';
import { Poster, GalleryUser, GalleryImage, PosterDetail, PosterClaim, PosterPostRequest } from './GalleryModels';
import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
// ✅ [修改] 引入 TokenStore 类
import { TokenStore } from '../storage/tokenStore';
// 辅助: 解决 stringToBuffer 中的 util 引用问题
import util from '@ohos.util';

export enum PostersMode {
  Recommend = 'recommend',
  Hot = 'hot',
  Follow = 'follow',
  Newest = 'newest',
  Search = 'search'
}
export interface UpdatePosterReq {
  id: number;
  title: string;
  text: string;
  imageMids: string[];
  anonymous: boolean;
  tags: string[];
  claimId: number;
  public: boolean;
  plugins: string; // 和安卓一样默认 "[]"
}

class GalleryService {
  private logger = new Logger('GalleryService');
  private apiPath = '/posters';
  // ✅ [新增] 实例化 TokenStore，用于获取 fake-cookie
  private tokenStore = new TokenStore();

  // ✅ [真实] 上传图片接口
  // 使用原生 http + fs 实现 Multipart 上传，确保能获取服务器响应 Body
  async uploadImage(context: Object, uri: string): Promise<string | null> {
    let fileFd: number | null = null;
    try {
      this.logger.debug('Starting upload:', uri);

      // 1. 准备文件数据
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fileFd = file.fd;
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);

      // 2. 构造 Multipart 参数
      const boundary = '----Bit101HarmonyOSBoundary' + Date.now();
      const lineBreak = '\r\n';
      const fileName = 'image.jpg';

      // Header Part
      let bodyString = `--${boundary}${lineBreak}`;
      // 注意：API 定义 Part Name 为 "file"
      bodyString += `Content-Disposition: form-data; name="file"; filename="${fileName}"${lineBreak}`;
      bodyString += `Content-Type: image/jpeg${lineBreak}`;
      bodyString += lineBreak;

      const headerArray = new Uint8Array(this.stringToBuffer(bodyString));

      // Footer Part
      const footerString = `${lineBreak}--${boundary}--${lineBreak}`;
      const footerArray = new Uint8Array(this.stringToBuffer(footerString));

      // 合并 Buffer
      const fileArray = new Uint8Array(buffer);
      const payload = new Uint8Array(headerArray.length + fileArray.length + footerArray.length);
      payload.set(headerArray, 0);
      payload.set(fileArray, headerArray.length);
      payload.set(footerArray, headerArray.length + fileArray.length);

      // 3. 获取鉴权 Token
      // ✅ [核心] 模仿 bit101Session 的逻辑手动获取 fake-cookie
      const fakeCookie = await this.tokenStore.getFakeCookie();

      // 4. 发送请求
      const uploadUrl = `${RCP_BASE_URL}/upload/image`;
      const httpRequest = http.createHttp();

      const headerObj: Record<string, string> = {
        'Content-Type': `multipart/form-data; boundary=${boundary}`
      };
      // 注入 fake-cookie
      if (fakeCookie) {
        headerObj['fake-cookie'] = fakeCookie;
      }

      const resp = await httpRequest.request(uploadUrl, {
        method: http.RequestMethod.POST,
        header: headerObj,
        extraData: payload.buffer
      });

      // 5. 解析响应
      if (resp.responseCode === 200 && resp.result) {
        const resultStr = typeof resp.result === 'string' ? resp.result : JSON.stringify(resp.result);
        this.logger.info('Upload response:', resultStr);

        const json = JSON.parse(resultStr);
        // 后端返回结构 { mid: "...", url: "...", lowUrl: "..." }
        if (json && json.mid) {
          return json.mid;
        }
      } else {
        this.logger.warn('Upload failed, code:', resp.responseCode);
      }
      return null;

    } catch (e) {
      this.logger.error('Upload exception', e);
      return null;
    } finally {
      if (fileFd !== null) {
        try { fs.closeSync(fileFd); } catch (e) {}
      }
    }
  }

  async deletePosterById(id: number): Promise<boolean> {
    const path = `/posters/${id}`;

    const res = await bit101Session.fetch('DELETE', path);

    if (res.statusCode === 200) {
      return true;
    }
    return false;
  }

  private stringToBuffer(str: string): ArrayBuffer {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(str).buffer;
  }

  // ===================== 以下保持原有逻辑不变 =====================

  async getPosters(
    mode: PostersMode,
    page: number = 0,
    options?: { keyword?: string, order?: string, uid?: number }
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
          if (options?.keyword) queryParams['search'] = options.keyword;
          if (options?.order) queryParams['order'] = options.order;
          queryParams['uid'] = options?.uid !== undefined ? options.uid : -1;
          break;
        default: break;
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
      const base = this.safeParsePoster(raw);
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

  async getClaims(): Promise<PosterClaim[]> {
    try {
      const resp = await bit101Session.get(`${this.apiPath}/claims`);
      if (resp.statusCode === 200 && resp.bodyText) {
        const json = JSON.parse(resp.bodyText);
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

  async postPoster(req: PosterPostRequest): Promise<boolean> {
    try {
      this.logger.debug('Sending request body:', req);
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

  async updatePoster(id: number, req: PosterPostRequest): Promise<boolean> {
    // 打印要发送的 JSON
    try {
      this.logger.info('[updatePoster] id=' + id + ', body=' + JSON.stringify(req));
    } catch (e) {
      this.logger.error('[updatePoster] JSON.stringify error', e);
    }

    const res = await bit101Session.fetch('PUT', `/posters/${id}`, {
      body: req
    });

    this.logger.info('[updatePoster] status=' + res.statusCode);
    this.logger.info('[updatePoster] respBody=' + res.bodyText);

    if (res.statusCode === 200) {
      return true;
    }

    this.logger.error('[updatePoster] failed, status=' + res.statusCode + ', body=' + res.bodyText);
    return false;
  }

  private safeParsePoster(raw: any): Poster {
    const rawUser = raw.user || {};
    let avatarUrl = '';
    if (rawUser.avatar) {
      if (typeof rawUser.avatar === 'string') {
        avatarUrl = rawUser.avatar;
      } else if (typeof rawUser.avatar === 'object') {
        avatarUrl = rawUser.avatar.url || rawUser.avatar.lowUrl || rawUser.avatar.low_url || '';
      }
    }

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
      identity: userIdentity,
    };

    const rawImages = Array.isArray(raw.images) ? raw.images : [];
    const safeImages: GalleryImage[] = rawImages.map((img: any) => ({
      id: String(img.id ?? img.mid ?? ''),
      url: String(img.url ?? img.low_url ?? ''),
      w: Number(img.w ?? 0),
      h: Number(img.h ?? 0),
      type: img.type,
    }));

    const createTime = raw.create_time ? String(raw.create_time) : '';
    const editTime = raw.edit_time
      ? String(raw.edit_time)
      : raw.update_time
        ? String(raw.update_time)
        : createTime;

    return {
      id: Number(raw.id ?? 0),
      text: String(raw.text ?? ''),
      title: raw.title ? String(raw.title) : undefined,
      user: safeUser,
      images: safeImages,
      likeNum: Number(raw.like_num ?? 0),
      commentNum: Number(raw.comment_num ?? 0),
      createTime,
      editTime,
      anonymous: Boolean(raw.anonymous),
      public: Boolean(raw.public),
      tags: Array.isArray(raw.tags) ? raw.tags : [],
    };
  }
}

export const galleryService = new GalleryService();