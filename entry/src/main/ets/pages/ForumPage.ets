import { WebPage } from '../components/web/WebPage';

@Component
export default struct ForumPage {
  private readonly forumUrl: string = 'https://bit101.cn/';

  build() {
    Column() {
      WebPage({ url: this.forumUrl })
    }
    .width('100%')
    .height('100%')
  }
}
