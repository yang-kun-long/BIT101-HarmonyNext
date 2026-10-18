import { getGallerySettingsStore } from '../services/storage/GallerySettingsStore';
import { Logger } from '../utils/Logger';
// entry/src/main/ets/pages/UserDetailPage.ets
import { UserRepository, UserInfoResponse } from '../services/user/userRepository';
import { PosterRepository } from '../services/gallery/PosterRepository';
import { filterUserPosters } from '../services/gallery/GalleryFilter';
import { FilteredPager, FilteredPageSnapshot } from '../services/gallery/FilteredPager';
import { GalleryUser, Poster } from '../services/gallery/GalleryModels';
import { AvatarWithName, FollowInfo, UserInfoButton } from '../components/user/UserInfoComponents';
import { PosterCard } from '../components/gallery/PosterCard';
import { uiBack, uiGetParams, uiPushUrl, uiReplaceUrl, uiShowToast } from '../utils/uiContextBridge';
import { isAuthedBit101 } from '../services/auth/authGuard';

@Entry
@Component
struct UserDetailPage {
  private logger: Logger = new Logger('UserDetailPage');
  @State hidden: boolean = false;
  @State hidingBusy: boolean = false;
  private unsubscribeSettings: (() => void) | null = null;
  @State uid: number = -1;
  @State isLoading: boolean = true;
  @State userInfo: UserInfoResponse | null = null;
  @State uiUser: GalleryUser | null = null;
  @State posters: Poster[] = [];

  // 分页状态
  @State hasMore: boolean = true;
  @State postersError: string = '';
  @State isPostersLoading: boolean = false;
  @State followingBusy: boolean = false;
  private posterRepo: PosterRepository = new PosterRepository();
  private postersPager: FilteredPager<Poster> = new FilteredPager<Poster>(
    (page: number) => {
      if (getGallerySettingsStore().snapshot().hiddenUids.includes(String(this.uid))) {
        return Promise.resolve<Poster[]>([]);
      }
      const requestUid = this.userInfo && this.userInfo.own ? 0 : this.uid;
      return this.posterRepo.getPostersOfUser(requestUid, page);
    },
    (items: Poster[]) => filterUserPosters(items, getGallerySettingsStore().snapshot()),
    (item: Poster) => item.id, (state: FilteredPageSnapshot<Poster>) => {
      this.posters = filterUserPosters(state.items, getGallerySettingsStore().snapshot());
      this.isPostersLoading = state.loading;
      this.hasMore = state.hasMore;
      this.postersError = state.error;
    });

  // --- 🌟 滚动与导航栏状态 ---
  @State navOpacity: number = 0; // 导航栏背景透明度 (0.0 - 1.0)
  @State showSmallTitle: boolean = false; // 是否显示小标题
  private scroller: Scroller = new Scroller();

  aboutToDisappear(): void {
    if (this.unsubscribeSettings) this.unsubscribeSettings();
    this.unsubscribeSettings = null;
    this.postersPager.cancel();
  }
  onPageShow(): void {
    const settings = getGallerySettingsStore().snapshot();
    this.hidden = settings.hiddenUids.includes(String(this.uid));
    this.posters = filterUserPosters(this.posters, settings);
    if (this.uiUser) {
      this.loadPosters(false);
    }
  }
  private async toggleHidden(): Promise<void> {
    if (this.hidingBusy || this.uid <= 0) return;
    this.hidingBusy = true;
    const next = getGallerySettingsStore().snapshot();
    next.hiddenUids = this.hidden ? next.hiddenUids.filter(id => id !== String(this.uid))
      : next.hiddenUids.concat(String(this.uid));
    try {
      await getGallerySettingsStore().save(next);
      this.hidden = getGallerySettingsStore().snapshot().hiddenUids.includes(String(this.uid));
      uiShowToast(this.getUIContext(), { message: this.hidden ? '已隐藏该用户，关注流仍保留' : '已取消隐藏' });
    } catch (_) { uiShowToast(this.getUIContext(), { message: '隐藏设置未保存，请重试' }); }
    finally { this.hidingBusy = false; }
  }

  aboutToAppear() {
    this.unsubscribeSettings = getGallerySettingsStore().subscribe(() => { this.onPageShow(); });
    const params = uiGetParams(this.getUIContext()) as Record<string, Object>;
    if (params && params['uid']) {
      this.uid = params['uid'] as number;
      this.onPageShow();
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
        uiReplaceUrl(this.getUIContext(), {
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
      uiShowToast(this.getUIContext(), { message: '获取用户信息失败: ' + (err as Error).message });
    } finally {
      this.isLoading = false;
    }
  }


  async loadPosters(isLoadMore: boolean) {
    if (!this.uiUser) return;
    if (isLoadMore) {
      if (!this.postersError) await this.postersPager.loadMore();
    } else {
      await this.postersPager.refresh();
    }
  }

  // --- 逻辑区 ---

  // 🔥 [核心修改] 真实的关注逻辑
  private async handleFollow() {
    if (!this.userInfo || !this.uiUser || this.followingBusy) return;
    this.followingBusy = true;

    const userRepo = new UserRepository();

    try {
      if (!(await isAuthedBit101())) {
        await uiPushUrl(this.getUIContext(), { url: 'pages/LoginPage', params: {
          redirect: 'pages/UserDetailPage', redirectParams: { uid: this.uid },
        } });
        return;
      }
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

        uiShowToast(this.getUIContext(), {
          message: result.following ? '关注成功' : '已取消关注',
          duration: 1500
        });

      } else {
        uiShowToast(this.getUIContext(), { message: '操作失败，请重试' });
      }
    } catch (e) {
      uiShowToast(this.getUIContext(), { message: '网络错误，请检查连接' });
    } finally {
      this.followingBusy = false;
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
            uiShowToast(this.getUIContext(), { message: "即将跳转我的主页..." });
          }
        })
      } else {
        // ✅ 这里的绑定是正确的，点击触发上面的 handleFollow
        UserInfoButton({
          text: this.getButtonText(),
          enable: !this.followingBusy,
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
        .backgroundColor($r('sys.color.ohos_id_color_background'))
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
          uiBack(this.getUIContext());
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
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4, bottom: 16 })
        }

        if (!this.userInfo.own && this.uid > 0) {
          Button(this.hidden ? '取消隐藏此用户' : '隐藏此用户').enabled(!this.hidingBusy)
            .margin({ bottom: 12 }).onClick(() => { this.toggleHidden(); })
        }

        FollowInfo({
          followerNum: this.userInfo.follower_num,
          followingNum: this.userInfo.following_num
        })
          .margin({ bottom: 16 })
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .padding({ top: 56 + 12 })
    }
  }

  @Builder
  FooterLoading() {
    Row() {
      if (this.isPostersLoading) {
        LoadingProgress().width(20).height(20).margin({ right: 8 })
        Text("正在加载...").fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary'))
      } else if (this.postersError) {
        Text(this.postersError).fontSize(14).onClick(() => { this.postersPager.retry(); })
      } else if (!this.hasMore && this.posters.length > 0) {
        Text("没有更多了 -").fontSize(12).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
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
        } else if (!this.isPostersLoading && !this.postersError) {
          ListItem() {
            Text("暂无动态")
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(40)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
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
