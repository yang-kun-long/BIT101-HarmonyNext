import { describe, it, expect } from '@ohos/hypium';
import {
  buildDdlCardTextLines,
  getDdlEmptyText,
  getDdlFabSpecs,
  resolveDdlContentState,
} from '../main/ets/components/deadline/ddlListModel';
import type { DdlCardTextLines } from '../main/ets/components/deadline/ddlListModel';
import type { DdlItem } from '../main/ets/services/deadline/DdlModels';

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

    it('uses Android DDL empty-state copy', 0, () => {
      expect(getDdlEmptyText()).assertEqual('怎么会有人没事儿了啊ヽ(`Д´)ﾉ\n快去卷😭');
    });

    it('builds Android-style DDL card text lines', 0, () => {
      const now: number = new Date(2026, 4, 26, 8, 0, 0).getTime();
      const item: DdlItem = {
        uid: 'ddl-1',
        source: 'lexue',
        title: '实验报告 已到期',
        courseName: '数据结构',
        startTime: now + 60 * 60 * 1000,
        endTime: now + 60 * 60 * 1000,
        description: '提交 PDF',
        location: '线上',
        done: false,
        updatedAt: now,
      };

      const lines: DdlCardTextLines = buildDdlCardTextLines(item, now);

      expect(lines.title).assertEqual('实验报告');
      expect(lines.body).assertEqual('数据结构\n\n提交 PDF');
      expect(lines.remain).assertEqual('剩余 1小时 0分钟');
    });
  });
}
