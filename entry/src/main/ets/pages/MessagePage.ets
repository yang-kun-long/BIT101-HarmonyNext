import { Message, MessageType, MESSAGE_TYPES, MESSAGE_LABELS, badgeText, messageTarget, messageAction } from '../services/message/MessageModels';
import { MessageRepository } from '../services/message/MessageRepository';
import { MessageListModel, MessageListSnapshot, emptyMessages } from '../services/message/MessageListModel';
import { unreadStore, UnreadSnapshot } from '../services/message/UnreadStore';
import { uiBack, uiPushUrl, uiReplaceUrl, uiShowToast } from '../utils/uiContextBridge';
interface MessageRouteParams { id?: number; uid?: number; }

@Entry
@Component
struct MessagePage {
  @State selected: number = 0;
  @State lists: MessageListSnapshot[] = [emptyMessages(), emptyMessages(), emptyMessages(), emptyMessages()];
  @State unread: UnreadSnapshot = unreadStore.snapshot();
  private models: MessageListModel[] = [];
  private stopObserving: () => void = () => {};
  private navigating: boolean = false;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.stopObserving = unreadStore.observe((state: UnreadSnapshot) => { this.unread = state; });
    const repository = new MessageRepository();
    this.models = MESSAGE_TYPES.map((type: MessageType, index: number) => new MessageListModel(repository, type,
      (state: MessageListSnapshot) => {
        this.lists[index] = state;
        if (state.requiresLogin) this.gotoLogin();
      }, () => { unreadStore.refresh(); }));
    unreadStore.refresh();
    this.models[0].ensureLoaded();
  }
  aboutToDisappear(): void {
    this.active = false; this.stopObserving();
    for (const model of this.models) model.cancel();
  }
  private async gotoLogin(): Promise<void> {
    if (this.navigating || !this.active) return;
    this.navigating = true;
    try {
      await uiReplaceUrl(this.getUIContext(), { url: 'pages/LoginPage', params: { redirect: 'pages/MessagePage' } });
    } catch (_) { uiShowToast(this.getUIContext(), { message: '请重新登录 BIT101' }); }
    finally { this.navigating = false; }
  }
  private openMessage(type: MessageType, item: Message): void {
    const target = messageTarget(type, item);
    if (!target) return;
    const params: MessageRouteParams = {};
    if (target.page === 'pages/UserDetailPage') params.uid = target.id; else params.id = target.id;
    uiPushUrl(this.getUIContext(), { url: target.page, params })
      .catch(() => { uiShowToast(this.getUIContext(), { message: '无法打开消息目标，请重试' }); });
  }
  @Builder
  MessageRow(type: MessageType, item: Message) {
    Row({ space: 12 }) {
      Image(item.from_user.avatar.low_url || item.from_user.avatar.url || $r('app.media.startIcon'))
        .width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover)
      Column({ space: 6 }) {
        Text(item.from_user.nickname || '系统通知').fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Text(messageAction(type, item.obj)).fontSize(13).fontColor($r('sys.color.ohos_id_color_text_primary_activated'))
        if (item.text.trim()) {
          Text(item.text).fontSize(14).maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        Text(item.update_time).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (messageTarget(type, item)) {
        Image($r('app.media.ic_chevron_right')).width(20).height(20).fillColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
    }.width('100%').padding(16).alignItems(VerticalAlign.Top)
    .onClick(() => { this.openMessage(type, item); })
  }
  @Builder
  MessageList(index: number) {
    List() {
      ForEach(this.lists[index].items, (item: Message) => {
        ListItem() { this.MessageRow(MESSAGE_TYPES[index], item) }
      }, (item: Message) => String(item.id))
      ListItem() {
        Column({ space: 12 }) {
          if (this.lists[index].loading) {
            LoadingProgress().width(28).height(28)
            Text('正在加载…').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          } else if (this.lists[index].error) {
            Button(this.lists[index].error).onClick(() => { this.models[index].retry(); })
          } else if (this.lists[index].loaded && this.lists[index].items.length === 0) {
            Text('暂无消息').fontColor($r('sys.color.ohos_id_color_text_secondary'))
          } else if (!this.lists[index].hasMore) {
            Text('没有更多消息了').fontSize(12).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          } else if (this.lists[index].items.length > 0) {
            Button('加载更多').onClick(() => { this.models[index].loadMore(); })
          }
        }.width('100%').padding(24)
      }
    }.width('100%').height('100%').alignListItem(ListItemAlign.Start)
    .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
    .onReachEnd(() => { if (!this.lists[index].error) this.models[index]?.loadMore(); })
  }
  build() {
    Column() {
      Row({ space: 16 }) {
        Button('返回').onClick(() => { uiBack(this.getUIContext()); })
        Text('消息').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Button('刷新').onClick(() => { this.models[this.selected]?.refresh(); unreadStore.refresh(); })
      }.width('100%').height(56).padding({ left: 12, right: 12 })
      if (this.unread.error) {
        Text(this.unread.error).fontSize(12).padding(8).width('100%')
          .fontColor($r('sys.color.ohos_id_color_warning')).onClick(() => { unreadStore.refresh(); })
      }
      Tabs({ index: this.selected }) {
        ForEach(MESSAGE_TYPES, (type: MessageType, index: number) => {
          TabContent() { this.MessageList(index) }
            .tabBar(MESSAGE_LABELS[index] + (badgeText(this.unread.counts[type]) ? ` ${badgeText(this.unread.counts[type])}` : ''))
        })
      }.layoutWeight(1).barMode(BarMode.Fixed)
      .onChange((index: number) => { this.selected = index; this.models[index]?.ensureLoaded(); })
    }.width('100%').height('100%').backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
