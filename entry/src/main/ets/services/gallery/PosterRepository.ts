import RcpSession from '../../core/network/rcpSession';
import { Poster, GalleryUser, GalleryImage } from './GalleryModels';
import { TokenStore } from '../storage/tokenStore';
import { Logger } from '../../utils/Logger'; // ✅ 引入您的 Logger

const logger = new Logger('PosterRepository'); // ✅ 使用定义的模块名

// 定义 API 返回的原始数据接口
interface PosterApiRaw {
  id: number;
  text: string;
  title?: string;
  create_time: string;
  edit_time?: string;
  like_num: number;
  comment_num: number;
  anonymous: boolean;
  public: boolean;
  images: {
    mid: string;
    url: string;
    low_url: string;
    w: number;
    h: number;
    type?: string;
  }[];
  user: {
    id: number;
    nickname: string;
    avatar: {
      url: string;
    };
    identity?: {
      id: number;
      text: string;
      color: string;
    };
  };
}

export class PosterRepository {
  private rcp: RcpSession;
  private tokenStore: TokenStore = new TokenStore();

  constructor() {
    this.rcp = new RcpSession({
      baseUrl: 'https://bit101.flwfdd.xyz',
      debug: false // RcpSession 内部也有 Logger，这里可以关掉 console debug
    });
  }

  async getPostersOfUser(uid: number, page: number = 1): Promise<Poster[]> {
    if (uid === -1) {
      logger.info('匿名用户，不获取帖子列表');
      return [];
    }

    try {
      const fakeCookie = await this.tokenStore.getFakeCookie();
      const headers: Record<string, string> = {};

      if (fakeCookie) {
        headers['fake-cookie'] = fakeCookie;
      } else {
        logger.warn('缺少 fake-cookie，请求可能受限');
      }

      const queryParams: Record<string, string | number> = {
        uid: uid,
        mode: 'search'
      };

      // 策略：第一页不传 page 参数，完全依赖后端默认行为
      if (page > 1) {
        queryParams['page'] = page;
      }

      logger.info(`发起请求: uid=${uid}, page=${page}, params=${JSON.stringify(queryParams)}`);

      const response = await this.rcp.get('/posters', {
        headers: headers,
        query: queryParams
      });

      if (response.statusCode !== 200) {
        logger.error(`请求失败: code=${response.statusCode}, body部分=${response.bodyText.substring(0, 200)}`);
        return [];
      }

      let rawList: PosterApiRaw[] = [];
      try {
        const json = JSON.parse(response.bodyText);

        // 🔍 调试关键点：打印原始数据结构类型
        if (Array.isArray(json)) {
          logger.info(`解析成功: 根数组模式, 长度=${json.length}`);
          rawList = json;
        } else if (json && Array.isArray(json.data)) {
          logger.info(`解析成功: data包装模式, 长度=${json.data.length}`);
          rawList = json.data;
        } else {
          logger.warn(`数据格式异常: 既不是数组也不是{data:[]}. Body前100字: ${response.bodyText.substring(0, 100)}`);
        }
      } catch (e) {
        logger.error('JSON解析失败', e);
        return [];
      }

      return rawList.map(item => this.mapApiToModel(item));

    } catch (err) {
      logger.error('网络层异常', err);
      throw err;
    }
  }

  private mapApiToModel(raw: PosterApiRaw): Poster {
    const avatarUrl = raw.user?.avatar?.url || '';

    const uiUser: GalleryUser = {
      id: raw.user?.id?.toString() ?? '0',
      nickname: raw.user?.nickname ?? '未知用户',
      avatar: avatarUrl,
      identity: raw.user?.identity ? {
        id: raw.user.identity.id,
        text: raw.user.identity.text,
        color: raw.user.identity.color
      } : undefined
    };

    const uiImages: GalleryImage[] = (raw.images || []).map(img => ({
      id: img.mid,
      url: img.url,
      w: img.w,
      h: img.h,
      type: img.type
    }));

    return {
      id: raw.id,
      text: raw.text,
      title: raw.title,
      createTime: raw.create_time,
      editTime: raw.edit_time,
      likeNum: raw.like_num,
      commentNum: raw.comment_num,
      anonymous: raw.anonymous,
      public: raw.public,
      tags: [],
      images: uiImages,
      user: uiUser
    };
  }
}