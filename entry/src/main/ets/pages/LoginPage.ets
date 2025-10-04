// entry/src/main/ets/pages/LoginPage.ets
import { AuthRepository } from '../services/auth/authRepository'
import router from '@ohos.router'

interface RedirectParams {
  redirect?: string
}

@Entry
@Component
export default struct LoginPage {
  @State sid: string = ''        // 学号
  @State password: string = ''   // 明文密码
  @State captcha: string = ''    // 验证码（允许留空）
  @State busy: boolean = false   // 加载态
  @State msg: string = ''        // 成功/失败提示
  @State showRaw: boolean = false // 开发开关：是否打印原始返回

  private auth = new AuthRepository() // 默认 https://bit101.flwfdd.xyz

  private async onLogin() {
    if (this.busy) return
    this.busy = true
    this.msg = ''
    try {
      // 同时登录 BIT101 + WebVPN（你的 loginBoth 返回：{ bit101FakeCookie, webvpnCookie, webvpn }）
      const ret = await this.auth.loginBoth({
        sid: this.sid.trim(),
        password: this.password,
        captcha: this.captcha.trim(),
      })

      if (this.showRaw) {
        console.log('[Login] loginBoth result: ' + JSON.stringify(ret))
      }

      // 成功判断：BIT101 拿到 fake_cookie；WebVPN 返回 ok=true
      const okBit101 = !!(ret.bit101FakeCookie && ret.bit101FakeCookie.length > 0)
      const okWebvpn = !!ret.webvpn && !!ret.webvpn.ok

      if (okBit101 && okWebvpn) {
        this.msg = '登录成功'

        // 登录后返回：优先使用路由参数 redirect，否则回首页
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

      // 失败提示（不读 .code，避免类型冲突）
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
        Button(this.busy ? '登录中…' : '登录')
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
