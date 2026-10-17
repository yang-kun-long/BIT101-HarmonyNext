import { GallerySettings } from '../storage/GallerySettingsStore';
import { Poster, Comment, ImageUploadItem } from './GalleryModels';

export function hideBotForMode(mode: string, settings: GallerySettings): boolean {
  return mode !== 'follow' && settings.hideBot && (mode !== 'search' || settings.hideBotInSearch);
}

export function filterPosters(items: Poster[], mode: string, settings: GallerySettings): Poster[] {
  if (mode === 'follow') return items;
  return items.filter(item => !settings.hiddenUids.includes(item.user.id) &&
    !(settings.hideAnonymous && item.anonymous));
}

export function filterComments(items: Comment[], settings: GallerySettings): Comment[] {
  return items.filter(item => !settings.hiddenUids.includes(item.user.id) &&
    !(settings.strict && item.replyUser && settings.hiddenUids.includes(item.replyUser.id)))
    .map(item => {
      const copy: Comment = { id: item.id, obj: item.obj, images: item.images, user: item.user,
        anonymous: item.anonymous, createTime: item.createTime, updateTime: item.updateTime,
        like: item.like, likeNum: item.likeNum, commentNum: item.commentNum, own: item.own,
        rate: item.rate, replyUser: item.replyUser, replyObj: item.replyObj, text: item.text,
        sub: filterComments(item.sub, settings) };
      return copy;
    });
}

export function commentSendError(text: string, images: ImageUploadItem[]): string {
  if (images.some(item => item.status === 'uploading' || item.status === 'pending')) return '图片上传中，请稍候';
  if (images.some(item => item.status === 'fail')) return '图片上传失败，请删除失败图片后重试';
  return text.trim().length > 0 || images.some(item => item.status === 'success' && !!item.mid)
    ? '' : '请输入评论或添加上传成功的图片';
}
