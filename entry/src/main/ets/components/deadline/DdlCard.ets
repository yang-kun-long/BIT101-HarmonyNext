import type { DdlItem } from '../../services/deadline/DdlModels';
import { computeDdlRemainRatio } from '../../services/deadline/DdlModels';
import { buildDdlCardTextLines, getDdlCardLayoutSpec } from './ddlListModel';
import type { DdlCardLayoutSpec, DdlCardTextLines } from './ddlListModel';

@Component
export struct DdlCard {
  @Prop event: DdlItem;
  @Prop warningDays: number = 7;
  @Prop nowMs: number = 0;

  onTap: () => void = () => {};
  onDoneChange: (checked: boolean) => void = () => {};

  private baseFont: number = 12;

  private hexToRgb(hex: string): number[] {
    const normalized = hex.replace('#', '');
    const r = parseInt(normalized.substring(0, 2), 16);
    const g = parseInt(normalized.substring(2, 4), 16);
    const b = parseInt(normalized.substring(4, 6), 16);
    return [r, g, b];
  }

  private componentToHex(value: number): string {
    const clamped = Math.max(0, Math.min(255, Math.round(value)));
    return clamped.toString(16).padStart(2, '0').toUpperCase();
  }

  private mixColor(normalColor: string, urgentColor: string, ratio: number): string {
    const normal = this.hexToRgb(normalColor);
    const urgent = this.hexToRgb(urgentColor);
    const r = normal[0] * ratio + urgent[0] * (1 - ratio);
    const g = normal[1] * ratio + urgent[1] * (1 - ratio);
    const b = normal[2] * ratio + urgent[2] * (1 - ratio);
    return '#' + this.componentToHex(r) + this.componentToHex(g) + this.componentToHex(b);
  }

  private cardColor(): string {
    if (this.event.done) {
      return '#E5E7EB';
    }
    const deadline = this.event.endTime > 0 ? this.event.endTime : this.event.startTime;
    const now = this.nowMs > 0 ? this.nowMs : Date.now();
    const ratio = computeDdlRemainRatio(deadline, now, this.warningDays);
    return this.mixColor('#FFFFFF', '#FEE2E2', ratio);
  }

  private lines(): DdlCardTextLines {
    const now = this.nowMs > 0 ? this.nowMs : Date.now();
    return buildDdlCardTextLines(this.event, now);
  }

  private layoutSpec(): DdlCardLayoutSpec {
    return getDdlCardLayoutSpec();
  }

  build() {
    Row() {
      Column() {
        Text(this.lines().title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        if (this.lines().body.length > 0) {
          Text(this.lines().body)
            .fontSize(this.baseFont)
            .fontColor('#6B7280')
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }

        Text(this.lines().remain)
          .fontSize(this.baseFont)
          .fontColor('#9CA3AF')
          .margin({ top: 5 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)

      Toggle({ type: ToggleType.Checkbox, isOn: this.event.done })
        .onChange((checked: boolean) => {
          this.onDoneChange(checked);
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      top: this.layoutSpec().contentVerticalPaddingVp,
      bottom: this.layoutSpec().contentVerticalPaddingVp,
      left: this.layoutSpec().contentStartPaddingVp,
      right: this.layoutSpec().contentEndPaddingVp,
    })
    .backgroundColor(this.cardColor())
    .borderRadius(8)
    .onClick(() => this.onTap())
  }
}
