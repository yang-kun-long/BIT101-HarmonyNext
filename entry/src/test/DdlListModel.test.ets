import { describe, it, expect } from '@ohos/hypium';
import {
  buildDdlSettingsDataItems,
  buildDdlSettingsResultToast,
  buildDdlDeleteConfirmModel,
  buildDdlEditDialogModel,
  buildDdlDetailModel,
  buildDdlCardTextLines,
  getDdlCardLayoutSpec,
  getDdlEmptyLayoutSpec,
  getDdlFetchLexueCtaModel,
  getDdlFetchLexueToastPolicy,
  getDdlSettingsDataActionToastPolicy,
  formatDdlDatePickerValue,
  formatDdlTimePickerValue,
  getDdlEmptyText,
  getDdlFabSpecs,
  resolveDdlContentState,
  shouldDismissDdlSettingsNumberDialogFromParent,
  shouldAutoSyncDdlOnAppear,
  validateDdlSettingsNumberInput,
  validateDdlEditInput,
} from '../main/ets/components/deadline/ddlListModel';
import type {
  DdlEmptyLayoutSpec,
  DdlFetchLexueCtaModel,
  DdlFetchLexueToastPolicy,
  DdlSettingsDataActionToastPolicy,
  DdlCardTextLines,
  DdlDeleteConfirmModel,
  DdlDetailModel,
  DdlEditDialogModel,
  DdlSettingsItem,
  DdlSettingsResultAction,
  DdlSettingsNumberValidationResult,
  DdlEditValidationResult,
} from '../main/ets/components/deadline/ddlListModel';
import type { DdlItem } from '../main/ets/services/deadline/DdlModels';

