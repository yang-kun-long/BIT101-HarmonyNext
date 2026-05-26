import { uiBack, uiShowToast } from '../../utils/uiContextBridge';
import { CampusInfo, FreeClassroomRepository } from '../../services/jw/freeClassroomRepository';
import { detectSchoolLoginMode } from '../../services/school/SchoolNetworkProbe';
import type { SchoolLoginMode } from '../../services/school/SchoolAuthTypes';
import {
  DEFAULT_FREE_CLASSROOM_SETTINGS,
  FREE_CLASSROOM_APP_CAMPUS_CODE,
  FREE_CLASSROOM_APP_CAMPUS_NAME,
  FREE_CLASSROOM_APP_FREE_THRESHOLD,
  FREE_CLASSROOM_APP_HIDE_BUSY,
  FreeClassroomSettingsStore,
  normalizeFreeClassroomThreshold,
  parseFreeClassroomThresholdInput,
} from '../../services/storage/FreeClassroomSettingsStore';

@Entry
@Component
struct FreeClassroomSettingPage {
  private store = new FreeClassroomSettingsStore();
  private repo = new FreeClassroomRepository({ debug: true, mode: 'inner' });

  @State currentCampusCode: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusCode;
  @State currentCampusName: string = DEFAULT_FREE_CLASSROOM_SETTINGS.currentCampusName;
  @State hideBusyClassroom: boolean = DEFAULT_FREE_CLASSROOM_SETTINGS.hideBusyClassroom;
  @State freeMinutesThreshold: number = DEFAULT_FREE_CLASSROOM_SETTINGS.freeMinutesThreshold;
  @State campusList: CampusInfo[] = [];
  @State loadingCampus: boolean = false;
  @State errorText: string = '';
  @State loginMode: SchoolLoginMode = 'inner';
  private thresholdDialogController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    await this.loadSettings();
    await this.loadCampusList();
  }

  private async loadSettings(): Promise<void> {
    try {
      const settings = await this.store.load();
      this.currentCampusCode = settings.currentCampusCode;
      this.currentCampusName = settings.currentCampusName;
      this.hideBusyClassroom = settings.hideBusyClassroom;
      this.freeMinutesThreshold = settings.freeMinutesThreshold;
      this.syncAppStorage();
    } catch (e) {
      this.errorText = e instanceof Error ? e.message : String(e);
    }
  }

  private syncAppStorage(): void {
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_CAMPUS_CODE, this.currentCampusCode);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_CAMPUS_NAME, this.currentCampusName);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_HIDE_BUSY, this.hideBusyClassroom);
    AppStorage.setOrCreate(FREE_CLASSROOM_APP_FREE_THRESHOLD, this.freeMinutesThreshold);
  }

  private async loadCampusList(): Promise<void> {
    this.loadingCampus = true;
    this.errorText = '';
    try {
      try {
        this.loginMode = await detectSchoolLoginMode({ debug: true });
      } catch (_) {
        this.loginMode = 'inner';
      }
      this.repo = new FreeClassroomRepository({ debug: true, mode: this.loginMode });
      await this.repo.restoreWebvpnCookiesFromStorage();
      this.campusList = await this.repo.getCampusInfos();
    } catch (e) {
      this.errorText = e instanceof Error ? e.message : String(e);
    } finally {
      this.loadingCampus = false;
    }
  }

  private async selectCampus(campus: CampusInfo): Promise<void> {
    this.currentCampusCode = campus.code;
    this.currentCampusName = campus.displayName;
    await this.store.saveCampus(campus.code, campus.displayName);
    this.syncAppStorage();
    uiShowToast(this.getUIContext(), { message: '设置成功' });
  }

  private async selectAllCampus(): Promise<void> {
    this.currentCampusCode = '';
    this.currentCampusName = '';
    await this.store.saveCampus('', '');
    this.syncAppStorage();
    uiShowToast(this.getUIContext(), { message: '设置成功' });
  }

  private async setHideBusy(value: boolean): Promise<void> {
    this.hideBusyClassroom = value;
    await this.store.saveHideBusyClassroom(value);
    this.syncAppStorage();
    uiShowToast(this.getUIContext(), { message: '设置成功' });
  }

  private async setThreshold(value: number): Promise<void> {
    const safe = normalizeFreeClassroomThreshold(value);
    this.freeMinutesThreshold = safe;
    await this.store.saveFreeMinutesThreshold(safe);
    this.syncAppStorage();
    uiShowToast(this.getUIContext(), { message: '设置成功' });
  }

  private openThresholdDialog(): void {
    if (this.thresholdDialogController !== null) {
      this.thresholdDialogController.close();
    }
    const controller = new CustomDialogController({
      builder: FreeClassroomThresholdDialog({
        title: '空闲时段阈值',
        text: '不大于此值的空闲时段将被忽略 (单位: 分钟)',
        initValue: this.freeMinutesThreshold,
        onConfirm: (value: number) => {
          this.setThreshold(value);
        },
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true,
    });
    this.thresholdDialogController = controller;
    controller.open();
  }

  @Builder
  private TopBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(24)
          .fontColor([$r('sys.color.ohos_id_color_text_primary')])
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        uiBack(this.getUIContext());
      })

      Text('空教室设置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ left: 8 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }

  @Builder
  private SettingsGroup(title: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .margin({ left: 4, bottom: 8 })
    }
    .width('100%')
  }

  @Builder
  private CampusRow(campus: CampusInfo) {
    Row() {
      Radio({ value: campus.code, group: 'freeClassroomCampus' })
        .checked(campus.code === this.currentCampusCode)
        .onChange((checked: boolean) => {
          if (checked) {
            this.selectCampus(campus);
          }
        })
      Text(campus.displayName)
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ left: 10 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ minHeight: 54 })
    .padding({ left: 12, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.selectCampus(campus);
    })
  }

  @Builder
  private CampusSettings() {
    Column() {
      this.SettingsGroup('校区')
      Column() {
        Row() {
          Column() {
            Text('当前校区')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            Text(this.currentCampusName.length > 0 ? this.currentCampusName : '全部校区')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('重新拉取')
            .type(ButtonType.Capsule)
            .fontSize(13)
            .height(32)
            .onClick(() => {
              this.loadCampusList();
            })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

        if (this.loadingCampus) {
          Row() {
            LoadingProgress().width(22).height(22).margin({ right: 8 })
            Text('正在拉取校区列表...')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .height(56)
          .justifyContent(FlexAlign.Center)
        } else {
          Row() {
            Radio({ value: '', group: 'freeClassroomCampus' })
              .checked(this.currentCampusCode.length === 0)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.selectAllCampus();
                }
              })
            Text('全部校区')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .margin({ left: 10 })
          }
          .width('100%')
          .constraintSize({ minHeight: 54 })
          .padding({ left: 12, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            this.selectAllCampus();
          })

          ForEach(this.campusList, (campus: CampusInfo) => {
            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })
            this.CampusRow(campus)
          }, (campus: CampusInfo) => campus.code)
        }
      }
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)
      .clip(true)

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(12)
          .fontColor('#B91C1C')
          .margin({ top: 8, left: 4, right: 4 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
  }

  @Builder
  private DisplaySettings() {
    Column() {
      this.SettingsGroup('空教室查询设置')
      Column() {
        Row() {
          Column() {
            Text('隐藏当前不空闲的教室')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            Text('开启后列表只显示当前可用教室')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Toggle({ type: ToggleType.Switch, isOn: this.hideBusyClassroom })
            .selectedColor($r('sys.color.ohos_id_color_text_primary_activated'))
            .onChange((isOn: boolean) => {
              this.setHideBusy(isOn);
            })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

        Row() {
          Column() {
            Text('空闲时段阈值')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
            Text('不大于此值的空闲时段将被忽略')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(`${this.freeMinutesThreshold} 分钟`)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ right: 8 })

          Image($r('app.media.ic_chevron_right'))
            .width(20)
            .height(20)
            .fillColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%')
        .constraintSize({ minHeight: 56 })
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => {
          this.openThresholdDialog();
        })
      }
      .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
      .borderRadius(12)
      .clip(true)
    }
    .width('100%')
  }

  build() {
    Column() {
      this.TopBar()
      List() {
        ListItem() {
          this.CampusSettings()
        }
        .padding({ left: 16, right: 16, top: 16 })

        ListItem() {
          this.DisplaySettings()
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

@CustomDialog
struct FreeClassroomThresholdDialog {
  controller: CustomDialogController;
  title: string = '';
  text: string = '';
  initValue: number = 0;
  onConfirm: (value: number) => void = () => {};

  @State inputValue: string = '';
  @State errorMessage: string = '';

  aboutToAppear(): void {
    this.inputValue = this.initValue.toString();
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .padding({ top: 24, left: 24, right: 24, bottom: 8 })
        .width('100%')

      Text(this.text)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .padding({ left: 24, right: 24, bottom: 16 })
        .width('100%')

      TextInput({ text: this.inputValue })
        .width('90%')
        .height(56)
        .type(InputType.Number)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('sys.color.ohos_id_color_text_tertiary'), radius: 8 })
        .onChange((value: string) => {
          this.inputValue = value;
          this.errorMessage = '';
        })
        .margin({ bottom: 4 })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor(Color.Red)
          .padding({ left: 24, bottom: 8 })
          .width('100%')
      } else {
        Blank().height(22)
      }

      Row() {
        Button('取消', { type: ButtonType.Normal })
          .onClick(() => {
            this.controller.close();
          })
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .layoutWeight(1)

        Button('确定', { type: ButtonType.Normal })
          .onClick(() => {
            const value = parseFreeClassroomThresholdInput(this.inputValue);
            if (value !== null) {
              this.onConfirm(value);
              this.controller.close();
            } else {
              this.errorMessage = '格式校验失败Orz';
            }
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
    .width('80%')
  }
}
