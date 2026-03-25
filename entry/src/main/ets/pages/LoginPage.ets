// entry/src/main/ets/pages/LoginPage.ets
import { AuthRepository } from '../services/auth/authRepository'
import router from '@ohos.router'
import { createBitSsoSessionAuto } from '../services/lexue/BitSsoAuto';
import { syncUserCalendar } from '../services/lexue/CalendarService';
import { BusinessError } from '@kit.BasicServicesKit'; // 引入系统错误类型
import { Logger } from '../utils/Logger';
import { TokenStore } from '../services/storage/tokenStore';

interface RedirectParams {
  redirect?: string
}

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';
const WEBVPN_PORTAL_URL = 'https://webvpn.bit.edu.cn/';

@Entry
@Component
export default struct LoginPage {
  private logger = new Logger('LoginPage');
  @State sid: string = ''        // 学号
  @State password: string = ''   // 明文密码
  @State captcha: string = ''    // 验证码（允许留空）
  @State busy: boolean = false   // 加载态
  @State msg: string = ''        // 成功/失败提示
  @State showRaw: boolean = false // 开发开关：是否打印原始返回

  private auth = new AuthRepository()
  private tokenStore = new TokenStore()

  private async onLogin() {
    if (this.busy) return
    this.busy = true
    this.msg = ''

    try {
      // 1. BIT101 后端登录
      const bit101FakeCookie = await this.auth.loginBit101({
        sid: this.sid.trim(),
        password: this.password,
      })

      if (this.showRaw) {
        this.logger.debug('bit101FakeCookie saved:', !!bit101FakeCookie);
      }

      const okBit101 = !!(bit101FakeCookie && bit101FakeCookie.length > 0)

      // 2. 学校登录流程（inner / webvpn 自动选择）
      const GeneratedDestructObj_1 = await createBitSsoSessionAuto({
        debug: true,
        webvpnLexueBase: WEBVPN_LEXUE_BASE,
        forceMode: 'webvpn',
      });

      const mode = GeneratedDestructObj_1.mode;
      const sso = GeneratedDestructObj_1.sso;

      // 执行登录
      await sso.loginToLexue(this.sid.trim(), this.password);
      const okSchool = sso.isFullyLoggedIn();

      if (mode === 'webvpn') {
        const webvpnCookie = sso.getCookieHeaderFor(WEBVPN_PORTAL_URL) ?? '';
        if (webvpnCookie) {
          await this.tokenStore.saveWebvpnCookie(webvpnCookie);
          this.logger.info('已写入 WebVPN cookie 到 TokenStore');
        } else {
          this.logger.warn('WebVPN 模式下未取到 cookie header');
        }
      }

      // 3. 判定登录结果并同步数据
      if (okBit101 && okSchool) {
        this.msg = '登录成功，正在同步课表...';

        try {
          // === 核心业务整合：同步日历 ===
          const currentBaseUrl = mode === 'inner'
            ? 'https://lexue.bit.edu.cn'
            : WEBVPN_LEXUE_BASE;

          const count = await syncUserCalendar({
            sso: sso,
            username: this.sid.trim(),
            webvpnLexueBase: currentBaseUrl
          });

          this.logger.info('日历同步完成，共', count, '条数据');
        } catch (syncErr) {
          // 日历同步失败不应阻止跳转，但要打印详细日志
          this.logger.error('日历同步失败详情:', syncErr);
        }

        AppStorage.setOrCreate('current_username', this.sid)

        // 4. 页面跳转
        const p = router.getParams() as object
        let target = 'pages/Index'
        if (p && typeof p === 'object') {
          const maybe = p as RedirectParams
          if (typeof maybe.redirect === 'string' && maybe.redirect.length > 0) {
            target = maybe.redirect
          }
        }

        await router.replaceUrl({ url: target })
        return
      }

      // 失败处理
      const bit101Text = okBit101 ? 'OK' : 'FAIL'
      const schoolText = okSchool ? 'OK' : 'FAIL'
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
