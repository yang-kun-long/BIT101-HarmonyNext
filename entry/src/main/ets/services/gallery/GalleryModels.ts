// entry/src/main/ets/services/gallery/GalleryModels.ts
// 1. 定义图片结构
// 对应 Android 中的 Image 类
export interface GalleryImage {
  id: string;
  url: string;
  w: number;
  h: number;
  type?: string;
}

// 2. 定义用户信息结构
// 对应 Android 中的 User 类
export interface GalleryUser {
  id: string;
  nickname: string;
  avatar: string;
  identity?: UserIdentity; // 新增此字段
}

// 3. 定义帖子结构
// 对应 Android 中的 GetPostersDataModel.ResponseItem
export interface Poster {
  id: number;           // 帖子ID
  title?: string;       // 标题 (部分帖子可能有)
  text: string;         // 正文内容

  images: GalleryImage[]; // 图片列表
  user: GalleryUser;      // 发帖人信息

  likeNum: number;      // 点赞数
  commentNum: number;   // 评论数

  createTime: string;   // 发布时间 (通常是字符串格式 "2023-10-24 12:00")
  editTime?: string;

  // 标记位
  anonymous: boolean;   // 是否匿名
  public: boolean;      // 是否公开
  tags: string[];       // 标签列表

}

export interface PosterClaim {
  id: number;
  text: string;
}

// 3.2 帖子详情类型：在列表 Poster 的基础上，多了一些字段
export interface PosterDetail extends Poster {
  like: boolean;                // 当前用户是否点赞
  own: boolean;                 // 是否自己的帖子（可编辑删除）
  claim: PosterClaim | null;    // 声明（可以先允许为 null）
  plugins?: string;             // 插件 JSON 字符串
  subscription?: number;        // 订阅级别
}

export interface Comment {
  id: number;
  obj: string;
  images: GalleryImage[];
  user: GalleryUser;
  anonymous: boolean;
  createTime: string;
  updateTime: string;
  like: boolean;
  likeNum: number;
  commentNum: number;
  own: boolean;
  rate: number;
  replyUser?: GalleryUser | null;
  replyObj?: string;
  text: string;
  sub: Comment[];
}
export interface UserIdentity {
  id: number;
  color: string; // 例如 "#FF0000"
  text: string;  // 例如 "管理员", "学生"
}




export type CommentsOrder = 'new' | 'old' | 'like' | 'default';


// 4. 定义 API 返回的最外层结构
// 根据 Android 代码，Retrofit 返回的是 Response<GetPostersDataModel.Response>
// GetPostersDataModel.Response 继承自 ArrayList<ResponseItem>
// 所以 API 返回的 JSON 应该直接是一个数组，或者是包含 data 字段的对象。
// 这里我们定义两种常见的，稍后调试接口时确定。
export type PosterListResponse = Poster[];