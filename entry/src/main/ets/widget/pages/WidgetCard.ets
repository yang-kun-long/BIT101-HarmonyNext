// entry/src/main/ets/widgets/WidgetCard.ets

// ✅ 不要 import formProvider / postCardAction
// ✅ 在 ArkTS 中声明全局函数签名，避免“对象字面量当类型”等检查报错
interface RouterParams {
  courseId: string;
  courseName: string;
  action: string;
}
interface RouterEvent {
  action: 'router' | 'message' | 'call';
  abilityName?: string;
  bundleName?: string;
  moduleName?: string;
  uri?: string;
  params: RouterParams;
}
// 按官方签名声明（component 用 object；不要用 any/unknown）
declare function postCardAction(component: object, action: RouterEvent): void;

interface Course {
  id?: string;
  name: string;
  time: string;
  room?: string;
}
interface NavParams {
  courseId?: string;
  courseName?: string;
  action?: string;
}

@Entry
@Component
export default struct WidgetCard {
  // 由 FormBindingData 注入
  @State title: string = '今日课程';
  @State courses: Course[] = [];
  @State emptyText: string = '今天没有课～';

  private readonly actionType: 'router' = 'router';
  private readonly abilityName: string = 'EntryAbility';
  private readonly fullWidthPercent: string = '100%';
  private readonly fullHeightPercent: string = '100%';

  private buildEvent(payload?: NavParams): RouterEvent {
    const params: RouterParams = {
      courseId: payload && payload.courseId ? payload.courseId : '',
      courseName: payload && payload.courseName ? payload.courseName : '',
      action: payload && payload.action ? payload.action : ''
    };
    const evt: RouterEvent = {
      action: this.actionType,       // 'router'
      abilityName: this.abilityName, // 你的 UIAbility 名称
      params: params
    };
    return evt;
  }

  private launchToDetail(payload?: NavParams): void {
    const evt: RouterEvent = this.buildEvent(payload);
    // ✅ 直接调用全局 postCardAction（无任何 import/命名空间）
    postCardAction(this, evt);
  }

  build() {
    Column() {
      // 标题
      Text(this.title)
        .fontSize($r('app.float.font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font'))
        .margin({ bottom: 6 })

      // 课程列表 / 空状态
      if (this.courses && this.courses.length > 0) {
        ForEach(
          this.courses.slice(0, 4),
          (c: Course) => {
            Row() {
              // 左：时间
              Column() {
                Text(c.time)
                  .fontSize(14)
                  .fontColor($r('sys.color.font_secondary'))
              }
              .width('30%')

              // 右：课程名 + 教室
              Column() {
                Text(c.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (c.room) {
                  Text(c.room)
                    .fontSize(12)
                    .fontColor($r('sys.color.font_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('70%')
            }
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              const p: NavParams = {
                courseId: c.id ? c.id : '',
                courseName: c.name
              };
              this.launchToDetail(p);
            })
          },
          (c: Course) => c.id ? c.id : (c.time + '-' + c.name) // key
        )
      } else {
        Row() {
          Text(this.emptyText)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .height(48)
      }

      // 底部：查看全部
      Row() {
        Text('查看全部课表')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .justifyContent(FlexAlign.Center)
      .height(32)
      .onClick(() => {
        const p: NavParams = { action: 'openSchedule' };
        this.launchToDetail(p);
      })
    }
    .width(this.fullWidthPercent)
    .height(this.fullHeightPercent)
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }
}
