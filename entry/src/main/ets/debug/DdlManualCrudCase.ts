import { DebugCase } from './DebugCase';
import { resolveDdlContentState } from '../components/deadline/ddlListModel';
import { DdlStore } from '../services/storage/DdlStore';
import type { DdlItem, ManualDdlInput } from '../services/deadline/DdlModels';

export class DdlManualCrudCase extends DebugCase {
  readonly name = 'DDL manual CRUD smoke';

  async run(): Promise<void> {
    this.logInfo('=== DdlManualCrudCase START ===');

    const store = new DdlStore();
    const previous: DdlItem[] = await store.getItems();
    const deadline = Date.now() + 24 * 60 * 60 * 1000;
    const createInput: ManualDdlInput = {
      title: 'Debug manual DDL',
      courseName: '',
      time: deadline,
      description: 'created by DdlManualCrudCase',
      location: '',
    };

    try {
      const created: DdlItem = await store.addManual(createInput, 1000);
      this.logInfo('created uid =', created.uid, 'title =', created.title);
      this.assertTrue(created.source === 'manual', 'created DDL should be manual');

      let items: DdlItem[] = await store.getItems();
      const createdIndex = items.findIndex((item: DdlItem) => item.uid === created.uid);
      this.assertTrue(createdIndex >= 0, 'created DDL should be persisted');

      const contentState = resolveDdlContentState(false, false, 1);
      this.logInfo('content state without subscribe URL and one local item =', contentState);
      this.assertEquals(contentState, 'list', 'local manual DDL should show list without subscribe URL');

      await store.updateManual(created.uid, {
        title: 'Debug manual DDL edited',
        courseName: '',
        time: deadline + 60 * 60 * 1000,
        description: 'edited by DdlManualCrudCase',
        location: '',
      }, 2000);

      items = await store.getItems();
      const edited = items.find((item: DdlItem) => item.uid === created.uid);
      this.assertTrue(!!edited, 'edited DDL should exist');
      this.assertEquals(edited?.title ?? '', 'Debug manual DDL edited', 'edited DDL title should persist');
      this.logInfo('edited uid =', created.uid, 'title =', edited?.title ?? '');

      await store.delete(created.uid);
      items = await store.getItems();
      const deletedIndex = items.findIndex((item: DdlItem) => item.uid === created.uid);
      this.assertTrue(deletedIndex < 0, 'deleted DDL should be removed');
      this.logInfo('deleted uid =', created.uid);
    } finally {
      await store.saveItems(previous);
      this.logInfo('previous DDL items restored, count =', previous.length);
    }

    this.logInfo('=== DdlManualCrudCase END ===');
  }
}
