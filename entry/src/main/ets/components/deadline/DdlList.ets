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
  DdlEditDialogModel,
  DdlEditValidationResult,
  DdlFabSpec,
  DdlFetchLexueCtaModel,
  buildDdlEditDialogModel,
  formatDdlDatePickerValue,
  formatDdlTimePickerValue,
  getDdlEmptyLayoutSpec,
  getDdlEmptyText,
  getDdlFetchLexueCtaModel,
  getDdlFetchLexueToastPolicy,
  getDdlFabSpecs,
  resolveDdlContentState,
  shouldAutoSyncDdlOnAppear,
  validateDdlEditInput,
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
    this.autoSyncDdlFromLexue();
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
    uiShowToast(this.getUIContext(), { message: buildDdlEditDialogModel(null).addSuccessToast });
  }

  private async updateManualDdl(uid: string, input: ManualDdlInput): Promise<void> {
    await this.store.updateManual(uid, input);
    this.showEditor = false;
    this.editingItem = null;
    await this.loadDdl();
    uiShowToast(this.getUIContext(), { message: buildDdlEditDialogModel(null).editSuccessToast });
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
    const toastPolicy = getDdlFetchLexueToastPolicy();
    if (toastPolicy.showStartToast) {
      uiShowToast(this.getUIContext(), { message: '正在获取乐学日程...' });
    }
    refreshDdlSubscribeUrl(this.currentUsername)
      .then(() => {
        this.hasSubscribeUrl = true;
        return syncDdlFromLexue(this.currentUsername);
      })
      .then((count: number) => {
        if (toastPolicy.showSuccessToast) {
          uiShowToast(this.getUIContext(), { message: `同步成功，更新了 ${count} 条 DDL` });
        }
        return this.loadDdl();
      })
      .catch((err: Error) => {
        this.logger.error('fetch Lexue DDL failed', err);
        if (!toastPolicy.showFailureToast) {
          return;
        }
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

  private autoSyncDdlFromLexue(): void {
    if (!shouldAutoSyncDdlOnAppear(this.hasSubscribeUrl, this.loading, this.isFetchingLexue)) {
      return;
    }
    this.isFetchingLexue = true;
    syncDdlFromLexue(this.currentUsername)
      .then((_count: number) => {
        return this.loadDdl();
      })
      .catch((err: Error) => {
        this.logger.error('auto sync Lexue DDL failed', err);
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
  private EmptyState() {
    Column() {
      Text(getDdlEmptyText())
        .fontSize(14)
        .fontColor('#4B5563')
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({
          left: getDdlEmptyLayoutSpec().horizontalInnerPaddingVp,
          right: getDdlEmptyLayoutSpec().horizontalInnerPaddingVp,
          top: getDdlEmptyLayoutSpec().verticalInnerPaddingVp,
          bottom: getDdlEmptyLayoutSpec().verticalInnerPaddingVp,
        })
        .backgroundColor('#E5E7EB')
        .borderRadius(getDdlEmptyLayoutSpec().cornerRadiusVp)
    }
    .width('100%')
    .padding({
      left: getDdlEmptyLayoutSpec().horizontalOuterPaddingVp,
      right: getDdlEmptyLayoutSpec().horizontalOuterPaddingVp,
      top: getDdlEmptyLayoutSpec().verticalOuterPaddingVp,
      bottom: getDdlEmptyLayoutSpec().verticalOuterPaddingVp,
    })
  }

  @Builder
  private FetchLexueEntry() {
    Column() {
      Button() {
        Row({ space: 8 }) {
          if (this.fetchLexueCtaModel().showSpinner) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(Color.White)
          }
          if (this.fetchLexueCtaModel().text.length > 0) {
            Text(this.fetchLexueCtaModel().text)
              .fontSize(16)
              .fontColor(Color.White)
          }
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

  private fetchLexueCtaModel(): DdlFetchLexueCtaModel {
    return getDdlFetchLexueCtaModel(this.isFetchingLexue);
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
            this.EmptyState()
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
                    DdlCard({
                      event: item,
                      warningDays: this.warningDays,
                      nowMs: this.nowMs,
                      onTap: () => this.onItemClick(item),
                      onDoneChange: (checked: boolean) => {
                        this.setDone(item.uid, checked).catch((err: Error) => {
                          this.logger.error('setDone failed', err);
                        });
                      }
                    })
                      .width('100%')
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
  @State private dateText: string = '';
  @State private timeText: string = '';
  @State private description: string = '';
  @State private errorText: string = '';
  @State private pickerMode: 'none' | 'date' | 'time' = 'none';
  @State private pendingDate: Date = new Date();
  @State private pendingTimeHour: number = 0;
  @State private pendingTimeMinute: number = 0;
  @State private pendingTimeSecond: number = 0;

  aboutToAppear(): void {
    const model: DdlEditDialogModel = buildDdlEditDialogModel(this.editItem);
    this.title = model.initialTitle;
    this.dateText = model.initialDateText;
    this.timeText = model.initialTimeText;
    this.description = model.initialDetail;
    if (!this.editItem) {
      this.errorText = '';
    }
  }

  private parseDeadline(dateText: string, timeText: string): number {
    const dateMatched = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateText.trim());
    const timeMatched = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(timeText.trim());
    if (!dateMatched || !timeMatched) {
      return 0;
    }
    const year = Number(dateMatched[1]);
    const month = Number(dateMatched[2]) - 1;
    const day = Number(dateMatched[3]);
    const hour = Number(timeMatched[1]);
    const minute = Number(timeMatched[2]);
    const second = timeMatched[3] ? Number(timeMatched[3]) : 0;
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day) ||
      !Number.isFinite(hour) || !Number.isFinite(minute) || !Number.isFinite(second)) {
      return 0;
    }
    if (month < 0 || month > 11 || day < 1 || day > 31 || hour < 0 || hour > 23 ||
      minute < 0 || minute > 59 || second < 0 || second > 59) {
      return 0;
    }
    return new Date(year, month, day, hour, minute, second).getTime();
  }

  private formatDateText(value: Date): string {
    return formatDdlDatePickerValue(value);
  }

  private fallbackPickerDate(): Date {
    const parsed = this.parseDeadline(
      this.dateText.length > 0 ? this.dateText : this.formatDateText(new Date()),
      this.timeText.length > 0 ? this.timeText : '00:00:00'
    );
    if (parsed > 0) {
      return new Date(parsed);
    }
    return new Date();
  }

  private applyDatePickerText(value: string): void {
    if (value.length === 0) {
      return;
    }
    this.dateText = value;
    if (this.timeText.length === 0) {
      this.timeText = '00:00:00';
    }
    this.errorText = '';
  }

  private showDatePicker(): void {
    this.pendingDate = this.fallbackPickerDate();
    this.pickerMode = 'date';
  }

  private showTimePicker(): void {
    if (this.dateText.length === 0) {
      return;
    }
    const selected = this.fallbackPickerDate();
    this.pendingTimeHour = selected.getHours();
    this.pendingTimeMinute = selected.getMinutes();
    this.pendingTimeSecond = selected.getSeconds();
    this.pickerMode = 'time';
  }

  private cancelPicker(): void {
    this.pickerMode = 'none';
  }

  private confirmPicker(): void {
    if (this.pickerMode === 'date') {
      this.applyDatePickerText(formatDdlDatePickerValue(this.pendingDate));
    } else if (this.pickerMode === 'time') {
      const value = formatDdlTimePickerValue({
        hour: this.pendingTimeHour,
        minute: this.pendingTimeMinute,
        second: this.pendingTimeSecond,
      });
      if (value.length > 0) {
        this.timeText = value;
        this.errorText = '';
      }
    }
    this.pickerMode = 'none';
  }

  private submit(): void {
    const title = this.title.trim();
    const deadline = this.parseDeadline(this.dateText, this.timeText);
    const validation: DdlEditValidationResult = validateDdlEditInput(title, deadline);
    if (!validation.isValid) {
      this.errorText = validation.errorText;
      return;
    }
    this.onConfirm({
      title,
      courseName: this.editItem?.courseName ?? '',
      time: deadline,
      description: this.description,
      location: this.editItem?.location ?? '',
    });
  }

  private editModel(): DdlEditDialogModel {
    return buildDdlEditDialogModel(this.editItem);
  }

  private canPickTime(): boolean {
    return !this.editModel().timeRequiresDate || this.dateText.length > 0;
  }

  @Builder
  private DatePickerButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        Text(this.dateText.length > 0 ? this.dateText : this.editModel().datePlaceholder)
          .fontSize(14)
          .fontColor('#334155')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .height(44)
    .backgroundColor('#E9F1FF')
    .onClick(() => this.showDatePicker())
  }

  @Builder
  private TimePickerButton() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 6 }) {
        Text(this.timeText.length > 0 ? this.timeText : this.editModel().timePlaceholder)
          .fontSize(14)
          .fontColor(this.canPickTime() ? '#334155' : '#94A3B8')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
    }
    .height(44)
    .enabled(this.canPickTime())
    .backgroundColor('#E9F1FF')
    .onClick(() => this.showTimePicker())
  }

  @Builder
  private PickerOverlay() {
    if (this.pickerMode !== 'none') {
      Stack() {
        Column({ space: 12 }) {
          if (this.pickerMode === 'date') {
            Text(formatDdlDatePickerValue(this.pendingDate))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Center)

            DatePicker({
              start: new Date('2000-01-01T00:00:00'),
              end: new Date('2100-12-31T23:59:59'),
              selected: this.pendingDate,
            })
              .height(230)
              .width('100%')
              .onDateChange((value: Date) => {
                this.pendingDate = value;
              })
          } else {
            Text(formatDdlTimePickerValue({
              hour: this.pendingTimeHour,
              minute: this.pendingTimeMinute,
              second: this.pendingTimeSecond,
            }))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Center)

            TimePicker({
              selected: new Date(2026, 0, 1, this.pendingTimeHour, this.pendingTimeMinute, this.pendingTimeSecond),
              format: TimePickerFormat.HOUR_MINUTE_SECOND,
            })
              .useMilitaryTime(true)
              .height(230)
              .width('100%')
              .onChange((value: TimePickerResult) => {
                if (value.hour !== undefined) {
                  this.pendingTimeHour = value.hour;
                }
                if (value.minute !== undefined) {
                  this.pendingTimeMinute = value.minute;
                }
                this.pendingTimeSecond = value.second === undefined ? 0 : value.second;
              })
          }

          Row() {
            Text('取消')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0A59F7')
              .textAlign(TextAlign.Center)
              .height('100%')
              .layoutWeight(1)
              .onClick(() => this.cancelPicker())

            Divider()
              .vertical(true)
              .height(28)
              .color('#E5E7EB')

            Text('确定')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0A59F7')
              .textAlign(TextAlign.Center)
              .height('100%')
              .layoutWeight(1)
              .onClick(() => this.confirmPicker())
          }
          .width('100%')
          .height(52)
          .alignItems(VerticalAlign.Center)
        }
        .padding({ left: 24, right: 24, top: 22, bottom: 16 })
        .width('88%')
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .align(Alignment.Center)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.18)')
      .zIndex(10)
    }
  }

  build() {
    Stack() {
      Row() { }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.25)')
      .onClick(() => this.onCancel())

      Column({ space: 10 }) {
        Text(this.editModel().title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor('#EF4444')
            .width('100%')
        }

        TextInput({ placeholder: this.editModel().titlePlaceholder, text: this.title })
          .height(44)
          .onChange((value: string) => {
            this.title = value;
            this.errorText = '';
          })

        Row({ space: 10 }) {
          Column() {
            this.DatePickerButton()
          }
            .layoutWeight(1)

          Column() {
            this.TimePickerButton()
          }
            .layoutWeight(1)
        }
        .width('100%')

        TextInput({ placeholder: this.editModel().detailPlaceholder, text: this.description })
          .height(44)
          .onChange((value: string) => {
            this.description = value;
          })

        Row({ space: 10 }) {
          Button(this.editModel().cancelText)
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .onClick(() => this.onCancel())

          Button(this.editModel().confirmText)
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

      this.PickerOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
