// entry/src/main/ets/components/gallery/PosterCard.ets
import { Poster, GalleryImage } from '../../services/gallery/GalleryModels';
import { TimeUtils } from '../../utils/TimeUtils';
import { RCP_BASE_URL } from '../../core/network/bit101Session';
import promptAction from '@ohos.promptAction';
import { AvatarWithVerified } from './AvatarWithVerified';
import { UserNameWithIdentity } from './UserNameWithIdentity';
import router from '@ohos.router';
import { ImageViewer } from '../ImageViewer';
import { uiPushUrl, uiShowToast } from '../../utils/uiContextBridge';

@Component
export struct PosterCard {
  @Prop poster: Poster;

  // 外部传入的点击回调
  onClickPoster?: () => void;

  @State isPreviewOpen: boolean = false;
  @State previewIndex: number = 0;

  private onUserClick() {
    // 获取用户ID
    const targetUid = this.poster.user?.id;

    // 如果ID无效（比如是匿名用户），提示一下
    if (!targetUid || targetUid === '0' || targetUid === '-1') {
      uiShowToast(this.getUIContext(), { message: '无法查看该用户详情' });
      return;
    }

    // 2. 执行路由跳转
    uiPushUrl(this.getUIContext(), {
      url: 'pages/UserDetailPage',
      params: {
        uid: parseInt(targetUid) // 确保传过去的是数字
      }
    }).catch((err: Error) => {
      console.error(`跳转失败, message: ${err.message}`);
    });
  }

  private onImageClick(index: number) {
    this.previewIndex = index;
    this.isPreviewOpen = true;
  }

  @Builder
  PhotoViewerBuilder() {
    ImageViewer({
      images: this.poster.images || [],
      initialIndex: this.previewIndex,
      onClose: () => {
        this.isPreviewOpen = false;
      }
    })
  }

