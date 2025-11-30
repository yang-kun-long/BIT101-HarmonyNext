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
  @State currentPage: number = 1;
  @State hasMore: boolean = true;
  @State isPostersLoading: boolean = false;

  // --- 🌟 滚动与导航栏状态 ---
  @State navOpacity: number = 0; // 导航栏背景透明度 (0.0 - 1.0)
  @State showSmallTitle: boolean = false; // 是否显示小标题(昵称)
  private scroller: Scroller = new Scroller(); // 列表滚动控制器

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
      promptAction.showToast({ message: '获取用户信息失败: ' + err.message });
    } finally {
      this.isLoading = false;
    }
  }

  async loadPosters(isLoadMore: boolean) {
    // 1. 防抖：正在加载中，直接退出
    if (this.isPostersLoading) return;

    // ✅ 核心修复：竞态条件保护
    // 如果是“加载更多”模式，但列表是空的，说明第一页还没加载完（或者没数据）。
    // 此时禁止触发加载更多，防止 onReachEnd 抢在初始化之前请求第 2 页。
    if (isLoadMore && this.posters.length === 0) {
      return;
    }

    // 2. 如果没有更多数据了，也退出
    if (isLoadMore && !this.hasMore) return;

    this.isPostersLoading = true;

    // 计算页码
    const pageToFetch = isLoadMore ? this.currentPage + 1 : 1;

    try {
      const posterRepo = new PosterRepository();
      // ... 以下代码保持不变 ...
      const newPosters = await posterRepo.getPostersOfUser(this.uid, pageToFetch);

      if (isLoadMore) {
        this.posters = [...this.posters, ...newPosters];
      } else {
        this.posters = newPosters;
      }

      // 只有成功获取到数据才更新页码
      if (newPosters.length > 0) {
        this.currentPage = pageToFetch;
      }

      // 判定是否还有更多 (BIT101 API 默认分页大小为 10)
      this.hasMore = newPosters.length >= 10;

    } catch (err) {
      console.error('加载帖子失败', err);
    } finally {
      this.isPostersLoading = false;
    }
  }

  // --- 逻辑区 ---
  private handleFollow() {
    promptAction.showToast({ message: '关注功能开发中...' });
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
          isPrimary: true,
          onAction: () => {
            promptAction.showToast({ message: "即将跳转我的主页..." });
          }
        })
      } else {
        UserInfoButton({
          text: this.getButtonText(),
          isPrimary: !this.userInfo.following,
          onAction: () => {
            this.handleFollow();
          }
        })
      }
    }
  }

  // --- 🌟 顶部导航栏 (仿 BasicTwoRowsTopAppBar 的折叠态) ---
  @Builder
  CustomNavBar() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 背景层 (白色，透明度随滚动变化)
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.White)
        .opacity(this.navOpacity) // 控制背景透明度
        .shadow(this.navOpacity > 0.8 ? { radius: 2, color: '#1a000000', offsetY: 1 } : undefined) // 只有完全显示时才有阴影

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

        // 小标题 (昵称) - 渐变显示
        if (this.uiUser) {
          Text(this.uiUser.nickname)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 16, right: 16 })
            .opacity(this.showSmallTitle ? 1 : 0) // 控制文字可见性
            .animation({ duration: 200 }) // 添加淡入淡出动画
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56) // 标准导航栏高度
  }

  // --- 🌟 用户信息大卡片 (仿 BasicTwoRowsTopAppBar 的展开态) ---
  @Builder
  UserInfoHeader() {
    if (this.userInfo && this.uiUser) {
      Column() {
        // 顶部留白，因为现在导航栏是悬浮的，防止内容被遮挡
        // 同时配合白色背景，模拟出 Android 的 Surface 效果

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
      .backgroundColor(Color.White) // 关键：白色背景，对应 Surface
      .padding({ top: 12 })
      // 去掉圆角，让它看起来更像是一个延伸下来的 App Bar
      // .borderRadius({ bottomLeft: 12, bottomRight: 12 })
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

      // 1. 底层内容列表
      List({ scroller: this.scroller }) {
        // 占位符：给悬浮导航栏留出初始高度 (56vp)
        // 这样初始状态下，UserInfoHeader 会在导航栏下方显示，而不是被压住
        // 如果想模仿安卓那种内容可以滚到透明栏底下的效果，可以把这个高度设为 0，然后在 UserInfoHeader 里加 padding
        ListItem() {
          Column().height(56).width('100%').backgroundColor(Color.White)
        }

        // 大标题区域 (用户信息)
        ListItem() {
          this.UserInfoHeader()
        }

        // 帖子列表
        if (this.posters.length > 0) {
          ForEach(this.posters, (item: Poster) => {
            ListItem() {
              Column() {
                // 加一个间隔条，区分用户信息和帖子，以及帖子之间
                if (item === this.posters[0]) {
                  Divider().color($r('sys.color.ohos_id_color_sub_background')).height(8).width('100%')
                }

                PosterCard({
                  poster: item,
                  onClickPoster: () => {
                    router.pushUrl({
                      url: 'pages/PosterDetailPage',
                      params: { id: item.id }
                    });
                  }
                })
                Divider().color($r('sys.color.ohos_id_color_sub_background')).height(8).width('100%')
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
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadPosters(true);
      })
      // 🌟 核心：监听滚动，计算渐变效果
      .onScroll(() => {
        const yOffset = this.scroller.currentOffset().yOffset;

        // 设定渐变阈值：比如滚动 100vp 后完全变白
        const threshold = 100;

        // 计算透明度 0 ~ 1
        let opacity = 0;
        if (yOffset > 0) {
          opacity = Math.min(yOffset / threshold, 1);
        }

        this.navOpacity = opacity;

        // 当透明度超过 0.8 时，显示小标题
        this.showSmallTitle = opacity > 0.8;
      })

      // 2. 顶层悬浮导航栏
      this.CustomNavBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}