import { describe, it, expect } from '@ohos/hypium';
import {
  mapCurrentTermResponse,
  mapFirstDayResponse,
  mapTermListResponse,
} from '../main/ets/services/jw/courseTermRepository';

export default function courseTermRepositoryTest() {
  describe('Course term repository helpers', () => {
    it('maps current term response from Android JXZX API', 0, () => {
      const term = mapCurrentTermResponse({
        datas: {
          dqxnxq: {
            rows: [{ DM: '2025-2026-2' }],
          },
        },
      });

      expect(term).assertEqual('2025-2026-2');
    });

    it('maps selectable term list and drops invalid rows', 0, () => {
      const terms = mapTermListResponse({
        datas: {
          xnxqcx: {
            rows: [
              { DM: '2025-2026-2' },
              { DM: '' },
              { DM: '2024-2025-1' },
            ],
          },
        },
      });

      expect(terms.length).assertEqual(2);
      expect(terms[0]).assertEqual('2025-2026-2');
      expect(terms[1]).assertEqual('2024-2025-1');
    });

    it('maps first day response by finding school week one', 0, () => {
      const firstDay = mapFirstDayResponse({
        data: [
          { XQ: 2, RQ: '2026-02-24' },
          { XQ: 1, RQ: '2026-02-23' },
        ],
      });

      expect(firstDay).assertEqual('2026-02-23');
    });
  });
}
