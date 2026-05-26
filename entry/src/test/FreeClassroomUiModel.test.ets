import { describe, it, expect } from '@ohos/hypium';
import {
  FREE_CLASSROOM_FAB_BOTTOM_PADDING_VP,
  FREE_CLASSROOM_FAB_RIGHT_PADDING_VP,
  getFreeClassroomFabSpecs,
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
  });
}
