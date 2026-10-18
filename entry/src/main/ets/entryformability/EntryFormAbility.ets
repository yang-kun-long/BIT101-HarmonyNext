import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';
import { ScheduleWidgetPayload } from '../services/schoolSchedule/ScheduleWidgetModel';
import { loadScheduleWidgetPayload, registerScheduleWidget } from '../services/schoolSchedule/ScheduleWidgetPublisher';

export default class EntryFormAbility extends FormExtensionAbility {
  private logger: Logger = new Logger('EntryFormAbility');

  private buildPayload(): ScheduleWidgetPayload {
    return loadScheduleWidgetPayload(this.context.filesDir);
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const payload = this.buildPayload();
    const formId = String(want.parameters?.[formInfo.FormParam.IDENTITY_KEY] || '');
    if (formId) {
      registerScheduleWidget(this.context.filesDir, formId);
      this.scheduleRefresh(formId, payload.refreshMinutes);
    }
    this.logger.info('[FORM] added, cards=', payload.deck.cards.length, 'focus=', payload.deck.focusIndex);
    return formBindingData.createFormBindingData(payload);
  }

  async onUpdateForm(formId: string): Promise<void> {
    try {
      registerScheduleWidget(this.context.filesDir, formId);
      const payload = this.buildPayload();
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(payload));
      await this.scheduleRefresh(formId, payload.refreshMinutes);
      this.logger.info('[FORM] updated, cards=', payload.deck.cards.length, 'focus=', payload.deck.focusIndex);
    } catch (error) {
      this.logger.error('[FORM] update failed:', error);
    }
  }

  async onFormEvent(formId: string, _message: string): Promise<void> {
    await this.onUpdateForm(formId);
  }

  private async scheduleRefresh(formId: string, minutes: number): Promise<void> {
    try {
      await formProvider.setFormNextRefreshTime(formId, minutes);
    } catch (error) {
      this.logger.warn('[FORM] using periodic refresh:', error);
    }
  }

  onAcquireFormState(): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  onRemoveForm(formId: string): void {
    registerScheduleWidget(this.context.filesDir, formId, true);
  }
}
