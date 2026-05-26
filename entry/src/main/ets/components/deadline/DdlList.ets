import { DdlDetailDialog } from './DdlDetailDialog';
import { DdlCard } from './DdlCard';
import { Logger } from '../../utils/Logger';
import { uiPushUrl, uiShowToast } from '../../utils/uiContextBridge';
import { DdlStore } from '../../services/storage/DdlStore';
import { LexueCalendarStore } from '../../services/storage/LexueCalendarStore';
import type { DdlItem, ManualDdlInput } from '../../services/deadline/DdlModels';
import { refreshDdlSubscribeUrl, syncDdlFromLexue } from '../../services/deadline/DdlSyncService';
import {
  applyDdlDisplaySettingsToAppStorage,
  DDL_APP_RETENTION_DAYS,
  DDL_APP_WARNING_DAYS,
  DdlSettingsStore,
} from '../../services/storage/DdlSettingsStore';
import {
  DDL_FAB_BOTTOM_PADDING_VP,
  DDL_FAB_RIGHT_PADDING_VP,
  DdlContentState,
  DdlFabSpec,
  getDdlEmptyText,
  getDdlFabSpecs,
  resolveDdlContentState,
} from './ddlListModel';

@Component
export default struct DdlList {
  @State private ddlList: DdlItem[] = [];
  @State private loading: boolean = true;
  @State private showEditor: boolean = false;
  @State private editingItem: DdlItem | null = null;
  @State private nowMs: number = Date.now();
  @State private hasSubscribeUrl: boolean = true;
  @State private isFetchingLexue: boolean = false;
  @StorageProp(DDL_APP_WARNING_DAYS) warningDays: number = 7;
  @StorageProp(DDL_APP_RETENTION_DAYS) @Watch('onRetentionDaysChanged') retentionDays: number = 3;
  @StorageProp('current_username') currentUsername: string = '';
  private logger = new Logger('DdlList');

  // 弹框相关状态
  @State private showDetail: boolean = false;
  @State private currentEvent: DdlItem | null = null;

  private store: DdlStore = new DdlStore();
  private settingsStore: DdlSettingsStore = new DdlSettingsStore();
  private calendarStore: LexueCalendarStore = new LexueCalendarStore();

  aboutToAppear(): void {
    this.loadSettingsAndDdl().catch((err: Error) => {
      this.logger.error('loadDdl failed', err);
    });
  }

  private async loadSettingsAndDdl(): Promise<void> {
    try {
      const settings = await this.settingsStore.load();
      applyDdlDisplaySettingsToAppStorage(settings);
      this.warningDays = settings.warningDays;
      this.retentionDays = settings.retentionDays;
    } catch (err) {
      this.logger.error('load DDL settings failed', err);
    }
    await this.loadSubscribeState();
    await this.loadDdl();
  }

  private onRetentionDaysChanged(): void {
    this.loadDdl().catch((err: Error) => {
      this.logger.error('reload DDL after retention setting changed failed', err);
    });
  }

  private async loadDdl(): Promise<void> {
    this.loading = true;
    try {
      this.nowMs = Date.now();
      const allEvents: DdlItem[] = await this.store.getVisibleItems(this.nowMs, this.retentionDays);

      this.ddlList = allEvents;
      this.logger.debug('loadDdl done, count=', this.ddlList.length);
    } catch (err) {
      this.logger.error('loadDdl error', err);
      this.ddlList = [];
    } finally {
      this.loading = false;
    }
  }

  private async loadSubscribeState(): Promise<void> {
    try {
      this.hasSubscribeUrl = await this.calendarStore.hasAnyCachedSubscribeUrl();
    } catch (err) {
      this.logger.warn('load subscribe URL cache state failed', err);
      this.hasSubscribeUrl = true;
    }
  }

  private contentState(): DdlContentState {
    return resolveDdlContentState(this.loading, this.hasSubscribeUrl, this.ddlList.length);
  }

  // ---------- 与详情页一致的一些格式化 ----------

