// 获取用户信息仓库（/user/info/{id}，需要 header: fake-cookie）
// 依赖：HttpClient、TokenStore

import { HttpClient } from '../../core/network/httpClient';
import { TokenStore } from '../storage/tokenStore';

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

export class UserRepository {
  private http: HttpClient;
  private store = new TokenStore();

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
      // 按 OpenAPI：header 名为 fake-cookie
      headers['fake-cookie'] = fakeCookie;
    } else if (String(id) === '0') {
      // 取当前用户信息但没有 fake_cookie → 明确提示
      throw new Error('未登录 BIT101：缺少 fake_cookie，请先通过 /user/login 获取。');
    }

    const res = await this.http.request<UserInfoResponse>({
      url: `/user/info/${id}`,
      method: 'GET',
      headers,
    });

    // 兼容 data 包裹或直出
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
}
