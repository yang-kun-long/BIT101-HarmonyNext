// entry/src/main/ets/components/gallery/MoreCommentsSheet.ets
import { Comment, GalleryImage, GalleryUser } from '../../services/gallery/GalleryModels';
import { reactionService } from '../../services/gallery/ReactionService';
import { TimeUtils } from '../../utils/TimeUtils';
import { RCP_BASE_URL } from '../../core/network/bit101Session';
import { AvatarWithVerified } from './AvatarWithVerified';
import { UserNameWithIdentity } from './UserNameWithIdentity';

@Component
export struct MoreCommentsSheet {
  // 核心参数
  @Prop parentComment: Comment; // 当前的主评论

  // 交互回调
  onClose: () => void = () => {};
  // 回复某人 (comment: 具体被回复的评论对象)
  onReply: (comment: Comment) => void = () => {};
  onUserClick: (user: GalleryUser) => void = () => {};
  onImageClick: (index: number, images: GalleryImage[]) => void = () => {};

  // 内部状态
  @State subComments: Comment[] = [];
  @State isLoading: boolean = false;
  @State hasMore: boolean = true;
  @State page: number = 0; // 从第0页开始

  aboutToAppear() {
    this.loadData(false);
  }

  async loadData(isLoadMore: boolean) {
    if (this.isLoading) return;
    if (isLoadMore && !this.hasMore) return;

    this.isLoading = true;
    const requestPage = isLoadMore ? this.page + 1 : 0;

    try {
      // 调用刚才在 ReactionService 新增的接口
      const newItems = await reactionService.getCommentsForComment(
        this.parentComment.id,
        requestPage,
        'new' // 默认按最新排序
      );

      if (isLoadMore) {
        this.subComments = [...this.subComments, ...newItems];
      } else {
        this.subComments = newItems;
      }

      if (newItems.length > 0) {
        this.page = requestPage;
        // 假设一页10条，如果返回少于10条说明没更多了 (这里简单判断 > 0)
        // 更严谨的判断依赖后端是否返回 total，或者判断 count < pageSize
        // 这里暂时假设如果返回空就是没有了
      }
      this.hasMore = newItems.length > 0;

    } catch (e) {
      console.error('加载子评论失败', e);
    } finally {
      this.isLoading = false;
    }
  }

  // 辅助方法：获取图片完整URL
  private getImageUrl(url: string): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${RCP_BASE_URL}${url}`;
  }

  private getAvatarUrl(c: Comment): string | Resource {
    if (c.anonymous || !c.user || !c.user.avatar) {
      return $r('app.media.startIcon');
    }
    return this.getImageUrl(c.user.avatar);
  }

  private getTimeText(c: Comment): string {
    return TimeUtils.getRelativeTime(c.updateTime || c.createTime);
  }

  // --- UI Builders ---

  // 图片网格 (复用逻辑)
  @Builder
  CommentImageGrid(images: GalleryImage[]) {
    if (images && images.length > 0) {
      Grid() {
        ForEach(images, (img: GalleryImage, index: number) => {
          GridItem() {
            Image(this.getImageUrl(img.url))
              .width('100%').aspectRatio(1)
              .objectFit(ImageFit.Cover)
              .borderRadius(4).backgroundColor('#F3F4F6')
              .onClick(() => this.onImageClick(index, images))
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(4).rowsGap(4)
      .height(Math.ceil(images.length / 3) * 90)
      .margin({ top: 8 })
    }
  }

  // 单条评论项
  @Builder
  ItemBuilder(c: Comment, isParent: boolean = false) {
    Row() {
      // 头像
      Image(this.getAvatarUrl(c))
        .width(32).height(32)
        .borderRadius(16).backgroundColor('#F3F4F6')
        .margin({ right: 12 }).objectFit(ImageFit.Cover)
        .onClick(() => {
          if (c.user) this.onUserClick(c.user);
        })

      Column() {
        // 昵称
        Row() {
          Text(c.anonymous ? '匿名用户' : c.user?.nickname)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4B5563')
            .layoutWeight(1)

          // 如果是楼主(父评论)，可以加个标记，或者显示楼层
          if (isParent) {
            Text('楼主').fontSize(10).fontColor('white').backgroundColor('#2563EB')
              .padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4)
          }
        }
        .width('100%').alignItems(VerticalAlign.Center)

        // 正文
        Text() {
          // ArkUI 里不能写 const，只能写 if 判断
          if (c.replyUser && c.replyUser.nickname && c.replyObj && c.replyObj !== `comment${this.parentComment.id}`) {
            Span('回复 ')
              .fontSize(15).fontColor('#1F2937')

            Span(`@${c.replyUser.nickname}`)
              .fontSize(15).fontColor('#2563EB')

            Span('：')
              .fontSize(15).fontColor('#1F2937')
          }

          Span(c.text)
            .fontSize(15).fontColor('#1F2937')
        }
        .lineHeight(24).margin({ top: 4 })
        .onClick(() => this.onReply(c))

        // 图片
        this.CommentImageGrid(c.images)

        // 底部信息
        Row() {
          Text(this.getTimeText(c)).fontSize(12).fontColor('#9CA3AF').margin({ right: 12 })
          if (!isParent) {
            Text('回复').fontSize(12).fontColor('#4B5563').fontWeight(FontWeight.Bold)
          }
        }
        .margin({ top: 6, bottom: 6 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top) // 顶部对齐
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(isParent ? Color.White : Color.Transparent)
  }

  build() {
    Column() {
      // 1. 顶部标题栏
      Row() {
        Text(`共 ${this.parentComment.commentNum} 条回复`)
          .fontSize(16).fontWeight(FontWeight.Bold)
        Blank()
        Image($r('app.media.ic_public_cancel'))
          .width(20).height(20).fillColor('#9CA3AF')
          .onClick(() => this.onClose())
      }
      .width('100%').height(48).padding({ left: 16, right: 16 })
      .border({ width: { bottom: 0.5 }, color: '#E5E7EB' })
      .backgroundColor(Color.White)

      // 2. 列表区域
      List() {
        // 第一项：主评论自己
        ListItem() {
          Column() {
            this.ItemBuilder(this.parentComment, true)
            Divider().color('#F3F4F6').strokeWidth(8)
          }
          .padding({ left: 16, right: 16 })
        }

        // 后续项：子评论列表
        ForEach(this.subComments, (item: Comment) => {
          ListItem() {
            this.ItemBuilder(item, false)
          }
          .padding({ left: 16, right: 16 })
        })

        // 底部 Loading / NoMore
        ListItem() {
          Row() {
            if (this.isLoading) {
              LoadingProgress().width(20).height(20)
            } else if (!this.hasMore) {
              Text('没有更多了').fontSize(12).fontColor('#9CA3AF')
            }
          }
          .width('100%').height(40).justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onReachEnd(() => {
        this.loadData(true);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}