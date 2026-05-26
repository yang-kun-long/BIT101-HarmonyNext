import type { DdlItem } from '../../services/deadline/DdlModels';
import { formatDdlRemainText } from '../../services/deadline/DdlModels';

export type DdlContentState = 'loading' | 'fetch-lexue' | 'empty' | 'list';
export type DdlFabAction = 'add' | 'settings';

export interface DdlFabSpec {
  action: DdlFabAction;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
}

export interface DdlCardTextLines {
  title: string;
  body: string;
  remain: string;
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
  if (visibleItemCount > 0) {
    return 'list';
  }
  if (!hasSubscribeUrl) {
    return 'fetch-lexue';
  }
  return 'empty';
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
