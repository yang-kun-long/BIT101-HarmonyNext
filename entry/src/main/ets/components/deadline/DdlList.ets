// entry/src/main/ets/components/deadline/DdlList.ets

import { LexueCalendarStore } from '../../services/storage/LexueCalendarStore';
import type { LexueCalendarEvent } from '../../services/lexue/LexueCalendarParser';
import { DdlDetailDialog } from './DdlDetailDialog';
import { DdlCard } from './DdlCard';
@Component
export default struct DdlList {
  @State private ddlList: LexueCalendarEvent[] = [];
  @State private loading: boolean = true;

  // 弹框相关状态
  @State private showDetail: boolean = false;
  @State private currentEvent: LexueCalendarEvent | null = null;

  private store: LexueCalendarStore = new LexueCalendarStore();

  aboutToAppear(): void {
    this.loadDdl().catch((err: Error) => {
      console.error('[DdlList] loadDdl failed', err);
    });
  }

  private async loadDdl(): Promise<void> {
    this.loading = true;
    try {
      const allEvents: LexueCalendarEvent[] = await this.store.getEvents();
      const now: number = Date.now();

      const ddlEvents: LexueCalendarEvent[] = allEvents
        .filter((e: LexueCalendarEvent): boolean => {
          const time: number = e.endTime ?? e.startTime;
          if (time < now) {
            return false;
          }
          const text: string =
            (e.title ?? '') + (e.description ?? '') + (e.location ?? '');
          const lower: string = text.toLowerCase();
          return (
            text.includes('作业') ||
            text.includes('考试') ||
            text.includes('测验') ||
            text.includes('实验') ||
            lower.includes('assignment') ||
            lower.includes('homework') ||
            lower.includes('quiz') ||
            lower.includes('exam') ||
            lower.includes('ddl') ||
            lower.includes('deadline')
          );
        })
        .sort((a: LexueCalendarEvent, b: LexueCalendarEvent): number => {
          const ta: number = a.endTime ?? a.startTime;
          const tb: number = b.endTime ?? b.startTime;
          return ta - tb;
        });

      this.ddlList = ddlEvents;
      console.info('[DdlList] loadDdl done, count=', this.ddlList.length);
    } catch (err) {
      console.error('[DdlList] loadDdl error', err);
      this.ddlList = [];
    } finally {
      this.loading = false;
    }
  }

  // ---------- 与详情页一致的一些格式化 ----------

  private formatTime(ts: number): string {
    const d: Date = new Date(ts);
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const hour: string = d.getHours().toString().padStart(2, '0');
    const minute: string = d.getMinutes().toString().padStart(2, '0');
    return `${m}/${day} ${hour}:${minute}`;
  }

  private timeText(ev: LexueCalendarEvent): string {
    const start: string = this.formatTime(ev.startTime);
    if (!ev.endTime || ev.endTime === ev.startTime) {
      return `截止：${start}`;
    }
    const end: string = this.formatTime(ev.endTime);
    return `${start} - ${end}`;
  }

  private prettyTitle(ev: LexueCalendarEvent): string {
    let raw: string = ev.title ?? '(未命名 DDL)';
    raw = raw.replace(/\s*已到期\s*$/u, '');
    return raw;
  }

  // 直接用解析时存好的 courseName，不再从标题里瞎猜
  private courseName(ev: LexueCalendarEvent): string {
    return (ev.courseName ?? '').trim();
  }



  private ddlTypeTag(ev: LexueCalendarEvent): string {
    const text: string = (ev.title ?? '').toLowerCase();
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

  private getDescriptionText(ev: LexueCalendarEvent): string {
    if (!ev.description) {
      return '';
    }
    let text: string = ev.description as string;
    text = text.replace(/\\n/g, '\n');
    text = text.replace(/[ \u00A0\t]*\n[ \u00A0\t]*/g, '\n');
    text = text.replace(/\n{3,}/g, '\n\n');
    return text.trim();
  }

  private stripBullet(line: string): string {
    const trimmed: string = line.trim();
    if (trimmed.startsWith('•') || trimmed.startsWith('·')) {
      return trimmed.substring(1).trim();
    }
    return trimmed;
  }

  // 列表里用的一行摘要：找第一行非空内容，截断到 N 个字符
  private summaryText(ev: LexueCalendarEvent): string {
    const t: string = this.getDescriptionText(ev);
    if (t.length === 0) {
      return '';
    }
    const lines: string[] = t.split('\n');
    let first: string = '';
    for (let i = 0; i < lines.length; i++) {
      const s: string = this.stripBullet(lines[i]);
      if (s.length > 0) {
        first = s;
        break;
      }
    }
    if (first.length === 0) {
      return '';
    }
    const limit: number = 40;
    if (first.length > limit) {
      return first.substring(0, limit) + '…';
    }
    return first;
  }

  private getEventColor(event: LexueCalendarEvent): string {
    const text: string = (event.title ?? '').toLowerCase();
    if (text.includes('考试') || text.includes('exam')) {
      return '#F97373';
    }
    if (text.includes('实验') || text.includes('lab')) {
      return '#60A5FA';
    }
    if (text.includes('测验') || text.includes('quiz')) {
      return '#FBBF24';
    }
    return '#34D399';
  }

  // ---------- 点击 / 弹框 ----------

  private onItemClick(event: LexueCalendarEvent): void {
    console.info('[DdlList] onItemClick, uid=' + event.uid);
    this.openDetail(event);
  }

  private openDetail(event: LexueCalendarEvent): void {
    console.info('[DdlList] openDetail, uid=' + event.uid);
    this.currentEvent = event;
    this.showDetail = true;
    console.info(
      '[DdlList] after openDetail, showDetail=',
      this.showDetail,
      ', currentTitle=',
      this.currentEvent?.title ?? 'null'
    );
  }

  private onDialogClose(): void {
    console.info('[DdlList] dialog onClose');
    this.showDetail = false;
    this.currentEvent = null;
  }

  // ---------- UI ----------

  build() {
    Stack() {
      // 底层内容
      Column() {
        // 顶部标题
        Row() {
          Text('DDL')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')
        .margin({ top: 0, bottom: 8 })

        if (this.loading) {
          Column() {
            Text('加载中…')
              .fontSize(14)
              .fontColor('#9CA3AF')
              .margin({ top: 24 })
          }
          .width('100%')
          .layoutWeight(1)
        } else if (this.ddlList.length === 0) {
          Column() {
            Text('暂无即将到来的 DDL')
              .fontSize(14)
              .fontColor('#9CA3AF')
              .margin({ top: 24 })
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Column() {
            List() {
              ForEach(
                this.ddlList,
                (item: LexueCalendarEvent) => {
                  ListItem() {
                    DdlCard({
                      event: item,
                      onTap: () => this.onItemClick(item)
                    })
                  }
                  .width('100%')
                  .margin({ top: 4, bottom: 4 })
                },
                (item: LexueCalendarEvent): string => item.uid
              )
            }
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .padding({ left: 10, right: 10, top: 0, bottom: 0 })
      .width('100%')
      .height('100%')
      .backgroundColor('#F3F4F6')

      // 顶层：详情弹框（只在需要时挂载）
      if (this.showDetail && this.currentEvent) {
        DdlDetailDialog({
          ev: this.currentEvent,
          onClose: () => this.onDialogClose()
        })
      }
    }
  }
}
