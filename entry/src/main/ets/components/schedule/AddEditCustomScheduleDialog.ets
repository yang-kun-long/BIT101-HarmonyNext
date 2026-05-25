import type { CustomScheduleItem } from '../../services/schoolSchedule/ScheduleModels'
import { createValidatedCustomSchedule } from '../../services/schoolSchedule/ScheduleLocalStore'

@Component
export struct AddEditCustomScheduleDialog {
  @Prop item: CustomScheduleItem | null = null
  @Prop defaultDateISO: string = ''
  onCancel: () => void = () => {}
  onSave: (item: CustomScheduleItem) => void = () => {}

  @State titleText: string = '自定义日程'
  @State subtitleText: string = ''
  @State descriptionText: string = ''
  @State dateText: string = ''
  @State beginText: string = '08:00'
  @State endText: string = '08:45'
  @State errorText: string = ''

  aboutToAppear(): void {
    if (this.item) {
      this.titleText = this.item.title
      this.subtitleText = this.item.subtitle
      this.descriptionText = this.item.description
      this.dateText = this.item.dateISO
      this.beginText = this.item.beginTime
      this.endText = this.item.endTime
      return
    }
    this.titleText = '自定义日程'
    this.dateText = this.defaultDateISO
  }

  private submit(): void {
    const item = createValidatedCustomSchedule({
      title: this.titleText,
      subtitle: this.subtitleText,
      description: this.descriptionText,
      dateISO: this.dateText,
      beginTime: this.beginText,
      endTime: this.endText,
      existingId: this.item ? this.item.id : '',
      now: Date.now(),
    })
    if (!item) {
      this.errorText = '请填写标题、日期和有效时间段'
      return
    }
    this.errorText = ''
    this.onSave(item)
  }

  @Builder
  Field(label: string, value: string, placeholder: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#6B7280')
        .width('100%')
      TextInput({ text: value, placeholder })
        .height(42)
        .fontSize(14)
        .margin({ top: 4 })
        .onChange((text: string) => onChange(text))
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  build() {
    Stack() {
      Row() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#00000066')
        .onClick(() => this.onCancel())

      Column() {
        Text(this.item ? '编辑自定义日程' : '新增自定义日程')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .width('100%')
          .margin({ bottom: 12 })

        Scroll() {
          Column() {
            this.Field('标题', this.titleText, '例如 小组讨论', (value: string) => {
              this.titleText = value
            })
            this.Field('副标题', this.subtitleText, '地点或简短说明', (value: string) => {
              this.subtitleText = value
            })
            this.Field('日期', this.dateText, 'YYYY-MM-DD', (value: string) => {
              this.dateText = value
            })
            this.Field('开始时间', this.beginText, 'HH:mm', (value: string) => {
              this.beginText = value
            })
            this.Field('结束时间', this.endText, 'HH:mm', (value: string) => {
              this.endText = value
            })

            Text('备注')
              .fontSize(12)
              .fontColor('#6B7280')
              .width('100%')
            TextArea({ text: this.descriptionText, placeholder: '可选' })
              .height(90)
              .fontSize(14)
              .margin({ top: 4 })
              .onChange((value: string) => {
                this.descriptionText = value
              })

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(12)
                .fontColor('#DC2626')
                .margin({ top: 8 })
                .width('100%')
            }
          }
          .width('100%')
        }
        .layoutWeight(1)

        Row({ space: 12 }) {
          Button('取消')
            .type(ButtonType.Capsule)
            .backgroundColor('#F3F4F6')
            .fontColor('#111827')
            .onClick(() => this.onCancel())
            .layoutWeight(1)

          Button('保存')
            .type(ButtonType.Capsule)
            .onClick(() => this.submit())
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .width('88%')
      .height('78%')
    }
    .width('100%')
    .height('100%')
  }
}
