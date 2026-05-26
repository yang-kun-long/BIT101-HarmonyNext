import type { DdlItem } from '../../services/deadline/DdlModels';
import { Logger } from '../../utils/Logger';
import { buildDdlDetailModel } from './ddlListModel';
import type { DdlDetailModel, DdlDetailRow } from './ddlListModel';

@Component
export struct DdlDetailDialog {
  @Prop ev: DdlItem | null;
  private logger = new Logger('DdlDetailDialog');

  onClose: () => void = () => {};
  onDelete: (uid: string) => void = () => {};
  onEdit: (item: DdlItem) => void = () => {};
  onToggleDone: (uid: string, done: boolean) => void = () => {};

  @State private opacityVal: number = 0;
  @State private scaleVal: number = 0.96;
  @State private offsetY: number = 24;

  aboutToAppear(): void {
    this.logger.info('aboutToAppear, evNull=', this.ev === null);
    this.opacityVal = 0;
    this.scaleVal = 0.96;
    this.offsetY = 24;
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.opacityVal = 1;
      this.scaleVal = 1;
      this.offsetY = 0;
    });
  }

  private closeAnim(): void {
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.opacityVal = 0;
      this.scaleVal = 0.96;
      this.offsetY = 24;
      this.onClose();
    });
  }

  private detailModel(): DdlDetailModel | null {
    if (!this.ev) {
      return null;
    }
    return buildDdlDetailModel(this.ev);
  }

  @Builder
  private DetailRow(row: DdlDetailRow) {
    Column() {
      Text(row.title)
        .fontSize(13)
        .fontColor('#64748B')
        .width('100%')
      Text(row.content)
        .fontSize(16)
        .fontColor('#111827')
        .margin({ top: 4 })
        .width('100%')
        .maxLines(12)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#E9F1FF')
    .borderRadius(8)
    .margin({ top: 10 })
  }

  @Builder
  private ManualActions() {
    if (this.ev && this.detailModel()?.canEditDelete === true) {
      Row({ space: 10 }) {
        Button('删除')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .backgroundColor('#E9F1FF')
          .fontColor('#334155')
          .onClick(() => {
            if (this.ev) {
              this.onDelete(this.ev.uid);
            }
            this.closeAnim();
          })
        Button('编辑')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .backgroundColor('#E9F1FF')
          .fontColor('#334155')
          .onClick(() => {
            if (this.ev) {
              this.onEdit(this.ev);
            }
            this.closeAnim();
          })
      }
      .width('100%')
      .margin({ top: 10 })
    }
  }

  build() {
    Stack() {
      Row() { }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.25)')
      .onClick(() => this.closeAnim())

      if (this.detailModel()) {
        Column() {
          Text(this.detailModel()?.title ?? '')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Scroll() {
            Column() {
              ForEach(
                this.detailModel()?.rows ?? [],
                (row: DdlDetailRow) => {
                  this.DetailRow(row)
                },
                (row: DdlDetailRow, index: number): string => `${index}-${row.title}`
              )
              this.ManualActions()
            }
          }
          .layoutWeight(1)

          Row() {
            Blank()
            Button('关闭')
              .type(ButtonType.Capsule)
              .onClick(() => this.closeAnim())
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .width('90%')
        .height('90%')
        .align(Alignment.Center)
        .opacity(this.opacityVal)
        .scale({ x: this.scaleVal, y: this.scaleVal })
        .translate({ y: this.offsetY })
      }
    }
    .width('100%')
    .height('100%')
  }
}
