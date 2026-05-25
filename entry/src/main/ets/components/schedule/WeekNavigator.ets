// entry/src/main/ets/components/schedule/WeekNavigator.ets
import {
  clampScheduleFabOffsetY,
  getScheduleFabSpecs,
  getScheduleFabStackHeightVp,
  ScheduleFabSpec,
  SCHEDULE_FAB_HORIZONTAL_PADDING_VP,
  SCHEDULE_FAB_VERTICAL_PADDING_VP
} from './weekNavigatorModel'

@Component
export struct WeekNavigator {
  // --- Callbacks ---
  containerHeight: number = 0
  onNext: () => void = () => {}
  onPrev: () => void = () => {}
  onSettings: () => void = () => {}
  onAddCustom: () => void = () => {}

  @State private offsetY: number = 0
  private dragStartOffsetY: number = 0
  private readonly iconColor: string = '#0A59F7'
  private readonly containerColor: string = '#DDEBFF'

  private clampOffsetY(nextOffsetY: number): number {
    return clampScheduleFabOffsetY(
      nextOffsetY,
      this.containerHeight,
      getScheduleFabStackHeightVp(),
      SCHEDULE_FAB_VERTICAL_PADDING_VP
    )
  }

  private actionFor(spec: ScheduleFabSpec): () => void {
    if (spec.action === 'next') {
      return this.onNext
    }
    if (spec.action === 'prev') {
      return this.onPrev
    }
    if (spec.action === 'add') {
      return this.onAddCustom
    }
    return this.onSettings
  }

  @Builder
  Fab(spec: ScheduleFabSpec) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (spec.action === 'next') {
        Image($r('app.media.ic_chevron_right'))
          .width(spec.iconVp)
          .height(spec.iconVp)
          .fillColor(this.iconColor)
      } else if (spec.action === 'prev') {
        Image($r('app.media.ic_chevron_left'))
          .width(spec.iconVp)
          .height(spec.iconVp)
          .fillColor(this.iconColor)
      } else if (spec.action === 'add') {
        Image($r('app.media.ic_add'))
          .width(spec.iconVp)
          .height(spec.iconVp)
          .fillColor(this.iconColor)
      } else {
        Image($r('app.media.ic_settings'))
          .width(spec.iconVp)
          .height(spec.iconVp)
          .fillColor(this.iconColor)
      }
    }
    .width(spec.sizeVp)
    .height(spec.sizeVp)
    .backgroundColor(this.containerColor)
    .borderRadius(spec.sizeVp / 2)
    .onClick(() => this.actionFor(spec)())
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column({ space: 10 }) {
        ForEach(getScheduleFabSpecs(), (spec: ScheduleFabSpec) => {
          this.Fab(spec)
        }, (spec: ScheduleFabSpec) => spec.action)
      }
      .align(Alignment.Center)
      .margin({
        right: SCHEDULE_FAB_HORIZONTAL_PADDING_VP,
        bottom: SCHEDULE_FAB_VERTICAL_PADDING_VP
      })
      .offset({ x: 0, y: this.offsetY })
      .gesture(
        PanGesture({ direction: PanDirection.Vertical })
          .onActionStart(() => {
            this.dragStartOffsetY = this.offsetY
          })
          .onActionUpdate((event: GestureEvent) => {
            this.offsetY = this.clampOffsetY(this.dragStartOffsetY + event.offsetY)
          })
          .onActionEnd(() => {
            this.offsetY = this.clampOffsetY(this.offsetY)
          })
      )
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .zIndex(10)
  }
}
