@Component
export default struct MapPage {
  build() {
    Column({ space: 8 }) {
      Text('图 · 校园地图').fontSize(20).fontWeight(FontWeight.Bold)
      Column() {
        Text('这里放地图（后续接 Web 组件或原生地图能力）').fontColor('#666')
        // TODO: 嵌入 WebComponent / 地图 SDK
      }.padding(12).backgroundColor('#FFF').borderRadius(12).layoutWeight(1)
    }.padding(16).height('100%')
  }
}
