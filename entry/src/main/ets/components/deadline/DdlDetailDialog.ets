// entry/src/main/ets/components/deadline/DdlDetailDialog.ets

import type { LexueCalendarEvent } from '../../services/lexue/LexueCalendarParser';
import { Logger } from '../../utils/Logger';

@Component
export struct DdlDetailDialog {
  // 父组件只负责把当前事件传进来
  @Prop ev: LexueCalendarEvent | null;
  private logger = new Logger('DdlDetailDialog');

  // 回调不要加 @Prop（函数不能作为 @Prop）
  onClose: () => void = () => {};

  baseFont: number = 13;

  // ===== 动画相关状态 =====
  @State private opacityVal: number = 0;   // 透明度
  @State private scaleVal: number = 0.96;  // 缩放
  @State private offsetY: number = 24;     // 向下位移

  aboutToAppear(): void {
    this.logger.info('aboutToAppear, evNull=', this.ev === null);

    // 进场动画：从略小、略下、透明 -> 正常
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
    // 退场动画：稍微缩小 + 下移 + 淡出
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.opacityVal = 0;
      this.scaleVal = 0.96;
      this.offsetY = 24;
      this.onClose(); // 动画结束后通知父组件卸载
    });
  }

  private handleMaskClick(): void {
    this.closeAnim();
  }

  private handleCloseBtn(): void {
    this.closeAnim();
  }

  // ---------- 标题相关 ----------

  // 去掉尾部 “已到期” 的标题
  private prettyTitle(): string {
    let raw: string = this.ev?.title ?? '(未命名 DDL)';
    raw = raw.replace(/\s*已到期\s*$/u, '');
    return raw;
  }

  // 课程名
  private courseName(): string {
    return this.ev?.courseName ?? '';
  }

  // 类型 Tag：作业 / 实验 / 测验 / 考试 / DDL
  private ddlTypeTag(): string {
    const text: string = (this.ev?.title ?? '').toLowerCase();
    if (text.includes('实验') || text.includes('lab')) return '实验';
    if (
      text.includes('作业') ||
      text.includes('assignment') ||
      text.includes('homework')
    ) {
      return '作业';
    }
    if (text.includes('测验') || text.includes('quiz')) return '测验';
    if (text.includes('考试') || text.includes('exam')) return '考试';
    return 'DDL';
  }

  // ---------- 时间相关 ----------

  private formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: string = d.getHours().toString().padStart(2, '0');
    const minute: string = d.getMinutes().toString().padStart(2, '0');
    return `${m} 月 ${day} 日 ${hour}:${minute}`;
  }

  // 如果 start == end，当作“截止：xxx”，否则显示区间
  private timeText(ev: LexueCalendarEvent): string {
    const start: string = this.formatTime(ev.startTime);
    if (!ev.endTime || ev.endTime === ev.startTime) {
      return `截止：${start}`;
    }
    const end: string = this.formatTime(ev.endTime);
    return `${start}  -  ${end}`;
  }

  // ---------- DESCRIPTION 预处理 + bullet ----------

  private getDescriptionText(): string {
    if (!this.ev || !this.ev.description) {
      return '';
    }
    let text: string = this.ev.description as string;

    // 把 "\n" 还原成真实换行
    text = text.replace(/\\n/g, '\n');

    // 去掉换行前后的空白
    text = text.replace(/[ \u00A0\t]*\n[ \u00A0\t]*/g, '\n');

    // 连续 >=3 个换行缩成 2 个
    text = text.replace(/\n{3,}/g, '\n\n');

    return text.trim();
  }

  private hasDescription(): boolean {
    return this.getDescriptionText().length > 0;
  }

  private getDescriptionLines(): string[] {
    const t: string = this.getDescriptionText();
    if (t.length === 0) {
      return [];
    }
    return t.split('\n');
  }

  private isBulletLine(line: string): boolean {
    const trimmed: string = line.trim();
    return trimmed.startsWith('•') || trimmed.startsWith('·');
  }

  private stripBullet(line: string): string {
    const trimmed: string = line.trim();
    if (this.isBulletLine(line) && trimmed.length > 0) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  private isEmptyLine(line: string): boolean {
    return this.stripBullet(line).length === 0;
  }

  build() {
    // ⚠️ build 里只能有一个根节点，这里直接一个 Stack
    Stack() {
      // 半透明遮罩
      Row() { }
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.25)')
      .onClick(() => this.handleMaskClick())

      // 中间卡片
      Column() {
        // 课程名 + 类型 tag
        if (this.courseName().length > 0) {
          Row() {
            Text(this.courseName())
              .fontSize(12)
              .fontColor('#6B7280')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.ddlTypeTag())
              .fontSize(11)
              .fontColor('#F97316')
              .backgroundColor('#FFEDD5')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(999)
              .margin({ left: 6 })
          }
          .margin({ bottom: 4 })
        }

        // 标题（去掉“已到期”）
        Text(this.prettyTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 时间
        if (this.ev) {
          Text(this.timeText(this.ev))
            .fontSize(this.baseFont)
            .fontColor('#6B7280')
            .margin({ top: 6 })
        }

        // 说明：伪 bullet 列表
        if (this.hasDescription()) {
          Text('说明')
            .fontSize(this.baseFont)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 4 })

          Scroll() {
            Column() {
              ForEach(
                this.getDescriptionLines(),
                (line: string, index: number) => {
                  if (this.isBulletLine(line)) {
                    // bullet 行
                    Row() {
                      Text('•')
                        .fontSize(this.baseFont)
                        .margin({ right: 4 })

                      Text(this.stripBullet(line))
                        .fontSize(this.baseFont)
                        .fontColor('#4B5563')
                        .maxLines(10)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .margin({ top: 2, bottom: 2 })
                  } else if (this.isEmptyLine(line)) {
                    // 空行 -> 小间距
                    Blank()
                      .height(6)
                  } else {
                    // 普通段落
                    Text(this.stripBullet(line))
                      .fontSize(this.baseFont)
                      .fontColor('#4B5563')
                      .maxLines(10)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 2, bottom: 2 })
                  }
                },
                (line: string, index: number): string => index.toString()
              )
            }
          }
          .height(160)
        }

        // 地点
        if (this.ev && this.ev.location) {
          Text('地点')
            .fontSize(this.baseFont)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12, bottom: 4 })

          Text(this.ev.location)
            .fontSize(this.baseFont)
            .fontColor('#4B5563')
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // 关闭按钮
        Row() {
          Blank()
          Button('关闭')
            .type(ButtonType.Capsule)
            .onClick(() => this.handleCloseBtn())
        }
        .margin({ top: 16 })
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .width('86%')
      .align(Alignment.Center)
      // ✨ 动画效果
      .opacity(this.opacityVal)
      .scale({ x: this.scaleVal, y: this.scaleVal })
      .translate({ y: this.offsetY })
    }
    .width('100%')
    .height('100%')
  }
}
