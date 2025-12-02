// entry/src/main/ets/services/gallery/ReactionService.ts
import { Logger } from '../../utils/Logger';
import { bit101Session } from '../../core/network/bit101Session';
import { Comment, GalleryImage, GalleryUser } from './GalleryModels';

// ✅ [新增] 必须导出这个接口，PosterDetailPage 才能引用
export interface PostCommentReq {
  obj: string;
  text: string;
  reply_obj?: string;
  reply_uid?: number;
  anonymous?: boolean;
  image_mids: string[];
  rate?: number;
}
interface PostLikeResp {
  like: boolean;
  likeNum: number;
}

class ReactionService {
  private commentsPath = '/reaction/comments';
  private likePath = '/reaction/like';
  private logger = new Logger('ReactionService');
  private makeObj(type: 'poster' | 'comment', id: number): string {
    return `${type}${id}`;
  }

  async getCommentsForPoster(
    posterId: number,
    order: string = 'new',
    page?: number
  ): Promise<Comment[]> {
    return this.getComments(this.makeObj('poster', posterId), order, page);
  }

  async getCommentsForComment(
    commentId: number,
    page: number = 0,
    order: string = 'new'
  ): Promise<Comment[]> {
    // 复用底层的 getComments，构造 obj = "comment123"
    return this.getComments(this.makeObj('comment', commentId), order, page);
  }

  // ✅ [新增] 发送评论方法
  async postComment(req: PostCommentReq): Promise<Comment | null> {
    try {
      this.logger.info(`Sending comment req: ${JSON.stringify(req)}`);

      // 发送 POST 请求
      // 使用 as unknown as Record... 规避类型检查，直接透传对象
      const resp = await bit101Session.post(this.commentsPath, req as unknown as Record<string, Object>);

      if (resp.statusCode === 200 && resp.bodyText) {
        const json = JSON.parse(resp.bodyText);
        // 复用你已有的安全解析方法，确保返回格式统一
        return this.safeParseComment(json);
      }
      return null;
    } catch (e) {
      this.logger.error('postComment error', e);
      return null;
    }
  }
  async deleteComment(id: number): Promise<boolean> {
    try {
      this.logger.info(`[deleteComment] id=${id}`);

      // ✅ 直接用你已经有的 fetch，method = 'DELETE'
      const resp = await bit101Session.fetch('DELETE', `${this.commentsPath}/${id}`);

      if (resp.statusCode === 200) {
        return true;
      }

      this.logger.error(`[deleteComment] bad status: ${resp.statusCode}`);
      return false;
    } catch (e) {
      this.logger.error('[deleteComment] error', e);
      return false;
    }
  }

  private async postLike(obj: string): Promise<PostLikeResp | null> {
    try {
      this.logger.info(`[like] POST ${this.likePath}, obj=${obj}`);

      const body = { obj } as Record<string, Object>;
      const resp = await bit101Session.post(this.likePath, body);

      if (resp.statusCode === 200 && resp.bodyText) {
        const json = JSON.parse(resp.bodyText);
        // 直接按 Android 的结构解析
        return {
          like: Boolean(json.like),
          likeNum: Number(json.likeNum ?? json.like_num ?? 0)
        };
      }

      this.logger.error(`[like] bad status: ${resp.statusCode}`);
      return null;
    } catch (e) {
      this.logger.error('[like] postLike error', e);
      return null;
    }
  }

  // 帖子点赞
  async likePoster(id: number): Promise<PostLikeResp | null> {
    return this.postLike(`poster${id}`);
  }

  // 评论点赞（先留好，后面用）
  async likeComment(id: number): Promise<PostLikeResp | null> {
    return this.postLike(`comment${id}`);
  }

  private async getComments(
    obj: string,
    order?: string,
    page?: number
  ): Promise<Comment[]> {
    try {
      const query: Record<string, string | number> = { obj };
      if (order) query['order'] = order;
      if (page !== undefined) query['page'] = page;

      const resp = await bit101Session.get(this.commentsPath, { query });

      if (resp.statusCode !== 200 || !resp.bodyText) {
        return [];
      }

      const json = JSON.parse(resp.bodyText);
      const rawList: any[] = Array.isArray(json)
        ? json
        : (json?.data ?? []);

      return rawList.map((raw) => this.safeParseComment(raw));
    } catch (e) {
      this.logger.error('getComments error', e);
      return [];
    }
  }

  private safeParseComment(raw: any): Comment {
    const rawUser = raw.user || {};
    const avatarRaw = rawUser.avatar || {};
    const avatarUrl =
      typeof avatarRaw === 'string'
        ? avatarRaw
        : (avatarRaw.url || avatarRaw.low_url || '');

    const user: GalleryUser = {
      id: String(rawUser.id ?? '0'),
      nickname: String(rawUser.nickname ?? '匿名用户'),
      avatar: String(avatarUrl ?? ''),
    };

    const rawImages = Array.isArray(raw.images) ? raw.images : [];
    const images: GalleryImage[] = rawImages.map((img: any) => ({
      id: String(img.id ?? img.mid ?? ''),
      url: String(img.url ?? img.low_url ?? ''),
      w: Number(img.w ?? 0),
      h: Number(img.h ?? 0),
      type: img.type,
    }));

    const subRaw = Array.isArray(raw.sub) ? raw.sub : [];
    if (raw.reply_user || raw.replyUser) {
      this.logger.debug('Parsing replyUser:', JSON.stringify(raw.reply_user || raw.replyUser));
    }
    const replyUserRaw = raw.reply_user || raw.replyUser;
    let replyUser: GalleryUser | null = null;
    if (replyUserRaw) {
      const replyAvatarRaw = replyUserRaw.avatar || {};
      const replyAvatarUrl =
        typeof replyAvatarRaw === 'string'
          ? replyAvatarRaw
          : (replyAvatarRaw.url || replyAvatarRaw.low_url || '');
      let rawNick = replyUserRaw.nickname;
      // 2. 如果是 null/undefined 或者是空字符串，就回退到 '匿名用户'
      if (!rawNick || String(rawNick).trim() === '') {
        rawNick = '匿名用户';
      }

      replyUser = {
        id: String(replyUserRaw.id ?? '0'),
        nickname: String(replyUserRaw.nickname ?? '匿名用户'),
        avatar: String(replyAvatarUrl ?? ''),
      };
    }

    const base: Comment = {
      id: Number(raw.id ?? 0),
      obj: String(raw.obj ?? ''),
      images,
      user,
      anonymous: Boolean(raw.anonymous),
      createTime: String(raw.createTime ?? raw.create_time ?? ''),
      updateTime: String(raw.updateTime ?? raw.update_time ?? ''),
      like: Boolean(raw.like),
      likeNum: Number(raw.likeNum ?? raw.like_num ?? 0),
      commentNum: Number(raw.commentNum ?? raw.comment_num ?? 0),
      own: Boolean(raw.own),
      rate: Number(raw.rate ?? 0),
      replyUser,
      replyObj: raw.reply_obj ? String(raw.reply_obj) : '',
      text: String(raw.text ?? ''),
      sub: [],
    };

    // 递归解析子评论
    base.sub = subRaw.map((child: any) => this.safeParseComment(child));
    return base;
  }
}

export const reactionService = new ReactionService();