import { Comment, GalleryImage, GalleryUser } from '../../services/gallery/GalleryModels';
import { reactionService } from '../../services/gallery/ReactionService';
import { TimeUtils } from '../../utils/TimeUtils';
import { RCP_BASE_URL } from '../../core/network/bit101Session';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import router from '@ohos.router';
import curves from '@ohos.curves';
import { uiPushUrl, uiShowToast } from '../../utils/uiContextBridge';

@Component
export struct MoreCommentsSheet {
  // 核心参数
  @Prop parentComment: Comment;
  @State subCommentsOrder: string = 'new';

  // 交互回调
  onClose: () => void = () => {};
  onReply: (comment: Comment) => void = () => {};
  onUserClick: (user: GalleryUser) => void = () => {};
  onImageClick: (index: number, images: GalleryImage[]) => void = () => {};

  // 内部状态
  @State subComments: Comment[] = [];
  @State isLoading: boolean = false;
  @State hasMore: boolean = true;
  @State page: number = 0;

  aboutToAppear() {
    this.loadData(false);
  }

  // --- 数据加载 ---
  async loadData(isLoadMore: boolean) {
    if (this.isLoading) return;
    if (isLoadMore && !this.hasMore) return;

    this.isLoading = true;
    const requestPage = isLoadMore ? this.page + 1 : 0;

    try {
      const newItems = await reactionService.getCommentsForComment(
        this.parentComment.id,
        requestPage,
        this.subCommentsOrder
      );

      if (isLoadMore) {
        this.subComments = [...this.subComments, ...newItems];
      } else {
        this.subComments = newItems;
      }

      if (newItems.length > 0) {
        this.page = requestPage;
      }
      this.hasMore = newItems.length > 0;

    } catch (e) {
      console.error('[MoreComments] 加载失败', e);
    } finally {
      this.isLoading = false;
    }
  }

  // --- 交互逻辑 ---

  private showToast(msg: string) {
    uiShowToast(this.getUIContext(), { message: msg, duration: 1500 });
  }

