// entry/src/main/ets/pages/ReportPage.ets

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { reportService, ReportType } from '../services/manage/ReportService';
import { Logger } from '../utils/Logger';

@Entry
@Component
export default struct ReportPage {
  private logger: Logger = new Logger('ReportPage');

  // 路由参数
  @State private objType: string = '';  // 'poster' / 'comment' / 其他
  @State private objId: number = 0;

  // 举报类型列表 & 选择状态
  @State private loadingTypes: boolean = true;
  @State private loadTypesError: boolean = false;
  @State private reportTypes: ReportType[] = [];
  @State private selectedTypeIndex: number = 0;

  // 文本内容 & 提交状态
  @State private text: string = '';
  @State private submitting: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    const typeParam = params && params['type'];
    const idParam = params && params['id'];

    if (typeof typeParam === 'string') {
      this.objType = typeParam;
    } else {
      this.objType = '';
    }

    if (typeof idParam === 'number') {
      this.objId = idParam;
    } else if (typeof idParam === 'string') {
      // 如果从其他页面传的是字符串，这里尝试转一下
      const parsed = Number(idParam);
      if (!Number.isNaN(parsed)) {
        this.objId = parsed;
      }
    }

    if (!this.objType || !this.objId) {
      this.showToast('举报参数不正确');
      // 参数有问题就直接返回上一页，避免页面空挂着
      try {
        router.back();
      } catch (_) {
        // ignore
      }
      return;
    }

    this.loadReportTypes();
  }

  private async loadReportTypes(): Promise<void> {
    this.loadingTypes = true;
    this.loadTypesError = false;

    try {
      const list = await reportService.getReportTypes();
      this.reportTypes = list;
      if (list.length > 0) {
        this.selectedTypeIndex = 0;
      }
    } catch (e) {
      this.logger.error('[ReportPage] loadReportTypes error', e);
      this.loadTypesError = true;
      this.showToast('加载举报类型失败，请稍后重试');
    } finally {
      this.loadingTypes = false;
    }
  }

  private getTitle(): string {
    if (this.objType === 'poster') {
      return `举报帖子#${this.objId}`;
    }
    if (this.objType === 'comment') {
      return `举报评论#${this.objId}`;
    }
    return `举报${this.objType}#${this.objId}`;
  }

  private getSelectedTypeText(): string {
    if (!this.reportTypes || this.reportTypes.length === 0) {
      return '暂无可用类型';
    }
    const idx = this.selectedTypeIndex;
    if (idx < 0 || idx >= this.reportTypes.length) {
      return '请选择举报类型';
    }
    return this.reportTypes[idx].text;
  }

  private canSubmit(): boolean {
    // 至少要有类型列表，防止没有选项也能点提交
    if (!this.reportTypes || this.reportTypes.length === 0) {
      return false;
    }
    if (this.selectedTypeIndex < 0 || this.selectedTypeIndex >= this.reportTypes.length) {
      return false;
    }
    if (!this.text || this.text.trim().length === 0) {
      return false;
    }
    if (this.submitting) {
      return false;
    }
    return true;
  }

  private showToast(msg: string): void {
    promptAction.showToast({
      message: msg,
      duration: 1500
    });
  }

  private async submitReport(): Promise<void> {
    if (!this.canSubmit()) {
      return;
    }

    const idx = this.selectedTypeIndex;
    const typeItem = this.reportTypes[idx];

    this.submitting = true;
    try {
      let ok: boolean = false;

      if (this.objType === 'poster') {
        ok = await reportService.reportPoster(this.objId, typeItem.id, this.text);
      } else if (this.objType === 'comment') {
        ok = await reportService.reportComment(this.objId, typeItem.id, this.text);
      } else {
        ok = await reportService.report(`obj${this.objId}`, typeItem.id, this.text);
      }

      if (ok) {
        this.showToast('举报成功');
        try {
          router.back();
        } catch (_) {
          // ignore
        }
      } else {
        this.showToast('举报失败（Tips: 不要举报自己哦！）');
      }
    } catch (e) {
      this.logger.error('[ReportPage] submitReport error', e);
      this.showToast('举报失败（Tips: 不要举报自己哦！）');
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      // 顶部简易标题栏
      Row() {
        Text('< 返回')
          .fontSize(14)
          .fontColor('#2563EB')
          .onClick(() => {
            try {
              router.back();
            } catch (_) {
              // ignore
            }
          });

        Text(this.getTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .margin({ left: 12 })
          .layoutWeight(1);

        // 右侧占位
        Blank().width(24).height(24);
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(Color.White)
      .border({ width: { bottom: 0.5 }, color: '#E5E7EB' });

      // 内容区域
      if (this.loadingTypes) {
        Column() {
          Text('正在加载举报类型...')
            .fontSize(14)
            .fontColor('#6B7280');
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center);
      } else if (this.loadTypesError) {
        Column() {
          Text('举报类型加载失败')
            .fontSize(14)
            .fontColor('#EF4444')
            .margin({ bottom: 8 });
          Text('点击重试')
            .fontSize(14)
            .fontColor('#2563EB')
            .onClick(() => {
              this.loadReportTypes();
            });
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center);
      } else {
        // 正常内容
        Scroll() {
          Column() {
            // 举报类型
            Text('举报类型')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 6 });

            // 当前选中的类型 + 列表
            Column() {
              Text(this.getSelectedTypeText())
                .fontSize(14)
                .fontColor('#111827')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor('#F3F4F6')
                .borderRadius(8)
                .width('100%');

              // 简单的列表点击选择，不用下拉控件，兼容性更好
              if (this.reportTypes && this.reportTypes.length > 0) {
                Column() {
                  ForEach(this.reportTypes, (item: ReportType, index: number) => {
                    Row() {
                      // 选中圆点
                      Circle()
                        .width(12)
                        .height(12)
                        .fill(this.selectedTypeIndex === index ? '#2563EB' : '#E5E7EB');

                      Text(item.text)
                        .fontSize(14)
                        .fontColor('#111827')
                        .margin({ left: 8 });
                    }
                    .padding({ top: 8, bottom: 8 })
                    .onClick(() => {
                      this.selectedTypeIndex = index;
                    });
                  });
                }
                .margin({ top: 8 });
              }
            }
            .width('100%')
            .margin({ bottom: 16 });

            // 文本输入
            Text('内容')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
              .margin({ bottom: 6 });

            TextArea({
              text: this.text,
              placeholder: '在这里输入内容哦'
            })
              .maxLength(500)
              .fontSize(14)
              .height(160)
              .width('100%')
              .borderRadius(8)
              .backgroundColor('#F9FAFB')
              .padding(12)
              .onChange((val: string) => {
                this.text = val;
              });


            // 占位让底部按钮不贴太近
            Blank()
              .height(80);
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 });
        }
        .layoutWeight(1);
      }

      // 底部提交按钮
      Row() {
        Blank().layoutWeight(1);

        Flex() {
          Text(this.submitting ? '提交中...' : '提交举报')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White);
        }
        .height(40)
        .padding({ left: 20, right: 20 })
        .backgroundColor(this.canSubmit() ? '#DC2626' : '#F87171')
        .borderRadius(20)
        .opacity(this.canSubmit() ? 1 : 0.6)
        .onClick(() => {
          if (this.canSubmit()) {
            this.submitReport();
          }
        });
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16, bottom: 12 })
      .backgroundColor(Color.White)
      .border({ width: { top: 0.5 }, color: '#E5E7EB' });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White);
  }
}