export default function ddlListModelTest() {
  describe('DDL list Android parity model', () => {
    it('shows Lexue fetch CTA only when no subscription URL and no local items exist', 0, () => {
      expect(resolveDdlContentState(true, false, 0)).assertEqual('loading');
      expect(resolveDdlContentState(false, false, 0)).assertEqual('fetch-lexue');
      expect(resolveDdlContentState(false, false, 2)).assertEqual('list');
      expect(resolveDdlContentState(false, true, 0)).assertEqual('empty');
      expect(resolveDdlContentState(false, true, 2)).assertEqual('list');
    });

    it('auto-syncs DDL silently on appear only after a subscription URL exists', 0, () => {
      expect(shouldAutoSyncDdlOnAppear(false, false, false)).assertFalse();
      expect(shouldAutoSyncDdlOnAppear(true, true, false)).assertFalse();
      expect(shouldAutoSyncDdlOnAppear(true, false, true)).assertFalse();
      expect(shouldAutoSyncDdlOnAppear(true, false, false)).assertTrue();
    });

    it('uses Android-style Lexue fetch CTA loading content', 0, () => {
      const idle: DdlFetchLexueCtaModel = getDdlFetchLexueCtaModel(false);
      const loading: DdlFetchLexueCtaModel = getDdlFetchLexueCtaModel(true);

      expect(idle.showSpinner).assertFalse();
      expect(idle.text).assertEqual('获取乐学日程');
      expect(loading.showSpinner).assertTrue();
      expect(loading.text).assertEqual('');
    });

    it('keeps Android main DDL fetch CTA silent except failures', 0, () => {
      const policy: DdlFetchLexueToastPolicy = getDdlFetchLexueToastPolicy();

      expect(policy.showStartToast).assertFalse();
      expect(policy.showSuccessToast).assertFalse();
      expect(policy.showFailureToast).assertTrue();
    });

    it('builds Android-style DDL settings data rows', 0, () => {
      const items: DdlSettingsItem[] = buildDdlSettingsDataItems(false, true);

      expect(items.length).assertEqual(2);
      expect(items[0].title).assertEqual('重新获取订阅链接');
      expect(items[0].subTitle).assertEqual('重新获取订阅链接');
      expect(items[0].enabled).assertTrue();
      expect(items[1].title).assertEqual('重新拉取乐学日程');
      expect(items[1].subTitle).assertEqual('请先获取订阅链接哦');
      expect(items[1].enabled).assertFalse();
    });

    it('builds Android-style DDL settings result toast copy', 0, () => {
      const urlAction: DdlSettingsResultAction = 'refreshSubscribeUrl';
      const calendarAction: DdlSettingsResultAction = 'refreshLexueCalendar';

      expect(buildDdlSettingsResultToast(urlAction, true)).assertEqual('获取成功');
      expect(buildDdlSettingsResultToast(urlAction, false)).assertEqual('获取失败');
      expect(buildDdlSettingsResultToast(calendarAction, true)).assertEqual('拉取成功');
      expect(buildDdlSettingsResultToast(calendarAction, false)).assertEqual('拉取失败');
    });

    it('keeps Android DDL settings data actions quiet until result', 0, () => {
      const policy: DdlSettingsDataActionToastPolicy = getDdlSettingsDataActionToastPolicy();

      expect(policy.showStartToast).assertFalse();
      expect(policy.showResultToast).assertTrue();
    });

    it('validates DDL settings number input like Android InputNumberDialog', 0, () => {
      const ok: DdlSettingsNumberValidationResult = validateDdlSettingsNumberInput('12');
      const empty: DdlSettingsNumberValidationResult = validateDdlSettingsNumberInput('');
      const mixed: DdlSettingsNumberValidationResult = validateDdlSettingsNumberInput('12abc');
      const negative: DdlSettingsNumberValidationResult = validateDdlSettingsNumberInput('-1');

      expect(ok.isValid).assertTrue();
      expect(ok.value).assertEqual(12);
      expect(empty.isValid).assertFalse();
      expect(empty.errorText).assertEqual('格式校验失败Orz');
      expect(mixed.isValid).assertFalse();
      expect(mixed.errorText).assertEqual('格式校验失败Orz');
      expect(negative.isValid).assertFalse();
      expect(negative.errorText).assertEqual('格式校验失败Orz');
    });

    it('closes DDL settings number dialog through the owning page to avoid missing controller injection', 0, () => {
      expect(shouldDismissDdlSettingsNumberDialogFromParent()).assertTrue();
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

    it('uses Android DDL empty-state card layout', 0, () => {
      const spec: DdlEmptyLayoutSpec = getDdlEmptyLayoutSpec();

      expect(spec.fullWidth).assertTrue();
      expect(spec.horizontalOuterPaddingVp).assertEqual(10);
      expect(spec.verticalOuterPaddingVp).assertEqual(5);
      expect(spec.horizontalInnerPaddingVp).assertEqual(10);
      expect(spec.verticalInnerPaddingVp).assertEqual(5);
      expect(spec.cornerRadiusVp).assertEqual(8);
      expect(spec.hasContainerBackground).assertTrue();
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

    it('uses Android single deadline time for DDL card detail and edit display', 0, () => {
      const now: number = new Date(2026, 4, 26, 8, 0, 0).getTime();
      const deadline: number = new Date(2026, 4, 26, 9, 0, 0).getTime();
      const laterCalendarEnd: number = new Date(2026, 4, 26, 18, 0, 0).getTime();
      const item: DdlItem = {
        uid: 'ddl-window',
        source: 'lexue',
        title: '窗口型作业',
        courseName: '数据结构',
        startTime: deadline,
        endTime: laterCalendarEnd,
        description: '提交 PDF',
        location: '',
        done: false,
        updatedAt: now,
      };

      const lines: DdlCardTextLines = buildDdlCardTextLines(item, now);
      const detail: DdlDetailModel = buildDdlDetailModel(item);
      const edit: DdlEditDialogModel = buildDdlEditDialogModel(item);

      expect(lines.remain).assertEqual('剩余 1小时 0分钟');
      expect(detail.rows[0].content).assertEqual('2026-05-26 09:00:00');
      expect(edit.initialDateText).assertEqual('2026-05-26');
      expect(edit.initialTimeText).assertEqual('09:00:00');
    });

    it('places the DDL checkbox inside the card trailing edge like Android', 0, () => {
      const spec = getDdlCardLayoutSpec();

      expect(spec.checkboxPlacement).assertEqual('trailing-inside-card');
      expect(spec.contentStartPaddingVp).assertEqual(15);
      expect(spec.contentEndPaddingVp).assertEqual(5);
    });

    it('builds Android-style DDL detail sections and actions', 0, () => {
      const deadline: number = new Date(2026, 4, 26, 23, 59, 0).getTime();
      const lexueItem: DdlItem = {
        uid: 'lexue-1',
        source: 'lexue',
        title: '实验报告 已到期',
        courseName: '数据结构',
        startTime: deadline,
        endTime: deadline,
        description: '提交 PDF',
        location: '线上',
        done: false,
        updatedAt: deadline,
      };
      const manualItem: DdlItem = {
        uid: 'manual-1',
        source: 'manual',
        title: '自定义 DDL',
        courseName: '',
        startTime: deadline,
        endTime: deadline,
        description: '自定义备注',
        location: '',
        done: false,
        updatedAt: deadline,
      };

      const lexueModel: DdlDetailModel = buildDdlDetailModel(lexueItem);
      const manualModel: DdlDetailModel = buildDdlDetailModel(manualItem);

      expect(lexueModel.title).assertEqual('实验报告 已到期');
      expect(lexueModel.rows.length).assertEqual(3);
      expect(lexueModel.rows[0].title).assertEqual('DDL：');
      expect(lexueModel.rows[0].content).assertEqual('2026-05-26 23:59:00');
      expect(lexueModel.rows[1].content).assertEqual('乐学');
      expect(lexueModel.rows[2].content).assertEqual('数据结构\n\n提交 PDF');
      expect(lexueModel.canEditDelete).assertFalse();
      expect(manualModel.canEditDelete).assertTrue();
      expect(manualModel.rows[1].content).assertEqual('自定义');
    });

    it('builds Android-style DDL delete confirmation copy', 0, () => {
      const deadline: number = new Date(2026, 4, 26, 23, 59, 0).getTime();
      const item: DdlItem = {
        uid: 'manual-1',
        source: 'manual',
        title: '自定义 DDL',
        courseName: '',
        startTime: deadline,
        endTime: deadline,
        description: '',
        location: '',
        done: false,
        updatedAt: deadline,
      };

      const model: DdlDeleteConfirmModel = buildDdlDeleteConfirmModel(item);

      expect(model.title).assertEqual('确认删除吗？');
      expect(model.message).assertEqual('自定义 DDL 删除后不可恢复');
      expect(model.confirmText).assertEqual('删除');
      expect(model.cancelText).assertEqual('取消');
      expect(model.successToast).assertEqual('删除成功OvO');
    });

    it('builds Android-style DDL edit dialog labels and defaults', 0, () => {
      const createModel: DdlEditDialogModel = buildDdlEditDialogModel(null);
      expect(createModel.title).assertEqual('添加DDL');
      expect(createModel.titlePlaceholder).assertEqual('标题');
      expect(createModel.datePlaceholder).assertEqual('请选择日期');
      expect(createModel.timePlaceholder).assertEqual('请选择时间');
      expect(createModel.dateFieldType).assertEqual('picker');
      expect(createModel.timeFieldType).assertEqual('picker');
      expect(createModel.timeRequiresDate).assertTrue();
      expect(createModel.detailPlaceholder).assertEqual('详情');
      expect(createModel.confirmText).assertEqual('确定');
      expect(createModel.cancelText).assertEqual('取消');
      expect(createModel.addSuccessToast).assertEqual('添加成功OvO');
      expect(createModel.editSuccessToast).assertEqual('修改成功OvO');
      expect(createModel.initialDateText).assertEqual('');
      expect(createModel.initialTimeText).assertEqual('');

      const deadline: number = new Date(2026, 4, 26, 23, 59, 0).getTime();
      const item: DdlItem = {
        uid: 'manual-1',
        source: 'manual',
        title: '自定义 DDL',
        courseName: '被详情合并，不在编辑框单独显示',
        startTime: deadline,
        endTime: deadline,
        description: '自定义备注',
        location: '地点不在 Android 编辑框单独显示',
        done: false,
        updatedAt: deadline,
      };

      const editModel: DdlEditDialogModel = buildDdlEditDialogModel(item);
      expect(editModel.title).assertEqual('编辑DDL');
      expect(editModel.initialTitle).assertEqual('自定义 DDL');
      expect(editModel.initialDateText).assertEqual('2026-05-26');
      expect(editModel.initialTimeText).assertEqual('23:59:00');
      expect(editModel.initialDetail).assertEqual('自定义备注');
    });

    it('formats legacy DatePicker accept results for DDL date chips', 0, () => {
      expect(formatDdlDatePickerValue({ year: 2026, month: 4, day: 26 })).assertEqual('2026-05-26');
    });

    it('formats TimePicker results for DDL time chips', 0, () => {
      expect(formatDdlTimePickerValue({ hour: 8, minute: 5 })).assertEqual('08:05:00');
      expect(formatDdlTimePickerValue({ hour: 23, minute: 59, second: 7 })).assertEqual('23:59:07');
    });

    it('validates DDL edit input with Android error copy', 0, () => {
      const titleResult: DdlEditValidationResult = validateDdlEditInput('', 1000);
      const timeResult: DdlEditValidationResult = validateDdlEditInput('自定义 DDL', 0);
      const okResult: DdlEditValidationResult = validateDdlEditInput('自定义 DDL', 1000);

      expect(titleResult.isValid).assertFalse();
      expect(titleResult.errorText).assertEqual('标题不能为空');
      expect(timeResult.isValid).assertFalse();
      expect(timeResult.errorText).assertEqual('请选择日期和时间');
      expect(okResult.isValid).assertTrue();
      expect(okResult.errorText).assertEqual('');
    });
  });
}
