export type FreeClassroomFabAction = 'backToTop' | 'settings';
export type ExpandedClassroomState = 'loading' | 'empty' | 'list';
export type FreeClassroomBuildingListState = 'loading' | 'empty' | 'list';

export interface FreeClassroomFabSpec {
  action: FreeClassroomFabAction;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
}

export type FreeClassroomSettingsItemKind = 'campus' | 'hideBusy' | 'threshold';

export interface FreeClassroomSettingsMainInput {
  currentCampusName: string;
  hideBusyClassroom: boolean;
  freeMinutesThreshold: number;
}

export interface FreeClassroomSettingsMainItem {
  kind: FreeClassroomSettingsItemKind;
  title: string;
  subTitle: string;
  valueText: string;
  checked: boolean;
}

export interface FreeClassroomCampusChoice {
  code: string;
  displayName: string;
}

export interface FreeClassroomCampusDialogModel {
  title: string;
  selectedCode: string;
  campuses: FreeClassroomCampusChoice[];
}

export const FREE_CLASSROOM_FAB_SIZE_VP = 42;
export const FREE_CLASSROOM_FAB_ICON_VP = 24;
export const FREE_CLASSROOM_FAB_GAP_VP = 10;
export const FREE_CLASSROOM_FAB_RIGHT_PADDING_VP = 10;
export const FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP = 20;

export function getFreeClassroomFabSpecs(): FreeClassroomFabSpec[] {
  return [
    {
      action: 'backToTop',
      sizeVp: FREE_CLASSROOM_FAB_SIZE_VP,
      iconVp: FREE_CLASSROOM_FAB_ICON_VP,
      gapVp: FREE_CLASSROOM_FAB_GAP_VP,
    },
    {
      action: 'settings',
      sizeVp: FREE_CLASSROOM_FAB_SIZE_VP,
      iconVp: FREE_CLASSROOM_FAB_ICON_VP,
      gapVp: FREE_CLASSROOM_FAB_GAP_VP,
    },
  ];
}

export function formatNoBuildingTip(campusName: string): string {
  if (campusName.length === 0) {
    return '';
  }
  const displayName = campusName.endsWith('校区') ? campusName : `${campusName}校区`;
  return `没有获取到${displayName}的教学楼QwQ\n(请尝试在设置中切换校区)`;
}

export function resolveExpandedClassroomState(
  loading: boolean,
  _errorText: string,
  rowCount: number,
): ExpandedClassroomState {
  if (loading) {
    return 'loading';
  }
  if (rowCount > 0) {
    return 'list';
  }
  return 'empty';
}

export function resolveFreeClassroomBuildingListState(
  loading: boolean,
  _errorText: string,
  visibleBuildingCount: number,
): FreeClassroomBuildingListState {
  if (loading) {
    return 'loading';
  }
  if (visibleBuildingCount > 0) {
    return 'list';
  }
  return 'empty';
}

export function shouldResetFreeClassroomCampus(
  loadedCampusCode: string,
  loadedCampusName: string,
  currentCampusCode: string,
  currentCampusName: string,
): boolean {
  return loadedCampusCode !== currentCampusCode || loadedCampusName !== currentCampusName;
}

export function shouldShowFreeClassroomBackToTop(firstVisibleItemIndex: number): boolean {
  return firstVisibleItemIndex > 0;
}

export function shouldRenderFreeClassroomSummaryHeader(): boolean {
  return false;
}

export function shouldRenderFreeClassroomSettingsInlineError(_errorText: string): boolean {
  return false;
}

export function shouldShowFreeClassroomCampusLoadingText(): boolean {
  return false;
}

export function shouldShowFreeClassroomSettingSuccessToast(kind: FreeClassroomSettingsItemKind): boolean {
  return kind === 'campus' || kind === 'threshold';
}

export function shouldShowFreeClassroomSettingFailureToast(kind: FreeClassroomSettingsItemKind): boolean {
  return kind === 'campus' || kind === 'threshold';
}

export function buildFreeClassroomSettingsMainItems(
  input: FreeClassroomSettingsMainInput,
): FreeClassroomSettingsMainItem[] {
  return [
    {
      kind: 'campus',
      title: '当前校区',
      subTitle: '',
      valueText: input.currentCampusName,
      checked: false,
    },
    {
      kind: 'hideBusy',
      title: '隐藏当前不空闲的教室',
      subTitle: '',
      valueText: '',
      checked: input.hideBusyClassroom,
    },
    {
      kind: 'threshold',
      title: '空闲时段阈值',
      subTitle: '不大于此值的空闲时段将被忽略',
      valueText: `${Math.max(0, Math.floor(input.freeMinutesThreshold))} 分钟`,
      checked: false,
    },
  ];
}

export function buildFreeClassroomCampusDialogModel(
  campuses: FreeClassroomCampusChoice[],
  currentCampusCode: string,
): FreeClassroomCampusDialogModel {
  let selectedCode = '';
  for (let i = 0; i < campuses.length; i++) {
    if (campuses[i].code === currentCampusCode) {
      selectedCode = currentCampusCode;
      break;
    }
  }
  if (selectedCode.length === 0 && campuses.length > 0) {
    selectedCode = campuses[0].code;
  }
  return {
    title: '切换校区',
    selectedCode,
    campuses,
  };
}
