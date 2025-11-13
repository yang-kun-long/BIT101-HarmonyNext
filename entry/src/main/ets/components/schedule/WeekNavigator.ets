// entry/src/main/ets/components/schedule/WeekNavigator.ets

@Component
export struct WeekNavigator {
  // --- Callbacks ---
  onNext: () => void = () => {}
  onPrev: () => void = () => {}
  onSettings: () => void = () => {}

  @Builder
  Fab(label: string, onTap: () => void) {
    Button(label).type(ButtonType.Capsule).onClick(() => onTap()).padding(12)
  }

  build() {
    Column() {
      this.Fab('＋', () => this.onNext())
      this.Fab('－', () => this.onPrev())
      this.Fab('⚙️', () => this.onSettings())
    }
    .align(Alignment.Center)
    .margin({ right: '-85%', bottom: '-140%' })
    .zIndex(10)
  }
}