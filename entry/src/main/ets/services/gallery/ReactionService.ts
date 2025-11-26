// entry/src/main/ets/services/gallery/ReactionService.ts
import { bit101Session } from '../../core/network/bit101Session';
import { Comment, GalleryImage, GalleryUser } from './GalleryModels';

class ReactionService {
  private commentsPath = '/reaction/comments';

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
      console.error('[ReactionService] getComments error', e);
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

    const replyUserRaw = raw.replyUser;
    let replyUser: GalleryUser | null = null;
    if (replyUserRaw) {
      const replyAvatarRaw = replyUserRaw.avatar || {};
      const replyAvatarUrl =
        typeof replyAvatarRaw === 'string'
          ? replyAvatarRaw
          : (replyAvatarRaw.url || replyAvatarRaw.low_url || '');

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
      replyObj: raw.replyObj ? String(raw.replyObj) : '',
      text: String(raw.text ?? ''),
      sub: [],
    };

    // 递归解析子评论
    base.sub = subRaw.map((child: any) => this.safeParseComment(child));
    return base;
  }
}

export const reactionService = new ReactionService();
