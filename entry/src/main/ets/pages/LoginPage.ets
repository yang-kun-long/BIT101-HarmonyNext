// entry/src/main/ets/pages/LoginPage.ets
import router from '@ohos.router'
import { BusinessError } from '@kit.BasicServicesKit'; // 引入系统错误类型
import { Logger } from '../utils/Logger';
import { uiGetParams, uiReplaceUrl } from '../utils/uiContextBridge';
import { LoginCoordinator } from '../services/auth/LoginCoordinator';

interface RedirectParams {
  redirect?: string
}

@Entry
@Component
struct LoginPage {
  private logger = new Logger('LoginPage');
  @State sid: string = ''        // 学号
  @State password: string = ''   // 明文密码
  @State captcha: string = ''    // 验证码（允许留空）
  @State busy: boolean = false   // 加载态
  @State msg: string = ''        // 成功/失败提示
  @State showRaw: boolean = false // 开发开关：是否打印原始返回

  private loginCoordinator = new LoginCoordinator()

  private async onLogin() {
    if (this.busy) return
    this.busy = true
    this.msg = ''

    try {
      const result = await this.loginCoordinator.login({
        sid: this.sid.trim(),
        password: this.password,
        captcha: this.captcha,
      });

      if (this.showRaw) {
        this.logger.debug(
          'login result:',
          'bit101=',
          result.bit101Ok,
          'school=',
          result.schoolOk,
          'mode=',
          result.mode,
          'calendar=',
          result.syncedCalendarCount,
        );
      }

      if (result.ok) {
        this.msg = '登录成功';
        AppStorage.setOrCreate('current_username', this.sid)

        const p = uiGetParams(this.getUIContext()) as object
        let target = 'pages/Index'
        if (p && typeof p === 'object') {
          const maybe = p as RedirectParams
          if (typeof maybe.redirect === 'string' && maybe.redirect.length > 0) {
            target = maybe.redirect
          }
        }

        await uiReplaceUrl(this.getUIContext(), { url: target })
        return
      }

      const bit101Text = result.bit101Ok ? 'OK' : 'FAIL'
      const schoolText = result.schoolOk ? 'OK' : 'FAIL'
      this.msg = `登录失败：BIT101=${bit101Text}，School=${schoolText}`

    } catch (e) {
      // 🔥 核心修复：不再盲目转字符串，而是尝试提取有用信息
      let errorMsg = '未知错误';

      if (typeof e === 'string') {
        errorMsg = e;
      } else if (e instanceof Error) {
        errorMsg = e.message;
      } else if (e && typeof e === 'object') {
        // 尝试读取 BusinessError 的 code 或 msg
        const err = e as BusinessError;
        if (err.code) {
          errorMsg = `Code: ${err.code}, Msg: ${err.message ?? 'No message'}`;
        } else {
          // 其他对象，尝试 JSON 序列化
          try {
            errorMsg = JSON.stringify(e);
          } catch {
            errorMsg = String(e);
          }
        }
      }

      this.msg = `登录异常：${errorMsg}`
      this.logger.error('login error details:', e);
    } finally {
      this.busy = false
    }
  }

  build() {
    Column({ space: 12 }) {
      Text('BIT101 登录（HarmonyOS NEXT）')
        .fontSize(22).fontWeight(FontWeight.Bold).margin({ bottom: 8 })

      TextInput({ placeholder: '学号 sid', text: this.sid })
        .onChange(v => this.sid = v)

      TextInput({ placeholder: '密码 password', text: this.password })
        .type(InputType.Password)
        .onChange(v => this.password = v)

      TextInput({ placeholder: 'WebVPN 验证码（若需要，可留空）', text: this.captcha })
        .onChange(v => this.captcha = v)

      Row({ space: 8 }) {
        Button(this.busy ? '处理中…' : '登录')
          .type(ButtonType.Capsule)
          .backgroundColor(this.busy ? '#9CA3AF' : '#2563EB')
          .enabled(!this.busy && !!this.sid && !!this.password)
          .onClick(() => this.onLogin())

        Toggle({ type: ToggleType.Switch, isOn: this.showRaw })
          .onChange(v => this.showRaw = v)
        Text('开发日志')
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
