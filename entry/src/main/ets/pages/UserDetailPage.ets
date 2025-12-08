// entry/src/main/ets/pages/UserDetailPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserRepository, UserInfoResponse } from '../services/user/userRepository';
import { PosterRepository } from '../services/gallery/PosterRepository';
import { GalleryUser, Poster } from '../services/gallery/GalleryModels';
import { AvatarWithName, FollowInfo, UserInfoButton } from '../components/user/UserInfoComponents';
import { PosterCard } from '../components/gallery/PosterCard';

@Entry
@Component
struct UserDetailPage {
  @State uid: number = -1;
  @State isLoading: boolean = true;
  @State userInfo: UserInfoResponse | null = null;
  @State uiUser: GalleryUser | null = null;
  @State posters: Poster[] = [];

  // 分页状态
  @State currentPage: number = 0;
  @State hasMore: boolean = true;
  @State isPostersLoading: boolean = false;

  // --- 🌟 滚动与导航栏状态 ---
  @State navOpacity: number = 0; // 导航栏背景透明度 (0.0 - 1.0)
  @State showSmallTitle: boolean = false; // 是否显示小标题
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['uid']) {
      this.uid = params['uid'] as number;
      this.fetchData();
    }
  }

  async fetchData() {
    this.isLoading = true;
    try {
      const userRepo = new UserRepository();
      const data = await userRepo.getUserInfo(this.uid.toString());
      this.userInfo = data;

      // ✅ 新增/修改：如果是当前登录用户，跳到 Index 的“我”Tab（tab = 4）
      if (data.own) {
        router.replaceUrl({
          url: 'pages/Index',
          params: {
            tab: 4   // 对应 Index 里的 TabKey.Me = 4
          }
        });
        return;
      }

      this.uiUser = {
        id: data.user.id.toString(),
        nickname: data.user.nickname,
        avatar: data.user.avatar.url,
        identity: data.user.identity ? {
          id: data.user.identity.id,
          color: data.user.identity.color,
          text: data.user.identity.text
        } : undefined
      };

      this.loadPosters(false);

    } catch (err) {
      promptAction.showToast({ message: '获取用户信息失败: ' + (err as Error).message });
    } finally {
      this.isLoading = false;
    }
  }


  async loadPosters(isLoadMore: boolean) {
    if (this.isPostersLoading) return;
    if (isLoadMore && this.posters.length === 0) return;
    if (isLoadMore && !this.hasMore) return;

    this.isPostersLoading = true;

    // ❌ [修复 2] 修正分页逻辑
    // 刷新时(isLoadMore=false) 必须请求第 0 页
    // 加载更多时，请求当前页 + 1
    const pageToFetch = isLoadMore ? this.currentPage + 1 : 0;

    try {
      const posterRepo = new PosterRepository();

      // ✅ [修复 3] 核心修改：如果是自己，uid 传 0
      let requestUid = this.uid;
      // 依赖于 fetchData 中已经获取了 userInfo 并且有了 own 字段
      if (this.userInfo && this.userInfo.own) {
        requestUid = 0;
      }

      // 使用计算后的 requestUid 发请求
      const newPosters = await posterRepo.getPostersOfUser(requestUid, pageToFetch);

      if (isLoadMore) {
        this.posters = [...this.posters, ...newPosters];
      } else {
        this.posters = newPosters;
      }

      if (newPosters.length > 0) {
        this.currentPage = pageToFetch;
      }
      // 简单判断是否有更多
      this.hasMore = newPosters.length >= 10;

    } catch (err) {
      console.error('加载帖子失败', err);
    } finally {
      this.isPostersLoading = false;
    }
  }

  // --- 逻辑区 ---

  // 🔥 [核心修改] 真实的关注逻辑
  private async handleFollow() {
    if (!this.userInfo || !this.uiUser) return;

    const userRepo = new UserRepository();

    try {
      const result = await userRepo.followUser(this.uiUser.id);

      if (result) {
        // ArkTS 不支持 ...this.userInfo 写法，必须手动构建新对象
        const newUserInfo: UserInfoResponse = {
          user: this.userInfo.user, // 保持原有 user 对象
          own: this.userInfo.own,   // 保持原有 own 状态

          // 更新关注相关的 4 个字段
          following: result.following,
          follower: result.follower,
          follower_num: result.follower_num,
          following_num: result.following_num
        };

        this.userInfo = newUserInfo;

        promptAction.showToast({
          message: result.following ? '关注成功' : '已取消关注',
          duration: 1500
        });

      } else {
        promptAction.showToast({ message: '操作失败，请重试' });
      }
    } catch (e) {
      promptAction.showToast({ message: '网络错误，请检查连接' });
    }
  }

  private getButtonText(): string {
    if (!this.userInfo) return "";
    if (!this.userInfo.following) return "关注";
    if (this.userInfo.follower) return "已互粉";
    return "已关注";
  }

  @Builder
  ActionButtonBuilder() {
    if (this.userInfo) {
      if (this.userInfo.own) {
        UserInfoButton({
          text: "我的主页",
          isPrimary: true, // 我的主页通常也用强调色
          onAction: () => {
            promptAction.showToast({ message: "即将跳转我的主页..." });
          }
        })
      } else {
        // ✅ 这里的绑定是正确的，点击触发上面的 handleFollow
        UserInfoButton({
          text: this.getButtonText(),
          isPrimary: !this.userInfo.following, // 未关注时为 True (粉色)，已关注为 False (灰色)
          onAction: () => {
            this.handleFollow();
          }
        })
      }
    }
  }

  // --- 🌟 顶部导航栏 (Fade 模式) ---
  @Builder
  CustomNavBar() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 背景层
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .opacity(this.navOpacity)
        .shadow(this.navOpacity > 0.9 ? { radius: 3, color: '#0D000000', offsetY: 1 } : undefined)

      // 2. 内容层
      Row() {
        // 返回按钮
        Row() {
          Image($r('app.media.ic_arrow_back'))
            .width(24)
            .height(24)
            .fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })
        .margin({ left: 4 })

        // 小标题 (昵称)
        if (this.uiUser) {
          Text(this.uiUser.nickname)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 16, right: 16 })
            .opacity(this.showSmallTitle ? 1 : 0)
            .animation({ duration: 200 })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
  }

  // --- 🌟 用户信息大卡片 ---
  @Builder
  UserInfoHeader() {
    if (this.userInfo && this.uiUser) {
      Column() {
        AvatarWithName({
          user: this.uiUser,
          createTime: this.userInfo.user.create_time,
          actionButton: () => { this.ActionButtonBuilder() }
        })

        if (this.userInfo.user.motto) {
          Text(this.userInfo.user.motto)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .margin({ top: 4, bottom: 16, left: 24, right: 24 })
            .textAlign(TextAlign.Center)
            .opacity(0.8)
        } else {
          Text("这个人很懒，什么都没有写")
            .fontSize(14)
            .fontColor(Color.Gray)
            .margin({ top: 4, bottom: 16 })
        }

        FollowInfo({
          followerNum: this.userInfo.follower_num,
          followingNum: this.userInfo.following_num
        })
          .margin({ bottom: 16 })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .padding({ top: 56 + 12 })
    }
  }

  @Builder
  FooterLoading() {
    Row() {
      if (this.isPostersLoading) {
        LoadingProgress().width(20).height(20).margin({ right: 8 })
        Text("正在加载...").fontSize(14).fontColor(Color.Gray)
      } else if (!this.hasMore && this.posters.length > 0) {
        Text("没有更多了 -").fontSize(12).fontColor(Color.Gray)
      }
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {

      // 1. 底层列表
      List({ scroller: this.scroller }) {
        ListItem() {
          this.UserInfoHeader()
        }

        if (this.posters.length > 0) {
          ListItem().height(8)

          ForEach(this.posters, (item: Poster) => {
            ListItem() {
              Column() {
                PosterCard({
                  poster: item,
                  onClickPoster: () => {
                    router.pushUrl({
                      url: 'pages/PosterDetailPage',
                      params: { id: item.id }
                    });
                  }
                })
                Divider()
                  .color(Color.Transparent)
                  .height(8)
                  .width('100%')
              }
            }
          })
        } else if (!this.isPostersLoading) {
          ListItem() {
            Text("暂无动态")
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(40)
              .fontColor(Color.Gray)
          }
        }

        ListItem() {
          this.FooterLoading()
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadPosters(true);
      })
      .onDidScroll(() => {
        const headerRect = this.scroller.getItemRect(0);
        if (headerRect.width > 0) {
          const yOffset = -headerRect.y;
          const threshold = 120;
          let opacity = 0;
          if (yOffset > 0) {
            opacity = Math.min(yOffset / threshold, 1);
          }
          this.navOpacity = opacity;
          this.showSmallTitle = opacity > 0.85;
        } else {
          this.navOpacity = 1;
          this.showSmallTitle = true;
        }
      })

      // 2. 顶层悬浮导航栏
      this.CustomNavBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}