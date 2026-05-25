import { describe, it, expect } from '@ohos/hypium';
import { clampScheduleFabOffsetY, getScheduleFabSpecs } from '../main/ets/components/schedule/weekNavigatorModel';

export default function weekNavigatorModelTest() {
  describe('Week navigator model', () => {
    it('matches Android schedule floating actions', 0, () => {
      const specs = getScheduleFabSpecs();

      expect(specs.length).assertEqual(4);
      expect(specs[0].action).assertEqual('next');
      expect(specs[1].action).assertEqual('prev');
      expect(specs[2].action).assertEqual('add');
      expect(specs[3].action).assertEqual('settings');
      expect(specs[0].sizeVp).assertEqual(42);
      expect(specs[0].gapVp).assertEqual(10);
    });

    it('clamps vertical drag like Android schedule floating actions', 0, () => {
      expect(clampScheduleFabOffsetY(12, 720, 198, 20)).assertEqual(0);
      expect(clampScheduleFabOffsetY(-1000, 720, 198, 20)).assertEqual(-482);
      expect(clampScheduleFabOffsetY(-120, 720, 198, 20)).assertEqual(-120);
    });
  });
}
