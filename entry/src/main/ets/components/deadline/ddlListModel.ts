import type { DdlItem } from '../../services/deadline/DdlModels';
import { formatDdlRemainText } from '../../services/deadline/DdlModels';

export type DdlContentState = 'loading' | 'fetch-lexue' | 'empty' | 'list';
export type DdlFabAction = 'add' | 'settings';
export type DdlEditFieldType = 'picker';

export interface DdlFabSpec {
  action: DdlFabAction;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
}

export interface DdlFetchLexueCtaModel {
  showSpinner: boolean;
  text: string;
}

export interface DdlCardTextLines {
  title: string;
  body: string;
  remain: string;
}

export type DdlCardCheckboxPlacement = 'trailing-inside-card';

export interface DdlCardLayoutSpec {
  checkboxPlacement: DdlCardCheckboxPlacement;
  contentStartPaddingVp: number;
  contentEndPaddingVp: number;
  contentVerticalPaddingVp: number;
}

export interface DdlEmptyLayoutSpec {
  fullWidth: boolean;
  horizontalOuterPaddingVp: number;
  verticalOuterPaddingVp: number;
  horizontalInnerPaddingVp: number;
  verticalInnerPaddingVp: number;
  cornerRadiusVp: number;
  hasContainerBackground: boolean;
}

export interface DdlDetailRow {
  title: string;
  content: string;
}

export interface DdlDetailModel {
  title: string;
  rows: DdlDetailRow[];
  canEditDelete: boolean;
}

export interface DdlDeleteConfirmModel {
  title: string;
  message: string;
  confirmText: string;
  cancelText: string;
  successToast: string;
}

export interface DdlEditDialogModel {
  title: string;
  titlePlaceholder: string;
  datePlaceholder: string;
  timePlaceholder: string;
  dateFieldType: DdlEditFieldType;
  timeFieldType: DdlEditFieldType;
  timeRequiresDate: boolean;
  detailPlaceholder: string;
  confirmText: string;
  cancelText: string;
  addSuccessToast: string;
  editSuccessToast: string;
  initialTitle: string;
  initialDateText: string;
  initialTimeText: string;
  initialDetail: string;
}

export interface DdlEditValidationResult {
  isValid: boolean;
  errorText: string;
}

export type DdlSettingsDataAction = 'refreshSubscribeUrl' | 'refreshLexueCalendar';
export type DdlSettingsResultAction = DdlSettingsDataAction;

export interface DdlSettingsItem {
  action: DdlSettingsDataAction;
  title: string;
  subTitle: string;
  enabled: boolean;
}

export interface DdlSettingsNumberValidationResult {
  isValid: boolean;
  value: number;
  errorText: string;
}

export interface DdlDatePickerResultValue {
  year?: number;
  month?: number;
  day?: number;
}

export interface DdlTimePickerResultValue {
  hour?: number;
  minute?: number;
  second?: number;
}

export const DDL_FAB_SIZE_VP = 42;
export const DDL_FAB_ICON_VP = 24;
export const DDL_FAB_GAP_VP = 10;
export const DDL_FAB_RIGHT_PADDING_VP = 10;
export const DDL_FAB_BOTTOM_PADDING_VP = 20;
export const DDL_EMPTY_TEXT = '怎么会有人没事儿了啊ヽ(`Д´)ﾉ\n快去卷😭';

export function resolveDdlContentState(
  loading: boolean,
  hasSubscribeUrl: boolean,
  visibleItemCount: number,
): DdlContentState {
  if (loading) {
    return 'loading';
  }
  if (!hasSubscribeUrl) {
    return 'fetch-lexue';
  }
  if (visibleItemCount > 0) {
    return 'list';
  }
  return 'empty';
}

export function shouldAutoSyncDdlOnAppear(
  hasSubscribeUrl: boolean,
  loading: boolean,
  isFetchingLexue: boolean,
): boolean {
  return hasSubscribeUrl && !loading && !isFetchingLexue;
}