  build() {
    Column() {
      Column() {
        // 0. 标题
        if (this.hasTitle()) {
          Text(this.poster.title!)
            .fontSize(16) // Android: TitleMedium (~16sp)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(24)
            .width('100%')
            .margin({ bottom: 4 }); // Android: Spacer 2dp (visual approx 4vp)
        }

        // 1. 布局分支
        if (this.hasFewImages()) {
          // === 分支 1：1~2 张图 (左右布局) ===
          // Android高度设置为 128dp
          Row() {
            // 左侧：头像 -> 正文 -> 底部信息 (垂直分布，自动撑满)
            Column() {
              this.AvatarWithName()

              // 模拟 Android BoxWithConstraints 计算行数逻辑
              // 这里使用 layoutWeight 让文字区域占据剩余空间
              Text(this.poster.text || '')
                .fontSize(14) // Android: BodyMedium
                .fontColor($r('sys.color.font_primary'))
                .lineHeight(20)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(4) // 限制最大行数防止溢出
                .margin({ top: 2, bottom: 4 })
                .layoutWeight(1) // 关键：占据中间剩余高度
                .align(Alignment.TopStart) // 文字顶对齐

              this.InfoBar()
            }
            .layoutWeight(1) // 占满左侧宽度
            .height('100%')  // 占满固定高度
            .padding({ right: 8 }) // 右侧间距
            .alignItems(HorizontalAlign.Start)

            // 右侧：第一张图片
            this.FirstImageBox()
          }
          .width('100%')
          .height(128) // Android: val height = 128.dp
          .alignItems(VerticalAlign.Top) // 顶部对齐

        } else {
          // === 分支 2：0 张 或 ≥3 张图 (垂直布局) ===

          this.AvatarWithName()

          if (this.poster.text) {
            Text(this.poster.text)
              .fontSize(14) // Android: BodyMedium
              .fontColor($r('sys.color.font_primary'))
              .maxLines(3)
              .lineHeight(20)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: 2 });
          }

          // 图片显示逻辑：≥3 张图才显示 Grid
          if (this.hasManyImages()) {
            this.ImageGrid(this.poster.images)
          }

          this.InfoBar()
        }
      }
      .width('100%')
      .padding(12) // Android: padding(12.dp)
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background')) // Surface color
    .onClick(() => {
      if (this.onClickPoster) {
        this.onClickPoster();
      } else {
        // 默认卡片点击行为
        uiShowToast(this.getUIContext(), { message: `打开帖子详情 ID: ${this.poster.id}` });
      }
    })
    // ✅ 补全这里：绑定全屏模态，实现大图预览
    .bindContentCover(this.isPreviewOpen, this.PhotoViewerBuilder(), {
      modalTransition: ModalTransition.ALPHA,
      backgroundColor: Color.Black,
      onDisappear: () => { this.isPreviewOpen = false }
    })
  }


  // ---------- 逻辑辅助方法 ----------

  private getImages(): GalleryImage[] {
    return this.poster.images ?? [];
  }

  private getImageCount(): number {
    return this.getImages().length;
  }

  private hasTitle(): boolean {
    return !!this.poster.title && this.poster.title.length > 0;
  }

  private hasFewImages(): boolean {
    const count = this.getImageCount();
    return count > 0 && count <= 2;
  }

  private hasManyImages(): boolean {
    return this.getImageCount() >= 3;
  }

  private getNickname(): string {
    if (this.poster.anonymous) return '匿名用户';
    return this.poster.user?.nickname ?? '匿名用户';
  }

  // 构造底部信息字符串
  private getInfoText(): string {
    const rawTime = this.poster.editTime || this.poster.createTime;
    const diff = TimeUtils.getRelativeTime(rawTime);
    const likeNum = this.poster.likeNum ?? 0;
    const commentNum = this.poster.commentNum ?? 0;
    const visibility = this.poster.public ? '' : ' · 仅自己可见';
    return `${likeNum}赞 · ${commentNum}评${visibility} · ${diff}`;
  }

  // 获取显示的图片切片
  private getGridImages(images: GalleryImage[]): GalleryImage[] {
    if (!images) return [];
    // Android逻辑: if size==3 subList(0,3) else subList(0,4)
    const count = images.length;
    const maxCount = count === 3 ? 3 : 4;
    return images.slice(0, maxCount);
  }

  private getAvatarUrl(url?: string): string | Resource {
    if (!url || this.poster.anonymous) return $r('app.media.startIcon'); // 替换为你的默认头像资源
    const safeUrl = String(url);
    if (safeUrl.startsWith('http')) return safeUrl;
    return `${RCP_BASE_URL}${safeUrl}`;
  }

  // ---------- UI Components ----------

  @Builder
  AvatarWithName() {
    Row() {
      // ✅ 替换为：带认证的头像组件
      AvatarWithVerified({
        user: this.poster.user,
        avatarSize: 20, // 列表页头像比较小，原来是 20
        onClickUser: () => {
          // 这里处理点击头像逻辑 (如果需要的话)
          this.onUserClick();
        }
      })

      // ✅ 替换为：带身份标签的昵称组件
      UserNameWithIdentity({
        user: this.poster.user,
        fontSize: 13, // 列表页字号
        fontColor: '#4B5563'
      })
        .layoutWeight(1) // 占满剩余空间
        .margin({ left: 6 }) // 名字和头像的间距
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  InfoBar() {
    Text(this.getInfoText())
      .fontSize(12) // Android: labelMedium
      .fontColor($r('sys.color.font_secondary')) // Android: onSurface copy alpha 0.6
      .width('100%')
      .margin({ top: 4 }) // margin(top=4.dp)
  }

  @Builder
  FirstImageBox() {
    // 右侧大图 (1-2张模式)
    Image(this.getImages()[0]?.url ?? '')
      .width(128)  // 保持正方形或固定宽高，对应 Android height=128.dp
      .height(128)
      .objectFit(ImageFit.Cover)
      .borderRadius(4)
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .onClick(() => this.onImageClick(0))
  }

  @Builder
  ImageGrid(images: GalleryImage[]) {
    // 动态计算显示数量
    // Android: if(data.images.size == 3) -> 3 columns, else -> 4 columns (based on maxCount=4)
    // 这里为了视觉对齐，3张图显示1行3列，4张图显示1行4列

    Grid() {
      ForEach(this.getGridImages(images), (img: GalleryImage, index: number) => {
        GridItem() {
          Image(img.url)
            .width('100%')
            .aspectRatio(1) // 1:1 正方形
            .objectFit(ImageFit.Cover)
            .borderRadius(4)
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .onClick(() => this.onImageClick(index))
        }
      })
    }
    .columnsTemplate(images.length === 3 ? '1fr 1fr 1fr' : '1fr 1fr 1fr 1fr') // 动态列数对齐安卓逻辑
    .columnsGap(4) // padding(4.dp)
    .rowsGap(4)
    .width('100%')
    // 计算 Grid 高度: 只有一行，所以高度 = (ScreenWidth - padding - gaps) / cols
    // 这里简单给定一个高度范围或让其自适应，Grid默认需要高度。
    // 由于是单行显示(3或4个)，使用 aspectRatio 在外层限制更佳，或者定高
    .height(this.calcGridHeight(images.length))
    .margin({ top: 4 })
  }

  // 简单的 Grid 高度估算，确保 Grid 可见
  calcGridHeight(totalCount: number): number {
    // 假设屏幕宽度约 360vp，减去 padding 24vp
    // 3列: (336 - 8)/3 ≈ 109
    // 4列: (336 - 12)/4 ≈ 81
    // 这是一个近似值，实际项目中最好用 Flex Wrap 或动态计算
    const isThree = totalCount === 3;
    return isThree ? 110 : 85;
  }
}
