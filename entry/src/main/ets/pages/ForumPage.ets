import { WebPage } from '../components/web/WebPage';

@Component
export default struct ForumPage {
  // 【修正】这里换成真正的网页前端地址
  // 如果手机版显示效果不好，也可以尝试 'http://android.bit101.cn' (Android源码里提到的另一个地址)
  private readonly FORUM_URL = 'https://bit101.cn';

  build() {
    Column() {
      // 我们的 WebPage 组件已经加了 'bit101.cn' 的白名单，
      // 所以这个地址可以正常加载，不会被拦截跳出去。
      WebPage({ url: this.FORUM_URL })
    }
    .width('100%')
    .height('100%')
  }
}