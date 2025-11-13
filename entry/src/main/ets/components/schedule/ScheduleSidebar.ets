// entry/src/main/ets/components/schedule/ScheduleSidebar.ets

import type { PeriodTime } from '../../services/jw/periodTimes'

@Component
export struct ScheduleSidebar {
  // --- Props ---
  // ✅ 修复：添加 @Prop
  @Prop periodTimes: PeriodTime[] = []
  @Prop unitHeight: number = 42
  @Prop baseFont: number = 12

  // --- Helpers ---
  private periods(): number[] {
    const arr: number[] = []
    let i = 1
    while (i <= 13) { arr.push(i); i++ }
    return arr
  }

  private periodNumText(i: number): string { return '' + i }

  private periodTimeTextStart(i: number): string {
    if (!this.periodTimes || this.periodTimes.length !== 13) return '';
    const t = this.periodTimes[i - 1];
    if (!t || !t.start) return '';
    return t.start; // 只显示开始时间
  }

  private periodTimeTextEnd(i: number): string {
    if (!this.periodTimes || this.periodTimes.length !== 13) return '';
    const t = this.periodTimes[i - 1];
    if (!t || !t.end) return '';
    return t.end;
  }

  // --- Builder ---
  @Builder
  LeftPeriods() {
    Column() {
      ForEach(this.periods(), (p: number, _idx: number) => {
        Column() {
          Text(this.periodTimeTextStart(p))
            .fontSize(this.baseFont)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)

          Text(this.periodNumText(p))
            .fontSize(this.baseFont)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)

          Text(this.periodTimeTextEnd(p))
            .fontSize(this.baseFont)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center)
        }
        // ✅ 修复 2：使用 layoutWeight(1) 让 13 节课平分高度
        .layoutWeight(1)
        // ✅ 修复 3：让文本垂直居中
        .justifyContent(FlexAlign.Center)
        .border({ width: { bottom: (p === 13 ? 0 : 1) }, color: '#E5E7EB' })
        .padding(2)
      })
    }
    // ✅ 修复 1：让侧栏填满 100% 高度
    .height('100%')
  }

  build() {
    this.LeftPeriods()
  }
}