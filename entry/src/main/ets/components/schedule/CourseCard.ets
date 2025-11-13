// entry/src/main/ets/components/schedule/CourseCard.ets

@Component
export struct CourseCard {
  // --- Props ---
  @Prop title: string = ''
  @Prop room: string = ''
  @Prop color: string = '#0EA5E9'
  @Prop cardHeight: number = 42
  @Prop baseFont: number = 12
  @Prop titleMaxLines: number = 1

  // ✅ 修复：去掉这里的 @Prop。函数/回调不使用 @Prop 传递。
  onCardClick: () => void = () => {}

  build() {
    Column() {
      Column() {
        if (this.titleMaxLines > 0) {
          Text(this.title)
            .fontSize(this.baseFont)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .maxLines(this.titleMaxLines)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank().layoutWeight(1)
        Text(this.room)
          .fontSize(this.baseFont)
          .fontColor('#F3F4F6')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Clip })
      }
      .padding({ left: 6, right: 6, top: 4, bottom: 4 })
      .backgroundColor(this.color)
      .borderRadius(10)
      .width('100%')
      .height('100%')
    }
    .height(this.cardHeight)
    .onClick(() => this.onCardClick()) // 这里的调用保持不变
  }
}