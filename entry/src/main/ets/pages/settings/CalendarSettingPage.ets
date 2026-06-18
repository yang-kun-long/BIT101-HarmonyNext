import { uiBack, uiShowToast } from '../../utils/uiContextBridge';
import {
  applyCourseScheduleSettingsToAppStorage,
  CourseScheduleSettingsStore,
} from '../../services/storage/CourseScheduleSettingsStore';
import {
  normalizeScheduleDisplaySettings,
  parsePeriodTimesText,
  periodTimesToText,
  ScheduleDisplaySettings,
} from '../../services/schoolSchedule/ScheduleSettingsModels';
import { CourseScheduleRepository } from '../../services/schoolSchedule/CourseScheduleRepository';
import { ScheduleLocalStore } from '../../services/schoolSchedule/ScheduleLocalStore';
import type { PeriodTime } from '../../services/jw/periodTimes';
import { CourseTermRepository } from '../../services/jw/courseTermRepository';
import { ExamScheduleRepository } from '../../services/jw/examScheduleRepository';
import { CourseScheduleApiRepository } from '../../services/jw/courseScheduleApiRepository';
import { detectSchoolLoginMode } from '../../services/school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../../services/school/SchoolAuthTypes';
import { doOperationRequiresLogin, LoginHealthService } from '../../services/auth/LoginHealthService';
import type { CourseScheduleItem, ExamScheduleItem } from '../../services/schoolSchedule/ScheduleModels';
import {
  buildScheduleCalendarEventDrafts,
  formatSystemCalendarSyncMessage,
  SystemCalendarEventDraft,
  SystemCalendarSyncResult,
} from '../../services/systemCalendar/SystemCalendarModels';
import {
  syncSystemCalendarEventDrafts,
  SystemCalendarService,
} from '../../services/systemCalendar/SystemCalendarService';

// ----------------------------------------------------------------------------
// 1. 数据模型定义
// ----------------------------------------------------------------------------
class SettingData {
  showSaturday: boolean = true;
  showSunday: boolean = true;
  showBorder: boolean = false;
  showHighlightToday: boolean = true;
  showDivider: boolean = true;
  showCurrentTime: boolean = true;
  showExamInfo: boolean = true;

  static copy(origin: SettingData, changes: Partial<SettingData>): SettingData {
    const newData = new SettingData();
    newData.showSaturday = changes.showSaturday ?? origin.showSaturday;
    newData.showSunday = changes.showSunday ?? origin.showSunday;
    newData.showBorder = changes.showBorder ?? origin.showBorder;
    newData.showHighlightToday = changes.showHighlightToday ?? origin.showHighlightToday;
    newData.showDivider = changes.showDivider ?? origin.showDivider;
    newData.showCurrentTime = changes.showCurrentTime ?? origin.showCurrentTime;
    newData.showExamInfo = changes.showExamInfo ?? origin.showExamInfo;
    return newData;
  }
}

// ----------------------------------------------------------------------------
// 2. 主页面结构
// ----------------------------------------------------------------------------

@Entry
@Component
struct CalendarSettingPage {
  private settingsStore: CourseScheduleSettingsStore = new CourseScheduleSettingsStore();
  private loginHealthService: LoginHealthService = new LoginHealthService();

  @State currentTerm: string = "";
  @State firstDay: string = "";
  @State settingData: SettingData = new SettingData();

  @State isGettingFirstDay: boolean = false;
  @State isGettingCourses: boolean = false;
  @State isGettingExams: boolean = false;
  @State isGettingTerms: boolean = false;
  @State isGettingCurrentTerm: boolean = false;
  @State isSyncingSystemCalendar: boolean = false;
  @State showTermOptions: boolean = false;
  @State termOptions: string[] = [];

  @State timeTableString: string = "";
  @StorageProp('filesDir') filesDirFromApp: string = '';

