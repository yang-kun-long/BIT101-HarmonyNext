// entry/src/main/ets/pages/MePage.ets
import { UserRepository, UserInfoResponse } from '../services/user/userRepository'
import { TokenStore } from '../services/storage/tokenStore'
import router from '@ohos.router'

@Component
export default struct MePage {
  @State loading: boolean = true
  @State err: string = ''
  @State authed: boolean = false
  @State me: UserInfoResponse | null = null
  @State hasFakeCookie: boolean = false

  private repo = new UserRepository()
  private store = new TokenStore()

  aboutToAppear() {
    this.bootstrap()
  }

  // -------- 业务方法（build() 外，不触发 ArkTS UI 语法限制） --------
  private async bootstrap() {
    this.loading = true
    this.err = ''
    this.me = null

    this.authed = await this.store.isLoggedInBit101()
    this.hasFakeCookie = this.authed

    if (!this.authed) {
      this.loading = false
      return
    }

    try {
      const data = await this.repo.getUserInfo('0') // 0 = 当前用户
      this.me = data
    } catch (e) {
      const m: string = (e as Error).message || String(e)
      this.err = m
      this.me = null
    } finally {
      this.loading = false
    }
  }

  private async logout() {
    await this.store.clear()
    this.authed = false
    this.me = null
    this.err = ''
    this.hasFakeCookie = false
  }

  private async gotoLogin() {
    await router.pushUrl({ url: 'pages/LoginPage', params: { redirect: 'pages/Index' } })
  }

  private avatarUrl(): string {
    const m = this.me
    if (!m) return ''
    const img = m.user.avatar
    return (img?.low_url) ?? (img?.url) ?? ''
  }

  // ---------------- UI 片段（@Builder） ----------------
  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label).fontColor('#666').width('28%').fontSize(14)
      Text(value && value.length > 0 ? value : '-').fontSize(15).layoutWeight(1)
    }
    .margin({ top: 4, bottom: 4 })
  }

  @Builder
  StatusDot(ok: boolean) {
    Row() { }
    .width(10)
    .height(10)
    .borderRadius(5)
    .backgroundColor(ok ? '#16a34a' : '#ef4444')
  }

  // ---------------- 页面 ----------------
  build() {
    Column() {
      // 标题 + 刷新
      Row() {
        Text('我').fontSize(22).fontWeight(FontWeight.Bold)
        Blank()
        Button('刷新')
          .type(ButtonType.Capsule)
          .onClick(() => { this.bootstrap() })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 会话状态
      Row() {
        this.StatusDot(this.hasFakeCookie)
        Text(this.hasFakeCookie ? 'BIT101 会话可用' : '未登录 BIT101（游客模式）')
          .fontColor(this.hasFakeCookie ? '#16a34a' : '#ef4444')
          .fontSize(12)
          .margin({ left: 6 })
      }
      .margin({ bottom: 8 })

      // 主体内容
      if (this.loading) {
        Text('加载中…').fontSize(16)
      } else if (!this.authed) {
        // 游客视图
        Column() {
          Text('游客').fontSize(20).fontWeight(FontWeight.Medium)
          Text('登录后可查看完整个人信息与互动功能')
            .fontColor('#666').fontSize(12)
            .margin({ top: 6, bottom: 12 })
          Button('去登录')
            .type(ButtonType.Capsule)
            .onClick(() => { this.gotoLogin() })
        }
        .padding(12)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
      } else if (this.err.length > 0) {
        // 错误视图
        Column() {
          Text('加载失败').fontColor('#ef4444').fontSize(16)
          Text(this.err).fontColor('#ef4444').fontSize(12).maxLines(3)
          Button('重试').type(ButtonType.Capsule).onClick(() => { this.bootstrap() }).margin({ top: 8 })
          Button('退出登录').type(ButtonType.Capsule).onClick(() => { this.logout() }).margin({ top: 8 })
        }
      } else if (this.me) {
        // 头像与昵称卡片
        Row() {
          Image(this.avatarUrl())
            .width(64).height(64).borderRadius(32).objectFit(ImageFit.Cover)
            .backgroundColor('#EEEEEE')

          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(this.me.user.nickname).fontSize(20).fontWeight(FontWeight.Medium)
              if (this.me.user.identity && this.me.user.identity.color && this.me.user.identity.text) {
                Row() {
                  Row() { }
                  .width(10).height(10).borderRadius(5).backgroundColor(this.me.user.identity.color)
                  Text(this.me.user.identity.text).fontSize(12).margin({ left: 6 })
                }
                .padding(6)
                .borderRadius(12)
                .backgroundColor('#F5F5F5')
              }
            }
            if (this.me.user.motto && this.me.user.motto.length > 0) {
              Text(this.me.user.motto).fontColor('#666').fontSize(13).maxLines(2)
            }
          }
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .padding(12)
        .backgroundColor('#FAFAFA')
        .borderRadius(16)

        // 关注信息
        Row({ space: 24 }) {
          Column() {
            Text(this.me.following_num.toString()).fontSize(18).fontWeight(FontWeight.Medium)
            Text('关注').fontSize(12).fontColor('#666')
          }
          Column() {
            Text(this.me.follower_num.toString()).fontSize(18).fontWeight(FontWeight.Medium)
            Text('粉丝').fontSize(12).fontColor('#666')
          }
          Column() {
            Text(this.me.own ? '是' : '否').fontSize(18).fontWeight(FontWeight.Medium)
            Text('是自己').fontSize(12).fontColor('#666')
          }
        }
        .margin({ top: 12, bottom: 12 })

        // 详细信息
        Column() {
          this.InfoRow('用户ID', String(this.me.user.id))
          this.InfoRow('注册时间', this.me.user.create_time)
          this.InfoRow('是否关注我', this.me.follower ? '是' : '否')
          this.InfoRow('我是否关注', this.me.following ? '是' : '否')
        }
        .padding(12)
        .backgroundColor('#FAFAFA')
        .borderRadius(16)

        // 操作
        Row({ space: 12 }) {
          Button('退出登录').type(ButtonType.Capsule).onClick(() => { this.logout() })
        }
        .margin({ top: 12 })
      } else {
        Text('暂无数据').fontSize(14).fontColor('#666')
      }
    }
    .padding(16)
  }
}
