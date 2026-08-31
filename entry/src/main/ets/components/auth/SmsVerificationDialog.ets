import {
  globalSmsChallengeCoordinator,
  PendingSmsChallenge,
  SmsChallengePurpose,
} from '../../services/auth/SmsChallengeCoordinator';
import { Logger } from '../../utils/Logger';

const logger = new Logger('SmsChallengeDialog');

@Component
export struct SmsChallengeDialogHost {
  private dialogController: CustomDialogController | null = null;
  private activeChallengeId: number = 0;
  private unregisterHost: (() => void) | null = null;

  aboutToAppear(): void {
    logger.info('register host');
    this.unregisterHost = globalSmsChallengeCoordinator.registerHost(
      (pending: PendingSmsChallenge | null): void => this.onChallengeChanged(pending),
    );
  }

  aboutToDisappear(): void {
    logger.info('unregister host');
    this.unregisterHost?.();
    this.unregisterHost = null;
    this.dialogController?.close();
    this.dialogController = null;
    this.activeChallengeId = 0;
  }

  private onChallengeChanged(pending: PendingSmsChallenge | null): void {
    logger.info(
      'challenge changed',
      'id=', pending?.id ?? 0,
      'purpose=', pending?.purpose ?? '',
    );
    if (!pending) {
      this.dialogController?.close();
      this.dialogController = null;
      this.activeChallengeId = 0;
      return;
    }
    if (pending.id === this.activeChallengeId) return;

    this.dialogController?.close();
    this.activeChallengeId = pending.id;
    this.dialogController = new CustomDialogController({
      builder: SmsVerificationDialog({
        maskedPhone: pending.maskedPhone,
        purpose: pending.purpose,
        onConfirm: (code: string): boolean =>
          globalSmsChallengeCoordinator.submit(pending.id, code),
        onCancel: (): void => {
          globalSmsChallengeCoordinator.cancel(pending.id);
        },
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true,
    });
    logger.info('open dialog', 'id=', pending.id);
    this.dialogController.open();
  }

  build() {
    Row()
      .width(1)
      .height(1)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
  }
}

@CustomDialog
export struct SmsVerificationDialog {
  controller: CustomDialogController;
  maskedPhone: string = '绑定手机';
  purpose: SmsChallengePurpose = 'password_second_factor';
  onConfirm: (code: string) => boolean = (): boolean => false;
  onCancel: () => void = (): void => {};
  @State private code: string = '';
  @State private validationMessage: string = '';

  private submit(): void {
    const normalized = this.code.trim();
    if (!normalized) {
      this.validationMessage = '请输入短信验证码';
      return;
    }
    if (!this.onConfirm(normalized)) {
      this.validationMessage = '验证码请求已结束，请重新登录';
      return;
    }
    this.controller.close();
  }

  build() {
    Column({ space: 16 }) {
      Text('输入短信验证码')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')

      Text(`学校统一身份认证要求二次验证，验证码已发送至 ${this.maskedPhone}`)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')

      TextInput({ text: this.code, placeholder: '短信验证码' })
        .type(InputType.Number)
        .maxLength(8)
        .height(48)
        .width('100%')
        .borderRadius(8)
        .onChange((value: string): void => {
          this.code = value;
          this.validationMessage = '';
        })
        .onSubmit((): void => this.submit())

      if (this.validationMessage) {
        Text(this.validationMessage)
          .fontSize(13)
          .fontColor('#EF4444')
          .width('100%')
      }

      Row({ space: 8 }) {
        Button('取消', { type: ButtonType.Normal })
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .onClick((): void => {
            this.onCancel();
            this.controller.close();
          })

        Button('确认', { type: ButtonType.Normal })
          .layoutWeight(1)
          .borderRadius(8)
          .onClick((): void => this.submit())
      }
      .width('100%')
    }
    .width('86%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('sys.color.ohos_id_color_dialog_bg'))
  }
}