  // --- 弹窗控制器 ---
  timeTableDialogController: CustomDialogController = new CustomDialogController({
    builder: TimeTableDialog({
      content: this.timeTableString,
      onConfirm: (val: string) => {
        this.saveTimeTable(val);
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

  aboutToAppear(): void {
    this.loadSettings();
  }

  build() {
    Column() {
      // 1. 顶部导航栏
      Row() {
        Image($r('app.media.ic_chevron_left'))
          .width(24)
          .height(24)
          .fillColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick(() => { uiBack(this.getUIContext()); })

        Text("课程表设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 2. 内容区域
      List() {
        // --- Group 1: 数据设置 ---
        ListItem() {
          SettingsGroup({ title: "数据设置", subTitle: "如果获取失败可以尝试在账号设置中“检查登录状态”哦" }) {
            Column() {
              SettingItem({
                title: "当前学期",
                subTitle: this.isGettingCurrentTerm ? "正在获取学校当前学期" : "从教务学期列表中选择",
                valueText: this.currentTerm.length > 0 ? this.currentTerm : "自动获取",
                enable: !this.isGettingCurrentTerm && !this.isGettingTerms,
                onItemClick: () => {
                  this.handleOpenTermOptions();
                }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              if (this.showTermOptions) {
                this.TermOptionsList()
                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })
              }

              SettingItem({
                title: "学期起始日期",
                subTitle: "点击重新获取当前学期的起始日期",
                valueText: this.firstDay.length > 0 ? this.firstDay : "未设置",
                enable: !this.isGettingFirstDay,
                onItemClick: () => { this.handleGetFirstDay() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "课表数据",
                subTitle: "点击重新获取当前学期的课表",
                enable: !this.isGettingCourses,
                onItemClick: () => { this.handleGetCourses() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "考试安排数据",
                subTitle: "点击重新获取当前学期的考试安排",
                enable: !this.isGettingExams,
                onItemClick: () => { this.handleGetExams() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "系统日历",
                subTitle: "将本地课程、考试和自定义日程写入系统日历",
                enable: !this.isSyncingSystemCalendar,
                onItemClick: () => { this.handleSyncSystemCalendar() }
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SettingItem({
                title: "时间表",
                subTitle: "每节课的上课和下课时间",
                onItemClick: () => { this.timeTableDialogController.open() }
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16 })

        // --- Group 2: 显示设置 ---
        ListItem() {
          SettingsGroup({ title: "显示设置" }) {
            Column() {
              // 【修复核心】显式添加 : void 返回类型
              SwitchSettingItem({
                title: "显示周六",
                checked: this.settingData.showSaturday,
                onChange: (v: boolean): void => this.updateSetting({ showSaturday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示周日",
                checked: this.settingData.showSunday,
                onChange: (v: boolean): void => this.updateSetting({ showSunday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示课程卡片边框",
                checked: this.settingData.showBorder,
                onChange: (v: boolean): void => this.updateSetting({ showBorder: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "高亮今日",
                checked: this.settingData.showHighlightToday,
                onChange: (v: boolean): void => this.updateSetting({ showHighlightToday: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示节次分割线",
                checked: this.settingData.showDivider,
                onChange: (v: boolean): void => this.updateSetting({ showDivider: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示当前时间线",
                checked: this.settingData.showCurrentTime,
                onChange: (v: boolean): void => this.updateSetting({ showCurrentTime: v })
              })
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              SwitchSettingItem({
                title: "显示考试安排",
                subTitle: "考试安排更新时需手动刷新才能更新",
                checked: this.settingData.showExamInfo,
                onChange: (v: boolean): void => this.updateSetting({ showExamInfo: v })
              })
            }
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // --- 逻辑处理 ---

  private getFilesDir(): string {
    return this.filesDirFromApp || '';
  }

  private toSettingData(settings: ScheduleDisplaySettings): SettingData {
    const data = new SettingData();
    data.showSaturday = settings.showSaturday;
    data.showSunday = settings.showSunday;
    data.showBorder = settings.showBorder;
    data.showHighlightToday = settings.showHighlightToday;
    data.showDivider = settings.showDivider;
    data.showCurrentTime = settings.showCurrentTime;
    data.showExamInfo = settings.showExamInfo;
    return data;
  }

  private applySettings(settings: ScheduleDisplaySettings): void {
    const normalized = normalizeScheduleDisplaySettings(settings);
    this.currentTerm = normalized.currentTerm;
    this.firstDay = normalized.firstDayISO;
    this.settingData = this.toSettingData(normalized);
    this.timeTableString = periodTimesToText(normalized.periodTimes);
    applyCourseScheduleSettingsToAppStorage(normalized);
  }

  private loadSettings(): void {
    this.settingsStore.load()
      .then((settings: ScheduleDisplaySettings) => {
        this.applySettings(settings);
        if (settings.currentTerm.length === 0) {
          this.fetchDefaultCurrentTerm();
        }
      })
      .catch(() => {
        uiShowToast(this.getUIContext(), { message: "读取课程表设置失败" });
      });
  }

  private saveSettings(settings: ScheduleDisplaySettings, successMessage: string, silent: boolean = false): void {
    this.settingsStore.save(settings)
      .then(() => {
        this.applySettings(settings);
        if (!silent) {
          uiShowToast(this.getUIContext(), { message: successMessage });
        }
      })
      .catch(() => {
        uiShowToast(this.getUIContext(), { message: "设置保存失败" });
      });
  }

  private saveCurrentTerm(term: string, silent: boolean = false): void {
    const trimmed = term.trim();
    this.settingsStore.load()
      .then((settings: ScheduleDisplaySettings) => {
        const next = normalizeScheduleDisplaySettings({
          currentTerm: trimmed,
          firstDayISO: settings.firstDayISO,
          showSaturday: settings.showSaturday,
          showSunday: settings.showSunday,
          showBorder: settings.showBorder,
          showHighlightToday: settings.showHighlightToday,
          showDivider: settings.showDivider,
          showCurrentTime: settings.showCurrentTime,
          showExamInfo: settings.showExamInfo,
          periodTimes: settings.periodTimes,
        });
        this.saveSettings(next, "切换学期成功", silent);
        this.fetchFirstDayForTerm(trimmed, true);
      })
      .catch(() => {
        uiShowToast(this.getUIContext(), { message: "设置保存失败" });
      });
  }

  updateSetting(changes: Partial<SettingData>): void {
    this.settingData = SettingData.copy(this.settingData, changes);
    this.settingsStore.load()
      .then((settings: ScheduleDisplaySettings) => {
        const next = normalizeScheduleDisplaySettings({
          currentTerm: settings.currentTerm,
          firstDayISO: settings.firstDayISO,
          showSaturday: this.settingData.showSaturday,
          showSunday: this.settingData.showSunday,
          showBorder: this.settingData.showBorder,
          showHighlightToday: this.settingData.showHighlightToday,
          showDivider: this.settingData.showDivider,
          showCurrentTime: this.settingData.showCurrentTime,
          showExamInfo: this.settingData.showExamInfo,
          periodTimes: settings.periodTimes,
        });
        this.saveSettings(next, "设置成功");
      })
      .catch(() => {
        uiShowToast(this.getUIContext(), { message: "设置保存失败" });
      });
  }

  handleGetFirstDay(): void {
    if (this.currentTerm.length === 0) {
      uiShowToast(this.getUIContext(), { message: "请先选择当前学期" });
      return;
    }
    this.fetchFirstDayForTerm(this.currentTerm, false);
  }

  async handleGetCourses(): Promise<void> {
    const filesDir = this.getFilesDir();
    if (filesDir.length === 0) {
      uiShowToast(this.getUIContext(), { message: "无法获取应用文件目录" });
      return;
    }
    if (this.currentTerm.length === 0 || this.firstDay.length === 0) {
      uiShowToast(this.getUIContext(), { message: "请先设置当前学期和学期起始日期" });
      return;
    }
    const periodTimes: PeriodTime[] = parsePeriodTimesText(this.timeTableString);
    if (periodTimes.length === 0) {
      uiShowToast(this.getUIContext(), { message: "时间表格式错误" });
      return;
    }

    this.isGettingCourses = true;
    uiShowToast(this.getUIContext(), { message: "正在获取课表..." });
    try {
      const repo: CourseScheduleRepository = await this.createCourseRefreshRepository(filesDir);
      await doOperationRequiresLogin<CourseScheduleItem[]>(
        async (): Promise<CourseScheduleItem[]> => await repo.refreshCourses(this.currentTerm, this.firstDay, periodTimes),
        async () => await this.loginHealthService.checkLogin(),
        'jxzx',
      );
      uiShowToast(this.getUIContext(), { message: "获取成功" });
    } catch (error) {
      const message = error instanceof Error && error.message.includes('教务应用登录态不可用')
        ? error.message
        : "获取失败，请检查登录状态";
      uiShowToast(this.getUIContext(), { message });
    } finally {
      this.isGettingCourses = false;
    }
  }

  async handleGetExams(): Promise<void> {
    this.isGettingExams = true;
    const filesDir = this.getFilesDir();
    if (filesDir.length === 0) {
      this.isGettingExams = false;
      uiShowToast(this.getUIContext(), { message: "无法获取应用文件目录" });
      return;
    }
    if (this.currentTerm.length === 0) {
      this.isGettingExams = false;
      uiShowToast(this.getUIContext(), { message: "请先设置当前学期" });
      return;
    }
    try {
      const repo: CourseScheduleRepository = await this.createExamRefreshRepository(filesDir);
      const exams: ExamScheduleItem[] = await doOperationRequiresLogin<ExamScheduleItem[]>(
        async (): Promise<ExamScheduleItem[]> => await repo.refreshExams(this.currentTerm),
        async () => await this.loginHealthService.checkLogin(),
        'jxzx',
      );
      uiShowToast(this.getUIContext(), { message: `获取成功，共 ${exams.length} 条` });
    } catch (error) {
      const message = error instanceof Error && error.message.includes('教务应用登录态不可用')
        ? error.message
        : "获取失败，请检查登录状态";
      uiShowToast(this.getUIContext(), { message });
    } finally {
      this.isGettingExams = false;
    }
  }

  async handleSyncSystemCalendar(): Promise<void> {
    const filesDir = this.getFilesDir();
    if (filesDir.length === 0) {
      uiShowToast(this.getUIContext(), { message: "无法获取应用文件目录" });
      return;
    }

    this.isSyncingSystemCalendar = true;
    try {
      const store = new ScheduleLocalStore({ filesDir });
      const periodTimes: PeriodTime[] = parsePeriodTimesText(this.timeTableString);
      const drafts: SystemCalendarEventDraft[] = buildScheduleCalendarEventDrafts({
        courses: store.loadCourses(),
        exams: store.loadExams(),
        customSchedules: store.loadCustomSchedules(),
        firstDayISO: this.firstDay,
        periodTimes,
      });
      if (drafts.length === 0) {
        uiShowToast(this.getUIContext(), { message: formatSystemCalendarSyncMessage({
          total: 0,
          created: 0,
          skipped: 0,
          failed: 0,
        }) });
        return;
      }

      const result: SystemCalendarSyncResult = await syncSystemCalendarEventDrafts(
        new SystemCalendarService(),
        drafts,
      );
      uiShowToast(this.getUIContext(), { message: formatSystemCalendarSyncMessage(result) });
    } catch (error) {
      const message = error instanceof Error && error.message.length > 0
        ? error.message
        : "写入系统日历失败";
      uiShowToast(this.getUIContext(), { message });
    } finally {
      this.isSyncingSystemCalendar = false;
    }
  }

  private saveTimeTable(value: string): void {
    const periodTimes = parsePeriodTimesText(value);
    if (periodTimes.length === 0) {
      uiShowToast(this.getUIContext(), { message: "时间表格式错误" });
      return;
    }
    this.settingsStore.load()
      .then((settings: ScheduleDisplaySettings) => {
        const next = normalizeScheduleDisplaySettings({
          currentTerm: settings.currentTerm,
          firstDayISO: settings.firstDayISO,
          showSaturday: settings.showSaturday,
          showSunday: settings.showSunday,
          showBorder: settings.showBorder,
          showHighlightToday: settings.showHighlightToday,
          showDivider: settings.showDivider,
          showCurrentTime: settings.showCurrentTime,
          showExamInfo: settings.showExamInfo,
          periodTimes,
        });
        this.saveSettings(next, "时间表已保存");
      })
      .catch(() => {
        uiShowToast(this.getUIContext(), { message: "时间表保存失败" });
      });
  }

  private async detectSchoolModeForJxzx(): Promise<SchoolLoginMode> {
    let mode: SchoolLoginMode = 'inner';
    try {
      mode = await detectSchoolLoginMode({ debug: true });
    } catch (_) {
      mode = 'inner';
    }
    return mode;
  }

  private async createTermRepository(): Promise<CourseTermRepository> {
    const mode = await this.detectSchoolModeForJxzx();
    return new CourseTermRepository({ mode, debug: true });
  }

  private async createExamRefreshRepository(filesDir: string): Promise<CourseScheduleRepository> {
    const mode = await this.detectSchoolModeForJxzx();
    return new CourseScheduleRepository({
      localStore: new ScheduleLocalStore({ filesDir }),
      examSource: new ExamScheduleRepository({
        mode,
        debug: true,
      }),
    });
  }

  private async createCourseRefreshRepository(filesDir: string): Promise<CourseScheduleRepository> {
    const mode = await this.detectSchoolModeForJxzx();
    return new CourseScheduleRepository({
      localStore: new ScheduleLocalStore({ filesDir }),
      courseSource: new CourseScheduleApiRepository({
        mode,
        debug: true,
      }),
    });
  }

  private fetchDefaultCurrentTerm(): void {
    this.isGettingCurrentTerm = true;
    this.createTermRepository()
      .then((repo: CourseTermRepository) => doOperationRequiresLogin<string>(
        async (): Promise<string> => await repo.getCurrentTerm(),
        async () => await this.loginHealthService.checkLogin(),
        'jxzx',
      ))
      .then((term: string) => {
        this.isGettingCurrentTerm = false;
        if (term.length > 0) {
          this.saveCurrentTerm(term, true);
        }
      })
      .catch((error: Error) => {
        this.isGettingCurrentTerm = false;
        const message = error.message.includes('教务应用登录态不可用')
          ? error.message
          : "自动获取当前学期失败，请检查登录状态";
        uiShowToast(this.getUIContext(), { message });
      });
  }

  private handleOpenTermOptions(): void {
    if (this.showTermOptions) {
      this.showTermOptions = false;
      return;
    }
    this.showTermOptions = true;
    if (this.termOptions.length === 0) {
      this.loadTermOptions();
    }
  }

  private loadTermOptions(): void {
    this.isGettingTerms = true;
    this.createTermRepository()
      .then((repo: CourseTermRepository) => doOperationRequiresLogin<string[]>(
        async (): Promise<string[]> => await repo.getTermList(),
        async () => await this.loginHealthService.checkLogin(),
        'jxzx',
      ))
      .then((terms: string[]) => {
        this.isGettingTerms = false;
        this.termOptions = terms;
        if (terms.length === 0) {
          uiShowToast(this.getUIContext(), { message: "没有获取到可选学期" });
        }
      })
      .catch((error: Error) => {
        this.isGettingTerms = false;
        const message = error.message.includes('教务应用登录态不可用')
          ? error.message
          : "获取学期列表失败，请检查登录状态";
        uiShowToast(this.getUIContext(), { message });
      });
  }

  private selectTerm(term: string): void {
    this.showTermOptions = false;
    this.saveCurrentTerm(term, false);
  }

  private fetchFirstDayForTerm(term: string, silent: boolean): void {
    this.isGettingFirstDay = true;
    this.createTermRepository()
      .then((repo: CourseTermRepository) => doOperationRequiresLogin<string>(
        async (): Promise<string> => await repo.getFirstDay(term),
        async () => await this.loginHealthService.checkLogin(),
        'jxzx',
      ))
      .then((firstDay: string) => {
        this.isGettingFirstDay = false;
        this.settingsStore.load()
          .then((settings: ScheduleDisplaySettings) => {
            const next = normalizeScheduleDisplaySettings({
              currentTerm: settings.currentTerm,
              firstDayISO: firstDay,
              showSaturday: settings.showSaturday,
              showSunday: settings.showSunday,
              showBorder: settings.showBorder,
              showHighlightToday: settings.showHighlightToday,
              showDivider: settings.showDivider,
              showCurrentTime: settings.showCurrentTime,
              showExamInfo: settings.showExamInfo,
              periodTimes: settings.periodTimes,
            });
            this.saveSettings(next, "学期起始日期已更新", silent);
          })
          .catch(() => {
            uiShowToast(this.getUIContext(), { message: "学期起始日期保存失败" });
          });
      })
      .catch((error: Error) => {
        this.isGettingFirstDay = false;
        const message = error.message.includes('教务应用登录态不可用')
          ? error.message
          : "获取学期起始日期失败，请检查登录状态";
        uiShowToast(this.getUIContext(), { message });
      });
  }

  @Builder
  private TermOptionsList() {
    Column() {
      if (this.isGettingTerms) {
        Row() {
          LoadingProgress()
            .width(22)
            .height(22)
            .margin({ right: 8 })
          Text("正在获取学期列表...")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .height(52)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.termOptions, (term: string) => {
          Row() {
            Radio({ value: term, group: 'courseScheduleTerm' })
              .checked(term === this.currentTerm)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.selectTerm(term);
                }
              })

            Text(term)
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .margin({ left: 10 })
              .layoutWeight(1)
          }
          .width('100%')
          .constraintSize({ minHeight: 52 })
          .padding({ left: 12, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            this.selectTerm(term);
          })
        }, (term: string) => term)
      }
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }
}

// ----------------------------------------------------------------------------
// 3. 弹窗组件
// ----------------------------------------------------------------------------

@CustomDialog
struct TimeTableDialog {
  controller: CustomDialogController;
  @State content: string = "";
  onConfirm: (val: string) => void = () => {};

  build() {
    Column() {
      Text("设置时间表")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, left: 24, right: 24, bottom: 8 })
        .width('100%')

      Text("可调整每天课程节数和时间，格式照猫画虎即可")
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .padding({ left: 24, right: 24, bottom: 16 })
        .width('100%')

      TextArea({ text: this.content })
        .width('90%')
        .height(300)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_text_tertiary'), radius: 8 })
        .fontSize(14)
        .fontFamily('Monospace')
        .onChange((value) => {
          this.content = value;
        })
        .margin({ bottom: 8 })

      // 按钮组
      Row() {
        Button("取消", { type: ButtonType.Normal })
          .onClick(() => { this.controller.close() })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        Button("确定", { type: ButtonType.Normal })
          .onClick(() => {
            this.onConfirm(this.content);
            this.controller.close();
          })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(52)
      .margin({ bottom: 8 })
    }
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
    .borderRadius(28)
    .width('90%')
  }
}

// ----------------------------------------------------------------------------
// 4. 复用组件
// ----------------------------------------------------------------------------

@Component
struct SettingsGroup {
  @Prop title: string;
  @Prop subTitle: string = "";
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.title) {
        Column() {
          Text(this.title)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .fontWeight(FontWeight.Medium)
            .width('100%')

          if (this.subTitle) {
            Text(this.subTitle)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
              .width('100%')
          }
        }
        .margin({ bottom: 8, left: 4 })
      }

      Column() {
        this.content()
      }
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
  }
}

@Component
struct SettingItem {
  @Prop title: string;
  @Prop subTitle: string = "";
  @Prop valueText: string = "";
  @Prop showArrow: boolean = true;
  @Prop enable: boolean = true;

  onItemClick: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.enable ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary'))

        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.valueText) {
        Text(this.valueText)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ right: 8 })
      }

      if (this.showArrow) {
        Image($r('app.media.ic_chevron_right'))
          .width(20)
          .height(20)
          .fillColor(this.enable ? $r('sys.color.ohos_id_color_text_tertiary') : Color.Transparent)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
    .opacity(this.enable ? 1 : 0.6)
    .enabled(this.enable)
    .onClick(() => {
      if (this.enable) {
        this.onItemClick();
      }
    })
  }
}

@Component
struct SwitchSettingItem {
  @Prop title: string;
  @Prop subTitle: string;
  @Prop checked: boolean;
  onChange: (isOn: boolean) => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        if (this.subTitle) {
          Text(this.subTitle)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.checked })
        .onChange((isOn) => {
          this.onChange(isOn);
        })
        .selectedColor($r('sys.color.ohos_id_color_text_primary_activated'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.Transparent)
  }
}
