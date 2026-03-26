// entry/src/main/ets/pages/MePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserRepository, UserInfoResponse } from '../services/user/userRepository';
import { PosterRepository } from '../services/gallery/PosterRepository';
import { GalleryUser, Poster } from '../services/gallery/GalleryModels';
import { AvatarWithName, FollowInfo, UserInfoButton } from '../components/user/UserInfoComponents';
import { PosterCard } from '../components/gallery/PosterCard';
import { TokenStore } from '../services/storage/tokenStore';
import { uiPushUrl, uiShowToast } from '../utils/uiContextBridge';

@Component
export default struct MePage {
  // 登录 / 加载状态
  @State loading: boolean = true;
  @State err: string = '';
  @State authed: boolean = false;

  // 用户信息 + UI 数据
  @State userInfo: UserInfoResponse | null = null;
  @State uiUser: GalleryUser | null = null;

  // 帖子列表 + 分页
  @State posters: Poster[] = [];
  @State currentPage: number = 0;
  @State hasMore: boolean = true;
  @State isPostersLoading: boolean = false;

  // 顶部导航栏滚动效果
  @State navOpacity: number = 0;
  @State showSmallTitle: boolean = false;
  private scroller: Scroller = new Scroller();

  // 仓库
  private userRepo: UserRepository = new UserRepository();
  private posterRepo: PosterRepository = new PosterRepository();
  private tokenStore: TokenStore = new TokenStore();

  aboutToAppear() {
    this.bootstrap();
  }

  // ---------------- 业务逻辑 ----------------
  private async bootstrap() {
    this.loading = true;
    this.err = '';
    this.userInfo = null;
    this.uiUser = null;
    this.posters = [];
    this.currentPage = 0;
    this.hasMore = true;

    this.authed = await this.tokenStore.isLoggedInBit101();

    if (!this.authed) {
      this.loading = false;
      return;
    }

    try {
      // 0 = 当前登录用户
      const data = await this.userRepo.getUserInfo('0');
      this.userInfo = data;

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

      await this.loadPosters(false);
    } catch (e) {
      const m: string = (e as Error).message || String(e);
      this.err = m;
      this.userInfo = null;
      this.uiUser = null;
    } finally {
      this.loading = false;
    }
  }

  private async loadPosters(isLoadMore: boolean) {
    if (!this.authed || !this.userInfo) return;
    if (this.isPostersLoading) return;
    if (isLoadMore && this.posters.length === 0) return;
    if (isLoadMore && !this.hasMore) return;

    this.isPostersLoading = true;
    const pageToFetch = isLoadMore ? this.currentPage + 1 : 0;

    try {
      // 自己主页时按后端约定使用 uid = 0
      let requestUid: number = this.userInfo.own ? 0 : this.userInfo.user.id;
      const newPosters = await this.posterRepo.getPostersOfUser(requestUid, pageToFetch);

      if (isLoadMore) {
        this.posters = [...this.posters, ...newPosters];
      } else {
        this.posters = newPosters;
      }

      if (newPosters.length > 0) {
        this.currentPage = pageToFetch;
      }
      this.hasMore = newPosters.length >= 10;
    } catch (e) {
      console.error('[MePage] loadPosters error', e);
    } finally {
      this.isPostersLoading = false;
    }
  }

  private async logout() {
    await this.tokenStore.clear();
    this.authed = false;
    this.userInfo = null;
    this.uiUser = null;
    this.posters = [];
    this.currentPage = 0;
    this.hasMore = true;
    this.err = '';

    uiShowToast(this.getUIContext(), { message: '已退出登录' });
  }

  private async gotoLogin() {
    await uiPushUrl(this.getUIContext(), { url: 'pages/LoginPage', params: { redirect: 'pages/Index' } });
  }

  // ---------------- UI 片段 ----------------

  // 顶部导航栏（与 UserDetailPage 保持一致：渐变背景 + 小标题）
  @Builder
  CustomNavBar() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .opacity(this.navOpacity)
        .shadow(this.navOpacity > 0.9 ? { radius: 3, color: '#0D000000', offsetY: 1 } : undefined)

