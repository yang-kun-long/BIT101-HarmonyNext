// entry/src/main/ets/components/deadline/DdlCard.ets

import type { DdlItem } from '../../services/deadline/DdlModels';
import { computeDdlRemainRatio, formatDdlRemainText } from '../../services/deadline/DdlModels';

@Component
export struct DdlCard {
  @Prop event: DdlItem;
  @Prop warningDays: number = 7;
  @Prop nowMs: number = 0;

  // 改名：不要叫 onClick，避免和底层冲突
  onTap: () => void = () => {};

  private baseFont: number = 12;

  // ---------- 文本格式化 ----------

  // 课程名：优先用 courseName，其次用 location
  private courseName(): string {
    if (this.event.courseName && this.event.courseName.length > 0) {
      return this.event.courseName.trim();
    }
    if (this.event.location && this.event.location.length > 0) {
      return this.event.location.trim();
    }
    return '';
  }

  // 类型 Tag：作业 / 实验 / 测验 / 考试 / DDL
  private ddlTypeTag(): string {
    const text: string = (this.event.title ?? '').toLowerCase();
    if (text.includes('实验') || text.includes('lab')) return '实验';
    if (text.includes('作业') || text.includes('assignment') || text.includes('homework')) return '作业';
    if (text.includes('测验') || text.includes('quiz')) return '测验';
    if (text.includes('考试') || text.includes('exam')) return '考试';
    return 'DDL';
  }

  // 标题：去掉结尾的“已到期”
  private prettyTitle(): string {
    let raw: string = this.event.title ?? '(未命名 DDL)';
    raw = raw.replace(/\s*已到期\s*$/u, '');
    return raw;
  }

  private remainTimeText(): string {
    const deadline = this.event.endTime > 0 ? this.event.endTime : this.event.startTime;
    const now = this.nowMs > 0 ? this.nowMs : Date.now();
    return formatDdlRemainText(deadline, now);
  }

  // 一行摘要：从 description 里挑第一行非空，去掉 bullet，截断
  private summaryText(): string {
    if (!this.event.description) {
      return '';
    }
    let text: string = this.event.description as string;
    text = text.replace(/\\n/g, '\n');
    text = text.replace(/[ \u00A0\t]*\n[ \u00A0\t]*/g, '\n');
    text = text.replace(/\n{3,}/g, '\n\n');
    text = text.trim();
    if (text.length === 0) return '';

    const lines: string[] = text.split('\n');
    let first: string = '';
    for (let i = 0; i < lines.length; i++) {
      const s: string = this.stripBullet(lines[i]);
      if (s.length > 0) {
        first = s;
        break;
      }
    }
    if (first.length === 0) return '';
    const limit: number = 50;
    return first.length > limit ? first.substring(0, limit) + '…' : first;
  }

  private stripBullet(line: string): string {
    const trimmed: string = line.trim();
    if (trimmed.startsWith('•') || trimmed.startsWith('·')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  // 左侧彩条颜色
  private barColor(): string {
    const text: string = (this.event.title ?? '').toLowerCase();
    if (text.includes('考试') || text.includes('exam')) {
      return '#F97373'; // 红：考试
    }
    if (text.includes('实验') || text.includes('lab')) {
      return '#3B82F6'; // 蓝：实验
    }
    if (text.includes('测验') || text.includes('quiz')) {
      return '#FBBF24'; // 黄：测验
    }
    return '#34D399';   // 绿：作业/其他
  }

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

  build() {
    Row() {
      // 左侧彩条
      Column() { }
      .width(3)
      .height(40)
      .backgroundColor(this.barColor())
      .borderRadius(999)

      // 右侧内容
      Column() {
        // 第一行：课程名 + 类型 Tag
        if (this.courseName().length > 0) {
          Row() {
            Text(this.courseName())
              .fontSize(this.baseFont)
              .fontColor('#6B7280')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.ddlTypeTag())
              .fontSize(this.baseFont - 1)
              .fontColor('#F97316')
              .backgroundColor('#FFEDD5')
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .borderRadius(999)
              .margin({ left: 6 })
          }
          .width('100%')                        // ✅ 这一行占满整行
          .justifyContent(FlexAlign.Center)      // ✅ 整行居中
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 2 })
        }

        // 标题
        Text(this.prettyTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')                        // ✅ 占满整行
          .textAlign(TextAlign.Center)          // ✅ 文本在整行内居中

        // 时间
        Text(this.remainTimeText())
          .fontSize(this.baseFont)
          .fontColor('#9CA3AF')
          .margin({ top: 2 })
          .width('100%')
          .textAlign(TextAlign.Center)          // ✅ 居中

        // 一行摘要
        if (this.summaryText().length > 0) {
          Text(this.summaryText())
            .fontSize(this.baseFont)
            .fontColor('#6B7280')
            .margin({ top: 2 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Center)        // ✅ 居中
        }
      }
      .margin({ left: 10 })
      .width('100%')                            // ✅ 右侧列本身也拉满
      .alignItems(HorizontalAlign.Center)       // 子元素默认都往中间排
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 10, bottom: 10, left: 12, right: 12 })
    .backgroundColor(this.cardColor())
    .borderRadius(12)
    .onClick(() => this.onTap())
  }
}
