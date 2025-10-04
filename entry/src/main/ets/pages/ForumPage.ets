@Component
export default struct ForumPage {
  build() {
    Column({ space: 8 }) {
      Text('网 · 话廊').fontSize(20).fontWeight(FontWeight.Bold)
      Column() {
        Text('后续接入：帖子流 / 点赞 / 评论').fontColor('#666')
      }.padding(12).backgroundColor('#FFF').borderRadius(12)
    }.padding(16)
  }
}
