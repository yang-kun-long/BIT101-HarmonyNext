// entry/src/main/ets/pages/Index.ets
import ScheduleShellPage from './ScheduleShellPage'
import MapPage from './MapPage'
import ForumPage from './ForumPage'
import PostPage from './PostPage'
import MePage from './MePage'
import router from '@ohos.router'
import { isAuthedBit101 } from '../services/auth/authGuard'

enum TabKey {
  Schedule = 0, // 卷：课表/DDL（受保护，需登录）
  Map = 1,      // 图：地图（游客可见）
  Forum = 2,    // 网：话廊（受保护，需登录）
  Post = 3,     // 话：发帖（受保护，需登录）
  Me = 4        // 我：个人信息（游客可见）
}

@Entry
@Component
struct Index {
  @State current: TabKey = TabKey.Schedule

  private async goto(tab: TabKey) {
    const needAuth = (tab === TabKey.Schedule || tab === TabKey.Forum || tab === TabKey.Post)
    if (needAuth && !(await isAuthedBit101())) {
      await router.pushUrl({ url: 'pages/LoginPage', params: { redirect: 'pages/Index' } })
      return
    }
    this.current = tab
    console.log('[tab]', this.current) // 应看到 0~4 的变化
  }


  @Builder
  TabButton(label: string, key: TabKey) {
    Column() {
      Text(label)
        .fontSize(this.current === key ? 16 : 14)
        .fontWeight(this.current === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === key ? '#2563EB' : '#6B7280')
    }
    .padding({ top: 10, bottom: 6 })
    .onClick(() => { this.goto(key) })
    .layoutWeight(1)
  }

  @Builder
  BottomBar() {
    Row() {
      this.TabButton('卷', TabKey.Schedule)
      this.TabButton('图', TabKey.Map)
      this.TabButton('网', TabKey.Forum)
      this.TabButton('话', TabKey.Post)
      this.TabButton('我', TabKey.Me)
    }
    .height(52)
    .backgroundColor('#FFFFFF')
    .padding({ left: 8, right: 8 })
  }

  build() {
    Column() {
      // 内容区（根据当前 Tab 切换）
      Stack() {
        if (this.current === TabKey.Schedule) {
          ScheduleShellPage()
        } else if (this.current === TabKey.Map) {
          MapPage()
        } else if (this.current === TabKey.Forum) {
          ForumPage()
        } else if (this.current === TabKey.Post) {
          PostPage()
        } else {
          MePage()
        }
      }
      .layoutWeight(1)

      // 底部导航
      this.BottomBar()
    }
    .backgroundColor('#F7F7F7')
    .height('100%')
    .width('100%')
  }
}
