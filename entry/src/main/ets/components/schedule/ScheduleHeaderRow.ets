import { DayEvents } from '../../pages/SchedulePage' // 假设您会将 DayEvents 导出
import { pad2, isSameDate } from '../../utils/scheduleUtils'

@Component
export struct ScheduleHeaderRow {
  // --- Props ---
  // ✅ 关键修复：添加 @Prop
  @Prop weekNoText: string = '1'
  @Prop weekDays: DayEvents[] = []
  @Prop leftColWidth: number = 0
  @Prop courseColWidth: number = 0
  @Prop colGap: number = 0

  // --- State ---
  private today: Date = new Date()

  // --- Builders ---
  @Builder
  LeftHeader() {
    Column() {
      // ✅ 这一行现在会自动响应 @Prop weekNoText 的变化
      Text(this.weekNoText)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0EA5E9')
        .textAlign(TextAlign.Center)
      Text('周').fontSize(12).fontColor('#6B7280').textAlign(TextAlign.Center)
    }
    .padding(4)
    .backgroundColor('#F3F4F6')
    .borderRadius(10)
  }

  @Builder
  DayHeader(d: Date, active: boolean) {
    Column() {
      Text(`周${['日', '一', '二', '三', '四', '五', '六'][d.getDay()]}`)
        .fontSize(12)
        .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(active ? '#0EA5E9' : '#6B7280')
        .textAlign(TextAlign.Center)

      Text(`${pad2(d.getMonth() + 1)}/${pad2(d.getDate())}`)
        .fontSize(12)
        .fontColor(active ? '#0EA5E9' : '#6B7280')
        .textAlign(TextAlign.Center)
    }
    .padding(4)
    .backgroundColor(active ? '#E0F2FE' : '#F3F4F6')
    .borderRadius(10)
  }

  build() {
    Row() {
      // 左侧窄列头（“周 / 周数”）
      Column() { this.LeftHeader() }
      .width(this.leftColWidth)
      .margin({ right: this.colGap })

      // 右侧 7 天头部
      ForEach(this.weekDays, (d: DayEvents, i: number) => {
        Column() {
          this.DayHeader(d.date, isSameDate(d.date, this.today))
        }
        .width(this.courseColWidth)
        .margin({ right: i < 6 ? this.colGap : 0 })
      })
    }
    .width('100%')
  }
}