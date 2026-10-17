import { User } from '../user/userRepository';

export type MessageType = 'like' | 'comment' | 'follow' | 'system';
export const MESSAGE_TYPES: MessageType[] = ['like', 'comment', 'follow', 'system'];
export const MESSAGE_LABELS: string[] = ['点赞', '评论', '关注', '系统'];
export interface Message {
  id: number;
  from_user: User;
  link_obj: string;
  obj: string;
  text: string;
  update_time: string;
}
export interface UnreadCounts { like: number; comment: number; follow: number; system: number; }
export interface MessageTarget { page: string; id: number; }
export function emptyUnread(): UnreadCounts { return { like: 0, comment: 0, follow: 0, system: 0 }; }
export function badgeText(count: number): string { return count > 99 ? '99+' : count > 0 ? String(count) : ''; }
export function validCount(value: number): boolean { return Number.isSafeInteger(value) && value >= 0; }
export function parseMessages(payload: Object): Message[] {
  if (!Array.isArray(payload)) throw new Error('消息返回格式异常');
  const messages = payload as Message[];
  for (const item of messages) {
    if (!item || !Number.isSafeInteger(item.id) || item.id <= 0 ||
      typeof item.text !== 'string' || typeof item.obj !== 'string' ||
      typeof item.link_obj !== 'string' || typeof item.update_time !== 'string' ||
      !item.from_user || !Number.isSafeInteger(item.from_user.id) ||
      typeof item.from_user.nickname !== 'string' || !item.from_user.avatar ||
      typeof item.from_user.avatar.url !== 'string') throw new Error('消息字段格式异常');
  }
  return messages;
}
function parseTarget(value: string): MessageTarget | null {
  const match = /^(poster|user)([1-9][0-9]*)$/.exec(value);
  if (!match) return null;
  const id = Number(match[2]);
  if (!Number.isSafeInteger(id)) return null;
  return { page: match[1] === 'poster' ? 'pages/PosterDetailPage' : 'pages/UserDetailPage', id };
}
export function messageTarget(type: MessageType, item: Message): MessageTarget | null {
  return parseTarget(item.link_obj) ?? parseTarget(item.obj) ??
    (type === 'follow' && item.from_user.id > 0 ? { page: 'pages/UserDetailPage', id: item.from_user.id } : null);
}
export function messageAction(type: MessageType, obj: string): string {
  const label = obj.startsWith('poster') ? '帖子' : obj.startsWith('comment') ? '评论' : obj.startsWith('user') ? '用户' : '内容';
  if (type === 'like') return `赞了你的${label}`;
  if (type === 'comment') return `评论了你的${label}`;
  return type === 'follow' ? '关注了你' : '系统消息';
}
