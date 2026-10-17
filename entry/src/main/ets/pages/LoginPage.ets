// entry/src/main/ets/pages/LoginPage.ets
import { Logger } from '../utils/Logger';
import { uiGetParams, uiReplaceUrl } from '../utils/uiContextBridge';
import { LoginCoordinator } from '../services/auth/LoginCoordinator';
import { AuthFailureKind, classifyAuthFailure } from '../services/auth/AuthFailure';
import { SmsChallengeDialogHost } from '../components/auth/SmsVerificationDialog';
import { createSecureCredentialStore } from '../services/storage/CredentialStorePlatform';
import { applyLoginCredentialChoice } from '../services/auth/LoginCredentialPolicy';
import { drainAuthenticationRefresh } from '../core/network/AuthRetryHook';
import { common } from '@kit.AbilityKit';

interface RedirectParams {
  redirect?: string
  redirectParams?: Object
}

@Entry
@Component
struct LoginPage {
  private logger = new Logger('LoginPage');
  @State sid: string = ''        // 学号
  @State password: string = ''   // 明文密码
  @State webvpnImageCaptcha: string = '' // WebVPN 图形验证码（允许留空）
  @State busy: boolean = false   // 加载态
  @State msg: string = ''        // 成功/失败提示
  @State saveCredentials: boolean = false;

  private loginCoordinator = new LoginCoordinator()

  private async onLogin() {
    if (this.busy) return
    this.busy = true
    this.msg = ''

    try {
      await drainAuthenticationRefresh();
      const result = await this.loginCoordinator.login({
        sid: this.sid.trim(),
        password: this.password,
        captcha: this.webvpnImageCaptcha,
      });

      if (result.ok) {
        try {
          await applyLoginCredentialChoice(createSecureCredentialStore(this.getUIContext().getHostContext() as common.Context),
            this.saveCredentials, { username: this.sid.trim(), password: this.password });
        } catch (_) {
          this.msg = '登录成功，但安全凭据保存或清除失败，请重试';
          this.password = '';
          return;
        }
        this.password = '';
        this.msg = '登录成功';
        AppStorage.setOrCreate('current_username', this.sid)

        const p = uiGetParams(this.getUIContext()) as object
        let target = 'pages/Index'
        let targetParams: Object | undefined = undefined
        if (p && typeof p === 'object') {
          const maybe = p as RedirectParams
          if (typeof maybe.redirect === 'string' && maybe.redirect.length > 0) {
            target = maybe.redirect
            targetParams = maybe.redirectParams
          }
        }

        await uiReplaceUrl(this.getUIContext(), { url: target, params: targetParams })
        return
      }

      const bit101Text = result.bit101Ok ? 'OK' : 'FAIL'
      const schoolText = result.schoolOk ? 'OK' : 'FAIL'
      this.msg = `登录失败：BIT101=${bit101Text}，School=${schoolText}`

    } catch (e) {
      const error: Error = e instanceof Error ? e : new Error(String(e));
      const kind: AuthFailureKind = classifyAuthFailure(error);
      this.msg = this.messageForFailure(kind);
      this.logger.error('login failed, kind=', kind);
    } finally {
      this.busy = false
    }
  }

  private messageForFailure(kind: AuthFailureKind): string {
    switch (kind) {
      case 'invalid_credentials':
        return '账号或密码错误';
      case 'sms_required':
        return '短信验证码错误或已失效，请重新登录';
      case 'interaction_required':
        return '登录需要短信验证，请在前台重试';
      case 'interaction_cancelled':
        return '已取消短信验证';
      case 'interaction_timeout':
        return '短信验证已超时，请重新登录';
      case 'captcha_required':
        return '需要验证码';
      case 'rate_limited':
        return '操作过于频繁，请稍后再试';
      case 'network_transient':
        return '网络异常，请稍后重试';
      case 'server_transient':
        return '服务暂时不可用，请稍后重试';
    }
    return '登录失败，请稍后重试';
  }

  build() {
    Column({ space: 12 }) {
      SmsChallengeDialogHost()

      Text('BIT101 登录（HarmonyOS NEXT）')
        .fontSize(22).fontWeight(FontWeight.Bold).margin({ bottom: 8 })

      TextInput({ placeholder: '学号 sid', text: this.sid })
        .onChange(v => this.sid = v)

      TextInput({ placeholder: '密码 password', text: this.password })
        .type(InputType.Password)
        .onChange(v => this.password = v)

      TextInput({ placeholder: 'WebVPN 图形验证码（若需要，可留空）', text: this.webvpnImageCaptcha })
        .onChange(v => this.webvpnImageCaptcha = v)

      Row({ space: 8 }) {
        Toggle({ type: ToggleType.Switch, isOn: this.saveCredentials })
          .enabled(!this.busy).onChange((value: boolean) => { this.saveCredentials = value; })
        Text('安全保存凭据用于会话恢复（默认关闭）').fontSize(13).layoutWeight(1)
      }
      Text('凭据仅加密保存在本机，清理缓存后需重新登录；短信验证需要手动登录。')
        .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
      Row({ space: 8 }) {
        Button(this.busy ? '处理中…' : '登录')
          .type(ButtonType.Capsule)
          .backgroundColor(this.busy ? '#9CA3AF' : '#2563EB')
          .enabled(!this.busy && !!this.sid && !!this.password)
          .onClick(() => this.onLogin())
      }

      if (this.msg) {
        Text(this.msg)
          .fontColor(this.msg.startsWith('登录成功') ? '#16a34a' : '#ef4444')
          .fontSize(14)
          .maxLines(5) // 增加行数以显示详细错误
      }
    }.padding(16)
  }
}
