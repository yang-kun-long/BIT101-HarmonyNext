import { AuthRepository } from '../services/auth/authRepository'
import router from '@ohos.router'
import { createBitSsoSessionAuto } from '../services/lexue/BitSsoAuto';
import { syncUserCalendar } from '../services/lexue/CalendarService'; // 导入封装的服务

interface RedirectParams {
  redirect?: string
}

const WEBVPN_LEXUE_BASE =
  'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421fcf25989227e6a596a468ca88d1b203b';

@Entry
@Component
export default struct LoginPage {
  @State sid: string = ''        // 学号
  @State password: string = ''   // 明文密码
  @State captcha: string = ''    // 验证码（允许留空）
  @State busy: boolean = false   // 加载态
  @State msg: string = ''        // 成功/失败提示
  @State showRaw: boolean = false // 开发开关：是否打印原始返回

  private auth = new AuthRepository()

  private async onLogin() {
    if (this.busy) return
    this.busy = true
    this.msg = ''

    try {
      // 1. BIT101 + WebVPN 基础登录
      const ret = await this.auth.loginBoth({
        sid: this.sid.trim(),
        password: this.password,
        captcha: this.captcha.trim(),
      })

      if (this.showRaw) {
        console.log('[Login] loginBoth result: ' + JSON.stringify(ret))
      }

      const okBit101 = !!(ret.bit101FakeCookie && ret.bit101FakeCookie.length > 0)
      const okWebvpn = !!ret.webvpn && !!ret.webvpn.ok

      // 2. 乐学 SSO 登录流程
      // 注意：createBitSsoSessionAuto 内部通常会进行网络探测来决定是 inner 还是 webvpn
      const GeneratedDestructObj_1 = await createBitSsoSessionAuto({
        debug: true,
        webvpnLexueBase: WEBVPN_LEXUE_BASE,
      });

      const mode = GeneratedDestructObj_1.mode; // 'inner' | 'webvpn'
      const sso = GeneratedDestructObj_1.sso;

      // 执行登录
      await sso.loginToLexue(this.sid.trim(), this.password);

      // 3. 判定登录结果并同步数据
      if (okBit101 && okWebvpn) {
        this.msg = '登录成功，正在同步课表...'; // 更新UI提示用户正在获取数据

        try {
          // === 核心业务整合：同步日历 ===
          // 动态决定使用哪个 BaseURL
          const currentBaseUrl = mode === 'inner'
            ? 'https://lexue.bit.edu.cn'
            : WEBVPN_LEXUE_BASE;

          const count = await syncUserCalendar({
            sso: sso,
            username: this.sid.trim(),
            webvpnLexueBase: currentBaseUrl
          });

          console.info(`[Login] 日历同步完成，共 ${count} 条数据`);
          // 可以选择在这里 toast 提示：`同步完成，更新了 ${count} 个DDL`
        } catch (syncErr) {
          // 日历同步失败不应该阻止用户进入 App，记录错误即可
          console.error('[Login] 日历同步失败，跳过:', syncErr);
          // 也可以在这里修改 this.msg 提示用户“登录成功但同步失败”
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

        // 使用 replaceUrl 防止用户点返回键回到登录页
        await router.replaceUrl({ url: target })
        return
      }

      // 失败处理
      const bit101Text = okBit101 ? 'OK' : 'FAIL'
      const webvpnText = okWebvpn ? 'OK' : 'FAIL'
      this.msg = `登录失败：BIT101=${bit101Text}，WebVPN=${webvpnText}`

    } catch (e) {
      const m = (e as Error)?.message ?? String(e)
      this.msg = `登录异常：${m}`
      console.error('[Login] login error', e)
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
          .maxLines(3)
      }
    }.padding(16)
  }
}