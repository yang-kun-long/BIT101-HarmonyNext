import { User, UserRepository } from '../services/user/userRepository';
import { emptyFollowList, FollowListMode, FollowListModel, FollowListSnapshot } from '../services/user/FollowListModel';
import { isAuthedBit101 } from '../services/auth/authGuard';
import { observeUserRelations } from '../services/user/UserRelationEvents';
import { uiBack, uiGetParams, uiPushUrl, uiReplaceUrl, uiShowToast } from '../utils/uiContextBridge';

@Entry
@Component
struct FollowListPage {
  @State mode: FollowListMode = 'followings';
  @State state: FollowListSnapshot = emptyFollowList();
  private model: FollowListModel | null = null;
  private navigating: boolean = false;
  private needsRefresh: boolean = false;
  private stopObserving: () => void = () => {};

  aboutToAppear(): void {
    const params = uiGetParams(this.getUIContext()) as Record<string, Object>;
    this.mode = params?.['mode'] === 'followers' ? 'followers' : 'followings';
    this.model = new FollowListModel(new UserRepository(), this.mode, (state: FollowListSnapshot) => {
      this.state = state;
      if (state.requiresLogin) this.gotoLogin();
    });
    this.stopObserving = observeUserRelations(() => { this.needsRefresh = true; });
    this.start();
  }

  onPageShow(): void {
    if (this.needsRefresh) {
      this.needsRefresh = false;
      this.model?.refresh();
    }
  }

  aboutToDisappear(): void {
    this.stopObserving();
    this.model?.cancel();
  }

  private async start(): Promise<void> {
    try {
      if (!(await isAuthedBit101())) { await this.gotoLogin(); return; }
      await this.model?.refresh();
    } catch (_) {
      this.state = { users: [], loading: false, hasMore: true, error: '加载失败，请重试', requiresLogin: false };
    }
  }

  private async gotoLogin(): Promise<void> {
    if (this.navigating) return;
    this.navigating = true;
    try {
      await uiReplaceUrl(this.getUIContext(), {
        url: 'pages/LoginPage',
        params: { redirect: 'pages/FollowListPage', redirectParams: { mode: this.mode } },
      });
    } catch (_) {
      uiShowToast(this.getUIContext(), { message: '无法打开登录页，请重试' });
    } finally { this.navigating = false; }
  }

  private openUser(user: User): void {
    uiPushUrl(this.getUIContext(), { url: 'pages/UserDetailPage', params: { uid: user.id } })
      .catch(() => { uiShowToast(this.getUIContext(), { message: '无法打开用户主页，请重试' }); });
  }

  @Builder
  UserRow(user: User) {
    Row({ space: 12 }) {
      Image(user.avatar.low_url || user.avatar.url)
        .width(48).height(48).borderRadius(24).objectFit(ImageFit.Cover)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      Column({ space: 4 }) {
        Text(user.nickname).fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (user.identity?.text) {
          Text(user.identity.text).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        Text(`UID: ${user.id}`).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($r('app.media.ic_chevron_right')).width(20).height(20)
        .fillColor($r('sys.color.ohos_id_color_text_tertiary'))
    }.width('100%').padding(16).backgroundColor($r('sys.color.ohos_id_color_card_bg'))
    .onClick(() => { this.openUser(user); })
  }

  build() {
    Column() {
      Row({ space: 16 }) {
        Image($r('app.media.ic_chevron_left')).width(24).height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })
        Text(this.mode === 'followers' ? '我的粉丝' : '我的关注')
          .fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Button('刷新').enabled(!this.state.loading).onClick(() => { this.model?.refresh(); })
      }.height(56).width('100%').padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      List({ space: 1 }) {
        ForEach(this.state.users, (user: User) => {
          ListItem() { this.UserRow(user) }
        }, (user: User) => user.id.toString())
        ListItem() {
          Column({ space: 12 }) {
            if (this.state.loading) {
              LoadingProgress().width(28).height(28)
              Text('正在加载…').fontColor($r('sys.color.ohos_id_color_text_secondary'))
            } else if (this.state.error.length > 0) {
              Text(this.state.error).fontColor($r('sys.color.ohos_id_color_text_secondary'))
              Button('重试').onClick(() => {
                if (this.state.requiresLogin) this.gotoLogin();
                else this.model?.retry();
              })
            } else if (this.state.users.length === 0) {
              Text(this.mode === 'followers' ? '还没有粉丝' : '还没有关注任何人')
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            } else if (!this.state.hasMore) {
              Text('没有更多了').fontColor($r('sys.color.ohos_id_color_text_secondary'))
            } else {
              Button('加载更多').onClick(() => { this.model?.loadMore(); })
            }
          }.width('100%').padding(24)
        }
      }.layoutWeight(1).width('100%')
      .onReachEnd(() => {
        if (this.state.error.length === 0) this.model?.loadMore();
      })
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
