import type { ExamScheduleItem } from '../../services/schoolSchedule/ScheduleModels'
import { buildExamDetailRows } from '../../services/schoolSchedule/ScheduleDetailModels'
import type { DetailRow } from '../../services/schoolSchedule/ScheduleDetailModels'

@Component
export struct ExamDetailDialog {
  @Prop exam: ExamScheduleItem | null = null
  @Prop baseFont: number = 12
  onClose: () => void = () => {}

  private textOrDash(value: string): string {
    return value && value.length > 0 ? value : '-'
  }

  private detailRows(): DetailRow[] {
    if (!this.exam) {
      return []
    }
    return buildExamDetailRows(this.exam)
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
          Text(this.exam ? this.exam.name : '考试安排')
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

        Button('关闭')
          .type(ButtonType.Capsule)
          .onClick(() => this.onClose())
          .alignSelf(ItemAlign.End)
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
