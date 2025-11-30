import { GalleryUser } from '../gallery/GalleryModels';

// 1. API 原始响应结构 (严格匹配 OpenAPI 文档)
export interface UserInfoApiRaw {
  user: {
    id: number;
    create_time: string;
    nickname: string;
    avatar: {
      mid: string;
      url: string;
      low_url: string;
    };
    motto: string;
    identity: {
      id: number;
      color: string;
      text: string;
    };
  };
  following_num: number;
  follower_num: number;
  following: boolean;
  follower: boolean;
  own: boolean;
}

// 2. UI 使用的结构 (Camel Case)
export interface UserInfo {
  // 我们扩展 GalleryUser，补上 motto 字段
  user: GalleryUser & { motto: string };

  followingNum: number;
  followerNum: number;

  // 语义化布尔值
  isFollowing: boolean;
  isFollower: boolean;
  isOwn: boolean;
}