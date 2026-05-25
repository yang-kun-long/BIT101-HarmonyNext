export interface ScheduleFabSpec {
  action: string;
  sizeVp: number;
  iconVp: number;
  gapVp: number;
}

export const SCHEDULE_FAB_VERTICAL_PADDING_VP = 20;
export const SCHEDULE_FAB_HORIZONTAL_PADDING_VP = 10;

export function getScheduleFabSpecs(): ScheduleFabSpec[] {
  return [
    { action: 'next', sizeVp: 42, iconVp: 24, gapVp: 10 },
    { action: 'prev', sizeVp: 42, iconVp: 24, gapVp: 10 },
    { action: 'add', sizeVp: 42, iconVp: 24, gapVp: 10 },
    { action: 'settings', sizeVp: 42, iconVp: 24, gapVp: 10 },
  ];
}

export function getScheduleFabStackHeightVp(): number {
  const specs = getScheduleFabSpecs();
  let total = 0;
  for (let i = 0; i < specs.length; i++) {
    total += specs[i].sizeVp;
    if (i < specs.length - 1) {
      total += specs[i].gapVp;
    }
  }
  return total;
}

export function clampScheduleFabOffsetY(
  nextOffsetY: number,
  containerHeightVp: number,
  fabsHeightVp: number,
  verticalPaddingVp: number
): number {
  if (containerHeightVp <= 0 || fabsHeightVp <= 0) {
    return 0;
  }

  const minOffsetY = Math.min(0, -containerHeightVp + verticalPaddingVp * 2 + fabsHeightVp);
  if (nextOffsetY > 0) {
    return 0;
  }
  if (nextOffsetY < minOffsetY) {
    return minOffsetY;
  }
  return nextOffsetY;
}
