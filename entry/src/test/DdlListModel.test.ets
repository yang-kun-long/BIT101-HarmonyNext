import { describe, it, expect } from '@ohos/hypium';
import {
  getDdlFabSpecs,
  resolveDdlContentState,
} from '../main/ets/components/deadline/ddlListModel';

export default function ddlListModelTest() {
  describe('DDL list Android parity model', () => {
    it('shows Lexue fetch CTA before any subscription URL exists', 0, () => {
      expect(resolveDdlContentState(true, false, 0)).assertEqual('loading');
      expect(resolveDdlContentState(false, false, 0)).assertEqual('fetch-lexue');
      expect(resolveDdlContentState(false, false, 2)).assertEqual('list');
      expect(resolveDdlContentState(false, true, 0)).assertEqual('empty');
    });

    it('uses Android DDL floating action button dimensions and order', 0, () => {
      const specs = getDdlFabSpecs();

      expect(specs.length).assertEqual(2);
      expect(specs[0].action).assertEqual('add');
      expect(specs[1].action).assertEqual('settings');
      expect(specs[0].sizeVp).assertEqual(42);
      expect(specs[0].iconVp).assertEqual(24);
      expect(specs[0].gapVp).assertEqual(10);
      expect(specs[1].sizeVp).assertEqual(42);
    });
  });
}
