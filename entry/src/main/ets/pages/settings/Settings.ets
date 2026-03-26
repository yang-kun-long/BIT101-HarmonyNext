import { SettingItemCard } from '../../components/settings/SettingItemCard';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Settings {
  build() {
    Column() {
      // 顶部标题栏 (模拟 Android SettingPage 的 Scaffold 顶部)
      Row() {
        Text("设置")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16 })
      .alignItems(VerticalAlign.Center)

      // 设置列表
      List() {
        ListItem() {
          Column() {
            // 1. 账号设置
            SettingItemCard({
              title: "账号设置",
              subTitle: "个人信息编辑及登录状态管理",
              icon: $r('app.media.ic_face'), // 暂时使用已有资源，需替换为 account 对应图标
              targetUrl: 'pages/settings/AccountPage' // 稍后创建
            })

            Divider().strokeWidth(0.5).color($r('sys.color.ohos_id_color_list_separator'))

            // 2. 页面设置
            SettingItemCard({
              title: "页面设置",
              subTitle: "主页及页面顺序",
              icon: $r('app.media.ic_public'), // 暂替 Dashboard
              targetUrl: 'pages/settings/PagesSettingPage'
            })

            // 3. 外观设置
            SettingItemCard({
              title: "外观设置",
              subTitle: "主题及暗黑模式",
              icon: $r('app.media.ic_image'), // 暂替 ColorLens
              targetUrl: 'pages/settings/ThemeSettingPage'
            })

            // 4. 课程表设置
            SettingItemCard({
              title: "课程表设置",
              subTitle: "课程表数据及显示方式",
              icon: $r('app.media.ic_tag'), // 暂替 EditCalendar
              targetUrl: 'pages/settings/CalendarSettingPage'
            })

            // 5. DDL设置
            SettingItemCard({
              title: "DDL设置",
              subTitle: "日程数据及显示方式",
              icon: $r('app.media.ic_sort'), // 暂替 EventNote
              targetUrl: 'pages/settings/DDLSettingPage'
            })

            Divider().strokeWidth(0.5).color($r('sys.color.ohos_id_color_list_separator'))

            // 6. 关于
            SettingItemCard({
              title: "关于",
              subTitle: "关于BIT101-Android",
              icon: $r('app.media.ic_warning'), // 暂替 Info
              targetUrl: 'pages/settings/AboutPage'
            })
          }
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          .borderRadius(12) // 卡片圆角风格
          .clip(true)
        }
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background')) // 灰色背景
    }
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
