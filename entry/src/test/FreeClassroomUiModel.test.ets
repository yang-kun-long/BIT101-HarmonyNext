import { describe, it, expect } from '@ohos/hypium';
import {
  FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP,
  FREE_CLASSROOM_FAB_RIGHT_PADDING_VP,
  buildFreeClassroomCampusDialogModel,
  buildFreeClassroomSettingsMainItems,
  formatNoBuildingTip,
  getFreeClassroomFabSpecs,
  resolveFreeClassroomBuildingListState,
  resolveExpandedClassroomState,
  shouldShowFreeClassroomBackToTop,
  shouldResetFreeClassroomCampus,
  shouldRenderFreeClassroomSummaryHeader,
  shouldRenderFreeClassroomSettingsInlineError,
  shouldShowFreeClassroomCampusLoadingText,
  shouldShowFreeClassroomSettingFailureToast,
  shouldShowFreeClassroomSettingSuccessToast,
} from '../main/ets/components/freeClassroom/freeClassroomUiModel';
import type {
  FreeClassroomCampusDialogModel,
  FreeClassroomSettingsMainItem,
} from '../main/ets/components/freeClassroom/freeClassroomUiModel';

export default function freeClassroomUiModelTest() {
  describe('Free classroom UI Android parity model', () => {
    it('uses Android free classroom floating action button dimensions and order', 0, () => {
      const specs = getFreeClassroomFabSpecs();

      expect(specs.length).assertEqual(2);
      expect(specs[0].action).assertEqual('backToTop');
      expect(specs[1].action).assertEqual('settings');
      expect(specs[0].sizeVp).assertEqual(42);
      expect(specs[0].iconVp).assertEqual(24);
      expect(specs[0].gapVp).assertEqual(10);
      expect(specs[1].sizeVp).assertEqual(42);
      expect(FREE_CLASSROOM_FAB_RIGHT_PADDING_VP).assertEqual(10);
      expect(FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP).assertEqual(20);
    });

    it('formats Android empty-building tip for selected campus', 0, () => {
      expect(formatNoBuildingTip('')).assertEqual('');
      expect(formatNoBuildingTip('中关村校区')).assertEqual('没有获取到中关村校区的教学楼QwQ\n(请尝试在设置中切换校区)');
      expect(formatNoBuildingTip('良乡')).assertEqual('没有获取到良乡校区的教学楼QwQ\n(请尝试在设置中切换校区)');
    });

    it('matches Android expanded classroom content states', 0, () => {
      expect(resolveExpandedClassroomState(true, '', 0)).assertEqual('loading');
      expect(resolveExpandedClassroomState(false, '', 2)).assertEqual('list');
      expect(resolveExpandedClassroomState(false, '', 0)).assertEqual('empty');
      expect(resolveExpandedClassroomState(false, 'network failed', 0)).assertEqual('empty');
    });

    it('does not show an inline building-load error row like Android', 0, () => {
      expect(resolveFreeClassroomBuildingListState(true, '', 0)).assertEqual('loading');
      expect(resolveFreeClassroomBuildingListState(false, '', 2)).assertEqual('list');
      expect(resolveFreeClassroomBuildingListState(false, '', 0)).assertEqual('empty');
      expect(resolveFreeClassroomBuildingListState(false, 'network failed', 0)).assertEqual('empty');
    });

    it('requests Android-style reset when selected campus changes', 0, () => {
      expect(shouldResetFreeClassroomCampus('', '', '', '')).assertFalse();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '01', '中关村校区')).assertFalse();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '02', '良乡校区')).assertTrue();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '01', '良乡校区')).assertTrue();
    });

    it('shows Android back-to-top FAB once the first row has scrolled away', 0, () => {
      expect(shouldShowFreeClassroomBackToTop(0)).assertFalse();
      expect(shouldShowFreeClassroomBackToTop(1)).assertTrue();
    });

    it('does not render the non-Android free classroom summary header', 0, () => {
      expect(shouldRenderFreeClassroomSummaryHeader()).assertFalse();
    });

    it('does not render raw settings load errors inline like Android', 0, () => {
      expect(shouldRenderFreeClassroomSettingsInlineError('network failed')).assertFalse();
      expect(shouldRenderFreeClassroomSettingsInlineError('')).assertFalse();
    });

    it('builds Android-style free classroom settings main rows without inline campus choices', 0, () => {
      const items: FreeClassroomSettingsMainItem[] = buildFreeClassroomSettingsMainItems({
        currentCampusName: '中关村校区',
        hideBusyClassroom: true,
        freeMinutesThreshold: 5,
      });

      expect(items.length).assertEqual(3);
      expect(items[0].title).assertEqual('当前校区');
      expect(items[0].valueText).assertEqual('中关村校区');
      expect(items[1].title).assertEqual('隐藏当前不空闲的教室');
      expect(items[1].checked).assertTrue();
      expect(items[2].title).assertEqual('空闲时段阈值');
      expect(items[2].valueText).assertEqual('5 分钟');
    });

    it('matches Android free classroom settings success toast triggers', 0, () => {
      expect(shouldShowFreeClassroomSettingSuccessToast('campus')).assertTrue();
      expect(shouldShowFreeClassroomSettingSuccessToast('threshold')).assertTrue();
      expect(shouldShowFreeClassroomSettingSuccessToast('hideBusy')).assertFalse();
    });

    it('matches Android free classroom settings failure toast triggers', 0, () => {
      expect(shouldShowFreeClassroomSettingFailureToast('campus')).assertTrue();
      expect(shouldShowFreeClassroomSettingFailureToast('threshold')).assertTrue();
      expect(shouldShowFreeClassroomSettingFailureToast('hideBusy')).assertFalse();
    });

    it('builds Android-style campus dialog selection without an extra all-campus row', 0, () => {
      const model: FreeClassroomCampusDialogModel = buildFreeClassroomCampusDialogModel([
        { code: '1', displayName: '中关村校区' },
        { code: '2', displayName: '良乡校区' },
      ], 'unknown');

      expect(model.title).assertEqual('切换校区');
      expect(model.selectedCode).assertEqual('1');
      expect(model.campuses.length).assertEqual(2);
      expect(model.campuses[0].displayName).assertEqual('中关村校区');
    });

    it('does not show loading helper text in Android-style campus dialog', 0, () => {
      expect(shouldShowFreeClassroomCampusLoadingText()).assertFalse();
    });
  });
}
