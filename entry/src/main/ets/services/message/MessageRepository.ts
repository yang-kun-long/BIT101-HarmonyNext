import { ApiError, HttpClient } from '../../core/network/httpClient';
import { TokenStore } from '../storage/tokenStore';
import { UserProfileHttpClient, UserProfileTokenStore } from '../user/userRepository';
import { Message, MessageType, MESSAGE_TYPES, UnreadCounts, parseMessages, validCount } from './MessageModels';

export interface MessageSource {
  getMessages(type: MessageType, lastId?: number): Promise<Message[]>;
  getUnreadTotal(): Promise<number>;
  getUnreadCounts(): Promise<UnreadCounts>;
}
export class MessageRepository implements MessageSource {
  constructor(
    private http: UserProfileHttpClient = new HttpClient('https://bit101.flwfdd.xyz'),
    private tokens: UserProfileTokenStore = new TokenStore()
  ) {}
  private async get<T>(url: string): Promise<T> {
    const cookie = await this.tokens.getFakeCookie();
    if (!cookie) throw new ApiError('请先登录 BIT101', 401);
    const response = await this.http.request<T>({ url, method: 'GET', headers: { 'fake-cookie': cookie } });
    if (response.status < 200 || response.status >= 300) throw new ApiError('消息请求失败', response.status);
    return response.data ?? JSON.parse(response.text) as T;
  }
  async getMessages(type: MessageType, lastId?: number): Promise<Message[]> {
    if (!MESSAGE_TYPES.includes(type) || (lastId !== undefined && (!Number.isSafeInteger(lastId) || lastId <= 0))) throw new Error('消息参数无效');
    return parseMessages(await this.get<Object>(`/messages?type=${type}` + (lastId === undefined ? '' : `&last_id=${lastId}`)));
  }
  async getUnreadTotal(): Promise<number> {
    const data = await this.get<{ unread_num: number }>('/messages/unread_num');
    if (!data || !validCount(data.unread_num)) throw new Error('未读数格式异常');
    return data.unread_num;
  }
  async getUnreadCounts(): Promise<UnreadCounts> {
    const data = await this.get<UnreadCounts>('/messages/unread_nums');
    if (!data || !validCount(data.like) || !validCount(data.comment) || !validCount(data.follow) || !validCount(data.system)) throw new Error('分类未读数格式异常');
    return data;
  }
}
