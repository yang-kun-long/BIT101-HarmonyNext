// entry/src/main/ets/services/user/userRepository.ts
// 获取用户信息仓库（/user/info/{id}，需要 header: fake-cookie）
// 依赖：HttpClient、TokenStore

import { HttpClient } from '../../core/network/httpClient';
import { TokenStore } from '../storage/tokenStore';
import { Logger } from '../../utils/Logger';

export interface Image {
  mid: string;
  url: string;
  low_url: string;
}
export interface Identity {
  id: number;
  color: string; // 勾勾颜色，空则不显示
  text: string;  // 身份称号
}
export interface User {
  id: number;
  create_time: string;
  nickname: string;
  avatar: Image;
  motto: string;
  identity: Identity;
}
export interface UserInfoResponse {
  user: User;
  following_num: number;
  follower_num: number;
  following: boolean; // 是否被我关注
  follower: boolean;  // 是否关注我
  own: boolean;       // 是否是自己
}

// 关注接口返回结构
export interface FollowResponse {
  following: boolean;      // 是否被我关注
  follower: boolean;       // 是否关注我
  following_num: number;   // 关注数量
  follower_num: number;    // 粉丝数量
}

export class UserRepository {
  private http: HttpClient;
  private store = new TokenStore();
  private logger = new Logger('UserRepository');

  constructor(baseUrl: string = 'https://bit101.flwfdd.xyz') {
    this.http = new HttpClient(baseUrl, {
      'User-Agent': 'BIT101 HarmonyOS/1.0 (ArkTS)',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    });
  }

  /**
   * 获取用户信息
   * @param id - '-1' 匿名，'0' 当前用户，其它为用户ID
   * @returns UserInfoResponse
   */
  async getUserInfo(id: string | number = '0'): Promise<UserInfoResponse> {
    const fakeCookie = await this.store.getFakeCookie();
    const headers: Record<string, string> = {};
    if (fakeCookie) {
      headers['fake-cookie'] = fakeCookie;
    } else if (String(id) === '0') {
      throw new Error('未登录 BIT101：缺少 fake_cookie，请先通过 /user/login 获取。');
    }

    const res = await this.http.request<UserInfoResponse>({
      url: `/user/info/${id}`,
      method: 'GET',
      headers,
    });

    if (typeof res.data === 'object' && res.data) {
      return res.data as UserInfoResponse;
    }
    try {
      const obj = JSON.parse(res.text);
      return (obj?.data ?? obj) as UserInfoResponse;
    } catch {
      throw new Error('获取用户信息：返回格式异常');
    }
  }

  /**
   * 关注/取消关注用户
   */
  async followUser(uid: string | number): Promise<FollowResponse | null> {
    try {
      const fakeCookie = await this.store.getFakeCookie();
      const headers: Record<string, string> = {};
      if (fakeCookie) {
        headers['fake-cookie'] = fakeCookie;
      } else {
        this.logger.warn('关注操作缺少 fake-cookie');
      }

      this.logger.info(`发起关注请求: uid=${uid}`);

      // 🔥【修正点】将 data 改为 json，因为你的 HttpClient 定义的是 json
      const res = await this.http.request<any>({
        url: `/user/follow/${uid}`,
        method: 'POST',
        headers: headers,
        json: {} // <--- 这里改成了 json，对应 HttpRequest 接口
      });

      // 解析逻辑
      let json = res.data;
      if (!json && res.text) {
        try {
          json = JSON.parse(res.text);
        } catch (e) {
          this.logger.error('关注返回解析失败', e);
        }
      }

      const data = json?.data ?? json;

      if (data && typeof data.following === 'boolean') {
        this.logger.info(`关注操作成功: following=${data.following}`);
        return {
          following: Boolean(data.following),
          follower: Boolean(data.follower),
          following_num: Number(data.following_num ?? 0),
          follower_num: Number(data.follower_num ?? 0)
        };
      }

      this.logger.warn('关注操作返回数据异常', JSON.stringify(data));
      return null;

    } catch (e) {
      this.logger.error('关注网络异常', e);
      return null;
    }
  }
}