      // 内容
      Row() {
        // 左侧占位（UserDetailPage 这里是返回按钮，MePage作为“我”页就不需要返回）
        Row() { }
        .width(48)
        .height(48)
        .margin({ left: 4 })

        // 小标题（昵称）
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

        // 右侧占位
        Row() {
          Image($r('app.media.ic_settings'))
            .width(20) // 图标稍微调小一点，显得精致
            .height(20)
            // 颜色逻辑：
            // 滚动下来(白底) -> 图标变黑
            // 未滚动(透明底) -> 图标变白
            .fillColor(this.navOpacity > 0.8 ? $r('sys.color.ohos_id_color_text_primary') : Color.White)
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .borderRadius(16) // 圆形背景
        // 背景色逻辑 (关键修正)：
        // 滚动下来(白底) -> 背景透明
        // 未滚动(透明底) -> 背景加半透明黑罩 (#4D000000)，防止背景图太白导致看不见
        .backgroundColor(this.navOpacity > 0.8 ? Color.Transparent : '#4D000000')
        .margin({ right: 12 })
        .onClick(() => {
          uiPushUrl(this.getUIContext(), { url: 'pages/settings/Settings' });
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
  }

  // 头像 + 昵称 + 签名 + 关注信息
  @Builder
  LogoutButtonBuilder() {
    // 使用已有的 UserInfoButton，只做一个“退出登录”按钮
    UserInfoButton({
      text: "退出登录",
      isPrimary: false,
      onAction: () => {
        this.logout();
      }
    })
  }

  @Builder
  UserInfoHeader() {
    if (this.userInfo && this.uiUser) {
      Column() {
        AvatarWithName({
          user: this.uiUser,
          createTime: this.userInfo.user.create_time,
          // 这里不再是“关注/我的主页”，而是唯一的“退出登录”
          actionButton: () => { this.LogoutButtonBuilder() }
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
      .padding({ top: 56 + 12 }) // 预留给顶部导航栏的高度
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

  // ---------------- 页面 ----------------
  build() {
    // 1. 加载中
    if (this.loading) {
      Column() {
        Text('加载中…').fontSize(16)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    // 2. 未登录：保留简单“游客 + 去登录”
    else if (!this.authed) {
      Column({ space: 12 }) {
        Text('游客').fontSize(22).fontWeight(FontWeight.Bold)
        Text('登录后可访问完整个人主页与动态')
          .fontSize(13)
          .fontColor('#666666')

        Button('去登录')
          .type(ButtonType.Capsule)
          .onClick(() => { this.gotoLogin() })
      }
      .padding(16)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    // 3. 加载出错
    else if (this.err.length > 0) {
      Column({ space: 12 }) {
        Text('加载失败').fontColor('#ef4444').fontSize(18)
        Text(this.err).fontColor('#ef4444').fontSize(12).maxLines(3)

        Button('重试')
          .type(ButtonType.Capsule)
          .onClick(() => { this.bootstrap() })

        Button('退出登录')
          .type(ButtonType.Capsule)
          .onClick(() => { this.logout() })
      }
      .padding(16)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    // 4. 正常：展示与 UserDetailPage 对齐的个人主页 + 动态列表，仅保留一个退出登录
    else if (this.userInfo && this.uiUser) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 列表主体
        List({ scroller: this.scroller }) {
          // 个人信息大卡片
          ListItem() {
            this.UserInfoHeader()
          }

          // 帖子列表
          if (this.posters.length > 0) {
            ListItem().height(8)

            ForEach(this.posters, (item: Poster) => {
              ListItem() {
                Column() {
                  PosterCard({
                    poster: item,
                    onClickPoster: () => {
                      uiPushUrl(this.getUIContext(), {
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

          // 底部加载提示
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

        // 顶部悬浮导航栏
        this.CustomNavBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    // 5. 兜底
    else {
      Column() {
        Text('暂无数据').fontSize(14).fontColor('#666666')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}
