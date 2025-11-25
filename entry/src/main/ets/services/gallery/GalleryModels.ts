// entry/src/main/ets/services/gallery/GalleryModels.ts
// 1. 定义图片结构
// 对应 Android 中的 Image 类
export interface GalleryImage {
  id: string;   // 图片ID
  url: string;  // 图片链接
  w: number;    // 宽
  h: number;    // 高
  type?: string; // 图片类型 (gif/jpg/png)

}

// 2. 定义用户信息结构
// 对应 Android 中的 User 类
export interface GalleryUser {
  id: string;      // 用户ID (Android是Long，TS中为了安全既可以是number也可以是string)
  nickname: string; // 昵称
  avatar: string;   // 头像URL
  // 可以在这里添加其他需要的用户字段，比如等级、签名等
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

// 4. 定义 API 返回的最外层结构
// 根据 Android 代码，Retrofit 返回的是 Response<GetPostersDataModel.Response>
// GetPostersDataModel.Response 继承自 ArrayList<ResponseItem>
// 所以 API 返回的 JSON 应该直接是一个数组，或者是包含 data 字段的对象。
// 这里我们定义两种常见的，稍后调试接口时确定。
export type PosterListResponse = Poster[];