export function getDdlFetchLexueCtaModel(isFetchingLexue: boolean): DdlFetchLexueCtaModel {
  if (isFetchingLexue) {
    return {
      showSpinner: true,
      text: '',
    };
  }
  return {
    showSpinner: false,
    text: '获取乐学日程',
  };
}

export function buildDdlSettingsDataItems(
  isUpdatingLexueCalendarUrl: boolean,
  isUpdatingLexueCalendar: boolean,
): DdlSettingsItem[] {
  return [
    {
      action: 'refreshSubscribeUrl',
      title: '重新获取订阅链接',
      subTitle: '重新获取订阅链接',
      enabled: !isUpdatingLexueCalendarUrl,
    },
    {
      action: 'refreshLexueCalendar',
      title: '重新拉取乐学日程',
      subTitle: '请先获取订阅链接哦',
      enabled: !isUpdatingLexueCalendar,
    },
  ];
}

export function buildDdlSettingsResultToast(action: DdlSettingsResultAction, success: boolean): string {
  if (action === 'refreshSubscribeUrl') {
    return success ? '获取成功' : '获取失败';
  }
  return success ? '拉取成功' : '拉取失败';
}

export function validateDdlSettingsNumberInput(input: string): DdlSettingsNumberValidationResult {
  const trimmed: string = input.trim();
  if (!/^\d+$/.test(trimmed)) {
    return {
      isValid: false,
      value: 0,
      errorText: '格式校验失败Orz',
    };
  }
  const value: number = Number(trimmed);
  if (!Number.isFinite(value) || value < 0) {
    return {
      isValid: false,
      value: 0,
      errorText: '格式校验失败Orz',
    };
  }
  return {
    isValid: true,
    value,
    errorText: '',
  };
}

export function getDdlFabSpecs(): DdlFabSpec[] {
  return [
    {
      action: 'add',
      sizeVp: DDL_FAB_SIZE_VP,
      iconVp: DDL_FAB_ICON_VP,
      gapVp: DDL_FAB_GAP_VP,
    },
    {
      action: 'settings',
      sizeVp: DDL_FAB_SIZE_VP,
      iconVp: DDL_FAB_ICON_VP,
      gapVp: DDL_FAB_GAP_VP,
    },
  ];
}

export function getDdlEmptyText(): string {
  return DDL_EMPTY_TEXT;
}

export function getDdlEmptyLayoutSpec(): DdlEmptyLayoutSpec {
  return {
    fullWidth: true,
    horizontalOuterPaddingVp: 10,
    verticalOuterPaddingVp: 5,
    horizontalInnerPaddingVp: 10,
    verticalInnerPaddingVp: 5,
    cornerRadiusVp: 8,
    hasContainerBackground: true,
  };
}

export function getDdlCardLayoutSpec(): DdlCardLayoutSpec {
  return {
    checkboxPlacement: 'trailing-inside-card',
    contentStartPaddingVp: 15,
    contentEndPaddingVp: 5,
    contentVerticalPaddingVp: 15,
  };
}

function normalizeDdlText(text: string): string {
  let out: string = text.replace(/\\n/g, '\n');
  out = out.replace(/[ \u00A0\t]*\n[ \u00A0\t]*/g, '\n');
  out = out.replace(/\n{3,}/g, '\n\n');
  return out.trim();
}

export function buildDdlCardTextLines(item: DdlItem, nowMs: number): DdlCardTextLines {
  let title: string = item.title ?? '(未命名 DDL)';
  title = title.replace(/\s*已到期\s*$/u, '');
  const courseName: string = normalizeDdlText(item.courseName ?? '');
  const description: string = normalizeDdlText(item.description ?? '');
  let body: string = description;
  if (courseName.length > 0 && description.length > 0) {
    body = `${courseName}\n\n${description}`;
  } else if (courseName.length > 0) {
    body = courseName;
  }
  const deadline: number = item.endTime > 0 ? item.endTime : item.startTime;
  return {
    title,
    body,
    remain: formatDdlRemainText(deadline, nowMs),
  };
}

