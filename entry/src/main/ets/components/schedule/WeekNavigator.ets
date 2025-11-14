// entry/src/main/ets/components/schedule/WeekNavigator.ets

@Component
export struct WeekNavigator {
  // --- Callbacks ---
  onNext: () => void = () => {}
  onPrev: () => void = () => {}
  onSettings: () => void = () => {}
  // ✅ 新增：刷新回调
  onRefresh: () => void = () => {}

  @Builder
  Fab(label: string, onTap: () => void) {
    Button(label)
      .type(ButtonType.Capsule)
      .onClick(() => onTap())
      .padding(12)
  }

  build() {
    Column() {
      this.Fab('＋', () => this.onNext())
      this.Fab('－', () => this.onPrev())
      // ✅ 新增：刷新按钮，用 ⟳ 作图标
      this.Fab('⟳', () => this.onRefresh())
      this.Fab('⚙️', () => this.onSettings())
    }
    .align(Alignment.Center)
    .margin({ right: '-85%', bottom: '-120%' })
    .zIndex(10)
  }
}
