import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import curves from '@ohos.curves';
import { PosterDetail, GalleryImage, Comment, GalleryUser } from '../services/gallery/GalleryModels';
import { galleryService } from '../services/gallery/GalleryService';
import { TimeUtils } from '../utils/TimeUtils';
import { RCP_BASE_URL } from '../core/network/bit101Session';
import { PostCommentReq, reactionService } from '../services/gallery/ReactionService';
import { AvatarWithVerified } from '../components/gallery/AvatarWithVerified';
import { UserNameWithIdentity } from '../components/gallery/UserNameWithIdentity';
import { LinkableText } from '../components/gallery/LinkableText';
import { ImageViewer } from '../components/ImageViewer';
import { Logger } from '../utils/Logger';
import { CommentInputDialog } from '../components/gallery/CommentInputDialog';
import { MoreCommentsSheet } from '../components/gallery/MoreCommentsSheet';

interface ReplyContext {
  type: 'poster' | 'comment';
  mainCommentId?: number;
  replyComment?: Comment;
}

@Entry
@Component
export default struct PosterDetailPage {
  private logger = new Logger('PosterDetailPage');
  @State postId: number = 0;
  @State poster: PosterDetail | null = null;
  @State loading: boolean = true;
  @State comments: Comment[] = [];
  @State commentsLoading: boolean = false;

  @State isTitleVisibleInTopBar: boolean = false;
  private scroller: Scroller = new Scroller();
  private readonly SCROLL_THRESHOLD = 60;

  @State isPreviewOpen: boolean = false;
  @State previewIndex: number = 0;
  @State previewImages: GalleryImage[] = [];

  @State replyContext: ReplyContext = { type: 'poster' };
  @State showSubCommentSheet: boolean = false;
  @State selectedParentComment: Comment | null = null;

