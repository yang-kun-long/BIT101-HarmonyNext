import { MapCanvas } from '../components/map/MapCanvas';

@Component
export default struct MapPage {
  build() {
    Column() {
      // 标题栏 (可选)
      Text("校园地图")
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .padding(10)

      // 地图组件
      MapCanvas()
        .layoutWeight(1) // 占满剩余空间
    }
    .width('100%')
    .height('100%')
  }
}