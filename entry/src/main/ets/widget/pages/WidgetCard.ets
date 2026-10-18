// Form UI only receives data; local cache access stays in EntryFormAbility.
import type { WidgetCourseCard, WidgetCourseDeck } from '../../services/schoolSchedule/ScheduleWidgetModel';

const storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('deck') @Watch('resetFocus') deck: WidgetCourseDeck = {
    cards: [], focusIndex: 0, cacheReady: false, emptyText: '先在应用内获取课表'
  };
  @State private selectedIndex: number = 0;

  aboutToAppear(): void {
    this.resetFocus();
  }

  private resetFocus(): void {
    this.selectedIndex = Math.max(0, Math.min(this.deck.focusIndex, this.deck.cards.length - 1));
  }

  private stackColor(depth: number): string {
    const index = (this.selectedIndex + depth) % this.deck.cards.length;
    return this.deck.cards[index]?.color || '#4F46E5';
  }

  private openSchedule(): void {
    postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { action: 'openSchedule', tab: '0' } });
  }

  @Builder
  CourseFace(card: WidgetCourseCard, index: number) {
    Column({ space: 5 }) {
      Row() {
        Text(card.heading).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#E6FFFFFF').layoutWeight(1)
        Text(card.status).fontSize(10).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 }).borderRadius(7).backgroundColor('#24FFFFFF')
      }.width('100%')
      Text(card.name).fontSize(21).fontWeight(FontWeight.Bold).fontColor(Color.White)
        .width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(card.room).fontSize(12).fontColor('#E6FFFFFF').width('100%')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank().layoutWeight(1)
      Row({ space: 8 }) {
        Text(card.time).fontSize(17).fontWeight(FontWeight.Medium).fontColor(Color.White)
        Text(card.sections).fontSize(10).fontColor('#D9FFFFFF').layoutWeight(1)
        if (this.deck.cards.length > 1) {
          Text((index + 1) + ' / ' + this.deck.cards.length).fontSize(10).fontColor('#CCFFFFFF')
        }
      }.width('100%')
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 11, bottom: 11 })
      .alignItems(HorizontalAlign.Start).borderRadius(18).backgroundColor(card.color)
      .onClick(() => this.openSchedule())
      .accessibilityText(card.heading + '，' + card.name + '，' + card.time + '，' + card.room + '，' + card.status)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.deck.cards.length > 0) {
        if (this.deck.cards.length > 2) {
          Column().width('88%').height('94%').borderRadius(18)
            .backgroundColor(this.stackColor(2)).opacity(0.35).align(Alignment.Bottom)
            .animation({ duration: 280, curve: Curve.EaseInOut })
        }
        if (this.deck.cards.length > 1) {
          Column().width('94%').height('97%').borderRadius(18)
            .backgroundColor(this.stackColor(1)).opacity(0.65).align(Alignment.Bottom)
            .animation({ duration: 280, curve: Curve.EaseInOut })
        }
        Swiper() {
          ForEach(this.deck.cards, (card: WidgetCourseCard, index: number) => {
            this.CourseFace(card, index)
          }, (card: WidgetCourseCard) => card.id)
        }.width('100%').height(this.deck.cards.length > 1 ? 'calc(100% - 12vp)' : '100%')
          .vertical(true).index(this.selectedIndex).loop(false).indicator(false)
          .curve(Curve.EaseInOut).itemSpace(10)
          .onChange((index: number) => { this.selectedIndex = index; })
      } else {
        Column({ space: 8 }) {
          Text(this.deck.cacheReady ? '今天' : '课程卡片').fontSize(13).fontColor('#CCFFFFFF')
          Text(this.deck.emptyText).fontSize(18).fontWeight(FontWeight.Medium).fontColor(Color.White)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          .borderRadius(18).backgroundColor('#475569').onClick(() => this.openSchedule())
      }
    }.width('100%').height('100%').clip(true)
  }
}