  private dialogController: CustomDialogController = new CustomDialogController({
    builder: CommentInputDialog({
      title: this.getDialogTitle(),
      onSend: (text, anon, mids) => this.handleSendComment(text, anon, mids)
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true,
    offset: { dx: 0, dy: -12 }
  });
  private async togglePosterLike(): Promise<void> {
    if (!this.poster) {
      return;
    }

    const oldLike = this.poster.like;
    const oldNum = this.poster.likeNum || 0;

    // 乐观更新：先改本地，提升手感
    this.poster.like = !oldLike;
    this.poster.likeNum = oldLike ? oldNum - 1 : oldNum + 1;

    const toastMsg = this.poster.like ? '点赞中...' : '取消点赞中...';
    this.showToast(toastMsg);

    const res = await reactionService.likePoster(this.poster.id);

    if (res) {
      // 以服务器结果为准，和 Android 一致
      this.poster.like = res.like;
      this.poster.likeNum = res.likeNum;
      this.showToast(res.like ? '点赞成功' : '已取消点赞');
    } else {
      // 失败就回滚
      this.poster.like = oldLike;
      this.poster.likeNum = oldNum;
      this.showToast('操作失败，请重试');
    }
  }
  private updateCommentLikeInList(
    list: Comment[],
    id: number,
    like: boolean,
    likeNum: number
  ): void {
    for (let i = 0; i < list.length; i++) {
      const item = list[i];

      if (item.id === id) {
        item.like = like;
        item.likeNum = likeNum;
      }

      if (item.sub && item.sub.length > 0) {
        this.updateCommentLikeInList(item.sub, id, like, likeNum);
      }
    }
  }

  // 点赞 / 取消点赞 某条评论（包括子评论）
  private async toggleCommentLike(target: Comment): Promise<void> {
    const id = target.id;
    const oldLike = target.like;
    const oldNum = target.likeNum || 0;

    // 乐观更新：原地改，再重新赋值触发 UI
    this.updateCommentLikeInList(
      this.comments,
      id,
      !oldLike,
      oldLike ? oldNum - 1 : oldNum + 1
    );
    this.comments = [...this.comments]; // 触发刷新

    this.showToast(oldLike ? '取消点赞中...' : '点赞中...');

    const res = await reactionService.likeComment(id);

    if (res) {
      this.updateCommentLikeInList(this.comments, id, res.like, res.likeNum);
      this.comments = [...this.comments];
      this.showToast(res.like ? '点赞成功' : '已取消点赞');
    } else {
      // 失败回滚
      this.updateCommentLikeInList(this.comments, id, oldLike, oldNum);
      this.comments = [...this.comments];
      this.showToast('操作失败，请重试');
    }
  }


  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    const idParam = params?.['id'];

    if (idParam !== undefined) {
      this.postId = Number(idParam);
      this.loadPoster();
      this.loadComments();
    } else {
      this.loading = false;
    }
  }

  private async loadComments(): Promise<void> {
    this.commentsLoading = true;
    const list = await reactionService.getCommentsForPoster(this.postId, 'new');
    this.comments = list;
    this.commentsLoading = false;
  }

  private async loadPoster(): Promise<void> {
    this.loading = true;
    const detail = await galleryService.getPosterById(this.postId);
    if (detail) {
      this.poster = detail;
    }
    this.loading = false;
  }

  private showToast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 1500 });
  }

  private getDialogTitle(): string {
    if (this.replyContext.type === 'poster') {
      return '评论帖子';
    } else {
      const targetUser = this.replyContext.replyComment?.user;
      const name = this.replyContext.replyComment?.anonymous
        ? '匿名用户'
        : (targetUser?.nickname || '未知用户');
      return `回复 @${name}`;
    }
  }

  private jumpToUser(user?: GalleryUser | null): void {
    const targetUid = user?.id;
    if (!targetUid || targetUid === '0' || targetUid === '-1') {
      this.showToast('无法查看该用户详情');
      return;
    }
    router.pushUrl({
      url: 'pages/UserDetailPage',
      params: { uid: parseInt(targetUid) }
    });
  }

  private openImageViewer(index: number, images: GalleryImage[]): void {
    this.logger.info(`[Viewer] Open: index=${index}, count=${images.length}`);
    if (this.showSubCommentSheet) {
      this.showSubCommentSheet = false;
    }
    this.previewImages = [...images];
    this.previewIndex = index;
    this.isPreviewOpen = true;
  }

  private async handleSendComment(text: string, isAnonymous: boolean, imageMids: string[]): Promise<void> {
    if (!this.poster) return;

    let req: PostCommentReq;

    if (this.replyContext.type === 'poster') {
      req = {
        obj: `poster${this.poster.id}`,
        text: text,
        anonymous: isAnonymous,
        image_mids: imageMids,
        reply_uid: 0
      };
    } else {
      if (!this.replyContext.mainCommentId || !this.replyContext.replyComment) return;

      const mainId = this.replyContext.mainCommentId;
      const subId = this.replyContext.replyComment.id;

      req = {
        obj: `comment${mainId}`,
        text: text,
        anonymous: isAnonymous,
        image_mids: imageMids
      };

      if (mainId !== subId) {
        req.reply_obj = `comment${subId}`;
        const uidStr = this.replyContext.replyComment.user?.id;
        if (uidStr) {
          req.reply_uid = Number(uidStr);
        }
      }
    }

    this.showToast('发送中...');
    const newComment = await reactionService.postComment(req);

    if (newComment) {
      this.showToast('评论成功！');
      this.loadComments();
      if (this.replyContext.type === 'poster' && this.poster) {
        this.poster.commentNum = (this.poster.commentNum || 0) + 1;
      }
    } else {
      this.showToast('评论失败，请重试');
    }
  }

  @Builder
  SubCommentSheetBuilder() {
    if (this.selectedParentComment) {
      MoreCommentsSheet({
        parentComment: this.selectedParentComment,
        onClose: () => {
          this.showSubCommentSheet = false;
        },
        onReply: (targetComment) => {
          this.replyContext = {
            type: 'comment',
            mainCommentId: this.selectedParentComment?.id,
            replyComment: targetComment
          };
          this.dialogController.open();
        },
        onUserClick: (u) => this.jumpToUser(u),
        onImageClick: (idx, imgs) => { this.openImageViewer(idx, imgs); }
      })
    }
  }

  build() {
    Stack() {
      // --- 页面内容 ---
      Column() {
        this.TopBar();

        if (this.loading && !this.poster) {
          this.LoadingView();
        } else if (!this.poster) {
          this.ErrorView();
        } else {
          Scroll(this.scroller) {
            Column() {
              this.PosterContent(this.poster as PosterDetail);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor(Color.White)
          .align(Alignment.TopStart)
          .onScroll(() => {
            const yOffset = this.scroller.currentOffset().yOffset;
            if (yOffset > this.SCROLL_THRESHOLD && !this.isTitleVisibleInTopBar) {
              this.isTitleVisibleInTopBar = true;
            } else if (yOffset <= this.SCROLL_THRESHOLD && this.isTitleVisibleInTopBar) {
              this.isTitleVisibleInTopBar = false;
            }
          })
        }

        if (this.poster) {
          this.BottomBar();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

      // --- 全屏图片预览 (Stack 覆盖) ---
      if (this.isPreviewOpen) {
        Column() {
          ImageViewer({
            images: this.previewImages,
            initialIndex: this.previewIndex,
            onClose: () => {
              this.logger.info('[Viewer] Close');
              this.isPreviewOpen = false;
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .zIndex(10000)
      }
    }
    .width('100%')
    .height('100%')
    // 绑定子评论弹窗 (注意这里没有括号)
    .bindSheet(this.showSubCommentSheet, this.SubCommentSheetBuilder, {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: Color.White,
      onDisappear: () => {
        this.showSubCommentSheet = false;
        this.selectedParentComment = null;
      }
    })
  }

  @Builder LoadingView() {
    Column() { Text('正在加载帖子...').fontSize(16).fontColor('#9CA3AF') }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  @Builder ErrorView() {
    Column() { Text('未找到帖子').fontSize(16).fontColor('#9CA3AF') }
    .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
  }

  @Builder
  TopBar(): void {
    Row() {
      Image($r('app.media.ic_public_back'))
        .width(24).height(24).fillColor('#1F2937')
        .onClick(() => router.back())
        .margin({ right: 12 });

      Stack() {
        if (this.poster) {
          Row() {
            AvatarWithVerified({
              user: this.poster.user,
              avatarSize: 32,
              onClickUser: () => this.jumpToUser(this.poster?.user)
            })
            Column() {
              UserNameWithIdentity({ user: this.poster.user, fontSize: 14, fontColor: '#1F2937' })
            }
            .alignItems(HorizontalAlign.Start).margin({ left: 8 })
            .onClick(() => this.jumpToUser(this.poster?.user))
          }
          .width('100%')
          .opacity(this.isTitleVisibleInTopBar ? 0 : 1)
          .animation({ duration: 200 })
          .visibility(this.isTitleVisibleInTopBar ? Visibility.None : Visibility.Visible)

          Text(this.poster.title)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1F2937')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .opacity(this.isTitleVisibleInTopBar ? 1 : 0)
            .animation({ duration: 200 })
            .visibility(this.isTitleVisibleInTopBar ? Visibility.Visible : Visibility.None)
        }
      }
      .layoutWeight(1).alignContent(Alignment.Start)

      Image($r('app.media.ic_public_more'))
        .width(24).height(24).fillColor('#1F2937').margin({ left: 12 })
        .onClick(() => this.showToast('更多操作'));
    }
    .width('100%').height(56).padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center).backgroundColor(Color.White)
    .shadow({ radius: 3, color: '#0A000000', offsetY: 1 }).zIndex(10)
  }

  @Builder
  BottomBar(): void {
    Row() {
      Row() {
        Text('快来评论吧').fontSize(14).fontColor('#9CA3AF')
      }
      .height(36).layoutWeight(1).backgroundColor('#F3F4F6')
      .borderRadius(18).padding({ left: 16 })
      .alignItems(VerticalAlign.Center).margin({ right: 16 })
      .onClick(() => {
        this.replyContext = { type: 'poster' };
        this.dialogController.open();
      });

      Row() {
        Image(this.poster?.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
          .width(26).height(26)
          .fillColor(this.poster?.like ? '#EF4444' : '#6B7280')
          .onClick(() => {
            this.togglePosterLike();
          })
          .animation({ duration: 300, curve: curves.springCurve(10, 1, 228, 30) })

        Text(this.formatNumber(this.poster?.likeNum || 0))
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1F2937').margin({ left: 4 });
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%').height(60).padding({ left: 12, right: 16 })
    .backgroundColor(Color.White).border({ width: { top: 0.5 }, color: '#E5E7EB' })
  }

  @Builder
  PosterContent(p: PosterDetail): void {
    Column() {
      Text(p.title)
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#111827')
        .lineHeight(30).margin({ bottom: 8 })
        .copyOption(CopyOptions.LocalDevice);

      if (p.claim && p.claim.id !== 0) {
        Text(`创作者声明：${p.claim.text}`)
          .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#EF4444').margin({ bottom: 8 });
      }

      if (p.text) {
        LinkableText({
          text: p.text, fontSize: 16, fontColor: '#1F2937', lineHeight: 26
        }).margin({ bottom: 12 }).width('100%')
      }

      if (p.images && p.images.length > 0) {
        this.ImageGrid(p.images);
      }

      if (p.tags && p.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(p.tags, (tag: string) => {
            Text('#' + tag)
              .fontSize(15).fontColor('#2563EB').margin({ right: 12, bottom: 6 })
              .onClick(() => this.showToast(`复制标签: #${tag}`));
          })
        }.margin({ top: 4, bottom: 4 });
      }

      Text(`最后编辑于：${this.getTimeText(p)}`)
        .fontSize(12).fontColor('#9CA3AF').margin({ top: 4, bottom: 16 });

      Divider().color('#F3F4F6').strokeWidth(8).margin({ left: -16, right: -16 });

      this.CommentsSection(p);
    }
    .padding({ left: 16, right: 16, top: 16, bottom: 24 }).alignItems(HorizontalAlign.Start)
  }

  @Builder
  ImageGrid(images: GalleryImage[]): void {
    Grid() {
      ForEach(images, (img: GalleryImage, index: number) => {
        GridItem() {
          Image(this.getImageUrl(img.url))
            .width('100%').aspectRatio(1).objectFit(ImageFit.Cover)
            .borderRadius(6).backgroundColor('#F3F4F6')
            .onClick(() => {
              this.logger.info(`[PostImage] Click index=${index}`);
              this.openImageViewer(index, images);
            })
        }
      })
    }
    .columnsTemplate('1fr 1fr 1fr').columnsGap(4).rowsGap(4)
    .height(Math.ceil(images.length / 3) * 120).margin({ bottom: 12 });
  }

  @Builder
  CommentImageGrid(images: GalleryImage[]): void {
    if (images && images.length > 0) {
      Grid() {
        ForEach(images, (img: GalleryImage, index: number) => {
          GridItem() {
            Image(this.getImageUrl(img.url))
              .width('100%').aspectRatio(1).objectFit(ImageFit.Cover)
              .borderRadius(4).backgroundColor('#F3F4F6')
              .onClick(() => {
                this.logger.info(`[CommentImage] Click index=${index}`);
                this.openImageViewer(index, images);
              })
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr').columnsGap(4).rowsGap(4)
      .height(Math.ceil(images.length / 3) * 90).margin({ top: 8 });
    }
  }

  @Builder
  CommentsSection(p: PosterDetail): void {
    Column() {
      Row() {
        Text(`评论 ${p.commentNum || 0}`)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#111827');
        Blank();
        Row() {
          Text('默认排序').fontSize(13).fontColor('#6B7280');
        }.onClick(() => this.showToast('切换排序'));
      }
      .width('100%').height(48).alignItems(VerticalAlign.Center);

      if (this.commentsLoading && this.comments.length === 0) {
        Text('加载评论中...').fontSize(14).fontColor('#9CA3AF').margin({ top: 20 });
      } else if (this.comments.length === 0) {
        Column() {
          Image($r('app.media.ic_public_empty_comment'))
            .width(40).height(40).fillColor('#D1D5DB').margin({ bottom: 8 });
          Text('这里没有评论呢').fontSize(14).fontColor('#9CA3AF');
        }
        .width('100%').padding({ top: 32, bottom: 32 }).alignItems(HorizontalAlign.Center);
      } else {
        ForEach(this.comments, (c: Comment) => {
          this.CommentItem(c);
        });
        Text('没有更多评论了')
          .fontSize(12).fontColor('#D1D5DB').width('100%')
          .textAlign(TextAlign.Center).padding(24);
      }
    }
    .width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8 })
  }

  @Builder
  CommentItem(c: Comment): void {
    Row() {
      Image(this.getCommentAvatarUrl(c))
        .width(36).height(36)
        .borderRadius(18).backgroundColor('#F3F4F6')
        .objectFit(ImageFit.Cover).margin({ right: 12 })
        .onClick(() => this.jumpToUser(c.user))

      Column() {
        Row() {
          Text(this.getCommentNickname(c))
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4B5563').layoutWeight(1);

          Row() {
            Image(c.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
              .width(14).height(14).fillColor(c.like ? '#EF4444' : '#9CA3AF')
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })
            Text(this.formatNumber(c.likeNum))
              .fontSize(12).fontColor('#6B7280').margin({ left: 4 });
          }
          .onClick(() => {
            this.toggleCommentLike(c);
          })
        }
        .width('100%').alignItems(VerticalAlign.Center);

        Text(c.text)
          .fontSize(15).fontColor('#1F2937').lineHeight(22).margin({ top: 4 })
          .onClick(() => {
            this.replyContext = { type: 'comment', mainCommentId: c.id, replyComment: c };
            this.dialogController.open();
          });

        this.CommentImageGrid(c.images);

        Row() {
          Text(this.getCommentTimeText(c)).fontSize(12).fontColor('#9CA3AF').margin({ right: 12 });
          Text('回复').fontSize(12).fontColor('#4B5563').fontWeight(FontWeight.Bold);
        }.margin({ top: 6, bottom: 6 });

        if (c.sub && c.sub.length > 0) {
          Column() {
            ForEach(c.sub, (item: Comment) => {
              this.SubCommentItem(c, item);
            }, (item: Comment) => item.id.toString());

            if (c.commentNum > c.sub.length) {
              Text(`查看共 ${c.commentNum} 条回复 >`)
                .fontSize(13).fontColor('#2563EB').padding({ top: 8, bottom: 4 })
                .fontWeight(FontWeight.Medium)
                .onClick(() => {
                  this.selectedParentComment = c;
                  this.showSubCommentSheet = true;
                });
            }
          }
          .width('100%').backgroundColor('#F9FAFB').borderRadius(8).padding(8).margin({ top: 4 });
        }
        Divider().color('#E5E7EB').margin({ top: 12 });
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start);
    }
    .width('100%').alignItems(VerticalAlign.Top).padding({ top: 12 });
  }
  private isLevel3(parentComment: Comment, subComment: Comment): boolean {
    const hasReplyUser = !!(subComment.replyUser && subComment.replyUser.nickname);
    const hasReplyObj = !!subComment.replyObj;
    const isReplyToParent = subComment.replyObj === `comment${parentComment.id}`;
    const result = hasReplyUser && hasReplyObj && !isReplyToParent;

    // 用你自己的 Logger 打日志
    this.logger.info(
      `[SubCommentItem] parentId=${parentComment.id}, subId=${subComment.id}, ` +
        `replyObj=${subComment.replyObj}, hasReplyUser=${hasReplyUser}, ` +
        `hasReplyObj=${hasReplyObj}, isReplyToParent=${isReplyToParent}, isLevel3=${result}`
    );

    return result;
  }


  @Builder
  SubCommentItem(parentComment: Comment, subComment: Comment): void {
    // 💡 [关键修复]：将变量定义移到 UI 组件外

    Row() {
      Image(this.getCommentAvatarUrl(subComment))
        .width(24).height(24).borderRadius(12).backgroundColor('#E5E7EB')
        .margin({ right: 8 }).objectFit(ImageFit.Cover)
        .onClick(() => this.jumpToUser(subComment.user));

      Column() {
        Row() {
          Text(this.getCommentNickname(subComment))
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4B5563').layoutWeight(1);

          Row() {
            Image(subComment.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
              .width(14).height(14)
              .fillColor(subComment.like ? '#EF4444' : '#9CA3AF')
              .animation({ duration: 300, curve: Curve.FastOutSlowIn })
            Text(this.formatNumber(subComment.likeNum))
              .fontSize(12).fontColor('#6B7280').margin({ left: 4 });
          }
          .onClick(() => {
            this.toggleCommentLike(subComment);
          })
        }
        .width('100%').alignItems(VerticalAlign.Center);

        Text() {
          if (this.isLevel3(parentComment, subComment)) {
            Span('回复 ').fontSize(15).fontColor('#1F2937')
            Span(`@${subComment.replyUser!.nickname}`)
              .fontSize(15).fontColor('#2563EB')
              .onClick(() => this.jumpToUser(subComment.replyUser ?? undefined))
            Span('：').fontSize(15).fontColor('#1F2937')
          }
          Span(subComment.text).fontSize(15).fontColor('#1F2937')
        }
        .lineHeight(24).margin({ top: 4 })
        .onClick(() => {
          this.replyContext = {
            type: 'comment',
            mainCommentId: parentComment.id,
            replyComment: subComment
          };
          this.dialogController.open();
        });

        this.CommentImageGrid(subComment.images);
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1);
    }
    .width('100%').margin({ bottom: 12 }).alignItems(VerticalAlign.Top);
  }

  private formatNumber(num: number | undefined): string {
    if (!num) return '0';
    if (num > 9999) return (num / 10000).toFixed(1) + 'w';
    return num.toString();
  }
  private getTimeText(p: PosterDetail): string {
    const rawTime = p.editTime || p.createTime;
    return TimeUtils.getRelativeTime(rawTime);
  }
  private getCommentNickname(c: Comment): string {
    return c.anonymous ? '匿名用户' : (c.user?.nickname || '匿名用户');
  }
  private getCommentTimeText(c: Comment): string {
    return TimeUtils.getRelativeTime(c.updateTime || c.createTime);
  }
  private getCommentAvatarUrl(c: Comment): string | Resource {
    if (c.anonymous || !c.user || !c.user.avatar) return $r('app.media.startIcon');
    return this.getImageUrl(c.user.avatar);
  }
  private getImageUrl(url: string): string {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${RCP_BASE_URL}${url}`;
  }
}