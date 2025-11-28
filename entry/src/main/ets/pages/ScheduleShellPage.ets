// entry/src/main/ets/pages/ScheduleShellPage.ets

import SchedulePage from './SchedulePage'
import DdlPage from './DdlPage'
import { CourseDetailDialog } from '../components/schedule/CourseDetailDialog'
import type { CalendarEvent } from '../services/jw/timetableRepository'
import type { RawIcsEvent } from '../services/storage/semesterStore'
import type { PeriodTime } from '../services/jw/periodTimes'
import curves from '@ohos.curves'; // ✅ 弹簧动画曲线
import { Logger } from '../utils/Logger';

enum ScheduleInnerTab {
  Timetable = 0, // 课表
  DDL = 1        // DDL
}

@Component
export default struct ScheduleShellPage {
  private logger = new Logger('ScheduleShellPage');
  @State current: ScheduleInnerTab = ScheduleInnerTab.Timetable

  // 统一管理课程详情弹窗的状态
  @State showCourseDlg: boolean = false
  @State dlgEv: CalendarEvent | null = null
  @State dlgRaw: RawIcsEvent | null = null
  @State dialogBaseFont: number = 12
  @State dialogPeriodTimes: PeriodTime[] = []

  private openCourseDialog(ev: CalendarEvent,
    raw: RawIcsEvent | null,
    baseFont?: number,
    periodTimes?: PeriodTime[]) {
    this.logger.debug('openCourseDialog fired',
      'summary=', ev?.summary,
      'baseFont=', baseFont,
      'periodsLen=', periodTimes?.length
    );

    this.logger.debug('BEFORE setState', 'showCourseDlg=', this.showCourseDlg, 'dlgEv=', this.dlgEv?.summary);

    this.dlgEv = ev
    this.dlgRaw = raw
    if (baseFont !== undefined) {
      this.dialogBaseFont = baseFont
    }
    if (periodTimes && periodTimes.length > 0) {
      this.dialogPeriodTimes = periodTimes
    }
    this.showCourseDlg = true

    this.logger.debug('AFTER setState', 'showCourseDlg=', this.showCourseDlg, 'dlgEv=', this.dlgEv?.summary);
  }

  private closeCourseDialog(): void {
    this.logger.debug('closeCourseDialog called');
    this.showCourseDlg = false
  }

  @Builder
  private TopSwitcherItem(label: string, key: ScheduleInnerTab) {
    Row() {
      Text(label)
        .fontSize(18)
        .fontWeight(this.current === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.current === key ? '#111827' : '#6B7280')
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .onClick(() => {
      const uiCtx = this.getUIContext()
      uiCtx?.animateTo(
        {
          // 时间可以略长一点，看起来更“弹”
          duration: 380,
          // 关键：弹簧曲线，参数可以自己慢慢调
          // velocity 初速度；mass 质量；stiffness 刚度；damping 阻尼
          curve: curves.springCurve(0, 1, 260, 18),
        },
        () => {
          this.current = key
        }
      )
    })
  }


  @Builder
  private TopSwitcher() {
    Stack() {
      // 灰色背景轨道
      Row() { }
      .width('100%')
      .height(42)
      .backgroundColor('#E5E7EB')
      .borderRadius(24)

      // 白色滑块：通过左右两侧 Blank 的 layoutWeight 来“挤动”位置
      Row() {
        // 左右空白权重反向变化，配合 animateTo 会产生滑动感
        Blank()
          .layoutWeight(this.current === ScheduleInnerTab.Timetable ? 0 : 1)

        Row() { }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(24)

        Blank()
          .layoutWeight(this.current === ScheduleInnerTab.Timetable ? 1 : 0)
      }
      .width('100%')
      .height(42)
      .padding(2) // 让白色块和灰色边缘之间留一点间隙

      // 最上层：真正可点击的文字区域
      Row() {
        this.TopSwitcherItem('课表', ScheduleInnerTab.Timetable)
        this.TopSwitcherItem('DDL', ScheduleInnerTab.DDL)
      }
      .width('100%')
      .height(42)
    }
    .margin({ top: 0, bottom: 0, left: 10, right: 10 })
  }

  build() {
    // 用 Stack 包整页：方便在最上层画遮罩 + 弹窗
    Stack() {
      // ===== 主体内容：上面切换条 + 下面子页面 =====
      Column() {
        this.TopSwitcher()

        // 下面这块占掉剩余空间
        Stack() {
          if (this.current === ScheduleInnerTab.Timetable) {
            // 把点击课程事件从 SchedulePage 抛上来
            SchedulePage({
              onCourseClick: (ev: CalendarEvent,
                raw?: RawIcsEvent | null,
                baseFont?: number,
                periodTimes?: PeriodTime[]) => {
                this.openCourseDialog(ev, raw ? raw : null, baseFont, periodTimes)
              }
            })
          } else {
            // DDL 页目前还不会点出详情，先单纯显示
            DdlPage()
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
      .backgroundColor('#F7F7F7')
      .height('100%')
      .width('100%')

      // ===== 统一的课程详情遮罩 + 弹窗 =====
      // ===== 课程详情弹窗：只控制“要不要挂载” =====
      if (this.showCourseDlg && this.dlgEv) {
        CourseDetailDialog({
          ev: this.dlgEv,
          raw: this.dlgRaw,
          baseFont: this.dialogBaseFont,
          periodTimes: this.dialogPeriodTimes,
          onClose: (): void => {
            this.closeCourseDialog()
          }
        })
      }
    }
    .height('100%')
    .width('100%')
  }
}
