// entry/src/main/ets/pages/DdlPage.ets

@Component
export default struct DdlPage {
  build() {
    Column() {
      Row() {
        Text('DDL')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      .margin({ top: 0, bottom: 8 })

      // TODO：这里以后放真正的 DDL 列表
      Column() {
        Text('这里以后是 DDL 页面')
          .fontSize(14)
          .fontColor('#9CA3AF')
          .margin({ top: 24 })
      }
      .layoutWeight(1)
    }
    .padding({ left: 10, right: 10, top: 0, bottom: 0 })
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F7')
  }
}
