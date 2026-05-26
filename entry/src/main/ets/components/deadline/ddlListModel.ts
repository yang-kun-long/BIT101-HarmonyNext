export type DdlContentState = 'loading' | 'fetch-lexue' | 'empty' | 'list';
export type DdlFabAction = 'add' | 'settings';

export interface DdlFabSpec {
  action: DdlFabAction;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
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
