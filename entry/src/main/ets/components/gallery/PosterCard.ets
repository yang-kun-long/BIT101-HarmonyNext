// entry/src/main/ets/components/gallery/PosterCard.ets
import { Poster, GalleryImage } from '../../services/gallery/GalleryModels';
import { TimeUtils } from '../../utils/TimeUtils';
import { RCP_BASE_URL } from '../../core/network/bit101Session';
import promptAction from '@ohos.promptAction';

@Component
export struct PosterCard {
  @Prop poster: Poster;
  onClickPoster?: () => void;
  aboutToAppear() {
    console.info('[PosterCard]', 'poster = ' + JSON.stringify(this.poster));
  }


  build() {
    Column() {
      // 0. 标题（对应 Android: Text(data.title, style = titleMedium)）
      if (this.hasTitle()) {
        Text(this.poster.title!)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 6 });
      }

      // 1. 根据图片数量分支布局
      if (this.hasFewImages()) {
        // === 分支 1：1~2 张图，横排布局 ===
        Row() {
          // 左侧：头像 + 正文 + Info
          Column() {
            this.AvatarWithName();

            if (this.poster.text) {
              Text(this.poster.text)
                .fontSize(15)
                .fontColor('#333333')
                .maxLines(4)
                .lineHeight(22)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 });
            }

            this.InfoBar();
          }
          .layoutWeight(1)
          .margin({ right: 8 });

          // 右侧：第一张图片
          this.FirstImageBox();
        }
        .width('100%')
        .margin({ top: 6 });
      } else {
        // === 分支 2：0 张 或 ≥3 张图，纵向布局 ===

        // 头像 + 昵称
        this.AvatarWithName();

        // 正文
        if (this.poster.text) {
          Text(this.poster.text)
            .fontSize(15)
            .fontColor('#333333')
            .maxLines(3)
            .lineHeight(22)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 4 });
        }

        // 图片网格（≥3 张时显示）
        if (this.hasManyImages()) {
          this.ImageGrid(this.poster.images);
        }

        // 底部 Info
        this.InfoBar();
      }
    }
    .backgroundColor(Color.White)
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .margin({ bottom: 10 })
    .onClick(() => {
      if (this.onClickPoster) {
        this.onClickPoster();
      } else {
        promptAction.showToast({
          message: `即将打开帖子 ID: ${this.poster.id}`,
          duration: 2000
        });
      }
    });
  }

  // ---------- 纯逻辑方法：不在 UI 区内写 const/let ----------

  private getImages(): GalleryImage[] {
    return this.poster.images ?? [];
  }

  private getImageCount(): number {
    const imgs = this.getImages();
    return imgs.length;
  }

  private hasTitle(): boolean {
    return !!this.poster.title && this.poster.title!.length > 0;
  }

  private hasFewImages(): boolean {
    const count = this.getImageCount();
    return count > 0 && count <= 2;
  }

  private hasManyImages(): boolean {
    const count = this.getImageCount();
    return count >= 3;
  }

  private getFirstImage(): GalleryImage | undefined {
    const imgs = this.getImages();
    return imgs.length > 0 ? imgs[0] : undefined;
  }

  private getNickname(): string {
    if (this.poster.anonymous) {
      return '匿名用户';
    }
    if (this.poster.user && this.poster.user.nickname) {
      return this.poster.user.nickname;
    }
    return '匿名用户';
  }

  private getInfoText(): string {
    const rawTime = this.poster.editTime || this.poster.createTime;
    const diff = TimeUtils.getRelativeTime(rawTime); // 内部返回 '未知' 或 'xx分钟前'

    const likeNum = this.poster.likeNum ?? 0;
    const commentNum = this.poster.commentNum ?? 0;

    const visibility = this.poster.public ? '' : ' · 仅自己可见';
    return `${likeNum}赞 · ${commentNum}评${visibility} · ${diff}`;
  }


  private getGridImages(images: GalleryImage[]): GalleryImage[] {
    if (!images) {
      return [];
    }
    const count = images.length;
    if (count === 0) {
      return [];
    }
    const maxCount = count >= 4 ? 4 : count; // Android: 3 或 4
    return images.slice(0, maxCount);
  }

  private getAvatarUrl(url?: string): string | Resource {
    if (!url || this.poster.anonymous) {
      return $r('app.media.startIcon');
    }
    const safeUrl = String(url);
    if (safeUrl.startsWith('http://') || safeUrl.startsWith('https://')) {
      return safeUrl;
    }
    return `${RCP_BASE_URL}${safeUrl}`;
  }

  // ---------- UI Builder 部分：只写组件语法 + if/ForEach ----------

  @Builder
  AvatarWithName() {
    Row() {
      Image(this.getAvatarUrl(this.poster.user?.avatar))
        .width(20)
        .height(20)
        .borderRadius(10)
        .backgroundColor('#F3F4F6')
        .objectFit(ImageFit.Cover)
        .alt($r('app.media.startIcon'));

      Text(this.getNickname())
        .fontSize(13)
        .fontColor('#4B5563')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 6 });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  InfoBar() {
    Text(this.getInfoText())
      .fontSize(12)
      .fontColor('#991F2937') // 约等于 onSurface 60% 透明度
      .width('100%')
      .margin({ top: 6 });
  }

  // 1~2 张图时用的右侧预览
  // 1~2 张图时用的右侧预览
  @Builder
  FirstImageBox() {
    if (this.hasFirstImage()) {
      Image(this.getFirstImageUrl())
        .width(120)
        .height(120)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .backgroundColor('#EEEEEE');
    } else {
      Column()
        .width(120)
        .height(120)
        .borderRadius(8)
        .backgroundColor('#EEEEEE');
    }
  }

  private hasFirstImage(): boolean {
    const img = this.getFirstImage();
    return !!(img && img.url);
  }

  private getFirstImageUrl(): string {
    const img = this.getFirstImage();
    return img && img.url ? img.url : '';
  }


  @Builder
  ImageGrid(images: GalleryImage[]) {
    // 这里不能用 let，只能直接在表达式里调方法
    if (this.getGridImages(images).length === 0) {
      // 不渲染任何内容
    } else {
      Grid() {
        ForEach(
          this.getGridImages(images),
          (img: GalleryImage) => {
            GridItem() {
              if (img && img.url) {
                Image(img.url)
                  .width('100%')
                  .aspectRatio(1)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(4)
                  .backgroundColor('#EEEEEE');
              } else {
                Column()
                  .width('100%')
                  .aspectRatio(1)
                  .borderRadius(4)
                  .backgroundColor('#EEEEEE');
              }
            }
          },
          (img: GalleryImage, index?: number) => index!.toString()
        );
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .height(this.getGridHeight(images))
      .width('100%')
      .margin({ top: 6 });
    }
  }

  private getGridHeight(images: GalleryImage[]): number {
    const gridImages = this.getGridImages(images);
    return this.calcGridHeight(gridImages.length);
  }

  calcGridHeight(count: number): number {
    const rowHeight = 110;
    const gap = 4;
    if (count <= 3) {
      return rowHeight;
    }
    if (count <= 6) {
      return rowHeight * 2 + gap;
    }
    return rowHeight * 3 + gap * 2;
  }
}
