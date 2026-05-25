import type { CustomScheduleItem } from '../../services/schoolSchedule/ScheduleModels'
import { buildCustomScheduleDetailRows } from '../../services/schoolSchedule/ScheduleDetailModels'
import type { DetailRow } from '../../services/schoolSchedule/ScheduleDetailModels'

@Component
export struct CustomScheduleDetailDialog {
  @Prop item: CustomScheduleItem | null = null
  @Prop baseFont: number = 12
  onClose: () => void = () => {}
  onEdit: (item: CustomScheduleItem) => void = () => {}
  onDelete: (id: string) => void = () => {}

  private textOrDash(value: string): string {
    return value && value.length > 0 ? value : '-'
  }

  private detailRows(): DetailRow[] {
    if (!this.item) {
      return []
    }
    return buildCustomScheduleDetailRows(this.item)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(this.baseFont)
        .fontColor('#6B7280')
      Text(this.textOrDash(value))
        .fontSize(this.baseFont + 1)
        .fontColor('#111827')
        .margin({ top: 4 })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  build() {
    Stack() {
      Row() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#00000066')
        .onClick(() => this.onClose())

      Column() {
        Row() {
          Text(this.item ? this.item.title : '自定义日程')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text('X')
            .fontSize(18)
            .fontColor('#9CA3AF')
            .onClick(() => this.onClose())
        }
        .margin({ bottom: 12 })

        Row() {}
          .height(1)
          .width('100%')
          .backgroundColor('#E5E7EB')
          .margin({ bottom: 12 })

        Scroll() {
          Column() {
            ForEach(this.detailRows(), (row: DetailRow) => {
              this.InfoRow(row.label, row.value)
            }, (row: DetailRow) => row.label)
          }
          .width('100%')
        }
        .layoutWeight(1)

        Row({ space: 10 }) {
          Button('删除')
            .type(ButtonType.Capsule)
            .backgroundColor('#FEE2E2')
            .fontColor('#DC2626')
            .onClick(() => {
              if (this.item) {
                this.onDelete(this.item.id)
              }
            })

          Blank()

          Button('编辑')
            .type(ButtonType.Capsule)
            .onClick(() => {
              if (this.item) {
                this.onEdit(this.item)
              }
            })

          Button('关闭')
            .type(ButtonType.Capsule)
            .onClick(() => this.onClose())
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .width('86%')
      .height('70%')
    }
    .width('100%')
    .height('100%')
  }
}
