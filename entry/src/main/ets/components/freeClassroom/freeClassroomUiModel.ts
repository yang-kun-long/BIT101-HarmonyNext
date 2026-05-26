export type FreeClassroomFabAction = 'backToTop' | 'settings';

export interface FreeClassroomFabSpec {
  action: FreeClassroomFabAction;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
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