  private copyCommentText(text: string) {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(pasteData);
      this.showToast('已复制');
    } catch (e) {
      this.showToast('复制失败');
    }
  }

  private async deleteComment(target: Comment) {
    try {
      const ok = await reactionService.deleteComment(target.id);
      if (ok) {
        // 使用 filter 产生新数组，触发 UI 刷新
        this.subComments = this.subComments.filter(item => item.id !== target.id);
        this.showToast('删除成功');
      } else {
        this.showToast('删除失败');
      }
    } catch (e) {
      this.showToast('删除出错');
    }
  }

  private goToReport(id: number) {
    // 【关键修复】跳转前先关闭弹窗，防止遮挡或返回时状态异常
    this.onClose();

    // 稍微延迟一点跳转（可选），让关闭动画更自然，或者直接跳转
    uiPushUrl(this.getUIContext(), {
      url: 'pages/ReportPage',
      params: { type: 'comment', id: id }
    });
  }

  // 【关键修复】更稳健的点赞逻辑
  private async toggleLike(item: Comment, index: number) {
    const oldLike = item.like;
    const oldNum = item.likeNum || 0;

    // 1. 乐观更新：直接修改数组内对象的属性
    // ArkTS 中不能使用 {...item} 展开对象，但可以直接修改属性
    this.subComments[index].like = !oldLike;
    this.subComments[index].likeNum = oldLike ? oldNum - 1 : oldNum + 1;

    // 2. 强制 UI 刷新：通过数组展开赋值 [...arr] 通知系统数据变了
    this.subComments = [...this.subComments];

    try {
      const res = await reactionService.likeComment(item.id);

      // 如果 res 存在且有效 (假设后端返回 { like: boolean, likeNum: number })
      if (res) {
        this.subComments[index].like = res.like;
        this.subComments[index].likeNum = res.likeNum;
        this.subComments = [...this.subComments]; // 再次刷新确信状态
      } else {
        // 如果返回 false 或 null，视为失败，抛错进入 catch 回滚
        throw new Error('Server returned failure');
      }
    } catch (e) {
      console.error('[MoreComments] Like failed', e);
      // 3. 失败回滚
      this.subComments[index].like = oldLike;
      this.subComments[index].likeNum = oldNum;
      this.subComments = [...this.subComments];
      this.showToast('操作失败');
    }
  }

  private getSubCommentsOrderLabel(): string {
    switch (this.subCommentsOrder) {
      case 'old': return '最旧排序';
      case 'like': return '高赞排序';
      case 'new': default: return '最新排序';
    }
  }

  private switchSubCommentsOrder(): void {
    if (this.subCommentsOrder === 'new') this.subCommentsOrder = 'old';
    else if (this.subCommentsOrder === 'old') this.subCommentsOrder = 'like';
    else this.subCommentsOrder = 'new';

    this.page = 0;
    this.hasMore = true;
    this.loadData(false);
  }

  // --- UI 辅助 ---
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

  private formatNumber(num: number | undefined): string {
    if (!num) return '0';
    if (num > 9999) return (num / 10000).toFixed(1) + 'w';
    return num.toString();
  }

  // 图片网格
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

  // 菜单 (点击更多 或 长按条目 时显示)
  @Builder
  MenuBuilder(c: Comment) {
    Menu() {
      MenuItem({ content: '复制内容' })
        .onClick(() => this.copyCommentText(c.text))

      if (c.own) {
        MenuItem({ content: '删除' })
          .contentFontColor('#EF4444') // 修复 fontColor 参数报错
          .onClick(() => this.deleteComment(c))
      }

      MenuItem({ content: '举报' })
        .onClick(() => this.goToReport(c.id))
    }
  }

  // 单条评论项
  @Builder
  ItemBuilder(c: Comment, isParent: boolean = false, index: number = -1) {
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
        // 昵称与点赞
        Row() {
          Text(c.anonymous ? '匿名用户' : c.user?.nickname)
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4B5563')
            .layoutWeight(1)

          if (isParent) {
            Text('楼主').fontSize(10).fontColor('white').backgroundColor('#2563EB')
              .padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4)
          } else {
            // 点赞区域
            Row() {
              Image(c.like ? $r('app.media.ic_public_heart_filled') : $r('app.media.ic_public_heart_outline'))
                .width(14).height(14)
                .fillColor(c.like ? '#EF4444' : '#9CA3AF')
                .animation({ duration: 300, curve: curves.springCurve(10, 1, 228, 30) })

              Text(this.formatNumber(c.likeNum))
                .fontSize(12).fontColor('#6B7280').margin({ left: 4 })
            }
            .onClick(() => {
              if (index >= 0) this.toggleLike(c, index);
            })
          }
        }
        .width('100%').alignItems(VerticalAlign.Center)

        // 正文
        Text() {
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

        // 底部 (时间、回复、更多)
        Row() {
          Text(this.getTimeText(c)).fontSize(12).fontColor('#9CA3AF').margin({ right: 12 })

          if (!isParent) {
            Text('回复').fontSize(12).fontColor('#4B5563').fontWeight(FontWeight.Bold)
              .onClick(() => this.onReply(c))
          }

          if (!isParent) {
            Text('更多')
              .fontSize(12).fontColor('#9CA3AF').margin({ left: 16 })
            // 点击 "更多" 触发菜单 (ResponseType.Tap 是默认)
              .bindMenu(this.MenuBuilder(c))
          }
        }
        .margin({ top: 6, bottom: 6 })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(isParent ? Color.White : Color.Transparent)
    // 【关键修复】整个 Item 绑定长按菜单 (模拟 Android/iOS 的长按效果)
    .bindContextMenu(this.MenuBuilder(c), ResponseType.LongPress)
  }

  build() {
    Column() {
      // 头部 (保留关闭按钮文字版)
      Row() {
        Blank().layoutWeight(1)
        Text(`共 ${this.parentComment.commentNum} 条回复`)
          .fontSize(16).fontWeight(FontWeight.Bold)
          .layoutWeight(2).textAlign(TextAlign.Center)
        Text('关闭')
          .fontSize(14).fontColor('#6B7280')
          .layoutWeight(1).textAlign(TextAlign.End)
          .onClick(() => this.onClose())
      }
      .width('100%').height(48)
      .padding({ left: 16, right: 16 })
      .border({ width: { bottom: 0.5 }, color: '#E5E7EB' })
      .backgroundColor(Color.White)

      // 排序
      Row() {
        Blank()
        Row() {
          Text(this.getSubCommentsOrderLabel())
            .fontSize(13).fontColor('#6B7280')
        }
        .onClick(() => this.switchSubCommentsOrder())
      }
      .width('100%').height(40)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 列表
      List() {
        // 主评论 (长按也可以有菜单，如果不想主评论有菜单，可以把 bindContextMenu 移到 else 分支里)
        ListItem() {
          Column() {
            this.ItemBuilder(this.parentComment, true)
            Divider().color('#F3F4F6').strokeWidth(8)
          }
          .padding({ left: 16, right: 16 })
        }

        // 子评论
        ForEach(this.subComments, (item: Comment, index: number) => {
          ListItem() {
            this.ItemBuilder(item, false, index)
          }
          .padding({ left: 16, right: 16 })
        })

        // 底部状态
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
    .width('100%').height('100%').backgroundColor(Color.White)
  }
}
