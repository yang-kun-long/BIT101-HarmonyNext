import { describe, it, expect } from '@ohos/hypium';
import {
  FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP,
  FREE_CLASSROOM_FAB_RIGHT_PADDING_VP,
  formatNoBuildingTip,
  getFreeClassroomFabSpecs,
  resolveExpandedClassroomState,
  shouldResetFreeClassroomCampus,
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

    it('requests Android-style reset when selected campus changes', 0, () => {
      expect(shouldResetFreeClassroomCampus('', '', '', '')).assertFalse();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '01', '中关村校区')).assertFalse();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '02', '良乡校区')).assertTrue();
      expect(shouldResetFreeClassroomCampus('01', '中关村校区', '01', '良乡校区')).assertTrue();
    });
  });
}