function formatDdlDetailTime(timestamp: number): string {
  const d = new Date(timestamp);
  const year = d.getFullYear().toString();
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  const hour = d.getHours().toString().padStart(2, '0');
  const minute = d.getMinutes().toString().padStart(2, '0');
  const second = d.getSeconds().toString().padStart(2, '0');
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

function formatDdlEditDate(timestamp: number): string {
  const d = new Date(timestamp);
  const year = d.getFullYear().toString();
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatDdlDatePickerValue(value: Date | DdlDatePickerResultValue): string {
  if (value instanceof Date) {
    return formatDdlEditDate(value.getTime());
  }

  if (value.year === undefined || value.month === undefined || value.day === undefined) {
    return '';
  }

  const year = value.year.toString();
  const month = (value.month + 1).toString().padStart(2, '0');
  const day = value.day.toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatDdlTimePickerValue(value: DdlTimePickerResultValue): string {
  if (value.hour === undefined || value.minute === undefined) {
    return '';
  }

  const second = value.second === undefined ? 0 : value.second;
  const hourText = value.hour.toString().padStart(2, '0');
  const minuteText = value.minute.toString().padStart(2, '0');
  const secondText = second.toString().padStart(2, '0');
  return `${hourText}:${minuteText}:${secondText}`;
}

function formatDdlEditTime(timestamp: number): string {
  const d = new Date(timestamp);
  const hour = d.getHours().toString().padStart(2, '0');
  const minute = d.getMinutes().toString().padStart(2, '0');
  const second = d.getSeconds().toString().padStart(2, '0');
  return `${hour}:${minute}:${second}`;
}

export function buildDdlDetailModel(item: DdlItem): DdlDetailModel {
  const deadline: number = item.endTime > 0 ? item.endTime : item.startTime;
  const courseName: string = normalizeDdlText(item.courseName ?? '');
  const description: string = normalizeDdlText(item.description ?? '');
  let detail: string = description;
  if (courseName.length > 0 && description.length > 0) {
    detail = `${courseName}\n\n${description}`;
  } else if (courseName.length > 0) {
    detail = courseName;
  }

  return {
    title: item.title ?? '(未命名 DDL)',
    rows: [
      { title: 'DDL：', content: formatDdlDetailTime(deadline) },
      { title: '分组：', content: item.source === 'lexue' ? '乐学' : '自定义' },
      { title: '详情：', content: detail },
    ],
    canEditDelete: item.source !== 'lexue',
  };
}

export function buildDdlDeleteConfirmModel(item: DdlItem): DdlDeleteConfirmModel {
  return {
    title: '确认删除吗？',
    message: `${item.title ?? '(未命名 DDL)'} 删除后不可恢复`,
    confirmText: '删除',
    cancelText: '取消',
    successToast: '删除成功OvO',
  };
}

export function buildDdlEditDialogModel(item: DdlItem | null): DdlEditDialogModel {
  const deadline: number = item ? (item.endTime > 0 ? item.endTime : item.startTime) : 0;
  return {
    title: item === null ? '添加DDL' : '编辑DDL',
    titlePlaceholder: '标题',
    datePlaceholder: '请选择日期',
    timePlaceholder: '请选择时间',
    dateFieldType: 'picker',
    timeFieldType: 'picker',
    timeRequiresDate: true,
    detailPlaceholder: '详情',
    confirmText: '确定',
    cancelText: '取消',
    addSuccessToast: '添加成功OvO',
    editSuccessToast: '修改成功OvO',
    initialTitle: item?.title ?? '',
    initialDateText: item === null ? '' : formatDdlEditDate(deadline),
    initialTimeText: item === null ? '' : formatDdlEditTime(deadline),
    initialDetail: item?.description ?? '',
  };
}

export function validateDdlEditInput(title: string, deadline: number): DdlEditValidationResult {
  if (title.trim().length === 0) {
    return {
      isValid: false,
      errorText: '标题不能为空',
    };
  }
  if (deadline <= 0 || !Number.isFinite(deadline)) {
    return {
      isValid: false,
      errorText: '请选择日期和时间',
    };
  }
  return {
    isValid: true,
    errorText: '',
  };
}
