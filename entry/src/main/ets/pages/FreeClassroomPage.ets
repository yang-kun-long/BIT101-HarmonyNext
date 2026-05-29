import { Logger } from '../utils/Logger';
import { uiPushUrl, uiShowToast } from '../utils/uiContextBridge';
import {
  buildClassroomDayRows,
  BuildingInfo,
  ClassroomBusyStatus,
  computeClassroomBusyStatus,
  FreeClassroomRepository,
  FreeClassroomRow,
  guessCurrentSchoolTermCode,
  resolveFreeClassroomTermCode,
  sortFreeClassroomRowsForAndroidDisplay,
} from '../services/jw/freeClassroomRepository';
import { getPeriodTimesInMemory, PeriodTime } from '../services/jw/periodTimes';
import { detectSchoolLoginMode } from '../services/school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../services/school/SchoolAuthTypes';
import {
  DEFAULT_FREE_CLASSROOM_SETTINGS,
  FREE_CLASSROOM_APP_CAMPUS_CODE,
  FREE_CLASSROOM_APP_CAMPUS_NAME,
  FREE_CLASSROOM_APP_FREE_THRESHOLD,
  FREE_CLASSROOM_APP_HIDE_BUSY,
  FreeClassroomSettingsStore,
} from '../services/storage/FreeClassroomSettingsStore';
import { COURSE_SCHEDULE_APP_CURRENT_TERM } from '../services/storage/CourseScheduleSettingsStore';
import {
  FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP,
  FREE_CLASSROOM_FAB_GAP_VP,
  FREE_CLASSROOM_FAB_ICON_VP,
  FREE_CLASSROOM_FAB_RIGHT_PADDING_VP,
  FREE_CLASSROOM_FAB_SIZE_VP,
  FREE_CLASSROOM_ITEM_INNER_BOTTOM_PADDING_VP,
  FREE_CLASSROOM_ITEM_INNER_LEFT_PADDING_VP,
  FREE_CLASSROOM_ITEM_INNER_RIGHT_PADDING_VP,
  FREE_CLASSROOM_ITEM_INNER_TOP_PADDING_VP,
  FREE_CLASSROOM_ITEM_OUTER_HORIZONTAL_PADDING_VP,
  FREE_CLASSROOM_ITEM_OUTER_VERTICAL_PADDING_VP,
  formatNoBuildingTip,
  resolveFreeClassroomBuildingListState,
  resolveExpandedClassroomState,
  shouldRenderFreeClassroomSummaryHeader,
  shouldShowFreeClassroomBackToTop,
  shouldResetFreeClassroomCampus,
} from '../components/freeClassroom/freeClassroomUiModel';

