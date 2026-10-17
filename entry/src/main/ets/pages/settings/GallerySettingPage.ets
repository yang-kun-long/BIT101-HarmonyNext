import { GallerySettings, defaultGallerySettings, getGallerySettingsStore } from '../../services/storage/GallerySettingsStore';
import { uiBack, uiPushUrl, uiShowToast } from '../../utils/uiContextBridge';

@Entry
@Component
struct GallerySettingPage {
  @State settings: GallerySettings = defaultGallerySettings();
  @State saving: boolean = false;

  aboutToAppear(): void { this.settings = getGallerySettingsStore().snapshot(); }

  onPageShow(): void { this.settings = getGallerySettingsStore().snapshot(); }

  private async save(next: GallerySettings): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    try { await getGallerySettingsStore().save(next); }
    catch (_) { uiShowToast(this.getUIContext(), { message: '话廊设置未保存，请重试' }); }
    finally { this.settings = getGallerySettingsStore().snapshot(); this.saving = false; }
  }

  private change(field: string, enabled: boolean): void {
    const next = getGallerySettingsStore().snapshot();
    if (field === 'bot') next.hideBot = enabled;
    if (field === 'search') next.hideBotInSearch = enabled;
    if (field === 'anonymous') next.hideAnonymous = enabled;
    if (field === 'strict') next.strict = enabled;
    if (field === 'scroll') next.allowHorizontalScroll = enabled;
    this.save(next);
  }

  @Builder
  SettingRow(title: string, description: string, field: string, selected: boolean) {
    Row({ space: 16 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontColor($r('sys.color.font_primary'))
        Text(description).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: selected }).enabled(!this.saving)
        .onChange((value: boolean) => { this.change(field, value); })
    }.padding(16).width('100%').backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => { uiBack(this.getUIContext()); })
        Text('话廊设置').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
      }.height(56).width('100%').padding({ left: 16 })
      List({ space: 1 }) {
        ListItem() { this.SettingRow('隐藏机器人帖子', '应用于推荐、最新和最热', 'bot', this.settings.hideBot) }
        ListItem() { this.SettingRow('搜索时隐藏机器人', '同时开启“隐藏机器人帖子”时生效', 'search', this.settings.hideBotInSearch) }
        ListItem() { this.SettingRow('隐藏匿名帖子', '应用于推荐、最新、最热和搜索，关注流保留', 'anonymous', this.settings.hideAnonymous) }
        ListItem() { this.SettingRow('严格屏蔽评论', '同时隐藏其他人对已隐藏用户的回复', 'strict', this.settings.strict) }
        ListItem() { this.SettingRow('允许横向滑动', '关闭后仍可点击话廊顶部标签切换', 'scroll', this.settings.allowHorizontalScroll) }
        ListItem() {
          Text('已隐藏用户（' + this.settings.hiddenUids.length + '）')
            .fontSize(16).fontWeight(FontWeight.Medium).padding(16)
        }
        if (this.settings.hiddenUids.length === 0) {
          ListItem() { Text('可在用户主页隐藏用户').fontColor($r('sys.color.font_secondary')).padding(16) }
        }
        ForEach(this.settings.hiddenUids, (uid: string) => {
          ListItem() {
            Row() {
              Text('UID ' + uid).layoutWeight(1).onClick(() => {
                uiPushUrl(this.getUIContext(), { url: 'pages/UserDetailPage', params: { uid: Number(uid) } });
              })
              Button('取消隐藏').enabled(!this.saving).onClick(() => {
                const next = getGallerySettingsStore().snapshot();
                next.hiddenUids = next.hiddenUids.filter(id => id !== uid);
                this.save(next);
              })
            }.padding(16).width('100%').backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          }
        }, (uid: string) => uid)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
