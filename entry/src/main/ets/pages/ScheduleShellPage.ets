// entry/src/main/ets/pages/ScheduleShellPage.ets

import SchedulePage from './SchedulePage'
import DdlPage from './DdlPage'
import { CourseDetailDialog } from '../components/schedule/CourseDetailDialog'
import type { CalendarEvent } from '../services/jw/timetableRepository'
import type { RawIcsEvent } from '../services/storage/semesterStore'
import type { PeriodTime } from '../services/jw/periodTimes'

enum ScheduleInnerTab {
  Timetable = 0, // 课表
  DDL = 1        // DDL
}

@Component
export default struct ScheduleShellPage {
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
    console.info('[Shell] openCourseDialog fired, summary=',
      ev ? ev.summary : 'null',
      ', baseFont=', baseFont,
      ', periodsLen=', periodTimes ? periodTimes.length : 'null')

    console.info('[Shell] BEFORE setState, showCourseDlg=',
      this.showCourseDlg,
      ', dlgEv=',
      this.dlgEv ? this.dlgEv.summary : 'null')

    this.dlgEv = ev
    this.dlgRaw = raw
    if (baseFont !== undefined) {
      this.dialogBaseFont = baseFont
    }
    if (periodTimes && periodTimes.length > 0) {
      this.dialogPeriodTimes = periodTimes
    }
    this.showCourseDlg = true

    console.info('[Shell] AFTER setState, showCourseDlg=',
      this.showCourseDlg,
      ', dlgEv=',
      this.dlgEv ? this.dlgEv.summary : 'null')
  }

  private closeCourseDialog(): void {
    console.info('[Shell] closeCourseDialog called')
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
        .textAlign(TextAlign.Center) // ✅ 文本在自己那一半水平居中
    }
    .layoutWeight(1)  // 一人一半
    .onClick(() => {
      // ✅ 用 animateTo 做滑动动画
      animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
        this.current = key
      })
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
      if (this.showCourseDlg && this.dlgEv) {
        // 整个遮罩层：盖在所有内容之上
        Stack() {
          // 半透明黑色背景，挡住下面内容 & 可点击关闭
          Row() { }
          .width('100%')
          .height('100%')
          .backgroundColor('#00000066')
          .onClick(() => {
            this.closeCourseDialog()
          })

          // 白色内容卡片交给 CourseDetailDialog 来画
          CourseDetailDialog({
            show: true, // 这里直接传 true，内部就别再管 show 了
            ev: this.dlgEv,
            raw: this.dlgRaw,
            baseFont: this.dialogBaseFont,
            periodTimes: this.dialogPeriodTimes,
            onClose: (): void => {
              this.closeCourseDialog()
            }
          })
        }
        .width('100%')
        .height('100%')
      }
    }
    .height('100%')
    .width('100%')
  }
}