interface BuildingClassroomState {
  buildingId: string;
  loading: boolean;
  rows: FreeClassroomRow[];
  errorText: string;
  cacheValidUntilMs: number;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

function formatDateISO(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

function formatClock(date: Date): string {
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

function parseClockMinutes(text: string): number {
  const parts = text.split(':');
  if (parts.length < 2) return 0;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return 0;
  return Math.max(0, Math.min(1439, Math.floor(hour) * 60 + Math.floor(minute)));
}

@Component
export default struct FreeClassroomPage {
  private logger = new Logger('FreeClassroomPage');
  private repo = new FreeClassroomRepository({ debug: true, mode: 'inner' });
  private settingsStore = new FreeClassroomSettingsStore();
  private listScroller: Scroller = new Scroller();
  private clockTimer: number = -1;

  @State loadingBuildings: boolean = false;
  @State errorText: string = '';
  @State buildingList: BuildingInfo[] = [];
  @State expandedBuildingIds: string[] = [];
  @State classroomStates: BuildingClassroomState[] = [];
  @State nowClockText: string = formatClock(new Date());
  @State termCode: string = guessCurrentSchoolTermCode();
  @State loginMode: SchoolLoginMode = 'inner';
  @State showBackToTop: boolean = false;
  @State loadedCampusCode: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusCode;
  @State loadedCampusName: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusName;
  @StorageLink(COURSE_SCHEDULE_APP_CURRENT_TERM) courseScheduleCurrentTerm: string = '';
  @StorageLink(FREE_CLASSROOM_APP_CAMPUS_CODE) currentCampusCode: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusCode;
  @StorageLink(FREE_CLASSROOM_APP_CAMPUS_NAME) currentCampusName: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusName;
  @StorageLink(FREE_CLASSROOM_APP_HIDE_BUSY) hideBusyClassroom: boolean = DEFAULT_FREE_CLASSROOM_SETTINGS.hideBusyClassroom;
  @StorageLink(FREE_CLASSROOM_APP_FREE_THRESHOLD) freeMinutesThreshold: number = DEFAULT_FREE_CLASSROOM_SETTINGS.freeMinutesThreshold;

  aboutToAppear(): void {
    this.bootstrap();
    this.clockTimer = setInterval((): void => {
      this.tickClock();
    }, 60000);
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
  }

  onPageShow(): void {
    this.refreshAfterSettingsPage();
  }

  private showToast(message: string): void {
    uiShowToast(this.getUIContext(), { message });
  }

  private friendlyError(message: string): string {
    if (message.includes('response is not JSON') || message.includes('/cas/login') || message.includes('统一身份认证')) {
      return '教务登录态不可用，请重新登录后再试';
    }
    return message;
  }

  private async bootstrap(): Promise<void> {
    this.loadingBuildings = true;
    this.errorText = '';
    try {
      await this.reloadSettings();
      const campusCodeForRequest = this.currentCampusCode;
      const campusNameForRequest = this.currentCampusName;
      this.resetBuildingSelection();
      try {
        this.loginMode = await detectSchoolLoginMode({ debug: true });
      } catch (modeError) {
        this.loginMode = 'inner';
        this.logger.warn('detectSchoolLoginMode failed, fallback to inner:', modeError);
      }
      this.repo = new FreeClassroomRepository({ debug: true, mode: this.loginMode });
      await this.repo.restoreWebvpnCookiesFromStorage();
      this.buildingList = await this.repo.getBuildingInfos(campusCodeForRequest);
      this.loadedCampusCode = campusCodeForRequest;
      this.loadedCampusName = campusNameForRequest;
    } catch (e) {
      const msg = this.friendlyError(e instanceof Error ? e.message : String(e));
      this.errorText = msg;
      this.logger.error('load buildings failed:', msg);
      this.showToast('拉取教学楼信息失败 Orz...');
    } finally {
      this.loadingBuildings = false;
    }
  }

  private resetBuildingSelection(): void {
    this.expandedBuildingIds = [];
    this.classroomStates = [];
    this.showBackToTop = false;
    this.listScroller.scrollToIndex(0, false);
  }

  private async refreshAfterSettingsPage(): Promise<void> {
    await this.reloadSettings();
    if (shouldResetFreeClassroomCampus(
      this.loadedCampusCode,
      this.loadedCampusName,
      this.currentCampusCode,
      this.currentCampusName,
    )) {
      this.resetBuildingSelection();
      await this.bootstrap();
    }
  }

  private async reloadSettings(): Promise<void> {
    try {
      const settings = await this.settingsStore.load();
      this.currentCampusCode = settings.currentCampusCode;
      this.currentCampusName = settings.currentCampusName;
      this.hideBusyClassroom = settings.hideBusyClassroom;
      this.freeMinutesThreshold = settings.freeMinutesThreshold;
      this.termCode = resolveFreeClassroomTermCode(this.courseScheduleCurrentTerm);
    } catch (e) {
      this.logger.warn('reloadSettings failed:', e);
      this.termCode = resolveFreeClassroomTermCode(this.courseScheduleCurrentTerm);
    }
  }

  private tickClock(): void {
    this.nowClockText = formatClock(new Date());
    this.refreshInvalidExpandedBuildings();
  }

  private refreshInvalidExpandedBuildings(): void {
    const nowMs = Date.now();
    for (let i = 0; i < this.expandedBuildingIds.length; i++) {
      const buildingId = this.expandedBuildingIds[i];
      const state = this.findBuildingState(buildingId);
      if (state.rows.length > 0 && state.cacheValidUntilMs <= nowMs && !state.loading) {
        const building = this.findBuilding(buildingId);
        if (building) {
          this.loadClassrooms(building, true);
        }
      }
    }
  }

  private findBuilding(buildingId: string): BuildingInfo | null {
    for (let i = 0; i < this.buildingList.length; i++) {
      if (this.buildingList[i].buildingIndex === buildingId) {
        return this.buildingList[i];
      }
    }
    return null;
  }

  private visibleBuildingList(): BuildingInfo[] {
    if (this.currentCampusCode.length === 0) {
      return this.buildingList;
    }
    const out: BuildingInfo[] = [];
    for (let i = 0; i < this.buildingList.length; i++) {
      if (this.buildingList[i].campusCode === this.currentCampusCode) {
        out.push(this.buildingList[i]);
      }
    }
    return out;
  }

  private findBuildingState(buildingId: string): BuildingClassroomState {
    for (let i = 0; i < this.classroomStates.length; i++) {
      if (this.classroomStates[i].buildingId === buildingId) {
        return this.classroomStates[i];
      }
    }
    return {
      buildingId,
      loading: false,
      rows: [],
      errorText: '',
      cacheValidUntilMs: 0,
    };
  }

  private upsertBuildingState(state: BuildingClassroomState): void {
    const next: BuildingClassroomState[] = [];
    let replaced = false;
    for (let i = 0; i < this.classroomStates.length; i++) {
      if (this.classroomStates[i].buildingId === state.buildingId) {
        next.push(state);
        replaced = true;
      } else {
        next.push(this.classroomStates[i]);
      }
    }
    if (!replaced) {
      next.push(state);
    }
    this.classroomStates = next;
  }

  private nextCacheDeadlineMs(): number {
    const now = new Date();
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const periodTimes = getPeriodTimesInMemory();
    for (let i = 0; i < periodTimes.length; i++) {
      const start = parseClockMinutes(periodTimes[i].start);
      const end = parseClockMinutes(periodTimes[i].end);
      if (start > nowMinutes) {
        return new Date(now.getFullYear(), now.getMonth(), now.getDate(), Math.floor(start / 60), start % 60).getTime();
      }
      if (end > nowMinutes) {
        return new Date(now.getFullYear(), now.getMonth(), now.getDate(), Math.floor(end / 60), end % 60).getTime();
      }
    }
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0).getTime();
  }

  private isExpanded(buildingId: string): boolean {
    return this.expandedBuildingIds.indexOf(buildingId) >= 0;
  }

  private toggleBuilding(building: BuildingInfo): void {
    const buildingId = building.buildingIndex;
    if (this.isExpanded(buildingId)) {
      const next: string[] = [];
      for (let i = 0; i < this.expandedBuildingIds.length; i++) {
        if (this.expandedBuildingIds[i] !== buildingId) {
          next.push(this.expandedBuildingIds[i]);
        }
      }
      this.expandedBuildingIds = next;
      return;
    }

    this.expandedBuildingIds = [...this.expandedBuildingIds, buildingId];
    this.loadClassrooms(building, false);
  }

  private async loadClassrooms(building: BuildingInfo, force: boolean): Promise<void> {
    const buildingId = building.buildingIndex;
    const current = this.findBuildingState(buildingId);
    if (!force && current.rows.length > 0 && current.cacheValidUntilMs > Date.now()) {
      return;
    }
    if (current.loading) {
      return;
    }

    this.upsertBuildingState({
      buildingId,
      loading: true,
      rows: current.rows,
      errorText: '',
      cacheValidUntilMs: current.cacheValidUntilMs,
    });

    try {
      const periodTimes = getPeriodTimesInMemory();
      const classrooms = await this.repo.getClassroomInfos({
        termCode: this.termCode,
        buildingId,
        date: formatDateISO(new Date()),
        periods: [1, periodTimes.length],
      });
      const rows = buildClassroomDayRows(classrooms, periodTimes.length);
      this.upsertBuildingState({
        buildingId,
        loading: false,
        rows,
        errorText: '',
        cacheValidUntilMs: this.nextCacheDeadlineMs(),
      });
    } catch (e) {
      const msg = this.friendlyError(e instanceof Error ? e.message : String(e));
      this.logger.error('load classrooms failed:', building.buildingName, msg);
      this.showToast('拉取教室信息失败 Orz...');
      this.upsertBuildingState({
        buildingId,
        loading: false,
        rows: current.rows,
        errorText: msg,
        cacheValidUntilMs: 0,
      });
    }
  }

  private classroomStatus(row: FreeClassroomRow): ClassroomBusyStatus {
    return computeClassroomBusyStatus(row, getPeriodTimesInMemory(), this.nowClockText, this.freeMinutesThreshold);
  }

  private classroomRowsForDisplay(rows: FreeClassroomRow[]): FreeClassroomRow[] {
    const periodTimes: PeriodTime[] = getPeriodTimesInMemory();
    return sortFreeClassroomRowsForAndroidDisplay(
      rows,
      periodTimes,
      this.nowClockText,
      this.freeMinutesThreshold,
      this.hideBusyClassroom,
    );
  }

  private noBuildingTip(): string {
    return formatNoBuildingTip(this.currentCampusName);
  }

  @Builder
  private LoadingTip(text: string) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text(text)
        .fontSize(14)
        .fontColor('#334155')
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#E9F1FF')
        .borderRadius(8)
      Progress({ value: 25, total: 100, type: ProgressType.Linear })
        .width('96%')
        .height(2)
        .margin({ left: 8, right: 8, bottom: 2 })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
  }

  @Builder
  private MessageTip(text: string) {
    Text(text)
      .fontSize(14)
      .fontColor('#475569')
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#E9F1FF')
      .borderRadius(8)
      .margin({ left: 10, right: 10, top: 5, bottom: 5 })
  }

  @Builder
  private BuildingHeader(building: BuildingInfo) {
    Row() {
      Column() {
        Text(building.buildingName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(building.campusName)
          .fontSize(12)
          .fontColor('#64748B')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(22)
        .fontColor(['#64748B'])
        .rotate({ angle: this.isExpanded(building.buildingIndex) ? 90 : 0 })
    }
    .width('100%')
    .padding({
      left: FREE_CLASSROOM_ITEM_INNER_LEFT_PADDING_VP,
      right: FREE_CLASSROOM_ITEM_INNER_RIGHT_PADDING_VP,
      top: FREE_CLASSROOM_ITEM_INNER_TOP_PADDING_VP,
      bottom: FREE_CLASSROOM_ITEM_INNER_BOTTOM_PADDING_VP,
    })
    .backgroundColor(this.isExpanded(building.buildingIndex) ? '#EAF1FF' : '#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      this.toggleBuilding(building);
    })
  }

  @Builder
  private ClassroomCard(row: FreeClassroomRow) {
    Row() {
      Column() {
        Text(row.classroomName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.classroomStatus(row).isFreeNow ? '#064E3B' : '#7F1D1D')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`空闲时段: ${row.freePeriodsText}`)
          .fontSize(12)
          .fontColor(this.classroomStatus(row).isFreeNow ? '#047857' : '#991B1B')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text(this.classroomStatus(row).statusText)
          .fontSize(13)
          .fontColor(this.classroomStatus(row).isFreeNow ? '#065F46' : '#7F1D1D')
          .maxLines(2)
          .textAlign(TextAlign.End)
        if (this.classroomStatus(row).detailText.length > 0) {
          Text(this.classroomStatus(row).detailText)
            .fontSize(12)
            .fontColor(this.classroomStatus(row).isFreeNow ? '#047857' : '#991B1B')
            .margin({ top: 3 })
            .textAlign(TextAlign.End)
        }
      }
      .alignItems(HorizontalAlign.End)
      .constraintSize({ maxWidth: 142 })
    }
    .width('100%')
    .padding({
      left: FREE_CLASSROOM_ITEM_INNER_LEFT_PADDING_VP,
      right: FREE_CLASSROOM_ITEM_INNER_RIGHT_PADDING_VP,
      top: FREE_CLASSROOM_ITEM_INNER_TOP_PADDING_VP,
      bottom: FREE_CLASSROOM_ITEM_INNER_BOTTOM_PADDING_VP,
    })
    .backgroundColor(this.classroomStatus(row).isFreeNow ? '#DFF3EA' : '#F7E3E7')
    .borderRadius(8)
  }

  @Builder
  private ExpandedBuildingContent(building: BuildingInfo) {
    Column({ space: 8 }) {
      if (resolveExpandedClassroomState(
        this.findBuildingState(building.buildingIndex).loading,
        this.findBuildingState(building.buildingIndex).errorText,
        this.findBuildingState(building.buildingIndex).rows.length,
      ) === 'loading') {
        this.LoadingTip('正在获取教室列表...')
      } else if (resolveExpandedClassroomState(
        this.findBuildingState(building.buildingIndex).loading,
        this.findBuildingState(building.buildingIndex).errorText,
        this.findBuildingState(building.buildingIndex).rows.length,
      ) === 'empty') {
        this.MessageTip('未找到教室 :(')
      } else {
        ForEach(this.classroomRowsForDisplay(this.findBuildingState(building.buildingIndex).rows), (row: FreeClassroomRow) => {
          this.ClassroomCard(row)
        }, (row: FreeClassroomRow) => row.classroomName)
      }
    }
    .width('100%')
    .padding({ left: 25, right: 10, top: 3, bottom: 6 })
  }

  @Builder
  private BuildingItem(building: BuildingInfo) {
    Column() {
      this.BuildingHeader(building)
      if (this.isExpanded(building.buildingIndex)) {
        this.ExpandedBuildingContent(building)
      }
    }
    .width('100%')
    .padding({
      left: FREE_CLASSROOM_ITEM_OUTER_HORIZONTAL_PADDING_VP,
      right: FREE_CLASSROOM_ITEM_OUTER_HORIZONTAL_PADDING_VP,
      top: FREE_CLASSROOM_ITEM_OUTER_VERTICAL_PADDING_VP,
      bottom: FREE_CLASSROOM_ITEM_OUTER_VERTICAL_PADDING_VP,
    })
  }

  @Builder
  private FloatingButtons() {
    Column({ space: FREE_CLASSROOM_FAB_GAP_VP }) {
      if (this.showBackToTop) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(FREE_CLASSROOM_FAB_ICON_VP)
            .fontColor(['#1D4ED8'])
        }
        .width(FREE_CLASSROOM_FAB_SIZE_VP)
        .height(FREE_CLASSROOM_FAB_SIZE_VP)
        .backgroundColor('#DBEAFE')
        .onClick(() => {
          this.listScroller.scrollToIndex(0, true);
        })
      }

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(FREE_CLASSROOM_FAB_ICON_VP)
          .fontColor(['#1D4ED8'])
      }
      .width(FREE_CLASSROOM_FAB_SIZE_VP)
      .height(FREE_CLASSROOM_FAB_SIZE_VP)
      .backgroundColor('#DBEAFE')
      .onClick(() => {
        uiPushUrl(this.getUIContext(), { url: 'pages/settings/FreeClassroomSettingPage' });
      })
    }
    .padding({ right: FREE_CLASSROOM_FAB_RIGHT_PADDING_VP, bottom: FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      List({ scroller: this.listScroller }) {
        if (shouldRenderFreeClassroomSummaryHeader()) {
          ListItem() {
            Row().height(0)
          }
        }

        if (resolveFreeClassroomBuildingListState(
          this.loadingBuildings,
          this.errorText,
          this.visibleBuildingList().length,
        ) === 'loading') {
          ListItem() {
            this.LoadingTip('正在拉取教学楼列表...')
          }
        } else if (resolveFreeClassroomBuildingListState(
          this.loadingBuildings,
          this.errorText,
          this.visibleBuildingList().length,
        ) === 'empty' && this.noBuildingTip().length > 0) {
          ListItem() {
            this.MessageTip(this.noBuildingTip())
          }
        } else {
          ForEach(this.visibleBuildingList(), (building: BuildingInfo) => {
            ListItem() {
              this.BuildingItem(building)
            }
          }, (building: BuildingInfo) => building.buildingIndex)
        }

        ListItem() {
          Row().height(96)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F7F7')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onScrollIndex((firstIndex: number) => {
        this.showBackToTop = shouldShowFreeClassroomBackToTop(firstIndex);
      })

      this.FloatingButtons()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }
}