  private formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: string = d.getHours().toString().padStart(2, '0');
    const minute: string = d.getMinutes().toString().padStart(2, '0');
    return `${m}/${day} ${hour}:${minute}`;
  }

  private timeText(ev: DdlItem): string {
    const start: string = this.formatTime(ev.startTime);
    if (!ev.endTime || ev.endTime === ev.startTime) {
      return `截止：${start}`;
    }
    const end: string = this.formatTime(ev.endTime);
    return `${start} - ${end}`;
  }

  private prettyTitle(ev: DdlItem): string {
    let raw: string = ev.title ?? '(未命名 DDL)';
    raw = raw.replace(/\s*已到期\s*$/u, '');
    return raw;
  }

  // 直接用解析时存好的 courseName，不再从标题里瞎猜
  private courseName(ev: DdlItem): string {
    return (ev.courseName ?? '').trim();
  }

  private ddlTypeTag(ev: DdlItem): string {
    const text: string = (ev.title ?? '').toLowerCase();
    if (text.includes('实验') || text.includes('lab')) return '实验';
    if (
      text.includes('作业') ||
      text.includes('assignment') ||
      text.includes('homework')
    ) {
      return '作业';
    }
    if (text.includes('测验') || text.includes('quiz')) return '测验';
    if (text.includes('考试') || text.includes('exam')) return '考试';
    return 'DDL';
  }

  private getDescriptionText(ev: DdlItem): string {
    if (!ev.description) {
      return '';
    }
    let text: string = ev.description as string;
    text = text.replace(/\\n/g, '\n');
    text = text.replace(/[ \u00A0\t]*\n[ \u00A0\t]*/g, '\n');
    text = text.replace(/\n{3,}/g, '\n\n');
    return text.trim();
  }

  private stripBullet(line: string): string {
    const trimmed: string = line.trim();
    if (trimmed.startsWith('•') || trimmed.startsWith('·')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  // 列表里用的一行摘要：找第一行非空内容，截断到 N 个字符
  private summaryText(ev: DdlItem): string {
    const t: string = this.getDescriptionText(ev);
    if (t.length === 0) {
      return '';
    }
    const lines: string[] = t.split('\n');
    let first: string = '';
    for (let i = 0; i < lines.length; i++) {
      const s: string = this.stripBullet(lines[i]);
      if (s.length > 0) {
        first = s;
        break;
      }
    }
    if (first.length === 0) {
      return '';
    }
    const limit: number = 40;
    if (first.length > limit) {
      return first.substring(0, limit) + '…';
    }
    return first;
  }

  private getEventColor(event: DdlItem): string {
    const text: string = (event.title ?? '').toLowerCase();
    if (text.includes('考试') || text.includes('exam')) {
      return '#F97373';
    }
    if (text.includes('实验') || text.includes('lab')) {
      return '#60A5FA';
    }
    if (text.includes('测验') || text.includes('quiz')) {
      return '#FBBF24';
    }
    return '#34D399';
  }

  // ---------- 点击 / 弹框 ----------

  private onItemClick(event: DdlItem): void {
    this.logger.debug('onItemClick, uid=', event.uid);
    this.openDetail(event);
  }

  private openDetail(event: DdlItem): void {
    this.logger.debug('openDetail, uid=', event.uid);
    this.currentEvent = event;
    this.showDetail = true;
    this.logger.debug(
      'after openDetail, showDetail=',
      this.showDetail,
      ', currentTitle=',
      this.currentEvent?.title ?? 'null'
    );
  }

  private onDialogClose(): void {
    this.logger.debug('dialog onClose');
    this.showDetail = false;
    this.currentEvent = null;
  }

  private async setDone(uid: string, done: boolean): Promise<void> {
    await this.store.setDone(uid, done);
    await this.loadDdl();
  }

  private async deleteItem(uid: string): Promise<void> {
    await this.store.delete(uid);
    await this.loadDdl();
    uiShowToast(this.getUIContext(), { message: '删除成功OvO' });
  }

  private async addManualDdl(input: ManualDdlInput): Promise<void> {
    await this.store.addManual(input);
    this.showEditor = false;
    this.editingItem = null;
    await this.loadDdl();
    uiShowToast(this.getUIContext(), { message: '已新增 DDL' });
  }

  private async updateManualDdl(uid: string, input: ManualDdlInput): Promise<void> {
    await this.store.updateManual(uid, input);
    this.showEditor = false;
    this.editingItem = null;
    await this.loadDdl();
    uiShowToast(this.getUIContext(), { message: '已保存' });
  }

  private openCreateEditor(): void {
    this.editingItem = null;
    this.showEditor = true;
  }

  private openEditEditor(item: DdlItem): void {
    this.editingItem = item;
    this.showDetail = false;
    this.currentEvent = null;
    this.showEditor = true;
  }

  private fetchLexueCalendar(): void {
    if (this.isFetchingLexue) {
      return;
    }
    this.isFetchingLexue = true;
    uiShowToast(this.getUIContext(), { message: '正在获取乐学日程...' });
    refreshDdlSubscribeUrl(this.currentUsername)
      .then(() => {
        this.hasSubscribeUrl = true;
        return syncDdlFromLexue(this.currentUsername);
      })
      .then((count: number) => {
        uiShowToast(this.getUIContext(), { message: `同步成功，更新了 ${count} 条 DDL` });
        return this.loadDdl();
      })
      .catch((err: Error) => {
        this.logger.error('fetch Lexue DDL failed', err);
        let message: string = '获取失败';
        if (err.message.includes('redirects hit maximum')) {
          message = '获取失败：登录状态失效，请重新登录';
        } else if (err.message.length > 0) {
          message = '获取失败：' + err.message;
        }
        uiShowToast(this.getUIContext(), { message });
      })
      .finally(() => {
        this.isFetchingLexue = false;
      });
  }

  // ---------- UI ----------

  @Builder
  private FloatingButtons() {
    Column({ space: 10 }) {
      ForEach(getDdlFabSpecs(), (spec: DdlFabSpec) => {
        this.Fab(spec)
      }, (spec: DdlFabSpec): string => spec.action)
    }
    .padding({ right: DDL_FAB_RIGHT_PADDING_VP, bottom: DDL_FAB_BOTTOM_PADDING_VP })
  }

  @Builder
  private Fab(spec: DdlFabSpec) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (spec.action === 'add') {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(spec.iconVp)
          .fontColor(['#0A59F7'])
      } else {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(spec.iconVp)
          .fontColor(['#0A59F7'])
      }
    }
    .width(spec.sizeVp)
    .height(spec.sizeVp)
    .backgroundColor('#DDEBFF')
    .onClick(() => {
      if (spec.action === 'add') {
        this.openCreateEditor();
        return;
      }
      uiPushUrl(this.getUIContext(), { url: 'pages/settings/DDLSettingPage' }).catch((err: Error) => {
        this.logger.error('open DDL settings failed', err);
        uiShowToast(this.getUIContext(), { message: '打开 DDL 设置失败' });
      });
    })
  }

  @Builder
  private FetchLexueEntry() {
    Column() {
      Button() {
        Row({ space: 8 }) {
          if (this.isFetchingLexue) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(Color.White)
          }
          Text(this.isFetchingLexue ? '获取中...' : '获取乐学日程')
            .fontSize(16)
            .fontColor(Color.White)
        }
        .alignItems(VerticalAlign.Center)
      }
      .type(ButtonType.Capsule)
      .enabled(!this.isFetchingLexue)
      .height(44)
      .padding({ left: 18, right: 18 })
      .backgroundColor('#2563EB')
      .onClick(() => this.fetchLexueCalendar())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // 底层内容
      Column() {
        // 顶部标题
        Row() {
          Text('DDL')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')
        .margin({ top: 0, bottom: 8 })

        if (this.contentState() === 'loading') {
          Column() {
            Text('加载中…')
              .fontSize(14)
              .fontColor('#9CA3AF')
              .margin({ top: 24 })
          }
          .width('100%')
          .layoutWeight(1)
        } else if (this.contentState() === 'fetch-lexue') {
          this.FetchLexueEntry()
        } else if (this.contentState() === 'empty') {
          Column() {
            Text(getDdlEmptyText())
              .fontSize(14)
              .fontColor('#9CA3AF')
              .margin({ top: 24 })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Column() {
            List() {
              ForEach(
                this.ddlList,
                (item: DdlItem) => {
                  ListItem() {
                    Row({ space: 8 }) {
                      Toggle({ type: ToggleType.Checkbox, isOn: item.done })
                        .onChange((checked: boolean) => {
                          this.setDone(item.uid, checked).catch((err: Error) => {
                            this.logger.error('setDone failed', err);
                          });
                        })

                      DdlCard({
                        event: item,
                        warningDays: this.warningDays,
                        nowMs: this.nowMs,
                        onTap: () => this.onItemClick(item)
                      })
                        .layoutWeight(1)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('100%')
                  .margin({ top: 4, bottom: 4 })
                },
                (item: DdlItem): string => item.uid
              )

              ListItem() {
                Row() {
                  Blank()
                    .height(124)
                }
              }
            }
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .padding({ left: 10, right: 10, top: 0, bottom: 0 })
      .width('100%')
      .height('100%')
      .backgroundColor('#F3F4F6')

      this.FloatingButtons()

      // 顶层：详情弹框（只在需要时挂载）
      if (this.showDetail && this.currentEvent) {
        DdlDetailDialog({
          ev: this.currentEvent,
          onClose: () => this.onDialogClose(),
          onDelete: (uid: string) => {
            this.deleteItem(uid).catch((err: Error) => {
              this.logger.error('deleteItem failed', err);
            });
          },
          onEdit: (item: DdlItem) => {
            this.openEditEditor(item);
          },
          onToggleDone: (uid: string, done: boolean) => {
            this.setDone(uid, done).catch((err: Error) => {
              this.logger.error('setDone from detail failed', err);
            });
          }
        })
      }

      if (this.showEditor) {
        DdlEditOverlay({
          editItem: this.editingItem,
          onCancel: () => {
            this.showEditor = false;
            this.editingItem = null;
          },
          onConfirm: (input: ManualDdlInput) => {
            if (this.editingItem) {
              this.updateManualDdl(this.editingItem.uid, input).catch((err: Error) => {
                this.logger.error('updateManualDdl failed', err);
                uiShowToast(this.getUIContext(), { message: '保存失败' });
              });
            } else {
              this.addManualDdl(input).catch((err: Error) => {
                this.logger.error('addManualDdl failed', err);
                uiShowToast(this.getUIContext(), { message: '新增失败' });
              });
            }
          }
        })
      }
    }
  }
}

@Component
struct DdlEditOverlay {
  @Prop editItem: DdlItem | null = null;
  onCancel: () => void = () => {};
  onConfirm: (input: ManualDdlInput) => void = () => {};

  @State private title: string = '';
  @State private courseName: string = '';
  @State private timeText: string = '';
  @State private description: string = '';
  @State private location: string = '';
  @State private errorText: string = '';

  aboutToAppear(): void {
    if (this.editItem) {
      this.title = this.editItem.title;
      this.courseName = this.editItem.courseName;
      this.timeText = this.formatDeadline(this.editItem.endTime > 0 ? this.editItem.endTime : this.editItem.startTime);
      this.description = this.editItem.description;
      this.location = this.editItem.location;
    } else if (this.timeText.length === 0) {
      const d = new Date(Date.now() + 24 * 60 * 60 * 1000);
      this.timeText = this.formatDeadline(new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 0).getTime());
    }
  }

  private formatDeadline(ts: number): string {
    const d = new Date(ts);
    const y = d.getFullYear().toString();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const h = d.getHours().toString().padStart(2, '0');
    const min = d.getMinutes().toString().padStart(2, '0');
    return `${y}-${m}-${day} ${h}:${min}`;
  }

  private parseDeadline(text: string): number {
    const matched = /^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/.exec(text.trim());
    if (!matched) {
      return 0;
    }
    const year = Number(matched[1]);
    const month = Number(matched[2]) - 1;
    const day = Number(matched[3]);
    const hour = Number(matched[4]);
    const minute = Number(matched[5]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day) ||
      !Number.isFinite(hour) || !Number.isFinite(minute)) {
      return 0;
    }
    if (month < 0 || month > 11 || day < 1 || day > 31 || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return 0;
    }
    return new Date(year, month, day, hour, minute, 0).getTime();
  }

  private submit(): void {
    const title = this.title.trim();
    if (title.length === 0) {
      this.errorText = '标题不能为空';
      return;
    }
    const deadline = this.parseDeadline(this.timeText);
    if (deadline <= 0) {
      this.errorText = '时间格式应为 YYYY-MM-DD HH:mm';
      return;
    }
    this.onConfirm({
      title,
      courseName: this.courseName,
      time: deadline,
      description: this.description,
      location: this.location,
    });
  }

  build() {
    Stack() {
      Row() { }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.25)')
      .onClick(() => this.onCancel())

      Column({ space: 10 }) {
        Text(this.editItem ? '编辑 DDL' : '新增 DDL')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        TextInput({ placeholder: '标题', text: this.title })
          .height(44)
          .onChange((value: string) => {
            this.title = value;
            this.errorText = '';
          })

        TextInput({ placeholder: '课程名，可选', text: this.courseName })
          .height(44)
          .onChange((value: string) => {
            this.courseName = value;
          })

        TextInput({ placeholder: 'YYYY-MM-DD HH:mm', text: this.timeText })
          .height(44)
          .onChange((value: string) => {
            this.timeText = value;
            this.errorText = '';
          })

        TextInput({ placeholder: '地点，可选', text: this.location })
          .height(44)
          .onChange((value: string) => {
            this.location = value;
          })

        TextInput({ placeholder: '备注，可选', text: this.description })
          .height(44)
          .onChange((value: string) => {
            this.description = value;
          })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor('#EF4444')
            .width('100%')
        }

        Row({ space: 10 }) {
          Button('取消')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .onClick(() => this.onCancel())

          Button('保存')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .backgroundColor('#10B981')
            .fontColor(Color.White)
            .onClick(() => this.submit())
        }
        .width('100%')
      }
      .padding(16)
      .width('86%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .align(Alignment.Center)
    }
    .width('100%')
    .height('100%')
  }
}
